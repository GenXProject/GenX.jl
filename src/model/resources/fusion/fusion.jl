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

function fusion_pulse_start_name(resource_component::AbstractString)::String
    "vFusionPulseStart_" * resource_component
end

function fusion_pulse_underway_name(resource_component::AbstractString)::String
    "vFusionPulseUnderway_" * resource_component
end

function fusion_parasitic_active_name(resource_component::AbstractString)::String
    "eFusionParasiticActive_" * resource_component
end

function fusion_parasitic_passive_name(resource_component::AbstractString)::String
    "eFusionParasiticPassive_" * resource_component
end

function fusion_parasitic_start_energy_name(resource_component::AbstractString)::String
    "eFusionParasiticStartEnergy_" * resource_component
end

function fusion_pulse_start_power_name(resource_component::AbstractString)::String
    "eFusionParasiticPulseStartPower_" * resource_component
end

function fusion_parasitic_total_name(resource_component::AbstractString)::String
    "eFusionParasiticTotal_" * resource_component
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
    This is available only after `fusion_formulation_thermal_commit!` has been called.
"""
function fusion_parasitic_power_expressions(dict::Dict)::Set{Symbol}
    dict[FUSION_PARASITIC_POWER]
end

@doc raw"""
    fusion_parasitic_power_expressions(inputs::Dict, zone::Int)

    inputs: model inputs

    get listings of parasitic power expressions in a zone.
    This is available only after `fusion_formulation!` has been called.
"""
function fusion_parasitic_power_expressions(inputs::Dict, zone::Int)::Set{Symbol}
    fusion_in_zone = inputs[FUSION_COMPONENT_ZONE][zone]
    exprs = Symbol.(fusion_parasitic_total_name.(fusion_in_zone))
    return Set(exprs)
end

@doc raw"""
    fusion_pulse_start_expressions(dict::Dict)

    dict: a dictionary of model data

    get listings of pulse start expressions
    This is available only after `fusion_formulation!` has been called.
"""
function fusion_pulse_start_expressions(dict::Dict)::Set{Symbol}
    dict[FUSION_PULSE_START]
end


function add_fusion_component_to_zone_listing(inputs::Dict, r_id::Int, resource_component::AbstractString)
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
    has_fusion(dict::Dict)

    dict: a dictionary of model data

    Checks whether the dictionary contains listings of fusion-related expressions.
    This is true only after `fusion_formulation!` has been called.
"""
function has_fusion(dict::Dict)::Bool
    FUSION_PARASITIC_POWER in keys(dict)
end

################################################
# Get ID's of resources with a fusion component
################################################

@doc raw"""
    resources_with_fusion(df::DataFrame)::Vector{Int}

    Get a vector of the R_ID's of all fusion resources listed in a dataframe.
    If there are none, return an empty vector.

    This method takes a specific dataframe because compound resources may have their
    data in multiple dataframes.
"""
function resources_with_fusion(df::DataFrame)::Vector{Int}
    if "FUSION" in names(df)
        df[df.FUSION.>0, :R_ID]
    else
        Vector{Int}[]
    end
end

@doc raw"""
    resources_with_fusion(inputs::Dict)::Vector{Int}

    Get a vector of the R_ID's of all resources listed in a dataframe
    that have fusion. If there are none, return an empty vector.
"""
function resources_with_fusion(inputs::Dict)::Vector{Int}
    resources_with_fusion(inputs["dfGen"])
end

#######################################
# Define a data structure for a reactor
#######################################

# Base.@kwdef could be used if we enforce Julia >= 1.9
# That would replace need for the keyword-argument constructor below
struct FusionReactorData
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
end

FusionReactorData(;
    component_size::Float64 = 1.0,
    parasitic_passive_fraction::Float64 = 0.0,
    parasitic_active_fraction::Float64 = 0.0,
    parasitic_start_energy_fraction::Float64 = 0.0,
    pulse_start_power_fraction::Float64 = 0.0,
    maintenance_remaining_parasitic_power_fraction::Float64 = 0.0,
    eff_down::Float64 = 1.0,
    dwell_time::Float64 = 0.0,
    max_pulse_length::Int = -1,
    max_starts::Int = -1,
) = FusionReactorData(
    component_size,
    parasitic_passive_fraction,
    parasitic_active_fraction,
    parasitic_start_energy_fraction,
    pulse_start_power_fraction,
    maintenance_remaining_parasitic_power_fraction,
    eff_down,
    dwell_time,
    max_pulse_length,
    max_starts,
)

#######################################
# Compute reactor properties
#######################################

function has_parasitic_power(r::FusionReactorData)
    r.parasitic_start_energy > 0 || r.parasitic_passive_fraction > 0 || r.parasitic_active_fraction > 0
