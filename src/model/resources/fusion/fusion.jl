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

function has_parasitic_power(r::FusionReactorData)
    r.parasitic_start_energy > 0 || r.parasitic_passive_fraction > 0 || r.parasitic_active_fraction > 0
end

function has_finite_starts(r::FusionReactorData)
    r.max_starts > 0
end

function has_pulse_start_power(r::FusionReactorData)
    r.pulse_start_power_fraction > 0
end

# keeping this for later
function fusion_average_net_electric_power_factor!(reactor::FusionReactorData)
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

# keeping this function for later
# function fusion_average_net_electric_power_expression!(EP::Model, inputs::Dict)
#     dfGen = inputs["dfGen"]
#
#     by_rid(rid, sym) = by_rid_df(rid, sym, dfTS)
#
#     FUSION = resources_with_fusion(inputs)
#
#     @expression(EP, eFusionAvgNetElectric[y in FUSION], EP[:eTotalCap][y] * net_el_factor[y])
# end

function fusion_formulation!(EP,
        inputs,
        resource_component::AbstractString,
        r_id::Int,
        reactor::FusionReactorData;
        capacity::Symbol,
        vp::Symbol,
        vstart::Symbol,
        vcommit::Symbol)

    fusion_parasitic_power!(
        EP,
        inputs,
        resource_component,
        r_id,
        reactor,
        capacity,
        vstart,
        vcommit,
    )

    if has_finite_starts(reactor)
        maximum_starts_constraint!(
            EP,
            inputs,
            y,
            reactor,
            capacity,
            vstart,
        )
    end

    fusion_pulse_constraints!(
        EP,
        inputs,
        resource_component,
        y,
        reactor,
        vp,
        vstart,
        vcommit,
    )

end

# capacity reserve margin adjustment for recirc, pulses
# capacity reserve margin adjustment for fusion+maintenance

@doc raw"""
    fusion_pulse_constraints!(EP::Model,
                              inputs::Dict,
                              resource_component::AbstractString,
                              r_id::Int,
                              reactor::FusionReactorData,
                              vp::Symbol,
                              vstart::Symbol,
                              vcommit::Symbol)

    Creates maintenance-tracking variables and adds their Symbols to two Sets in `inputs`.
    Adds constraints which act on the vCOMMIT-like variable.
"""
function fusion_pulse_constraints!(
    EP::Model,
    inputs::Dict,
    resource_component::AbstractString,
    r_id::Int,
    reactor::FusionReactorData,
    vp::Symbol,
    vstart::Symbol,
    vcommit::Symbol,
)
    T = 1:inputs["T"]
    p = inputs["hours_per_subperiod"]

    y = r_id

    component_size = reactor.component_size
    dwell_time = reactor.dwell_time
    max_pulse_length = reactor.max_pulse_length

    power = EP[vp]
    start = EP[vstart]
    commit = EP[vcommit]

    # Maximum thermal power generated by core y at hour y <= Max power of committed
    # core minus power lost from down time at startup
    if dwell_time > 0
        @constraint(
            EP,
            [t in T],
            power[y, t] <= component_size * (commit[y, t] - dwell_time * start[y, t])
        )
    end

    # Core max uptime. If this parameter > 0,
    # the fusion core must be cycled at least every n hours.
    # Looks back over interior timesteps and ensures that a core cannot
    # be committed unless it has been started at some point in
    # the previous n timesteps
    if max_pulse_length > 0
        starts_in_previous_hours(t) = start[y, hoursbefore(p, t, 0:(max_pulse_length - 1))]
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
    reactor::FusionReactorData,
    capacity::Symbol,
    vstart::Symbol,
)

    T = 1:inputs["T"]
    ω = inputs["omega"]
    y = r_id
    component_size = reactor.component_size
    max_starts = reactor.max_starts
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
    reactor::FusionReactorData,
    component_capacity::Symbol,
    vstart::Symbol,
    vcommit::Symbol,
)
    T = inputs["T"]
    y = r_id

    component_size = reactor.component_size
    parasitic_passive_fraction = reactor.parasitic_passive_fraction
    parasitic_active_fraction = reactor.parasitic_active_fraction
    parasitic_start_energy_fraction = reactor.parasitic_start_energy_fraction
    pulse_start_power_fraction = pulse_start_power_fraction
    dwell_time = reactor.dwell_time
    η = reactor.eff_down

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
            @expression(EP, [t in T], capacity[y] * η * parasitic_passive_fraction)

    # Active recirculating power, depending on committed capacity
    eActive =
        EP[active] = @expression(
            EP,
            [t in T],
            component_size *
            η *
            parasitic_active_fraction *
            (commit[y, t] - start[y, t] * dwell_time)
        )
    # Startup energy, taken from the grid every time the core starts up
    eStartEnergy =
        EP[start_energy] = @expression(
            EP,
            [t in T],
            component_size * start[y, t] * η * parasitic_start_energy_fraction
        )

    EP[total_parasitic] =
        @expression(EP, [t in T], ePassiveRecirc[t] + eActive[t] + eStartEnergy[t])
    union!(inputs[FUSION_PARASITIC_POWER], (total_parasitic,))

    # Startup power, required margin on the grid when the core starts
    EP[pulse_start_power] = @expression(
        EP,
        [t in T],
        component_size * start[y, t] * η * pulse_start_power_fraction
    )
    union!(inputs[FUSION_PULSE_START_POWER], (start_power,))

