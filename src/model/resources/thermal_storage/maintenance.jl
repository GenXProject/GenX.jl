
function get_maintenance(inputs::Dict)::Vector{Int}
    dfTS = inputs["dfTS"]
    if "MAINT" in names(dfTS)
        dfTS[dfTS.MAINT.>0, :R_ID]
    else
        Vector{Int}[]
    end
end

function get_maintenance_duration(inputs::Dict)::Vector{Int}
    G = inputs["G"]

    by_rid(rid, sym) = by_rid_df(rid, sym, inputs["dfTS"])

    MAINTENANCE = get_maintenance(inputs)
    maint_dur = zeros(Int, G)
    maint_dur[MAINTENANCE] .= Int.(floor.(by_rid(MAINTENANCE, :Maintenance_Duration_Hours)))
    return maint_dur
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

function maintenance_constraints!(EP::Model, inputs::Dict, setup::Dict)

    @info "Thermal+Storage Maintenance Module"

    dfGen = inputs["dfGen"]

    T = 1:inputs["T"]     # Number of time steps (hours)

    hours_per_subperiod = inputs["hours_per_subperiod"]

    by_rid(rid, sym) = by_rid_df(rid, sym, inputs["dfTS"])

    FUS = get_fus(inputs)
    MAINTENANCE = get_maintenance(inputs)

    weights = inputs["omega"]

    maintenance_begin_cadence = setup["ThermalStorageMaintenanceStartCadence"]
    maintenance_begin_hours = 1:maintenance_begin_cadence:T[end]
    maint_dur = get_maintenance_duration(inputs)

    # UC variables for fusion core maintenance
    @variables(EP, begin
        vMDOWN[t in T, y in MAINTENANCE] >= 0  # core maintenance status
        vMSHUT[t in maintenance_begin_hours, y in MAINTENANCE] >= 0  # core maintenance shutdown
    end)

    if setup["UCommit"] == 1 # Integer UC constraints
        for y in MAINTENANCE
            set_integer.(vMDOWN[:,y])
            set_integer.(vMSHUT[:,y])
        end
    end

    vCCAP = EP[:vCCAP]
    vCCOMMIT = EP[:vCCOMMIT]

    # Upper bounds on optional maintenance variables
    @constraints(EP, begin
        [t in T, y in MAINTENANCE], vMDOWN[t,y] <= vCCAP[y] / by_rid(y,:Cap_Size)
        [t in maintenance_begin_hours, y in MAINTENANCE], vMSHUT[t,y] <= vCCAP[y] / by_rid(y,:Cap_Size)
    end)


    # Require plant to shut down during maintenance
    @constraint(EP, [t in T, y in MAINTENANCE],
        vCCAP[y] / by_rid(y,:Cap_Size) - vCCOMMIT[t,y] >= vMDOWN[t,y])

    controlling_hours(t,y) = controlling_maintenance_start_hours(hours_per_subperiod, t, maint_dur[y], maintenance_begin_hours)
    @constraint(EP, [t in T, y in MAINTENANCE],
                vMDOWN[t,y] == sum(vMSHUT[controlling_hours(t,y), y]))


    @constraint(EP, [y in MAINTENANCE],
        sum(vMSHUT[t,y]*weights[t] for t in maintenance_begin_hours) >= vCCAP[y] / by_rid(y,:Maintenance_Cadence_Years) / by_rid(y,:Cap_Size))

    frac_passive_to_reduce(y) = by_rid(y, :Recirc_Pass) * (1 - by_rid(y, :Recirc_Pass_Maintenance_Reduction))
    for y in intersect(FUS, MAINTENANCE), t in T
            add_to_expression!(EP[:ePassiveRecircFus][t,y],
                               -by_rid(y,:Cap_Size) * vMDOWN[t,y] * dfGen[y,:Eff_Down] * frac_passive_to_reduce(y))
    end
end
