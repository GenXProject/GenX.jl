#################################
#
#    Capacity Reserve Margin
#
#################################

@doc raw"""
    fusion_capacity_reserve_margin_adjustment!(EP::Model, inputs::Dict)

    Subtracts parasitic power from the capacity reserve margin.
"""
function fusion_capacity_reserve_margin_adjustment!(EP::Model,
                                                    inputs::Dict)
    dfGen = inputs["dfGen"]
    THERM_COMMIT = inputs["THERM_COMMIT"]
    FUSION = resources_with_fusion(dfGen)
    applicable_resources = intersect(FUSION, THERM_COMMIT)

    resource_component(y) = dfGen[y, :Resource]

    for y in applicable_resources
        _fusion_capacity_reserve_margin_adjustment!(EP, inputs, resource_component(y), y)
    end
end

# inner-loop function: loops over Capacity Reserve Margin zones, for one resource
# and actually adjusts the eCapResMarBalance expression
function _fusion_capacity_reserve_margin_adjustment!(EP::Model,
    inputs::Dict,
    resource_component,
    y::Int)

    T = inputs["T"]
    timesteps = collect(1:T)
    ncapres = inputs["NCapacityReserveMargin"]

    eCapResMarBalance = EP[:eCapResMarBalance]

    for capres_zone in 1:ncapres
        adjustment = fusion_capacity_reserve_margin_adjustment(EP, inputs, resource_component, y, capres_zone, timesteps)
        add_similar_to_expression!(eCapResMarBalance[capres_zone, :], adjustment)
    end
    return
end

# Get the amount for one resource component in one CRM zone
function fusion_capacity_reserve_margin_adjustment(EP::Model,
    inputs::Dict,
    resource_component::AbstractString,
    y::Int,
    capres_zone::Int,
    timesteps::Vector{Int})

    dfGen = inputs["dfGen"]
    eTotalCap = EP[:eTotalCap][y]
    by_rid(rid, sym) = by_rid_df(rid, sym, dfGen)

    capresfactor = by_rid(y, Symbol("CapRes_" * string(capres_zone)))
    if capresfactor == 0.0
        return AffExpr.(zero.(timesteps))
    end
    dwell_time = Float64(by_rid(y, :Dwell_Time))
    component_size = by_rid(y, :Cap_Size)

    get_from_model(f::Function) = EP[Symbol(f(resource_component))]

    ePassive = get_from_model(fusion_parasitic_passive_name)
    eActive = get_from_model(fusion_parasitic_active_name)
    eStartPower = get_from_model(fusion_pulse_start_power_name)
    ePulseStart = component_size * get_from_model(fusion_pulse_start_name)
    ePulseUnderway = component_size * get_from_model(fusion_pulse_underway_name)

    capacity_to_underway_adj = capresfactor * (ePulseUnderway[timesteps] .- eTotalCap)
    parasitic_adj = _fusion_crm_parasitic_adjustment.(capresfactor, ePassive[timesteps], eActive[timesteps], eStartPower[timesteps])
    dwell_adj = - capresfactor * _fusion_dwell_avoided_operation.(dwell_time, ePulseStart[timesteps])

    total_adj = capacity_to_underway_adj + parasitic_adj + dwell_adj

    if y in resources_with_maintenance(dfGen)
        maint_adj = thermal_maintenance_and_fusion_capacity_reserve_margin_adjustment(EP, inputs, y, capres_zone, timesteps)
        add_to_expression!.(total_adj, maint_adj)
    end

    return total_adj
end


# alias for better parallelism in effective_capacity.jl
thermal_fusion_capacity_reserve_margin_adjustment = fusion_capacity_reserve_margin_adjustment

#################################
# Where the math actually happens
#################################
@doc raw"""
    _fusion_crm_parasitic_adjustment(capresfactor::Float64,
               passive_power::AffExpr,
               active_power::AffExpr,
               start_power::AffExpr)

    Parasitic power for a fusion plant.
    Passive parasitic power is always on, even if the plant is undergoing maintenance,
    so this adjustment is independent of capresfactor. Active and start power are associated
    with a plant being in working order, so they do get `capresfactor` applied.

    capresfactor: Factor associated with the reliability of a plant's ability to produce power.
       Must logically be between 0 to 1.
    passive_power: Expression for parasitic passive recirculating power.
    active_power: Expression for parasitic active recirculating power.
    start_power: Expression for parasitic pulse start (peak) power.
"""
function _fusion_crm_parasitic_adjustment(capresfactor::Float64,
                                 passive_power::AffExpr,
                                 active_power::AffExpr,
                                 start_power::AffExpr)::AffExpr
    return -capresfactor * (active_power + start_power) - passive_power
end

#################################
#
#    Energy Share Requirement
#
#################################

function fusion_parasitic_power_adjust_energy_share_requirement!(EP, inputs)
    eESR = EP[:eESR]
    nESR = inputs["nESR"]
    weights = inputs["omega"]
    dfGen = inputs["dfGen"]
    FUSION = resources_with_fusion(dfGen)

    for y in FUSION, p in 1:nESR
        esr_derating = dfGen[y, Symbol("ESR_" * string(p))]
        if esr_derating > 0
            resource_component = dfGen[y, :Resource]
            adjustment = -esr_derating * fusion_annual_parasitic_power(EP, inputs, resource_component)
            add_similar_to_expression!(eESR[p], adjustment)
        end
    end
end

