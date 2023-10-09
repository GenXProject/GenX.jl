const FUSION_PARASITIC_POWER = "FusionParasiticPowerExpressions"
const FUSION_PULSE_START_POWER = "FusionPulseStartPowerExpressions"

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
    "eFusionPulseStartPower_" * resource_component
end

function fusion_parasitic_total_name(resource_component::AbstractString)::String
    "eFusionParasiticTotal_" * resource_component
end

@doc raw"""
    fusion_parasitic_power_expressions(dict::Dict)

    dict: a dictionary of model data

    get listings of parasitic power expressions.
    This is available only after `fusion_formulation!` has been called.
"""
function fusion_parasitic_power_expressions(dict::Dict)::Set{Symbol}
    dict[FUSION_PARASITIC_POWER]
end

@doc raw"""
    ensure_fusion_expression_records!(dict::Dict)

    dict: a dictionary of model data

    This should be called by each method that adds fusion formulations,
    to ensure that certain entries in the model data dict exist.
"""
function ensure_fusion_expression_records!(dict::Dict)
    for var in (FUSION_PARASITIC_POWER)
        if var ∉ keys(dict)
            dict[var] = Set{Symbol}()
        end
    end
end

struct FusionReactorData
    parasitic_passive_recirculating_fraction::Float64
    parasitic_active_recirculating_fraction::Float64
    parasitic_start_energy_fraction::Float64
    parasitic_pulse_start_power_fraction::Float64
    maintenance_remaining_parasitic_power_fraction::Float64
    eff_down::Float64
    dwell_time::Float64
    max_pulse_length::Int
end

FusionReactorData(;
    parasitic_passive_recirculating_fraction = 0.0,
    parasitic_active_recirculating_fraction = 0.0,
    parasitic_start_energy_fraction = 0.0,
    parasitic_pulse_start_power_fraction = 0.0,
    maintenance_remaining_parasitic_power_fraction = 0.0,
    eff_down = 1.0,
    dwell_time = 0.0,
    max_pulse_length = -1,
) = FusionReactorData(
    parasitic_passive_recirculating_fraction,
    parasitic_active_recirculating_fraction,
    parasitic_start_energy_fraction,
    parasitic_pulse_start_power_fraction,
    maintenance_remaining_parasitic_power_fraction,
    eff_down,
    dwell_time,
    max_pulse_length,
)

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

function fusion_average_net_electric_power_factor!(fusiondata, eff_down)
    dwell_time = fusiondata.dwell_time
    max_up = fusiondata.max_up
    parasitic_start_energy = fusiondata.parasitic_start_energy
    parasitic_passive = fusiondata.parasitic_passive
    parasitic_active = fusiondata.parasitic_active
    pulse_start_power = fusiondata.parasitic_start_power

    active_frac = 1
    avg_start_power = 0
    if max_up > 0
        active_frac = 1 - dwell_time / max_up
        avg_start_power = parasitic_start_energy / max_up
    end
    net_th_frac = active_frac * (1 - parasitic_active) - parasitic_passive - avg_start_power
    net_el_factor = eff_down * net_th_frac
    return net_th_factor
end

function fusion_average_net_electric_power_expression!(EP::Model, inputs::Dict)
    dfGen = inputs["dfGen"]

    G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)

    dfTS = inputs["dfTS"]
    by_rid(rid, sym) = by_rid_df(rid, sym, dfTS)

    FUSION = resources_with_fusion(inputs)

    #System-wide installed capacity is less than a specified maximum limit
    has_max_up = dfTS[dfTS.Max_Up.>=0, :R_ID]
    has_max_up = intersect(has_max_up, FUSION)

    active_frac = ones(G)
    avg_start_power = zeros(G)
    net_th_frac = ones(G)
    net_el_factor = zeros(G)

    active_frac[has_max_up] .=
        1 .- by_rid(has_max_up, :Dwell_Time) ./ by_rid(has_max_up, :Max_Up)
    avg_start_power[has_max_up] .=
        by_rid(has_max_up, :Start_Energy) ./ by_rid(has_max_up, :Max_Up)
    net_th_frac[FUSION] .=
        active_frac[FUSION] .* (1 .- by_rid(FUSION, :Recirc_Act)) .-
        by_rid(FUSION, :Recirc_Pass) .- avg_start_power[FUSION]
    net_el_factor[FUSION] .= dfGen[FUSION, :Eff_Down] .* net_th_frac[FUSION]

    dfGen.Average_Net_Electric_Factor = net_el_factor

    @expression(EP, eCAvgNetElectric[y in FUSION], EP[:vCCAP][y] * net_el_factor[y])
