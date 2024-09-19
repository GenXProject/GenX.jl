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
    gen = inputs["RESOURCES"]
    THERM_COMMIT = inputs["THERM_COMMIT"]
    FUSION = ids_with(gen, fusion)
    applicable_resources = intersect(FUSION, THERM_COMMIT)

    resource_component(y) = resource_name(gen[y])

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
        adjustment = fusion_capacity_reserve_margin_adjustment(
            EP, inputs, resource_component, y, capres_zone, timesteps)
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
    gen = inputs["RESOURCES"]
    component = gen[y]
    eTotalCap = EP[:eTotalCap][y]

    capresfactor = derating_factor(component, tag=capres_zone)
    if capresfactor == 0.0
        return AffExpr.(zero.(timesteps))
    end
    dwell_time = Float64(get(component, :dwell_time, 0.0))
    component_size = get(component, :cap_size, 0.0)

    from_model(f::Function) = EP[f(resource_component)]

    ePassive = from_model(fusion_parasitic_passive_name)
    eActive = from_model(fusion_parasitic_active_name)
    eStartPower = from_model(fusion_pulse_start_power_name)
    ePulseStart = component_size * from_model(fusion_pulse_start_name)
    ePulseUnderway = component_size * from_model(fusion_pulse_underway_name)

    capacity_to_underway_adj = capresfactor * (ePulseUnderway[timesteps] .- eTotalCap)
    parasitic_adj = _fusion_crm_parasitic_adjustment.(
        capresfactor, ePassive[timesteps], eActive[timesteps], eStartPower[timesteps])
    dwell_adj = -capresfactor *
                _fusion_dwell_avoided_operation.(dwell_time, ePulseStart[timesteps])

    total_adj = @expression(EP, [t in 1:T], capacity_to_underway_adj[t] + parasitic_adj[t] + dwell_adj[t])

    # Cancel out the dependence on down_var, since CRM is related to power, not capacity
    if y in ids_with_maintenance(gen)
        maint_adj = thermal_maintenance_and_fusion_capacity_reserve_margin_adjustment(
            EP, inputs, y, capres_zone, timesteps)
        add_to_expression!.(total_adj, maint_adj)
    end

    return total_adj
end

# alias for better parallelism in effective_capacity.jl
const thermal_fusion_capacity_reserve_margin_adjustment = fusion_capacity_reserve_margin_adjustment

#################################
# Where the math actually happens
#################################
@doc raw"""
    _fusion_crm_parasitic_adjustment(derating_factor::Float64,
               passive_power::AffExpr,
               active_power::AffExpr,
               start_power::AffExpr)

    Parasitic power for a fusion plant.
    Passive parasitic power is always on, even if the plant is undergoing maintenance,
    so this adjustment is independent of the CRM derating factor. Active and start power are associated
    with a plant being in working order, so they do get `derating_factor` applied.

    derating_factor: Factor associated with the reliability of a plant's ability to produce power.
       Must logically be between 0 to 1.
    passive_power: Expression for parasitic passive recirculating power.
    active_power: Expression for parasitic active recirculating power.
    start_power: Expression for parasitic pulse start (peak) power.
"""
function _fusion_crm_parasitic_adjustment(derating_factor::Float64,
        passive_power::AffExpr,
        active_power::AffExpr,
        start_power::AffExpr)::AffExpr
    return -derating_factor * (active_power + start_power) - passive_power
end

#################################
#
#    Energy Share Requirement
#
#################################

function fusion_parasitic_power_adjust_energy_share_requirement!(EP, inputs)
    eESR = EP[:eESR]
    nESR = inputs["nESR"]
    gen = inputs["RESOURCES"]
    FUSION = ids_with(gen, fusion)

    for y in FUSION, p in 1:nESR
        esr_derating = esr(gen[y], tag=p)
        if esr_derating > 0
            resource_component = resource_name(gen[y])
            adjustment = -esr_derating *
                         fusion_annual_parasitic_power(EP, inputs, resource_component)
            add_similar_to_expression!(eESR[p], adjustment)
        end
    end
end