end

function fusion_parasitic_power_balance_adjustment!(EP, inputs::Dict, df::DataFrame, component::AbstractString="")
    T = 1:inputs["T"]
    zones_for_resources = inputs["R_ZONES"]

    FUSION = resources_with_fusion(df)
    for y in FUSION
        z = zones_for_resources[y]
        resource_component = df[y, :Resource] * component
        eTotalParasitic = EP[Symbol(fusion_parasitic_total_name(resource_component))]
        for t in T
            add_to_expression!(EP[:ePowerBalance][t, z], eTotalParasitic[t])
        end
    end
end

function total_fusion_parasitic_power_balance_adjustment!(EP::Model, inputs::Dict)
     T = inputs["T"]     # Time steps
     Z = inputs["Z"]     # Zones
     dfGen = inputs["dfGen"]
     FUSION = resources_with_fusion(inputs)
     # Total recirculating power from fusion in each zone
     gen_in_zone(z) = dfGen[dfGen.Zone.==z, :R_ID]
     FUSION_IN_ZONE = [intersect(FUSION, gen_in_zone(z)) for z in Z]

     function parasitic(t, y)
         resource_component = dfGen[y, :Resource]
         total_parasitic = Symbol(fusion_parasitic_total_name(resource_component))
         EP[total_parasitic][t]
     end

     @expression(
         EP,
         ePowerBalanceRecircFus[t in 1:T, z in 1:Z],
         -sum(parasitic(t, y) for y in FUSION_IN_ZONE[z])
     )

     add_similar_to_expression(EP[:ePowerBalance], ePowerBalanceRecircFus)
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