end

@doc raw"""
    fusion_formulation!(EP::Model, inputs::Dict)

Apply fusion-core-specific constraints to the model.

"""
function fusion_formulation!(EP::Model, inputs::Dict)

    dfGen = inputs["dfGen"]
    dfTS = inputs["dfTS"]

    by_rid(rid, sym) = by_rid_df(rid, sym, dfTS)

    FUSION = resources_with_fusion(inputs)
    vCP = EP[:vCP]
    vCCAP = EP[:vCCAP]
    vCSTART = EP[:vCSTART]
    vCCOMMIT = EP[:vCCOMMIT]
    core_cap_size(y) = by_rid(y, :Cap_Size)
    dwell_time(y) = by_rid(y, :Dwell_Time)
    max_starts(y) = by_rid(y, :Max_Starts)
    max_uptime(y) = by_rid(y, :Max_Up_Time)
    recirc_passive(y) = by_rid(y, :Recirc_Pass)
    recirc_active(y) = by_rid(y, :Recirc_Act)
    start_energy(y) = by_rid(y, :Start_Energy)
    start_power(y) = by_rid(y, :Start_Power)

    eff_down(y) = dfGen[y, :Eff_Down]
    resource_name(y) = dfGen[y, :Resource]

    FINITE_STARTS = intersect(FUSION, dfTS[dfTS.Max_Starts.>=0, :R_ID])

    resource_component(y) = resource_name(y) * "_ThermalCore"

    for y in FINITE_STARTS
        maximum_starts_constraint!(
            EP,
            inputs,
            y,
            max_starts(y),
            core_cap_size(y),
            :vCCAP,
            :vCSTART,
        )
    end

    for y in FUSION
        fusion_pulse_constraints!(
            EP,
            inputs,
            resource_component(y),
            y,
            max_uptime(y),
            dwell_time(y),
            core_cap_size(y),
            :vCP,
            :vCSTART,
            :vCCOMMIT,
        )

        fusion_parasitic_power!(
            EP,
            inputs,
            resource_component(y),
            y,
            core_cap_size(y),
            eff_down(y),
            dwell_time(y),
            start_energy(y),
            start_power(y),
            recirc_passive(y),
            recirc_active(y),
            :vCCAP,
            :vCSTART,
            :vCCOMMIT,
        )
    end
end

function total_fusion_power_balance_expressions!(EP::Model, inputs::Dict)
    T = 1:inputs["T"]     # Time steps
    Z = 1:inputs["Z"]     # Zones
    dfGen = inputs["dfGen"]
    FUSION = resources_with_fusion(inputs)

    # Total recirculating power from fusion in each zone
    gen_in_zone(z) = dfGen[dfGen.Zone.==z, :R_ID]

    FUSION_IN_ZONE = [intersect(FUSION, gen_in_zone(z)) for z in Z]
    @expression(
        EP,
        ePowerBalanceRecircFus[t in T, z in Z],
        -sum(eTotalRecircFus[t, y] for y in FUSION_IN_ZONE[z])
    )

    add_similar_to_expression(EP[:ePowerBalance], ePowerBalanceRecircFus)
end

