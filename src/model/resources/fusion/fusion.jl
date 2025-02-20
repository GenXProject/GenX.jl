#################################################################
# Names for keys in an inputs (or future outputs) dictionary
#################################################################

const FUSION_PULSE_START = "FusionPulseStartVariables"
const FUSION_PULSE_UNDERWAY = "FusionPulseUnderwayVariables"

const FUSION_PARASITIC_POWER = "FusionParasiticPowerExpressions"
const FUSION_PULSE_START_POWER = "FusionPulseStartPowerExpressions"

const FUSION_COMPONENT_ZONE = "FusionComponentZones"

#####################################################################
# Individual fusion reactor component variable and expressions names
#####################################################################

function fusion_pulse_start_name(resource_component::AbstractString)
    Symbol("vFusionPulseStart_" * resource_component)
end

function fusion_pulse_underway_name(resource_component::AbstractString)
    Symbol("vFusionPulseUnderway_" * resource_component)
end

function fusion_parasitic_active_name(resource_component::AbstractString)
    Symbol("eFusionParasiticActive_" * resource_component)
end

function fusion_parasitic_passive_name(resource_component::AbstractString)
    Symbol("eFusionParasiticPassive_" * resource_component)
end

function fusion_parasitic_start_energy_name(resource_component::AbstractString)
    Symbol("eFusionParasiticStartEnergy_" * resource_component)
end

function fusion_pulse_start_power_name(resource_component::AbstractString)
    Symbol("eFusionParasiticPulseStartPower_" * resource_component)
end

function fusion_parasitic_total_name(resource_component::AbstractString)
    Symbol("eFusionParasiticTotal_" * resource_component)
end

#############################################################################
# Set and get these variables, expressions from the inputs (or outputs) dict
#############################################################################

@doc raw"""
    ensure_fusion_expression_records!(dict::Dict)

    dict: a dictionary of model data

    This should be called by each method that adds fusion formulations,
    to ensure that certain entries in the model data dict exist.
"""
function ensure_fusion_expression_records!(dict::Dict)
    for var in (FUSION_PARASITIC_POWER, FUSION_PULSE_START_POWER)
        if var ∉ keys(dict)
            dict[var] = Set{Symbol}()
        end
    end
    var = FUSION_COMPONENT_ZONE
    if var ∉ keys(dict)
        dict[var] = Dict{Int, Set{AbstractString}}()
    end
end

@doc raw"""
    ensure_fusion_pulse_variable_records!(dict::Dict)

    dict: a dictionary of model data

    This should be called by each method that adds fusion formulations,
    to ensure that certain entries in the model data dict exist.
"""
function ensure_fusion_pulse_variable_records!(dict::Dict)
    for var in (FUSION_PULSE_START, FUSION_PULSE_UNDERWAY)
        if var ∉ keys(dict)
            dict[var] = Set{Symbol}()
        end
    end
end

@doc raw"""
    fusion_parasitic_power_expressions(dict::Dict)

    dict: a dictionary of model data

    get listings of parasitic power expressions.
    This is available only after a `fusion_formulation_*!` has been called.
"""
function fusion_parasitic_power_expressions(dict::Dict)::Set{Symbol}
    dict[FUSION_PARASITIC_POWER]
end

@doc raw"""
    fusion_parasitic_power_expressions(inputs::Dict, zone::Int)

    inputs: model inputs

    get listings of parasitic power expressions in a zone.
    This is available only after a `fusion_formulation_*!` has been called.
"""
function fusion_parasitic_power_expressions(inputs::Dict, zone::Int)::Set{Symbol}
    fusion_in_zone = inputs[FUSION_COMPONENT_ZONE][zone]
    exprs = fusion_parasitic_total_name.(fusion_in_zone)
    return Set(exprs)
end

@doc raw"""
    fusion_pulse_start_expressions(dict::Dict)

    dict: a dictionary of model data

    get listings of pulse start expressions
    This is available only after a `fusion_formulation_*!` has been called.
"""
function fusion_pulse_start_expressions(dict::Dict)::Set{Symbol}
    dict[FUSION_PULSE_START]
end

function add_fusion_component_to_zone_listing(
        inputs::Dict, r_id::Int, resource_component::AbstractString)
    zone = inputs["R_ZONES"][r_id]
    d = inputs[FUSION_COMPONENT_ZONE]
    new_set = Set([resource_component])
    if zone in keys(d)
        union!(d[zone], new_set)
    else
        d[zone] = new_set
    end