end

function has_finite_starts(r::FusionReactorData)
    r.max_starts > 0
end

function has_max_pulse_length(r::FusionReactorData)
    r.max_pulse_length > 0
end

function has_pulse_start_power(r::FusionReactorData)
    r.pulse_start_power_fraction > 0
end

function fusion_average_net_electric_power_factor(reactor::FusionReactorData)
    dwell_time = reactor.dwell_time
    max_up = reactor.max_pulse_length
    parasitic_start_energy = reactor.parasitic_start_energy_fraction
    parasitic_passive = reactor.parasitic_passive_fraction
    parasitic_active = reactor.parasitic_passive_fraction
    η = reactor.eff_down

    active_frac = 1
    avg_start_power = 0
    if max_up > 0
        active_frac = 1 - dwell_time / max_up
        avg_start_energy = parasitic_start_energy / max_up
    end
    net_th_frac = active_frac * (1 - parasitic_active) - parasitic_passive - parasitic_avg_start_energy
    net_el_factor = η * net_th_frac
    return net_th_factor
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
        capacity::Symbol,
        )

    T = inputs["T"]
    ω = inputs["omega"]
    p = inputs["hours_per_subperiod"]

    start_name = fusion_pulse_start_name(resource_component)
    underway_name = fusion_pulse_underway_name(resource_component)
    start = Symbol(start_name)
    underway = Symbol(underway_name)

    union!(inputs[FUSION_PULSE_START], (start,))
    union!(inputs[FUSION_PULSE_UNDERWAY], (underway,))

    ecap = EP[capacity][r_id]

    vPulseStart = EP[start] = @variable(EP, [t in 1:T], base_name = start_name, lower_bound = 0)
    vPulseUnderway = EP[underway] = @variable(EP, [t in 1:T], base_name = underway_name, lower_bound = 0)

    if integer_operational_unit_commitment
        set_integer.(vPulseStart)
        set_integer.(vPulseUnderway)
    end

    component_size = reactor.component_size

    # Pulse variables are measured in # of plants
    @constraint(EP, [t in 1:T], vPulseStart[t] * component_size <= ecap)
    @constraint(EP, [t in 1:T], vPulseUnderway[t] * component_size <= ecap)

    # Core max uptime. If this parameter > 0,
    # the fusion core must be cycled at least every n hours.
    # Looks back over interior timesteps and ensures that a core cannot
    # be committed unless it has been started at some point in
    # the previous n timesteps
    if has_max_pulse_length(reactor)
        max_pulse_length = reactor.max_pulse_length
        starts_in_previous_hours(t) = vPulseStart[hoursbefore(p, t, 0:(max_pulse_length - 1))]
        @constraint(EP, [t in 1:T], vPulseUnderway[t] <= sum(starts_in_previous_hours(t)))
    end

    if has_finite_starts(reactor)
        max_starts = reactor.max_starts
        @constraint(
            EP,
            sum(vPulseStart[t] * ω[t] for t in 1:T) * component_size <= max_starts * ecap[y]
        )
    end
end

function fusion_pulse_status_linking_constraints!(
    EP::Model,
    inputs::Dict,
    resource_component::AbstractString,
    r_id::Int,
    reactor::FusionReactorData,
    vcommit::Symbol,
)
    T = inputs["T"]

    y = r_id

    commit = EP[vcommit] # measured in number of components

    get_from_model(f::Function) = EP[Symbol(f(resource_component))]

    vPulseStart = get_from_model(fusion_pulse_start_name)
    vPulseUnderway = get_from_model(fusion_pulse_underway_name)

    # pulses cannot start unless the plant is committed
    @constraint(EP, [t in 1:T], vPulseStart[t] <= commit[y, t])
    @constraint(EP, [t in 1:T], vPulseUnderway[t] <= commit[y, t])
end

@doc raw"""
    fusion_pulse_thermal_power_generation_constraint!(EP::Model,
                              inputs::Dict,
                              resource_component::AbstractString,
                              r_id::Int,
                              reactor::FusionReactorData,
                              vp::Symbol,
                              vcommit::Symbol)

    Creates maintenance-tracking variables and adds their Symbols to two Sets in `inputs`.
    Adds constraints which act on the vCOMMIT-like variable.
"""
function fusion_pulse_thermal_power_generation_constraint!(
    EP::Model,
    inputs::Dict,
    resource_component::AbstractString,
    r_id::Int,
    reactor::FusionReactorData,
    power_like::AbstractArray,
)
    T = inputs["T"]
    p = inputs["hours_per_subperiod"]

    y = r_id

    component_size = reactor.component_size
    dwell_time = reactor.dwell_time

    get_from_model(f::Function) = EP[Symbol(f(resource_component))]
    vPulseStart = component_size * get_from_model(fusion_pulse_start_name)
    vPulseUnderway = component_size * get_from_model(fusion_pulse_underway_name)

    # Maximum thermal power generated by core y at hour y <= Max power of committed
    # core minus power lost from down time at startup
    @constraint(
        EP,
        [t in 1:T],
        power_like[y, t] <= vPulseUnderway[t] - dwell_time * vPulseStart[t]
    )