@doc raw"""
    fusion_pulse_constraints!(EP::Model,
        inputs::Dict,
        r_id::Int,
        max_uptime::Int,
        dwell_time::Float64
        cap_size::Float64,
        vcommit::Symbol,
        vstart::Symbol,
        ecap::Symbol)

    Creates maintenance-tracking variables and adds their Symbols to two Sets in `inputs`.
    Adds constraints which act on the vCOMMIT-like variable.
"""
function fusion_pulse_constraints!(
    EP::Model,
    inputs::Dict,
    resource_component::AbstractString,
    r_id::Int,
    max_uptime::Int,
    dwell_time::Float64,
    component_size::Float64,
    vp::Symbol,
    vstart::Symbol,
    vcommit::Symbol,
)
    T = 1:inputs["T"]
    p = inputs["hours_per_subperiod"]

    y = r_id

    power = EP[vp]
    start = EP[vstart]
    commit = EP[vcommit]

    # Maximum thermal power generated by core y at hour y <= Max power of committed
    # core minus power lost from down time at startup
    @constraint(
        EP,
        [t in T],
        power[y, t] <= component_size * (commit[y, t] - dwell_time * start[y, t])
    )

    # Core max uptime. If this parameter > 0,
    # the fusion core must be cycled at least every n hours.
    # Looks back over interior timesteps and ensures that a core cannot
    # be committed unless it has been started at some point in
    # the previous n timesteps
    if max_uptime > 0
        starts_in_previous_hours(t) = start[y, hoursbefore(p, t, 0:(max_uptime-1))]
        @constraint(EP, [t in T], commit[y, t] <= sum(starts_in_previous_hours(t)))
    end

end

@doc raw"""
    maximum_starts_constraint!(EP::Model,
        inputs::Dict,
        r_id::Int,
        max_starts::Int,
        component_size::Float64,
        vstart::Symbol,
        etotalcap::Symbol)
"""
function maximum_starts_constraint!(
    EP::Model,
    inputs::Dict,
    r_id::Int,
    max_starts::Int,
    component_size::Float64,
    capacity::Symbol,
    vstart::Symbol,
)

    T = 1:inputs["T"]
    ω = inputs["omega"]
    y = r_id
    start = EP[vstart]
    totalcap = EP[etotalcap]

    @constraint(
        EP,
        sum(start[y, t] * ω[t] for t in T) <= max_starts * totalcap[y] / component_size
    )
end

function fusion_parasitic_power!(
    EP::Model,
    inputs::Dict,
    resource_component,
    r_id::Int,
    component_size::Float64,
    eff_down::Float64,
    dwell_time::Float64,
    parasitic_start_energy_factor::Float64,
    pulse_start_power_factor::Float64,
    parasitic_passive_factor::Float64,
    parasitic_active_factor::Float64,
    component_capacity::Symbol,
    vstart::Symbol,
    vcommit::Symbol,
)
    T = inputs["T"]
    y = r_id

    capacity = EP[component_capacity]
    start = EP[vstart]
    commit = EP[vcommit]

    passive = Symbol(fusion_parasitic_passive_name(resource_component))
    active = Symbol(fusion_parasitic_active_name(resource_component))
    start_energy = Symbol(fusion_parasitic_start_energy_name(resource_component))
    total_parasitic = Symbol(fusion_parasitic_total_name(resource_component))
    pulse_start_power = Symbol(fusion_pulse_start_power_name(resource_component))

    # Passive recirculating power, depending on built capacity
    ePassive =
        EP[passive] =
            @expression(EP, [t in T], capacity[y] * eff_down * parasitic_passive_factor)

    # Active recirculating power, depending on committed capacity
    eActive =
        EP[active] = @expression(
            EP,
            [t in T],
            component_size *
            eff_down *
            parasitic_active_factor *
            (commit[y, t] - start[y, t] * dwell_time)
        )
    # Startup energy, taken from the grid every time the core starts up
    eStartEnergy =
        EP[start_energy] = @expression(
            EP,
            [t in T],
            component_size * start[y, t] * eff_down * parasitic_start_energy_factor
        )

    EP[total_parasitic] =
        @expression(EP, [t in T], ePassiveRecirc[t] + eActive[t] + eStartEnergy[t])
    union!(inputs[FUSION_PARASITIC_POWER], (total_parasitic,))

    # Startup power, required margin on the grid when the core starts
    EP[pulse_start_power] = @expression(
        EP,
        [t in T],
        component_size * start[y, t] * eff_down * parasitic_start_power_factor
    )
    union!(inputs[FUSION_PULSE_START_POWER], (start_power,))

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