# function thermal_commit_reserves!(EP::Model, inputs::Dict)
#
# 	@info "Thermal Commit Reserves Module"
#
# 	dfGen = inputs["dfGen"]
#
# 	T = 1:inputs["T"]     # Number of time steps (hours)
#
# 	THERM_COMMIT = inputs["THERM_COMMIT"]
#     REG = inputs["REG"]
#     RSV = inputs["RSV"]
#
#     pP_Max = inputs["pP_Max"]
#
# 	THERM_COMMIT_REG = intersect(THERM_COMMIT, REG) # Set of thermal resources with regulation reserves
# 	THERM_COMMIT_RSV = intersect(THERM_COMMIT, RSV) # Set of thermal resources with spinning reserves
#
#     vP = EP[:vP]
#     vREG = EP[:vREG]
#     vRSV = EP[:vRSV]
#     vCOMMIT = EP[:vCOMMIT]
#     cap_size(y) = dfGen[y, :Cap_Size]
#     reg_max(y) = dfGen[y, :Reg_Max]
#     rsv_max(y) = dfGen[y, :Rsv_Max]
#
#     max_lhs = @expression(EP, [y in THERM_COMMIT, t in T], vP[y, t])
#     max_rhs = @expression(EP, [y in THERM_COMMIT, t in T], pP_Max[y, t] * cap_size(y) * vCOMMIT[y, t])
#
#     min_stable_lhs = @expression(EP, [y in THERM_COMMIT, t in T], vP[y, t])
#     min_stable_rhs = @expression(EP, [y in THERM_COMMIT, t in T], min_power(y) * cap_size(y) * vCOMMIT[y, t])
#
#     S = THERM_COMMIT_REG
#     add_similar_to_expression!(max_lhs[S, :], vREG[S, :])
#     add_similar_to_expression!(min_stable_lhs[S, :], -vREG[S, :])
#
#     S = THERM_COMMIT_RSV
#     add_similar_to_expression!(max_lhs[S, :], vRSV[S, :])
#
#     @constraints(EP, begin
#         # Minimum stable power generated per technology "y" at hour "t" and contribution to regulation must be > min power
#         [y in THERM_COMMIT, t in T], min_stable_lhs[y, t] >= min_stable_rhs[y, t]
#         # Maximum power generated per technology "y" at hour "t"  and contribution to regulation and reserves up must be < max power
#         [y in THERM_COMMIT, t in T], max_lhs[y, t] <= max_rhs[y, t]
#     end)
#
#     # Maximum regulation and reserve contributions
#     @constraints(EP, [y in THERM_COMMIT_REG, t in T],
#                  vREG[y, t] <= pP_Max[y, t] * reg_max(y) * cap_size(y) * vCOMMIT[y, t])
#     @constraints(EP, [y in THERM_COMMIT_RSV, t in T],
#                  vRSV[y, t] <= pP_Max[y, t] * rsv_max(y) * cap_size(y) * vCOMMIT[y, t])
#
# end
#
function fusion_thermal_commit_reserves!(EP::Model, inputs::Dict)

	@info "Fusion thermal Commit Reserves Module"

	dfGen = inputs["dfGen"]

	T = 1:inputs["T"]     # Number of time steps (hours)

	THERM_COMMIT = inputs["THERM_COMMIT"]
    REG = inputs["REG"]
    RSV = inputs["RSV"]

    pP_Max = inputs["pP_Max"]

	THERM_COMMIT_REG = intersect(THERM_COMMIT, REG) # Resources with regulation reserves
	THERM_COMMIT_RSV = intersect(THERM_COMMIT, RSV) # Resources with spinning reserves

    vP = EP[:vP]
    vREG = EP[:vREG]
    vRSV = EP[:vRSV]
    vSTART = EP[:vSTART]
    vCOMMIT = EP[:vCOMMIT]
    cap_size(y) = dfGen[y, :Cap_Size]
    reg_max(y) = dfGen[y, :Reg_Max]
    rsv_max(y) = dfGen[y, :Rsv_Max]

    dwell_time(y) = dfGen[y, :Dwell_Time]

    max_lhs = @expression(EP, [y in THERM_COMMIT, t in T], vP[y, t])
    max_rhs = @expression(EP, [y in THERM_COMMIT, t in T],
                          pP_Max[y, t] * cap_size(y) * vCOMMIT[y, t])

    min_stable_lhs = @expression(EP, [y in THERM_COMMIT, t in T], vP[y, t])
    min_stable_rhs = @expression(EP, [y in THERM_COMMIT, t in T],
                                 min_power(y) * cap_size(y) * vCOMMIT[y, t])

    S = THERM_COMMIT_REG
    add_similar_to_expression!(max_lhs[S, :], vREG[S, :])
    add_similar_to_expression!(min_stable_lhs[S, :], -vREG[S, :])

    S = FUSION
    lost_production_dwell_fusion = @expression(EP, [y in S, t in T],
                                               -pP_Max[y, t] * cap_size(y) * dwell_time(y) * vSTART[y, t])
    add_similar_to_expression!(max_rhs[S, :], lost_production_dwell_fusion[S, :])

    S = THERM_COMMIT_RSV
    add_similar_to_expression!(max_lhs[S, :], vRSV[S, :])

    @constraints(EP, begin
        # Minimum stable power generated and contribution to regulation must be > min power
        [y in THERM_COMMIT, t in T], min_stable_lhs[y, t] >= min_stable_rhs[y, t]
        # Maximum power generated and contribution to regulation and reserves up must be < max power
        [y in THERM_COMMIT, t in T], max_lhs[y, t] <= max_rhs[y, t]
    end)

    # Maximum regulation and reserve contributions
    @constraints(EP, [y in THERM_COMMIT_REG, t in T],
                 vREG[y, t] <= pP_Max[y, t] * reg_max(y) * cap_size(y) * vCOMMIT[y, t])
    @constraints(EP, [y in THERM_COMMIT_RSV, t in T],
                 vRSV[y, t] <= pP_Max[y, t] * rsv_max(y) * cap_size(y) * vCOMMIT[y, t])

end
