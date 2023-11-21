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

# inner-loop function
function _fusion_capacity_reserve_margin_adjustment!(EP::Model,
    inputs::Dict,
    resource_component,
    r_id::Int
    )

    T = inputs["T"]
    dfGen = inputs["dfGen"]
    ncapres = inputs["NCapacityReserveMargin"]

    y = r_id

    capresfactor(capres) = dfGen[y, Symbol("CapRes_$capres")]

    eCapResMarBalance = EP[:eCapResMarBalance]

    get_from_model(f::Function) = EP[Symbol(f(resource_component))]

    ePassive = get_from_model(fusion_parasitic_passive_name)
    eActive = get_from_model(fusion_parasitic_active_name)
    eStartPower = get_from_model(fusion_pulse_start_power_name)

    fusion_adj = @expression(EP, [capres in 1:ncapres, t in 1:T],
                            _fusion_crm_adjustment(capresfactor(capres), ePassive[t], eActive[t], eStartPower[t])
                       )
    add_similar_to_expression!(eCapResMarBalance, fusion_adj)
end

@doc raw"""
    fusion_crm(capresfactor::Float64,
               eTotalCap::AffExpr,
               cap_size::Float64,
               passive_power::AffExpr,
               active_power::AffExpr,
               start_power::AffExpr,
               vMDOWN::VariableRef)

    Capacity reserve margin contributions for a whole plant, with maintenance.

    capresfactor: Factor associated with the reliability of a plant's ability to produce power.
       Must logically be between 0 to 1.
    eTotalCap: Capacity of the plants of this type in a zone.
    cap_size: Power per plant.
    passive_power: Expression for parasitic passive recirculating power.
    active_power: Expression for parasitic active recirculating power.
    start_power: Expression for parasitic pulse start (peak) power.
    vMDOWN: Variable for number of plants under maintenance.
"""
function fusion_crm(capresfactor::Float64,
                     eTotalCap::AffExpr,
                     cap_size::Float64,
                     passive_power::AffExpr,
                     active_power::AffExpr,
                     start_power::AffExpr,
                     vMDOWN::VariableRef)
    return fusion_crm(capresfactor, eTotalCap, passive_power, active_power, start_power) +
           _maintenance_crm_adjustmnet(capresfactor, cap_size, maintenance_down)
end

@doc raw"""
    fusion_crm(capresfactor::Float64,
               eTotalCap::AffExpr,
               passive_power::AffExpr,
               active_power::AffExpr,
               start_power::AffExpr)

    Capacity reserve margin contributions for a fusion plant.

    capresfactor: Factor associated with the reliability of a plant's ability to produce power.
       Must logically be between 0 to 1.
    eTotalCap: Capacity of the plants of this type in a zone.
    passive_power: Expression for parasitic passive recirculating power.
    active_power: Expression for parasitic active recirculating power.
    start_power: Expression for parasitic pulse start (peak) power.
"""
function fusion_crm(capresfactor::Float64,
                     eTotalCap::AffExpr,
                     passive_power::AffExpr,
                     active_power::AffExpr,
                     start_power::AffExpr)
    return capresfactor * eTotalCap +
           _fusion_crm_adjustment(capresfactor, passive_power, active_power, start_power)
end

@doc raw"""
    _maintenance_crm_adjustment(capresfactor::Float64,
                                cap_size::Float64,
                                vMDOWN::VariableRef)

    Term to account for plants down due to scheduled maintenance.
    (`capresfactor` is needed so that this cancels out eTotalCap in the basic CRM expression.)

    capresfactor: Factor associated with the reliability of a plant's ability to produce power.
       Must logically be between 0 to 1.
    cap_size: Power per plant.
    vMDOWN: Variable for number of plants under maintenance.
"""
function _maintenance_crm_adjustmnet(capresfactor::Float64,
                                     cap_size::Float64,
                                     maintenance_down::VariableRef)
    return - capresfactor * cap_size * maintenance_down
end

@doc raw"""
    _fusion_crm_adjustment(capresfactor::Float64,
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
function _fusion_crm_adjustment(capresfactor::Float64,
                                 passive_power::AffExpr,
                                 active_power::AffExpr,
                                 start_power::AffExpr)
    return -capresfactor * (active_power + start_power) - passive_power
end

