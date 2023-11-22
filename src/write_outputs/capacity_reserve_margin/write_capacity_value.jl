function write_capacity_value(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]
	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
	THERM_ALL = inputs["THERM_ALL"]
	VRE = inputs["VRE"]
	HYDRO_RES = inputs["HYDRO_RES"]
	STOR_ALL = inputs["STOR_ALL"]
	FLEX = inputs["FLEX"]
	MUST_RUN = inputs["MUST_RUN"]
	VRE_STOR = inputs["VRE_STOR"]

    minimum_plant_size = 1 # MW
    minimum_crm_price = 1 # $/MW
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
    eTotalCap = value.(EP[:eTotalCap])
    large_plants = findall(>=(minimum_plant_size), eTotalCap * scale_factor)

	THERM_ALL_EX = intersect(THERM_ALL, large_plants)
	VRE_EX = intersect(VRE, large_plants)
	HYDRO_RES_EX = intersect(HYDRO_RES, large_plants)
	STOR_ALL_EX = intersect(STOR_ALL, large_plants)
	FLEX_EX = intersect(FLEX, large_plants)
	MUST_RUN_EX = intersect(MUST_RUN, large_plants)
	# Will only be activated if grid connection capacity exists (because may build standalone storage/VRE, which will only be telling by grid connection capacity)
	VRE_STOR_EX = intersect(VRE_STOR, large_plants)
	if !isempty(VRE_STOR_EX)
		DC_DISCHARGE = inputs["VS_STOR_DC_DISCHARGE"]
		DC_CHARGE = inputs["VS_STOR_DC_CHARGE"]
		VRE_STOR_STOR_EX = intersect(inputs["VS_STOR"], VRE_STOR_EX)
		DC_DISCHARGE_EX = intersect(DC_DISCHARGE, VRE_STOR_EX)
		AC_DISCHARGE_EX = intersect(inputs["VS_STOR_AC_DISCHARGE"], VRE_STOR_EX)
		DC_CHARGE_EX = intersect(DC_CHARGE, VRE_STOR_EX)
		AC_CHARGE_EX = intersect(inputs["VS_STOR_AC_CHARGE"], VRE_STOR_EX)
		dfVRE_STOR = inputs["dfVRE_STOR"]
	end

    crm_derating(i, y::Vector{Int}) = dfGen[y, Symbol("CapRes_$i")]'
    max_power(t::Vector{Int}, y::Vector{Int}) = inputs["pP_Max"][y, t]'
	
	totalcap = repeat(eTotalCap, 1, T)
	dfCapValue = DataFrame()
	for i in 1:inputs["NCapacityReserveMargin"]
		temp_dfCapValue = DataFrame(Resource = inputs["RESOURCES"], Zone = dfGen[!, :Zone], Reserve = fill(Symbol("CapRes_$i"), G))
		capvalue = zeros(G, T)
		capvalue_new = zeros(T, G)
        is_risky = zeros(G, T)
		cap_derate = zeros(G, T)
		riskyhour = findall(>=(minimum_crm_price), capacity_reserve_margin_price(EP, inputs, setup, i))
		is_risky[:, riskyhour] = ones(Int, G, length(riskyhour))

        power(y) = value.(EP[:vP][riskyhour, y])'

        cap_derate[large_plants, :] = repeat(crm_derating(i, large_plants), 1, T)

        capvalue_new[riskyhour, THERM_ALL_EX] .= crm_derating(i, THERM_ALL_EX)

        capvalue_new[riskyhour, VRE_EX] .= crm_derating(i, VRE_EX) .* max_power(riskyhour, VRE_EX)

        capvalue_new[riskyhour, MUST_RUN_EX] = crm_derating(i, MUST_RUN_EX) .* max_power(riskyhour, VRE_EX)

        capvalue_new[riskyhour, HYDRO_RES_EX] = crm_derating(i, HYDRO_RES_EX) .* power(HYDRO_RES_EX) ./ eTotalCap[HYDRO_RES_EX]'

        capvalue .+= collect(transpose(capvalue_new))

		if !isempty(STOR_ALL_EX)
			capvalue[STOR_ALL_EX, :] = cap_derate[STOR_ALL_EX, :] .* ((value.(EP[:vP][STOR_ALL_EX, :]) - value.(EP[:vCHARGE][STOR_ALL_EX, :]).data  + value.(EP[:vCAPRES_discharge][STOR_ALL_EX, :]).data - value.(EP[:vCAPRES_charge][STOR_ALL_EX, :]).data)) .* is_risky[STOR_ALL_EX, :] ./ totalcap[STOR_ALL_EX, :]
		end
		if !isempty(FLEX_EX)
			capvalue[FLEX_EX, :] = cap_derate[FLEX_EX, :] .* ((value.(EP[:vCHARGE_FLEX][FLEX_EX, :]).data - value.(EP[:vP][FLEX_EX, :]))) .* is_risky[FLEX_EX, :] ./ totalcap[FLEX_EX, :]
		end
		if !isempty(VRE_STOR_EX)
			capvalue_dc_discharge = zeros(G, T)
			capvalue_dc_discharge[DC_DISCHARGE, :] = value.(EP[:vCAPRES_DC_DISCHARGE][DC_DISCHARGE, :].data) .* dfVRE_STOR[(dfVRE_STOR.STOR_DC_DISCHARGE.!=0), :EtaInverter]
			capvalue_dc_charge = zeros(G, T)
			capvalue_dc_charge[DC_CHARGE, :] = value.(EP[:vCAPRES_DC_CHARGE][DC_CHARGE, :].data) ./ dfVRE_STOR[(dfVRE_STOR.STOR_DC_CHARGE.!=0), :EtaInverter]
			capvalue[VRE_STOR_EX, :] = cap_derate[VRE_STOR_EX, :] .* (value.(EP[:vP][VRE_STOR_EX, :])) .* is_risky[VRE_STOR_EX, :] ./ totalcap[VRE_STOR_EX, :]
			capvalue[VRE_STOR_STOR_EX, :] .-= cap_derate[VRE_STOR_STOR_EX, :] .* (value.(EP[:vCHARGE_VRE_STOR][VRE_STOR_STOR_EX, :].data)) .* is_risky[VRE_STOR_STOR_EX, :] ./ totalcap[VRE_STOR_STOR_EX, :]
			capvalue[DC_DISCHARGE_EX, :] .+= cap_derate[DC_DISCHARGE_EX, :] .* capvalue_dc_discharge[DC_DISCHARGE_EX, :] .* is_risky[DC_DISCHARGE_EX, :] ./ totalcap[DC_DISCHARGE_EX, :]
			capvalue[AC_DISCHARGE_EX, :] .+= cap_derate[AC_DISCHARGE_EX, :] .* (value.(EP[:vCAPRES_AC_DISCHARGE][AC_DISCHARGE_EX, :]).data) .* is_risky[AC_DISCHARGE_EX, :] ./ totalcap[AC_DISCHARGE_EX, :]
			capvalue[DC_CHARGE_EX, :] .-= cap_derate[DC_CHARGE_EX, :] .* capvalue_dc_charge[DC_CHARGE_EX, :] .* is_risky[DC_CHARGE_EX, :] ./ totalcap[DC_CHARGE_EX, :]
			capvalue[AC_CHARGE_EX, :] .-= cap_derate[AC_CHARGE_EX, :] .* (value.(EP[:vCAPRES_AC_CHARGE][AC_CHARGE_EX, :]).data) .* is_risky[AC_CHARGE_EX, :] ./ totalcap[AC_CHARGE_EX, :]
		end
		temp_dfCapValue = hcat(temp_dfCapValue, DataFrame(capvalue, :auto))
		auxNew_Names = [Symbol("Resource"); Symbol("Zone"); Symbol("Reserve"); [Symbol("t$t") for t in 1:T]]
		rename!(temp_dfCapValue, auxNew_Names)
		append!(dfCapValue, temp_dfCapValue)
	end
	write_simple_csv(joinpath(path, "CapacityValue.csv"), dfCapValue)
end

@doc raw"""
    capacity_reserve_margin_price(EP::Model,
                                  inputs::Dict,
                                  setup::Dict,
                                  capres_zone::Int)::Vector{Float64}

Marginal electricity price for each model zone and time step.
This is equal to the dual variable of the power balance constraint.
When solving a linear program (i.e. linearized unit commitment or economic dispatch)
this output is always available; when solving a mixed integer linear program, this can
be calculated only if `WriteShadowPrices` is activated.

    Returns a vector, with units of $/MW
"""
function capacity_reserve_margin_price(EP::Model, inputs::Dict, setup::Dict, capres_zone::Int)::Vector{Float64}
    ω = inputs["omega"]
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
    return dual.(EP[:cCapacityResMargin][capres_zone, :]) ./ ω * scale_factor
end
