function write_capacity_value(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    gen = inputs["RESOURCES"]
    zones = zone_id.(gen)

    G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
    T = inputs["T"]     # Number of time steps (hours)
    THERM_ALL = inputs["THERM_ALL"]
    VRE = inputs["VRE"]
    HYDRO_RES = inputs["HYDRO_RES"]
    STOR_ALL = inputs["STOR_ALL"]
    FLEX = inputs["FLEX"]
    MUST_RUN = inputs["MUST_RUN"]
    VRE_STOR = inputs["VRE_STOR"]

    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
    eTotalCap = value.(EP[:eTotalCap])

    minimum_plant_size = 1 # MW
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
    end

    crm_derate(i, y::Vector{Int}) = derating_factor.(gen[y], tag = i)'
    max_power(t::Vector{Int}, y::Vector{Int}) = inputs["pP_Max"][y, t]'
    total_cap(y::Vector{Int}) = eTotalCap[y]'

    dfCapValue = DataFrame()
    for i in 1:inputs["NCapacityReserveMargin"]
        capvalue = zeros(T, G)

        minimum_crm_price = 1 # $/MW
        riskyhour = findall(>=(minimum_crm_price),
            capacity_reserve_margin_price(EP, inputs, setup, i))

        power(y::Vector{Int}) = value.(EP[:vP][y, riskyhour])'

        capvalue[riskyhour, THERM_ALL_EX] = thermal_plant_effective_capacity(EP,
            inputs,
            THERM_ALL_EX,
            i,
            riskyhour) ./ total_cap(THERM_ALL_EX)

        capvalue[riskyhour, VRE_EX] = crm_derate(i, VRE_EX) .* max_power(riskyhour, VRE_EX)

        capvalue[riskyhour, MUST_RUN_EX] = crm_derate(i, MUST_RUN_EX) .*
                                           max_power(riskyhour, MUST_RUN_EX)

        capvalue[riskyhour, HYDRO_RES_EX] = crm_derate(i, HYDRO_RES_EX) .*
                                            power(HYDRO_RES_EX) ./ total_cap(HYDRO_RES_EX)

        if !isempty(STOR_ALL_EX)
            charge = value.(EP[:vCHARGE][STOR_ALL_EX, riskyhour].data)'
            capres_discharge = value.(EP[:vCAPRES_discharge][STOR_ALL_EX, riskyhour].data)'
            capres_charge = value.(EP[:vCAPRES_charge][STOR_ALL_EX, riskyhour].data)'

            capvalue[riskyhour, STOR_ALL_EX] = crm_derate(i, STOR_ALL_EX) .*
                                               (power(STOR_ALL_EX) - charge +
                                                capres_discharge - capres_charge) ./
                                               total_cap(STOR_ALL_EX)
        end

        if !isempty(FLEX_EX)
            charge = value.(EP[:vCHARGE_FLEX][FLEX_EX, riskyhour].data)'
            capvalue[riskyhour, FLEX_EX] = crm_derate(i, FLEX_EX) .*
                                           (charge - power(FLEX_EX)) ./ total_cap(FLEX_EX)
        end
        if !isempty(VRE_STOR_EX)
            capres_dc_discharge = value.(EP[:vCAPRES_DC_DISCHARGE][DC_DISCHARGE,
                riskyhour].data)'
            discharge_eff = etainverter.(gen[storage_dc_discharge(gen)])'
            capvalue_dc_discharge = zeros(T, G)
            capvalue_dc_discharge[riskyhour, DC_DISCHARGE] = capres_dc_discharge .*
                                                             discharge_eff

            capres_dc_charge = value.(EP[:vCAPRES_DC_CHARGE][DC_CHARGE, riskyhour].data)'
            charge_eff = etainverter.(gen[storage_dc_charge(gen)])'
            capvalue_dc_charge = zeros(T, G)
            capvalue_dc_charge[riskyhour, DC_CHARGE] = capres_dc_charge ./ charge_eff

            capvalue[riskyhour, VRE_STOR_EX] = crm_derate(i, VRE_STOR_EX) .*
                                               power(VRE_STOR_EX) ./ total_cap(VRE_STOR_EX)

            charge_vre_stor = value.(EP[:vCHARGE_VRE_STOR][VRE_STOR_STOR_EX,
                riskyhour].data)'
            capvalue[riskyhour, VRE_STOR_STOR_EX] -= crm_derate(i, VRE_STOR_STOR_EX) .*
                                                     charge_vre_stor ./
                                                     total_cap(VRE_STOR_STOR_EX)

            capvalue[riskyhour, DC_DISCHARGE_EX] += crm_derate(i, DC_DISCHARGE_EX) .*
                                                    capvalue_dc_discharge[riskyhour,
                DC_DISCHARGE_EX] ./ total_cap(DC_DISCHARGE_EX)
            capres_ac_discharge = value.(EP[:vCAPRES_AC_DISCHARGE][AC_DISCHARGE_EX,
                riskyhour].data)'
            capvalue[riskyhour, AC_DISCHARGE_EX] += crm_derate(i, AC_DISCHARGE_EX) .*
                                                    capres_ac_discharge ./
                                                    total_cap(AC_DISCHARGE_EX)

            capvalue[riskyhour, DC_CHARGE_EX] -= crm_derate(i, DC_CHARGE_EX) .*
                                                 capvalue_dc_charge[riskyhour,
                DC_CHARGE_EX] ./ total_cap(DC_CHARGE_EX)
            capres_ac_charge = value.(EP[:vCAPRES_AC_CHARGE][AC_CHARGE_EX, riskyhour].data)'
            capvalue[riskyhour, AC_CHARGE_EX] -= crm_derate(i, AC_CHARGE_EX) .*
                                                 capres_ac_charge ./ total_cap(AC_CHARGE_EX)
        end
        capvalue = collect(transpose(capvalue))
        temp_dfCapValue = DataFrame(Resource = inputs["RESOURCE_NAMES"],
            Zone = zones,
            Reserve = fill(Symbol("CapRes_$i"), G))
        temp_dfCapValue = hcat(temp_dfCapValue, DataFrame(capvalue, :auto))
        auxNew_Names = [Symbol("Resource");
            Symbol("Zone");
            Symbol("Reserve");
            [Symbol("t$t") for t in 1:T]]
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
function capacity_reserve_margin_price(EP::Model,
    inputs::Dict,
    setup::Dict,
    capres_zone::Int)::Vector{Float64}
    ω = inputs["omega"]
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
    return dual.(EP[:cCapacityResMargin][capres_zone, :]) ./ ω * scale_factor
end