end

@doc raw"""
    has_fusion(dict::Dict)::Bool

    dict: a dictionary of model data

    Checks whether the dictionary contains listings of fusion-related expressions.
    This is true only after a `fusion_formulation_*!` has been called.
"""
function has_fusion(dict::Dict)::Bool
    FUSION_PARASITIC_POWER in keys(dict)
end

#######################################
# Define a data structure for a reactor
#######################################

# Base.@kwdef could be used if we enforce Julia >= 1.9
# That would replace need for the keyword-argument constructor below
Base.@kwdef struct FusionReactorData
    component_size::Float64
    parasitic_passive_fraction::Float64
    parasitic_active_fraction::Float64
    parasitic_start_energy_fraction::Float64
    pulse_start_power_fraction::Float64
    maintenance_remaining_parasitic_power_fraction::Float64
    eff_down::Float64
    dwell_time::Float64
    max_pulse_length::Int
    max_starts::Int
    max_fpy_per_year::Float64
end

#######################################
# Find fusion resources
#######################################

fusion(r) = get(r, :fusion, default_zero)

#######################################
# Create from a Therm resource
#######################################

function FusionReactorData(gen::Vector{<:AbstractResource}, y::Int)::FusionReactorData
    FusionReactorData(gen[y])
end

function FusionReactorData(r::Thermal)::FusionReactorData
    core_cap_size = Float64(cap_size(r))
    # holding this for use with future multi-component resources
    eff_down = 1.0
    dwell_time = Float64(get(r, :dwell_time, default_zero))
    max_starts = get(r, :max_starts, -1)
    max_pulse_length = get(r, :max_up_time, -1)
    parasitic_passive = Float64(get(r, :parasitic_passive, default_zero))
    parasitic_active = Float64(get(r, :parasitic_active, default_zero))
    start_energy = Float64(get(r, :parasitic_start_energy, default_zero))
    start_power = Float64(get(r, :parasitic_start_power, default_zero))

    parasitic_maint = Float64(get(
        r, :parasitic_passive_maintenance_remaining, default_zero))

    max_fpy_per_year = Float64(get(r, :max_fpy_per_year, -1))

    reactor = FusionReactorData(component_size = core_cap_size,
        parasitic_passive_fraction = parasitic_passive,
        parasitic_active_fraction = parasitic_active,
        parasitic_start_energy_fraction = start_energy,
        pulse_start_power_fraction = start_power,
        eff_down = eff_down,
        dwell_time = dwell_time,
        max_pulse_length = max_pulse_length,
        max_starts = max_starts,
        maintenance_remaining_parasitic_power_fraction = parasitic_maint,
        max_fpy_per_year = max_fpy_per_year)
end

#######################################
# Compute reactor properties
#######################################

function average_net_power_factor(reactor::FusionReactorData)
    dwell_time = reactor.dwell_time
    max_up = reactor.max_pulse_length
    parasitic_start_energy = reactor.parasitic_start_energy_fraction
    parasitic_passive = reactor.parasitic_passive_fraction
    parasitic_active = reactor.parasitic_active_fraction

    active_frac = 1
    avg_start_energy = 0
    if max_up > 0
        active_frac = 1 - dwell_time / max_up
        avg_start_energy = parasitic_start_energy / max_up
    end
    net_power_factor = active_frac * (1 - parasitic_active) - parasitic_passive -
                  avg_start_energy
    return net_power_factor
end

############################################################################
# Add variables, expressions, constraints for individual fusion components
# to the model
############################################################################

