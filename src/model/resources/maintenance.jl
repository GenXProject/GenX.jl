const MAINTENANCE_DOWN_VARS = "MaintenanceDownVariables"
const MAINTENANCE_SHUT_VARS = "MaintenanceShutVariables"
const HAS_MAINT = "HAS_MAINTENANCE"

function get_maintenance(df::DataFrame)::Vector{Int}
    if "MAINT" in names(df)
        df[df.MAINT.>0, :R_ID]
    else
        Vector{Int}[]
    end
end

function maintenance_down_name(inputs::Dict, y::Int, suffix::AbstractString)
    dfGen = inputs["dfGen"]
    resource = dfGen[y, :Resource]
    maintenance_down_name(resource, suffix)
end

function maintenance_down_name(resource::AbstractString, suffix::AbstractString)
    "vMDOWN_" * resource * "_" * suffix
end

function sanity_check_maintenance(MAINTENANCE::Vector{Int}, inputs::Dict)
    rep_periods = inputs["REP_PERIOD"]

    is_maint_reqs = !isempty(MAINTENANCE)
    if rep_periods > 1 && is_maint_reqs
        @error """Resources with R_ID $MAINTENANCE have MAINT > 0,
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
function controlling_maintenance_start_hours(p::Int, t::Int, maintenance_duration::Int, maintenance_begin_hours)
    controlled_hours = hoursbefore(p, t, 0:(maintenance_duration-1))
    return intersect(controlled_hours, maintenance_begin_hours)
end

@doc raw"""
    maintenance_constraints!(EP::Model,
        inputs::Dict,
        resource_name::AbstractString,
        suffix::AbstractString,
        r_id::Int,
        maint_begin_cadence::Int,
        maint_dur::Int,
        maint_freq_years::Int,
        cap::Float64,
        vcommit::Symbol,
        ecap::Symbol,
        integer_operational_unit_committment::Bool)

    EP: the JuMP model
    inputs: main data storage
    resource_name: unique resource name
    r_id: Resource ID (unique resource integer)
    suffix: the part of the plant which has maintenance applied
    maint_begin_cadence:
        It may be too expensive (from an optimization perspective) to allow maintenance
        to begin at any time step during the simulation. Instead this integer describes
        the cadence of timesteps in which maintenance can begin. Must be at least 1.
    maint_dur: Number of timesteps that maintenance takes. Must be at least 1.
    maint_freq_years: 1 is maintenannce every year,
        2 is maintenance every other year, etc. Must be at least 1.
    cap: Plant electrical capacity.
    vcommit: symbol of vCOMMIT-like variable.
    ecap: symbol of eTotalCap-like variable.
    integer_operational_unit_committment: whether this plant has integer unit
        committment for operational variables.
"""
function maintenance_constraints!(EP::Model,
        inputs::Dict,
        resource_name::AbstractString,
        suffix::AbstractString,
        r_id::Int,
        maint_begin_cadence::Int,
        maint_dur::Int,
        maint_freq_years::Int,
        cap::Float64,
        vcommit::Symbol,
        ecap::Symbol,
        integer_operational_unit_committment::Bool)

    T = 1:inputs["T"]     # Number of time steps (hours)
    hours_per_subperiod = inputs["hours_per_subperiod"]

    y = r_id
    down_name = maintenance_down_name(resource_name, suffix)
    shut_name = "vMSHUT_" * resource_name * "_" * suffix
    down = Symbol(down_name)
    shut = Symbol(shut_name)

    union!(inputs["MaintenanceDownVariables"], (down,))
    union!(inputs["MaintenanceShutVariables"], (shut,))

    maintenance_begin_hours = 1:maint_begin_cadence:T[end]

    # create variables
    vMDOWN = EP[down] = @variable(EP, [t in T], base_name=down_name, lower_bound=0)
    vMSHUT = EP[shut] = @variable(EP, [t in maintenance_begin_hours],
                                      base_name=shut_name,
                                      lower_bound=0)

    if integer_operational_unit_committment
        set_integer.(vMDOWN)
        set_integer.(vMSHUT)
    end

    vcommit = EP[vcommit]
    ecap = EP[ecap]

    # Maintenance variables are measured in # of plants
    @constraints(EP, begin
        [t in T], vMDOWN[t] <= ecap[y] / cap
        [t in maintenance_begin_hours], vMSHUT[t] <= ecap[y] / cap
    end)

    # Plant is non-committed during maintenance
    @constraint(EP, [t in T], ecap[y] / cap - vcommit[y,t] >= vMDOWN[t])

    controlling_hours(t) = controlling_maintenance_start_hours(hours_per_subperiod,
                                                               t,
                                                               maint_dur,
                                                               maintenance_begin_hours)
    # Plant is down for the required number of hours
    @constraint(EP, [t in T], vMDOWN[t] == sum(vMSHUT[controlling_hours(t)]))

    # Plant require maintenance every (certain number of) year(s)
    @constraint(EP, sum(vMSHUT[t] for t in maintenance_begin_hours) >=
                ecap[y] / cap / maint_freq_years)

    return down, shut
end

function ensure_maintenance_variable_records!(inputs::Dict)
    inputs[HAS_MAINT] = true
    for var in (MAINTENANCE_DOWN_VARS, MAINTENANCE_SHUT_VARS)
        if var ∉ keys(inputs)
            inputs[var] = Set{Symbol}()
        end
    end
end

function has_maintenance(inputs::Dict)::Bool
    rep_periods = inputs["REP_PERIOD"]
    HAS_MAINT in keys(inputs) && rep_periods == 1
end

function get_maintenance_down_variables(inputs::Dict)::Set{Symbol}
    inputs[MAINTENANCE_DOWN_VARS]
end
