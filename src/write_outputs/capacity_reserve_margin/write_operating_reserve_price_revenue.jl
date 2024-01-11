@doc raw"""
	write_operating_reserve_price_revenue(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for reporting the operating reserve prices and revenue earned by each generator listed in the input file.
    GenX will print this file only when operating reserve is modeled and the shadow price can be obtained form the solver.
    Each row corresponds to a generator, and each column starting from the 6th to the second last is the total revenue from each operating reserve constraint.
    The revenue is calculated as the operating reserve contribution of each time steps multiplied by the shadow price, and then the sum is taken over all modeled time steps.
    The last column is the total revenue received from all operating reserve constraints.
    As a reminder, GenX models the operating reserve at the time-dependent level, and each constraint either stands for an overall market or a locality constraint.
"""
function write_operating_reserve_revenue(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
  scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
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
	dfVRE_STOR = inputs["dfVRE_STOR"]
	if !isempty(VRE_STOR)
		VRE_STOR_STOR = inputs["VS_STOR"]
		DC_DISCHARGE = inputs["VS_STOR_DC_DISCHARGE"]
		AC_DISCHARGE = inputs["VS_STOR_AC_DISCHARGE"]
		DC_CHARGE = inputs["VS_STOR_DC_CHARGE"]
		AC_CHARGE = inputs["VS_STOR_AC_CHARGE"]
		dfVRE_STOR = inputs["dfVRE_STOR"]
	end
	dfOpResRevenue = DataFrame(Region = dfGen.region, Resource = inputs["RESOURCES"], Zone = dfGen.Zone, Cluster = dfGen.cluster)
	annual_sum = zeros(G)
	for t in 1:T
		weighted_reg_price = operating_regulation_price(EP, inputs, setup) .* inputs["omega"]
		weighted_rsv_price = operating_reserve_price(EP, inputs, setup) .* inputs["omega"]
		sym = Symbol("CapRes_$i")
		tempresrev = zeros(G)
		tempresrev[THERM_ALL] = thermal_plant_effective_capacity(EP, inputs, THERM_ALL, i)' * weighted_price
		tempresrev[VRE] = dfGen[VRE, sym] .* (value.(EP[:eTotalCap][VRE])) .* (inputs["pP_Max"][VRE, :] * weighted_price)
		tempresrev[MUST_RUN] = dfGen[MUST_RUN, sym] .* (value.(EP[:eTotalCap][MUST_RUN])) .* (inputs["pP_Max"][MUST_RUN, :] * weighted_price)
		tempresrev[HYDRO_RES] = dfGen[HYDRO_RES, sym] .* (value.(EP[:vP][HYDRO_RES, :]) * weighted_price)
		if !isempty(STOR_ALL)
			tempresrev[STOR_ALL] = dfGen[STOR_ALL, sym] .* ((value.(EP[:vP][STOR_ALL, :]) - value.(EP[:vCHARGE][STOR_ALL, :]).data + value.(EP[:vCAPRES_discharge][STOR_ALL, :]).data - value.(EP[:vCAPRES_charge][STOR_ALL, :]).data) * weighted_price)
		end
		if !isempty(FLEX)
			tempresrev[FLEX] = dfGen[FLEX, sym] .* ((value.(EP[:vCHARGE_FLEX][FLEX, :]).data - value.(EP[:vP][FLEX, :])) * weighted_price)
		end
		if !isempty(VRE_STOR)
			sym_vs = Symbol("CapResVreStor_$i")
			tempresrev[VRE_STOR] = dfVRE_STOR[!, sym_vs] .* ((value.(EP[:vP][VRE_STOR, :])) * weighted_price)
			tempresrev[VRE_STOR_STOR] .-= dfVRE_STOR[((dfVRE_STOR.STOR_DC_DISCHARGE.!=0) .| (dfVRE_STOR.STOR_DC_CHARGE.!=0) .| (dfVRE_STOR.STOR_AC_DISCHARGE.!=0) .|(dfVRE_STOR.STOR_AC_CHARGE.!=0)), sym_vs] .* (value.(EP[:vCHARGE_VRE_STOR][VRE_STOR_STOR, :]).data * weighted_price)
			tempresrev[DC_DISCHARGE] .+= dfVRE_STOR[(dfVRE_STOR.STOR_DC_DISCHARGE.!=0), sym_vs] .* ((value.(EP[:vCAPRES_DC_DISCHARGE][DC_DISCHARGE, :]).data .* dfVRE_STOR[(dfVRE_STOR.STOR_DC_DISCHARGE.!=0), :EtaInverter]) * weighted_price)
			tempresrev[AC_DISCHARGE] .+= dfVRE_STOR[(dfVRE_STOR.STOR_AC_DISCHARGE.!=0), sym_vs] .* ((value.(EP[:vCAPRES_AC_DISCHARGE][AC_DISCHARGE, :]).data) * weighted_price)
			tempresrev[DC_CHARGE] .-= dfVRE_STOR[(dfVRE_STOR.STOR_DC_CHARGE.!=0), sym_vs] .* ((value.(EP[:vCAPRES_DC_CHARGE][DC_CHARGE, :]).data ./ dfVRE_STOR[(dfVRE_STOR.STOR_DC_CHARGE.!=0), :EtaInverter]) * weighted_price)
			tempresrev[AC_CHARGE] .-= dfVRE_STOR[(dfVRE_STOR.STOR_AC_CHARGE.!=0), sym_vs] .* ((value.(EP[:vCAPRES_AC_CHARGE][AC_CHARGE, :]).data) * weighted_price)
		end
		tempresrev *= scale_factor
		annual_sum .+= tempresrev
		dfResRevenue = hcat(dfResRevenue, DataFrame([tempresrev], [sym]))
	end
	dfResRevenue.AnnualSum = annual_sum
	CSV.write(joinpath(path, "ReserveMarginRevenue.csv"), dfResRevenue)
	return dfResRevenue
end

function operating_regulation_price(EP::Model, inputs::Dict, setup::Dict)::Vector{Float64}
    ω = inputs["omega"]
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
    return dual.(EP[:cReg]) ./ ω * scale_factor
end

function operating_reserve_price(EP::Model, inputs::Dict, setup::Dict)::Vector{Float64}
    ω = inputs["omega"]
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
    return dual.(EP[:cRsvReq]) ./ ω * scale_factor
end