function fusion_pulse_variables!(EP::Model,
        inputs::Dict,
        integer_operational_unit_commitment::Bool,
        resource_component::AbstractString,
        r_id::Int,
        reactor::FusionReactorData,
        capacity::Symbol
)
    T = inputs["T"]
    ω = inputs["omega"]
    p = inputs["hours_per_subperiod"]

    start = fusion_pulse_start_name(resource_component)
    underway = fusion_pulse_underway_name(resource_component)

    union!(inputs[FUSION_PULSE_START], (start,))
    union!(inputs[FUSION_PULSE_UNDERWAY], (underway,))

    ecap = EP[capacity][r_id]

    vPulseStart = EP[start] = @variable(EP, [t in 1:T], base_name=string(start), lower_bound=0)
    vPulseUnderway = EP[underway] = @variable(EP, [t in 1:T], base_name=string(underway),
        lower_bound=0)

    if integer_operational_unit_commitment
        set_integer.(vPulseStart)
        set_integer.(vPulseUnderway)
    end

    component_size = reactor.component_size

    # Pulse variables are measured in # of plants
    @constraint(EP, [t in 1:T], vPulseStart[t] * component_size<=ecap)
    @constraint(EP, [t in 1:T], vPulseUnderway[t] * component_size<=ecap)

    # Core max uptime. If this parameter > 0,
    # the fusion core must be cycled at least every n hours.
    # Looks back over interior timesteps and ensures that a core cannot
    # be committed unless it has been started at some point in
    # the previous n timesteps
    max_pulse_length = reactor.max_pulse_length
    if max_pulse_length > 0
        function starts_in_previous_hours(t)
            vPulseStart[hoursbefore(p, t, 0:(max_pulse_length - 1))]
        end
        @constraint(EP, [t in 1:T], vPulseUnderway[t]<=sum(starts_in_previous_hours(t)))
    end

    max_starts = reactor.max_starts
    if max_starts > 0
        @constraint(EP,
            sum(vPulseStart[t] * ω[t] for t in 1:T) * component_size<=max_starts * ecap[y])
    end
end

function fusion_pulse_status_linking_constraints!(
        EP::Model,
        inputs::Dict,
        resource_component::AbstractString,
        r_id::Int,
        reactor::FusionReactorData,
        vcommit::Symbol
)
    T = inputs["T"]

    commit = EP[vcommit] # measured in number of components

    from_model(f::Function) = EP[f(resource_component)]

    vPulseStart = from_model(fusion_pulse_start_name)
    vPulseUnderway = from_model(fusion_pulse_underway_name)

    # pulses cannot start unless the plant is committed
    @constraint(EP, [t in 1:T], vPulseStart[t]<=commit[r_id, t])
    @constraint(EP, [t in 1:T], vPulseUnderway[t]<=commit[r_id, t])
end

@doc raw"""
    fusion_pulse_thermal_power_generation_constraint!(EP::Model,
                              inputs::Dict,
                              resource_component::AbstractString,
                              r_id::Int,
                              reactor::FusionReactorData,
                              vp::Symbol,
                              vcommit::Symbol)

    Add constraint which acts on the power-output-like variable.
"""
function fusion_pulse_thermal_power_generation_constraint!(
        EP::Model,
        inputs::Dict,
        resource_component::AbstractString,
        r_id::Int,
        reactor::FusionReactorData,
        power_like::AbstractArray
)
    T = inputs["T"]

    component_size = reactor.component_size
    dwell_time = reactor.dwell_time

    from_model(f::Function) = EP[f(resource_component)]
    ePulseStart = component_size * from_model(fusion_pulse_start_name)
    ePulseUnderway = component_size * from_model(fusion_pulse_underway_name)

    # Maximum thermal power generated by core y at hour y <= Max power of committed
    # core minus power lost from down time at startup
    @constraint(EP,
        [t in 1:T],
        power_like[r_id,
            t]<=ePulseUnderway[t] -
                _fusion_dwell_avoided_operation(dwell_time, ePulseStart[t]))
end

@doc raw"""
    _fusion_dwell_avoided_operation(dwell_time::Float64,
                                    ePulseStart::AffExpr)

    dwell_time in fractions of a timestep
    ePulseStart is the number of MW starting. Typically component_size * vPulseStart
"""
function _fusion_dwell_avoided_operation(dwell_time::Float64, ePulseStart::AffExpr)
    return dwell_time * ePulseStart
end