end

function fusion_parasitic_power!(
    EP::Model,
    inputs::Dict,
    resource_component,
    r_id::Int,
    reactor::FusionReactorData,
    component_capacity::Symbol,
)
    T = inputs["T"]

    component_size = reactor.component_size
    parasitic_passive_fraction = reactor.parasitic_passive_fraction
    parasitic_active_fraction = reactor.parasitic_active_fraction
    parasitic_start_energy_fraction = reactor.parasitic_start_energy_fraction
    pulse_start_power_fraction = reactor.pulse_start_power_fraction
    dwell_time = reactor.dwell_time
    η = reactor.eff_down

    get_from_model(f::Function) = EP[Symbol(f(resource_component))]

    pulsestart = component_size * get_from_model(fusion_pulse_start_name)
    underway = component_size * get_from_model(fusion_pulse_underway_name)

    capacity = EP[component_capacity][r_id]

    passive = Symbol(fusion_parasitic_passive_name(resource_component))
    active = Symbol(fusion_parasitic_active_name(resource_component))
    start_energy = Symbol(fusion_parasitic_start_energy_name(resource_component))
    pulse_start_power = Symbol(fusion_pulse_start_power_name(resource_component))

    # Passive recirculating power, depending on built capacity
    EP[passive] =
            @expression(EP, [t in 1:T], capacity * η * parasitic_passive_fraction)

    # Active recirculating power, depending on whether a pulse is underway
    EP[active] = @expression(
        EP,
        [t in 1:T],
        η *
        parasitic_active_fraction *
        (underway[t] - pulsestart[t] * dwell_time)
    )
    # Startup energy, taken from the grid every time the core starts up
    EP[start_energy] = @expression(
        EP,
        [t in 1:T],
        pulsestart[t] * η * parasitic_start_energy_fraction
    )

    # Startup power, required margin on the grid when the core starts
    EP[pulse_start_power] = @expression(
        EP,
        [t in 1:T],
        pulsestart[t] * η * pulse_start_power_fraction
    )
    union!(inputs[FUSION_PULSE_START_POWER], (pulse_start_power,))
end

function fusion_total_parasitic_power!(
    EP::Model,
    inputs::Dict,
    resource_component,
    r_id::Int,
    )

    get_from_model(f::Function) = EP[Symbol(f(resource_component))]

    ePassive = get_from_model(fusion_parasitic_passive_name)
    eActive = get_from_model(fusion_parasitic_active_name)
    eStartEnergy = get_from_model(fusion_parasitic_start_energy_name)

    total_parasitic = Symbol(fusion_parasitic_total_name(resource_component))

    EP[total_parasitic] = ePassive + eActive + eStartEnergy

    union!(inputs[FUSION_PARASITIC_POWER], (total_parasitic,))
end

function fusion_adjust_power_balance!(EP, inputs::Dict, df::DataFrame, component::AbstractString="")
    zones_for_resources = inputs["R_ZONES"]
    ePowerBalance = EP[:ePowerBalance]

    FUSION = resources_with_fusion(df)
    for y in FUSION
        z = zones_for_resources[y]
        resource_component = df[y, :Resource] * component
        fusion_total_parasitic_power!(EP, inputs, resource_component, y)
        eTotalParasitic = EP[Symbol(fusion_parasitic_total_name(resource_component))]
        add_similar_to_expression!(ePowerBalance[:, z], -eTotalParasitic)
    end
end

function fusion_parasitic_power_adjust_energy_share_requirement!(EP, inputs)
	@info "Adjusting fusion ESR"
	eESR = EP[:eESR]
	nESR = inputs["nESR"]
	weights = inputs["omega"]
	dfGen = inputs["dfGen"]
	FUSION = resources_with_fusion(dfGen)

	for y in FUSION, p in 1:nESR
		esr_derating = dfGen[y, Symbol("ESR_" * string(p))]
		if esr_derating > 0
			resource_component = dfGen[y, :Resource]
			eTotalParasitic = EP[Symbol(fusion_parasitic_total_name(resource_component))]
			annual_parasitic = esr_derating * weights' * eTotalParasitic
			add_similar_to_expression!(eESR[p], -annual_parasitic)
		end
	end
end
