const MAINTENANCE_DOWN_VARS = "MaintenanceDownVariables"
const MAINTENANCE_SHUT_VARS = "MaintenanceShutVariables"

@doc raw"""
    resources_with_maintenance(df::DataFrame)::Vector{Int}

    Get a vector of the R_ID's of all resources listed in a dataframe
    that have maintenance requirements. If there are none, return an empty vector.

    This method takes a specific dataframe because compound resources may have their
    data in multiple dataframes.
"""
function resources_with_maintenance(df::DataFrame)::Vector{Int}
    if "MAINT" in names(df)
        df[df.MAINT .> 0, :R_ID]
    else
        Vector{Int}[]
    end
end

@doc raw"""
    maintenance_down_name(resource_component::AbstractString)::String

    JuMP variable name to control whether a resource-component is down for maintenance.
    Here resource-component could be a whole resource or a component (for complex resources).
"""
function maintenance_down_name(resource_component::AbstractString)::String
    "vMDOWN_" * resource_component
end

@doc raw"""
    maintenance_shut_name(resource_component::AbstractString)::String

    JuMP variable name to control when a resource-components begins maintenance.
    Here resource-component could be a whole resource or a component (for complex resources).
"""
function maintenance_shut_name(resource_component::AbstractString)::String
    "vMSHUT_" * resource_component
end

function sanity_check_maintenance(MAINT::Vector{Int}, inputs::Dict)
    rep_periods = inputs["REP_PERIOD"]

    is_maint_reqs = !isempty(MAINT)
    if rep_periods > 1 && is_maint_reqs
        @error """Resources with R_ID $MAINT have MAINT > 0,
        but the number of representative periods ($rep_periods) is greater than 1.
        These are incompatible with a Maintenance requirement."""
        error("Incompatible GenX settings and maintenance requirements.")
    end
end

@doc raw"""
    controlling_maintenance_start_hours(p::Int, t::Int, maintenance_duration::Int, maintenance_begin_hours::UnitRange{Int64})

    p: hours_per_subperiod
    t: the current hour
    maintenance_duration: length of a maintenance period
    maintenance_begin_hours: collection of hours in which maintenance is allowed to start
"""
function controlling_maintenance_start_hours(p::Int,
    t::Int,
    maintenance_duration::Int,
    maintenance_begin_hours)
    controlled_hours = hoursbefore(p, t, 0:(maintenance_duration - 1))
    return intersect(controlled_hours, maintenance_begin_hours)
end

@doc raw"""
    maintenance_formulation!(EP::Model,
        inputs::Dict,
        resource_component::AbstractString,
        r_id::Int,
        maint_begin_cadence::Int,
        maint_dur::Int,
        maint_freq_years::Int,
        cap::Float64,
        vcommit::Symbol,
        ecap::Symbol,
        integer_operational_unit_commitment::Bool)

    EP: the JuMP model
    inputs: main data storage
    resource_component: unique resource name with optional component name
       If the plant has more than one component, this could identify a specific part which
       is undergoing maintenance.
    r_id: Resource ID (unique resource integer)
    maint_begin_cadence:
        It may be too expensive (from an optimization perspective) to allow maintenance
        to begin at any time step during the simulation. Instead this integer describes
        the cadence of timesteps in which maintenance can begin. Must be at least 1.
    maint_dur: Number of timesteps that maintenance takes. Must be at least 1.
    maint_freq_years: 1 is maintenannce every year,
        2 is maintenance every other year, etc. Must be at least 1.
    cap: Plant electrical capacity.
    vcommit: Symbol of vCOMMIT-like variable.
    ecap: Symbol of eTotalCap-like variable.
    integer_operational_unit_commitment: whether this plant has integer unit
        commitment for operational variables.

    Creates maintenance-tracking variables and adds their Symbols to two Sets in `inputs`.
    Adds constraints which act on the vCOMMIT-like variable.
"""
function maintenance_formulation!(EP::Model,
    inputs::Dict,
    resource_component::AbstractString,
    r_id::Int,
    maint_begin_cadence::Int,
    maint_dur::Int,
    maint_freq_years::Int,
    cap::Float64,
    vcommit::Symbol,
    ecap::Symbol,
    integer_operational_unit_commitment::Bool)
    T = 1:inputs["T"]
    hours_per_subperiod = inputs["hours_per_subperiod"]

    y = r_id
    down_name = maintenance_down_name(resource_component)
    shut_name = maintenance_shut_name(resource_component)
    down = Symbol(down_name)
    shut = Symbol(shut_name)

    union!(inputs[MAINTENANCE_DOWN_VARS], (down,))
    union!(inputs[MAINTENANCE_SHUT_VARS], (shut,))

    maintenance_begin_hours = 1:maint_begin_cadence:T[end]

    # create variables
    vMDOWN = EP[down] = @variable(EP, [t in T], base_name=down_name, lower_bound=0)
    vMSHUT = EP[shut] = @variable(EP,
        [t in maintenance_begin_hours],
        base_name=shut_name,
        lower_bound=0)

    if integer_operational_unit_commitment
        set_integer.(vMDOWN)
        set_integer.(vMSHUT)
    end

    vcommit = EP[vcommit]
    ecap = EP[ecap]

    # Maintenance variables are measured in # of plants
    @constraints(EP, begin
        [t in maintenance_begin_hours], vMSHUT[t] <= ecap[y] / cap
    end)

    # Plant is non-committed during maintenance
    @constraint(EP, [t in T], vMDOWN[t] + vcommit[y, t]<=ecap[y] / cap)

    function controlling_hours(t)
        controlling_maintenance_start_hours(hours_per_subperiod,
            t,
            maint_dur,
            maintenance_begin_hours)
    end
    # Plant is down for the required number of hours
    @constraint(EP, [t in T], vMDOWN[t]==sum(vMSHUT[controlling_hours(t)]))

    # Plant requires maintenance every (certain number of) year(s)
    @constraint(EP,
        sum(vMSHUT[t] for t in maintenance_begin_hours)>=ecap[y] / cap / maint_freq_years)

    return
end

@doc raw"""
    ensure_maintenance_variable_records!(dict::Dict)

    dict: a dictionary of model data

    This should be called by each method that adds maintenance formulations,
    to ensure that certain entries in the model data dict exist.
"""
function ensure_maintenance_variable_records!(dict::Dict)
    for var in (MAINTENANCE_DOWN_VARS, MAINTENANCE_SHUT_VARS)
        if var ∉ keys(dict)
            dict[var] = Set{Symbol}()
        end
    end
end

@doc raw"""
    has_maintenance(dict::Dict)

    dict: a dictionary of model data

    Checks whether the dictionary contains listings of maintenance-related variable names.
    This is true only after `maintenance_formulation!` has been called.
"""
function has_maintenance(dict::Dict)::Bool
    rep_periods = dict["REP_PERIOD"]
    MAINTENANCE_DOWN_VARS in keys(dict) && rep_periods == 1
end

@doc raw"""
    maintenance_down_variables(dict::Dict)

    dict: a dictionary of model data

    get listings of maintenance-related variable names.
    This is available only after `maintenance_formulation!` has been called.
"""
function maintenance_down_variables(dict::Dict)::Set{Symbol}
    dict[MAINTENANCE_DOWN_VARS]
end