function fusion_parasitic_power!(
        EP::Model,
        inputs::Dict,
        resource_component,
        r_id::Int,
        reactor::FusionReactorData,
        component_capacity::Symbol
)
    T = inputs["T"]

    component_size = reactor.component_size
    parasitic_passive_fraction = reactor.parasitic_passive_fraction
    parasitic_active_fraction = reactor.parasitic_active_fraction
    parasitic_start_energy_fraction = reactor.parasitic_start_energy_fraction
    pulse_start_power_fraction = reactor.pulse_start_power_fraction
    dwell_time = reactor.dwell_time
    η = reactor.eff_down

    from_model(f::Function) = EP[f(resource_component)]

    pulsestart = component_size * from_model(fusion_pulse_start_name)
    underway = component_size * from_model(fusion_pulse_underway_name)

    capacity = EP[component_capacity][r_id]

    passive = fusion_parasitic_passive_name(resource_component)
    active = fusion_parasitic_active_name(resource_component)
    start_energy = fusion_parasitic_start_energy_name(resource_component)
    pulse_start_power = fusion_pulse_start_power_name(resource_component)

    union!(inputs[FUSION_PULSE_START_POWER], (pulse_start_power,))

    # Passive recirculating power, depending on built capacity
    EP[passive] = @expression(EP, [t in 1:T], capacity*η*parasitic_passive_fraction)

    # Active recirculating power, depending on whether a pulse is underway
    EP[active] = @expression(EP,
        [t in 1:T],
        η*
        parasitic_active_fraction*
        (underway[t]-pulsestart[t] * dwell_time))
    # Startup energy, taken from the grid every time the core starts up
    EP[start_energy] = @expression(EP,
        [t in 1:T],
        pulsestart[t]*η*parasitic_start_energy_fraction)

    # Startup power, required margin on the grid when the core starts
    EP[pulse_start_power] = @expression(EP,
        [t in 1:T],
        pulsestart[t]*η*pulse_start_power_fraction)
end

function fusion_max_fpy_per_year_constraint!(
        EP::Model,
        inputs::Dict,
        r_id::Int,
        reactor::FusionReactorData,
        component_capacity::Symbol,
        power_like::AbstractArray
)
    T = inputs["T"]

    capacity = EP[component_capacity][r_id]
    max_fpy_per_year = reactor.max_fpy_per_year
    if  0 < max_fpy_per_year < 1
        @constraint(EP, sum(power_like[r_id, :]) / T<=max_fpy_per_year * capacity)
    end
    if max_fpy_per_year >= 1
        @info "Max FPY per year fusion constraint automatically met; not creating."
    end
end

function fusion_total_parasitic_power!(
        EP::Model,
        inputs::Dict,
        resource_component,
        r_id::Int
)
    T = inputs["T"]

    from_model(f::Function) = EP[f(resource_component)]

    ePassive = from_model(fusion_parasitic_passive_name)
    eActive = from_model(fusion_parasitic_active_name)
    eStartEnergy = from_model(fusion_parasitic_start_energy_name)

    total_parasitic = fusion_parasitic_total_name(resource_component)

    EP[total_parasitic] = @expression(EP, [t in 1:T], ePassive[t] + eActive[t] + eStartEnergy[t])

    union!(inputs[FUSION_PARASITIC_POWER], (total_parasitic,))
end

function fusion_adjust_power_balance!(
        EP, inputs::Dict, gen::Vector{<:AbstractResource}, component::AbstractString = "")
    zones_for_resources = inputs["R_ZONES"]
    ePowerBalance = EP[:ePowerBalance]

    FUSION = ids_with(gen, fusion)
    for y in FUSION
        z = zones_for_resources[y]
        resource_component = resource_name(gen[y]) * component
        fusion_total_parasitic_power!(EP, inputs, resource_component, y)
        eTotalParasitic = EP[fusion_parasitic_total_name(resource_component)]
        add_similar_to_expression!(ePowerBalance[:, z], -eTotalParasitic)
    end
end

########################
# Functions for outputs
########################

function fusion_annual_parasitic_power(
        EP, inputs, resource_component::AbstractString)::AffExpr
    ω = inputs["omega"]
    eTotalParasitic = EP[fusion_parasitic_total_name(resource_component)]
    annual_parasitic = ω' * eTotalParasitic
    return annual_parasitic
end

function thermal_fusion_annual_parasitic_power(
        EP::Model, inputs::Dict, setup::Dict)::Vector{Float64}
    gen = inputs["RESOURCES"]
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
    FUSION = ids_with(gen, fusion)

    resource_component = resource_name.(gen[FUSION])

    expr = fusion_annual_parasitic_power.(Ref(EP), Ref(inputs), resource_component)
    return scale_factor * value.(expr)
end
