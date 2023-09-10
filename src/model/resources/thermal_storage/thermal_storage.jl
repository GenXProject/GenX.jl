"""
GenX: An Configurable Capacity Expansion Model
Copyright (C) 2021,  Massachusetts Institute of Technology
This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
A complete copy of the GNU General Public License v2 (GPLv2) is available
in LICENSE.txt.  Users uncompressing this from an archive may not have
received this license file.  If not, see <http://www.gnu.org/licenses/>.
"""

function by_rid_df(rid::Integer, sym::Symbol, df::DataFrame)
    return df[df.R_ID .== rid, sym][]
end

function by_rid_df(rid::Vector{Int}, sym::Symbol, df::DataFrame)
    indices = [findall(x -> x == y, df.R_ID)[] for y in rid]
    return df[indices, sym]
end

function get_fus(inputs::Dict)::Vector{Int}
    dfTS = inputs["dfTS"]
    dfTS[dfTS.FUS.>=1,:R_ID]
end

function get_conventional_thermal_core(inputs::Dict)::Vector{Int}
    dfTS = inputs["dfTS"]
    dfTS[dfTS.FUS.==0,:R_ID]
end

function get_resistive_heating(inputs::Dict)::Vector{Int}
    dfTS = inputs["dfTS"]
    if "RH" in names(dfTS)
        dfTS[dfTS.RH.==1,:R_ID]
    else
        Vector{Int}[]
    end
end

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

function split_LDS_and_nonLDS(inputs::Dict)
    df = inputs["dfGen"]
    TS = inputs["TS"]
    rep_periods = inputs["REP_PERIOD"]
    if rep_periods > 1
        TS_and_LDS = intersect(TS, df[df.LDS.==1,:R_ID])
        TS_and_nonLDS = intersect(TS, df[df.LDS.!=1,:R_ID])
    else
        TS_and_LDS = Int[]
        TS_and_nonLDS = TS
    end
    TS_and_LDS, TS_and_nonLDS
end

@doc raw"""
    thermal_storage(EP::Model, inputs::Dict, setup::Dict)

"""
function thermal_storage!(EP::Model, inputs::Dict, setup::Dict)

    @info "Thermal Storage Module"

    thermal_storage_base_variables!(EP, inputs)
    thermal_storage_core_commit!(EP, inputs, setup)

    thermal_storage_capacity_costs!(EP, inputs)
    thermal_storage_variable_costs!(EP, inputs)
    thermal_storage_quantity_constraints!(EP, inputs)
    thermal_storage_resistive_heating_power_balance!(EP, inputs)

    TS_and_LDS, TS_and_nonLDS = split_LDS_and_nonLDS(inputs)
    if !isempty(TS_and_LDS)
        thermal_storage_lds_constraints!(EP, inputs)
    end

    thermal_storage_capacity_ratio_constraints!(EP, inputs)
    thermal_storage_duration_constraints!(EP, inputs)

    ### CONVENTIONAL CORE CONSTRAINTS ###
    CONV = get_conventional_thermal_core(inputs)

    if !isempty(CONV)
        conventional_thermal_core_effective_electric_power_expression!(EP, inputs)
        conventional_thermal_core_systemwide_max_cap_constraint!(EP, inputs)
        conventional_thermal_core_constraints!(EP, inputs, setup)
    end

    ### FUSION CONSTRAINTS ###
    FUS =  get_fus(inputs)

    if !isempty(FUS)
        fusion_average_net_electric_power_expression!(EP, inputs)
        fusion_systemwide_max_cap_constraint!(EP, inputs)
        fusion_constraints!(EP, inputs, setup)
    end

    MAINTENANCE = get_maintenance(inputs)
    if !isempty(MAINTENANCE)
        sanity_check_maintenance(MAINTENANCE, inputs)
        maintenance_constraints!(EP, inputs, setup)
    end

    if setup["CapacityReserveMargin"] > 0
        thermal_storage_capacity_reserve_margin!(EP, inputs)
    end

    thermal_core_emissions!(EP, inputs)

    # must be run after maintenance
    total_fusion_power_balance_expressions!(EP, inputs)
    return
end

function thermal_storage_base_variables!(EP::Model, inputs::Dict)
    T = 1:inputs["T"]
    TS = inputs["TS"]
    RH = get_resistive_heating(inputs)
    @variables(EP, begin
        # Thermal core variables
        vCP[t in T, y in TS] >= 0      #thermal core power for resource y at timestep t
        vCCAP[y in TS] >= 0             #thermal core capacity for resource y

        # Thermal storage variables
        vTS[t in T, y in TS] >= 0      #thermal storage state of charge for resource y at timestep t
        vTSCAP[y in TS] >= 0            #thermal storage energy capacity for resource y

        # resistive heating variables
        vRH[t in T, y in RH] >= 0      #electrical energy from grid
        vRHCAP[y in RH] >= 0            #RH power capacity for resource
    end)
end

function thermal_storage_core_commit!(EP::Model, inputs::Dict, setup::Dict)
    dfTS = inputs["dfTS"]
    T = 1:inputs["T"]
    CONV = get_conventional_thermal_core(inputs)
    FUS =  get_fus(inputs)
    THERM_COMMIT = inputs["THERM_COMMIT"]
    p = inputs["hours_per_subperiod"]

    CONV_COMMIT = intersect(THERM_COMMIT, CONV)
    set = union(FUS, CONV_COMMIT)

    by_rid(rid, sym) = by_rid_df(rid, sym, dfTS)

    if isempty(set)
        return
    end

    @variables(EP, begin
        vCCOMMIT[t in T, y in set] >= 0 #core commitment status
        vCSTART[t in T, y in set] >= 0 #core startup
        vCSHUT[t in T, y in set] >= 0 #core shutdown
    end)

    if setup["UCommit"] == 1 # Integer UC constraints
        for y in set
            set_integer.(vCCOMMIT[:, y])
            set_integer.(vCSTART[:, y])
            set_integer.(vCSHUT[:,y])
        end
    end

    # Upper bounds on core commitment/start/shut, and optional maintenance variables
    @constraints(EP, begin
        [t in T, y in set], vCCOMMIT[t,y] <= EP[:vCCAP][y] / by_rid(y,:Cap_Size)
        [t in T, y in set], vCSTART[t,y] <= EP[:vCCAP][y] / by_rid(y,:Cap_Size)
        [t in T, y in set], vCSHUT[t,y] <= EP[:vCCAP][y] / by_rid(y,:Cap_Size)
    end)

    # Minimum and maximum core power output
    @constraints(EP, begin
        # Minimum stable thermal power generated by core y at
        # hour y >= Min power of committed core
        [t in T, y in set], EP[:vCP][t,y] >= by_rid(y, :Min_Power) * by_rid(y, :Cap_Size) * vCCOMMIT[t,y]
        [t in T, y in set], EP[:vCP][t,y] <= by_rid(y, :Cap_Size) * vCCOMMIT[t,y]
    end)

    # Commitment state constraint linking startup and shutdown decisions (Constraint #4)
    @constraint(EP, [t in T, y in set],
        vCCOMMIT[t,y] == vCCOMMIT[hoursbefore(p,t,1), y] + vCSTART[t,y] - vCSHUT[t,y])
end

function thermal_storage_capacity_costs!(EP::Model, inputs::Dict)
    dfTS = inputs["dfTS"]
    TS = inputs["TS"]
    RH = get_resistive_heating(inputs)

    by_rid(rid, sym) = by_rid_df(rid, sym, dfTS)

    vCCAP = EP[:vCCAP]
    vTSCAP = EP[:vTSCAP]
    vRHCAP = EP[:vRHCAP]

    # Core investment costs
    # fixed cost for thermal core y
    @expression(EP, eCFixed_Core[y in TS], by_rid(y,:Fixed_Cost_per_MW_th) * vCCAP[y])
    # total fixed costs for all thermal cores
    @expression(EP, eTotalCFixedCore, sum(eCFixed_Core[y] for y in TS))
    EP[:eObj] += eTotalCFixedCore

    # Thermal storage investment costs
    # Fixed costs for thermal storage y
    @expression(EP, eCFixed_TS[y in TS], by_rid(y,:Fixed_Cost_per_MWh_th) * vTSCAP[y])
    # Total fixed costs for all thermal storage
    @expression(EP, eTotalCFixedTS, sum(eCFixed_TS[y] for y in TS))
    EP[:eObj] += eTotalCFixedTS

    # Resistive heating investment costs
    # Fixed costs for resource y
    @expression(EP, eCFixed_RH[y in RH], by_rid(y, :Fixed_Cost_per_MW_RH) * vRHCAP[y])
    # Total fixed costs for all resistive heating
    @expression(EP, eTotalCFixedRH, sum(eCFixed_RH[y] for y in RH))
    EP[:eObj] += eTotalCFixedRH
end

function thermal_storage_variable_costs!(EP::Model, inputs::Dict)
    dfTS = inputs["dfTS"]
    TS = inputs["TS"]
    T = 1:inputs["T"]

    by_rid(rid, sym) = by_rid_df(rid, sym, dfTS)
    vCP = EP[:vCP]

    # Variable cost of core operation
    # Variable cost at timestep t for thermal core y
    @expression(EP, eCVar_Core[t in T, y in TS], inputs["omega"][t] * (by_rid(y, :Var_OM_Cost_per_MWh_th) + inputs["TS_C_Fuel_per_MWh"][y][t]) * vCP[t,y])
    # Variable cost from all thermal cores at timestep t)
    @expression(EP, eTotalCVarCoreT[t in T], sum(eCVar_Core[t,y] for y in TS))
    # Total variable cost for all thermal cores
    @expression(EP, eTotalCVarCore, sum(eTotalCVarCoreT[t] for t in T))
    EP[:eObj] += eTotalCVarCore
end

function thermal_storage_capacity_limits!(EP::Model, inputs::Dict)
    dfTS = inputs["dfTS"]
    by_rid(rid, sym) = by_rid_df(rid, sym, dfTS)

    vCCAP = EP[:vCCAP]
    # Total installed capacity is less than specified maximum limit
    those_with_max_cap = dfTS[dfTS.Max_Cap_MW_th.>=0, :R_ID]
    @constraint(EP, cCCAPMax[y in those_with_max_cap], vCCAP[y] <= by_rid(y, :Max_Cap_MW_th))
end


function thermal_storage_quantity_constraints!(EP::Model, inputs::Dict)
    dfGen = inputs["dfGen"]
    T = 1:inputs["T"]
    p = inputs["hours_per_subperiod"]
    TS = inputs["TS"]
    RH = get_resistive_heating(inputs)
    vP = EP[:vP]
    vCP = EP[:vCP]
    vCCAP = EP[:vCCAP]
    vTSCAP = EP[:vTSCAP]
    vRHCAP = EP[:vRHCAP]
    vTS = EP[:vTS]
    vRH = EP[:vRH]

    ### THERMAL CORE CONSTRAINTS ###
    # Core power output must be <= installed capacity, including hourly capacity factors
    @constraint(EP, cCPMax[t in T, y in TS], vCP[t,y] <= vCCAP[y]*inputs["pP_Max"][y,t])

    ### THERMAL STORAGE CONSTRAINTS ###
    # Storage state of charge must be <= installed capacity
    @constraint(EP, cTSMax[t in T, y in TS], vTS[t,y] <= vTSCAP[y])

    # thermal state of charge balance for interior timesteps:
    # (previous SOC) - (discharge to turbines) - (turbine startup energy use) + (core power output) - (self discharge)
    @expression(EP, eTSSoCBalRHS[t in T, y in TS],
        vTS[hoursbefore(p, t, 1), y]
        - (1 / dfGen[y, :Eff_Down] * vP[y,t])
        - (1 / dfGen[y, :Eff_Down] * dfGen[y, :Start_Fuel_MMBTU_per_MW] * dfGen[y,:Cap_Size] * EP[:vSTART][y,t])
        + (dfGen[y,:Eff_Up] * vCP[t,y])
        - (dfGen[y,:Self_Disch] * vTS[hoursbefore(p, t, 1), y]))

    for y in RH, t in T
        add_to_expression!(EP[:eTSSoCBalRHS][t,y], vRH[t,y])
    end

    @constraint(EP, cTSSoCBal[t in T, y in TS], vTS[t,y] == eTSSoCBalRHS[t,y])

    ### RESISTIVE HEATING ###
    # Capacity constraint for RH
    @constraint(EP, cRHMax[t in T, y in RH], vRH[t, y] <= vRHCAP[y])
end

function thermal_storage_resistive_heating_power_balance!(EP::Model, inputs::Dict)
    dfGen = inputs["dfGen"]
    T = 1:inputs["T"]
    Z = 1:inputs["Z"]
    RH = get_resistive_heating(inputs)
    vRH = EP[:vRH]
    @expression(EP, ePowerBalanceRH[t in T, z in Z],
        - sum(vRH[t, y] for y in intersect(RH, dfGen[dfGen[!, :Zone].==z, :R_ID])))
    EP[:ePowerBalance] += ePowerBalanceRH
end


function thermal_storage_lds_constraints!(EP::Model, inputs::Dict)
    dfGen = inputs["dfGen"]
    p = inputs["hours_per_subperiod"]
    REP_PERIOD = inputs["REP_PERIOD"]
    dfPeriodMap = inputs["Period_Map"]

    TS_and_LDS, TS_and_nonLDS = split_LDS_and_nonLDS(inputs)
    nperiods = nrow(dfPeriodMap)

    MODELED_PERIODS_INDEX = 1:nperiods
    REP_PERIODS_INDEX = MODELED_PERIODS_INDEX[dfPeriodMap.Rep_Period .== MODELED_PERIODS_INDEX]

    vP = EP[:vP] # outflow
    vCP = EP[:vCP] # inflow
    vTS = EP[:vTS] # state of charge

    @variable(EP, vTSOCw[n in MODELED_PERIODS_INDEX, y in TS_and_LDS] >= 0)

    # Build up in storage inventory over each representative period w
    # Build up inventory can be positive or negative
    @variable(EP, vdTSOC[w in 1:REP_PERIOD, y in TS_and_LDS])
    # Note: tw_min = hours_per_subperiod*(w-1)+1; tw_max = hours_per_subperiod*w
    @constraint(EP, cThermSoCBalLongDurationStorageStart[w in 1:REP_PERIOD, y in TS_and_LDS], (
        vTS[hours_per_subperiod * (w - 1) + 1, y] ==
                   (1 - dfGen[y, :Self_Disch]) * (vTS[hours_per_subperiod * w, y] - vdTSOC[w, y])
                 - (1 / dfGen[y, :Eff_Down] * vP[y, hours_per_subperiod * (w - 1) + 1])
                 - (1 / dfGen[y, :Eff_Down] * dfGen[y,:Start_Fuel_MMBTU_per_MW] * dfGen[y,:Cap_Size] * EP[:vSTART][y,hours_per_subperiod * (w - 1) + 1])
                 + (dfGen[y, :Eff_Up] * vCP[y,hours_per_subperiod * (w - 1) + 1])
             ))

    # Storage at beginning of period w = storage at beginning of period w-1 + storage built up in period w (after n representative periods)
    ## Multiply storage build up term from prior period with corresponding weight
    @constraint(EP, cThermSoCBalLongDurationStorage[r in MODELED_PERIODS_INDEX, y in TS_and_LDS],
                    vTSOCw[mod1(r+1, nperiods), y] == vTSOCw[r, y] + vdTSOC[dfPeriodMap[r,:Rep_Period_Index], y])

    # Storage at beginning of each modeled period cannot exceed installed energy capacity
    @constraint(EP, cThermSoCBalLongDurationStorageUpper[r in MODELED_PERIODS_INDEX, y in TS_and_LDS],
                    vTSOCw[r, y] <= vTSCAP[y])

    # Initial storage level for representative periods must also adhere to sub-period storage inventory balance
    # Initial storage = Final storage - change in storage inventory across representative period
    @constraint(EP, cThermSoCBalLongDurationStorageSub[r in REP_PERIODS_INDEX, y in TS_and_LDS],
                    vTSOCw[r, y] == vTS[hours_per_subperiod*dfPeriodMap[r,:Rep_Period_Index], y]
                                    - vdTSOC[dfPeriodMap[r,:Rep_Period_Index], y])
end


function thermal_storage_capacity_ratio_constraints!(EP::Model, inputs::Dict)
    dfGen = inputs["dfGen"]
    dfTS = inputs["dfTS"]
    vCCAP = EP[:vCCAP]
    by_rid(rid, sym) = by_rid_df(rid, sym, dfTS)

    has_max_ratio = dfTS[dfTS.Max_Generator_Core_Power_Ratio.>=0, :R_ID]
    max_ratio(y) = by_rid(y, :Max_Generator_Core_Power_Ratio)
    @constraint(EP, cCPRatMax[y in has_max_ratio],
        vCCAP[y] * dfGen[y,:Eff_Down] * max_ratio(y) >= EP[:eTotalCap][y])

    has_min_ratio = dfTS[dfTS.Min_Generator_Core_Power_Ratio.>=0, :R_ID]
    min_ratio(y) = by_rid(y, :Min_Generator_Core_Power_Ratio)
    @constraint(EP, cCPRatMin[y in has_min_ratio],
        vCCAP[y] * dfGen[y,:Eff_Down] * min_ratio(y) <= EP[:eTotalCap][y])
end

function thermal_storage_duration_constraints!(EP::Model, inputs::Dict)
    dfGen = inputs["dfGen"]
    TS = inputs["TS"]
    vCCAP = EP[:vCCAP]
    vTSCAP = EP[:vTSCAP]
    # Limits on storage duration
    MIN_DUR = intersect(TS, dfGen[dfGen.Min_Duration .>= 0, :R_ID])
    MAX_DUR = intersect(TS, dfGen[dfGen.Max_Duration .>= 0, :R_ID])
    @constraint(EP, cTSMinDur[y in MIN_DUR], vTSCAP[y] >= dfGen[y,:Min_Duration] * vCCAP[y])
    @constraint(EP, cTSMaxDur[y in MAX_DUR], vTSCAP[y] <= dfGen[y,:Max_Duration] * vCCAP[y])
end

function conventional_thermal_core_effective_electric_power_expression!(EP::Model, inputs::Dict)
    dfGen = inputs["dfGen"]

    # convert thermal capacities to electrical capacities
    CONV =  get_conventional_thermal_core(inputs)
    @expression(EP, eCElectric[y in CONV], EP[:vCCAP][y] * dfGen[y, :Eff_Down])
end


function conventional_thermal_core_systemwide_max_cap_constraint!(EP::Model, inputs::Dict)
    dfTS = inputs["dfTS"]

    #System-wide installed capacity is less than a specified maximum limit
    FIRST_ROW = 1
    col = :Nonfus_System_Max_Cap_MWe
    if string(col) in names(dfTS)
        max_cap = dfTS[FIRST_ROW, col]
        if max_cap >= 0
            @constraint(EP, cNonfusSystemTot, sum(eCElectric[CONV]) <= max_cap)
        end
    end
end

function fusion_average_net_electric_power_expression!(EP::Model, inputs::Dict)
    dfGen = inputs["dfGen"]

    G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)

    dfTS = inputs["dfTS"]
    by_rid(rid, sym) = by_rid_df(rid, sym, dfTS)

    FUS =  get_fus(inputs)

    #System-wide installed capacity is less than a specified maximum limit
    has_max_up = dfTS[dfTS.Max_Up .>= 0, :R_ID]
    has_max_up = intersect(has_max_up, FUS)

    active_frac = ones(G)
    avg_start_power = zeros(G)
    net_th_frac = ones(G)
    net_el_factor = zeros(G)

    active_frac[has_max_up] .= 1 .- by_rid(has_max_up,:Dwell_Time) ./ by_rid(has_max_up,:Max_Up)
    avg_start_power[has_max_up] .= by_rid(has_max_up,:Start_Energy) ./ by_rid(has_max_up,:Max_Up)
    net_th_frac[FUS] .= active_frac[FUS] .* (1 .- by_rid(FUS,:Recirc_Act)) .- by_rid(FUS,:Recirc_Pass) .- avg_start_power[FUS]
    net_el_factor[FUS] .= dfGen[FUS,:Eff_Down] .* net_th_frac[FUS]

    dfGen.Average_Net_Electric_Factor = net_el_factor

    @expression(EP, eCAvgNetElectric[y in FUS], EP[:vCCAP][y] * net_el_factor[y])
end

function fusion_systemwide_max_cap_constraint!(EP::Model, inputs::Dict)
    dfGen = inputs["dfGen"]
    dfTS = inputs["dfTS"]

    FUS =  get_fus(inputs)

    FIRST_ROW = 1
    col = :System_Max_Cap_MWe_net
    if string(col) in names(dfTS)
        max_cap = dfTS[FIRST_ROW, col]
        if max_cap >= 0
			@constraint(EP, cCSystemTot, sum(EP[:eCAvgNetElectric][FUS]) <= max_cap)
        end
    end
end


# TODO make compatible with reserves
function conventional_thermal_core_constraints!(EP::Model, inputs::Dict, setup::Dict)

    dfTS = inputs["dfTS"]
    by_rid(rid, sym) = by_rid_df(rid, sym, dfTS)

    T = 1:inputs["T"]     # Number of time steps (hours)
    CONV = get_conventional_thermal_core(inputs)
    THERM_COMMIT = inputs["THERM_COMMIT"]

    p = inputs["hours_per_subperiod"] #total number of hours per subperiod

    COMMIT = intersect(THERM_COMMIT, CONV)
    NON_COMMIT = intersect(inputs["THERM_NO_COMMIT"], CONV)

    vCP = EP[:vCP]
    vCCAP = EP[:vCCAP]
    vCSTART = EP[:vCSTART]
    vCCOMMIT = EP[:vCCOMMIT]
    vCSHUT = EP[:vCSHUT]

    cap_size(y) = by_rid(y, :Cap_Size)
    ramp_up_frac(y) = by_rid(y, :Ramp_Up_Frac)
    ramp_dn_frac(y) = by_rid(y, :Ramp_Dn_Frac)
    min_power(y) = by_rid(y, :Min_Power)

    # constraints for generators not subject to UC
    if !isempty(NON_COMMIT)
        # ramp up and ramp down rates
        @constraints(EP, begin
                         [t in T, y in NON_COMMIT], vCP[t, y] - vCP[hoursbefore(p, t, 1), y] <= ramp_up_frac(y) * vCCAP[y]
                         [t in T, y in NON_COMMIT], vCP[hoursbefore(p, t, 1), y] - vCP[t,y] <= ramp_dn_frac(y) * vCCAP[y]
        end)

        # minimum stable power
        @constraint(EP, [t in T, y in NON_COMMIT], vCP[t,y] >= min_power(y) * vCCAP[y])
    end

    # constraints for generatiors subject to UC
    if !isempty(COMMIT)
        up_time(y) = Int(floor(by_rid(y, :Up_Time)))
        down_time(y) = Int(floor(by_rid(y, :Down_Time)))

        ### Add startup costs ###
        @expression(EP, eCStartTS[t in T, y in COMMIT], (inputs["omega"][t] * inputs["TS_C_Start"][y][t] * vCSTART[t, y]))
        @expression(EP, eTotalCStartTST[t in T], sum(eCStartTS[t,y] for y in COMMIT))
        @expression(EP, eTotalCStartTS, sum(eTotalCStartTST[t] for t in T))
        EP[:eObj] += eTotalCStartTS


        #ramp up
        @constraint(EP,[t in T, y in COMMIT],
                    vCP[t,y]-vCP[hoursbefore(p, t, 1), y] <= ramp_up_frac(y)*cap_size(y)*(vCCOMMIT[t,y]-vCSTART[t,y])
                    + min(1, max(min_power(y), ramp_up_frac(y)))*cap_size(y)*vCSTART[t,y]
                    - min_power(y) * cap_size(y) * vCSHUT[t,y])

        #ramp down
        @constraint(EP,[t in T, y in COMMIT],
                    vCP[hoursbefore(p, t, 1), y]-vCP[t,y] <= ramp_dn_frac(y)*cap_size(y)*(vCCOMMIT[t,y]-vCSTART[t,y])
                    - min_power(y)*cap_size(y)*vCSTART[t,y]
                    + min(1,max(min_power(y), ramp_dn_frac(y)))*cap_size(y)*vCSHUT[t,y])

        ### Minimum up and down times (Constraints #9-10)
        @constraint(EP, [t in T, y in COMMIT],
            vCCOMMIT[t,y] >= sum(vCSTART[hoursbefore(p, t, 0:(up_time(y) - 1)), y])
        )

        @constraint(EP, [t in T, y in COMMIT],
            vCCAP[y]/cap_size(y)-vCCOMMIT[t,y] >= sum(vCSHUT[hoursbefore(p, t, 0:(down_time(y) - 1)), y])
        )
    end
end

@doc raw"""
    fusion_constraints!(EP::Model, inputs::Dict)

Apply fusion-core-specific constraints to the model.

"""
function fusion_constraints!(EP::Model, inputs::Dict, setup::Dict)

    T = 1:inputs["T"]     # Number of time steps (hours)

    p = inputs["hours_per_subperiod"]

    dfTS = inputs["dfTS"]
    dfGen = inputs["dfGen"]

    by_rid(rid, sym) = by_rid_df(rid, sym, dfTS)

    FUS = get_fus(inputs)
    vCP = EP[:vCP]
    vCCAP = EP[:vCCAP]
    vCSTART = EP[:vCSTART]
    vCCOMMIT = EP[:vCCOMMIT]

    # Minimum and maximum core power output
    @constraints(EP, begin
        # Maximum thermal power generated by core y at hour y <= Max power of committed
        # core minus power lost from down time at startup
        [t in T, y in FUS], vCP[t,y] <= by_rid(y, :Cap_Size) * (vCCOMMIT[t,y] -
                                       by_rid(y, :Dwell_Time) * vCSTART[t,y])
    end)

    FINITE_STARTS = intersect(FUS, dfTS[dfTS.Max_Starts.>=0, :R_ID])

    #Limit on total core starts per year
    @constraint(EP, [y in FINITE_STARTS],
        sum(vCSTART[t,y]*inputs["omega"][t] for t in T) <=
        by_rid(y, :Max_Starts) * vCCAP[y] / by_rid(y,:Cap_Size)
    )

    MAX_UPTIME = intersect(FUS, dfTS[dfTS.Max_Up.>=0, :R_ID])
    # TODO: throw error if Max_Up == 0 since it's confusing & illdefined

    max_uptime(y) = by_rid(y, :Max_Up)
    eff_down(y) = dfGen[y, :Eff_Down]

    # Core max uptime. If this parameter > 0,
    # the fusion core must be cycled at least every n hours.
    # Looks back over interior timesteps and ensures that a core cannot
    # be committed unless it has been started at some point in
    # the previous n timesteps
    @constraint(EP, [t in T, y in MAX_UPTIME],
            vCCOMMIT[t,y] <= sum(vCSTART[hoursbefore(p, t, 0:(max_uptime(y)-1)), y]))

    # Passive recirculating power, depending on built capacity
    @expression(EP, ePassiveRecircFus[t in T, y in FUS],
                vCCAP[y] * eff_down(y) * by_rid(y,:Recirc_Pass))

    # Active recirculating power, depending on committed capacity
    @expression(EP, eActiveRecircFus[t in T, y in FUS],
                by_rid(y,:Cap_Size) * eff_down(y) * by_rid(y,:Recirc_Act) *
        (vCCOMMIT[t,y] - vCSTART[t,y] * by_rid(y,:Dwell_Time))
    )
    # Startup energy, taken from the grid every time the core starts up
    @expression(EP, eStartEnergyFus[t in T, y in FUS],
                by_rid(y,:Cap_Size) * vCSTART[t,y] * eff_down(y) * by_rid(y,:Start_Energy))

    # Startup power, required margin on the grid when the core starts
    @expression(EP, eStartPowerFus[t in T, y in FUS],
                by_rid(y,:Cap_Size) * vCSTART[t,y] * eff_down(y) * by_rid(y,:Start_Power))

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

function thermal_storage_capacity_reserve_margin!(EP::Model, inputs::Dict)
    dfGen = inputs["dfGen"]
    dfTS = inputs["dfTS"]
    T = 1:inputs["T"]
    reserves = 1:inputs["NCapacityReserveMargin"]
    capresfactor(res, y) = dfGen[y, Symbol("CapRes_$res")]

    TS = inputs["TS"]
    FUS = get_fus(inputs)
    CONV = get_conventional_thermal_core(inputs)
    MAINTENANCE = get_maintenance(inputs)

    by_rid(rid, sym) = by_rid_df(rid, sym, dfTS)

    vP = EP[:vP]

    # @expression(EP, eCapResMarBalanceThermalStorageAdjustment[res in reserves, t in T],
    #             sum(capresfactor(res, y) * (vP[y,t] - EP[:eTotalCap][y]) for y in TS))

    # EP[:eCapResMarBalance] += eCapResMarBalanceThermalStorageAdjustment

    @expression(EP, eCapResMarBalanceFusionAdjustment[res in reserves, t in T],
                sum(capresfactor(res, y) * (- EP[:eStartPowerFus][t,y]
                                            - EP[:ePassiveRecircFus][t,y]
                                            - EP[:eActiveRecircFus][t,y]) for y in FUS))

    EP[:eCapResMarBalance] += eCapResMarBalanceFusionAdjustment

    # remove plants from contributing while they are under maintenance
    FUS_MAINT = intersect(FUS, MAINTENANCE)
    if !isempty(FUS_MAINT)
        avg_net_el_fus(y) = dfGen[y, :Average_Net_Electric_Factor] * by_rid(y, :Cap_Size)
        @expression(EP, eCapResMarBalanceFusionMaintAdj[res in reserves, t in T],
                    -sum(capresfactor(res, y) * EP[:vMDOWN][t, y] * avg_net_el_fus(y) for y in FUS_MAINT))
        EP[:eCapResMarBalance] += eCapResMarBalanceFusionMaintAdj
    end

    CONV_MAINT = intersect(CONV, MAINTENANCE)
    if !isempty(CONV_MAINT)
        net_el_conv(y) = dfGen[y, :Eff_Down] * by_rid(y, :Cap_Size)
        @expression(EP, eCapResMarBalanceTSConvMaintAdj[res in reserves, t in T],
                    -sum(capresfactor(res, y) * EP[:vMDOWN][t, y] * net_el_conv(y) for y in CONV_MAINT))
        EP[:eCapResMarBalance] += eCapResMarBalanceTSConvMaintAdj
    end

end

function thermal_core_emissions!(EP::Model, inputs::Dict)
    dfTS = inputs["dfTS"]
    dfGen = inputs["dfGen"]

    TS = inputs["TS"]   # R_IDs of resources with thermal storage
    G = 1:inputs["G"]
    T = 1:inputs["T"]
    Z = 1:inputs["Z"]

    CONV = get_conventional_thermal_core(inputs)
    THERM_COMMIT = inputs["THERM_COMMIT"]
    by_rid(rid, sym) = by_rid_df(rid, sym, dfTS)

    @expression(EP, eEmissionsByPlantTS[y in G, t in T],
        if y ∉ TS
            0
        elseif y in intersect(THERM_COMMIT, CONV)
            by_rid(y, :CO2_per_MWh) * EP[:vCP][t, y] + by_rid(y, :CO2_per_Start) * EP[:vCSTART][t, y]
        else
            by_rid(y, :CO2_per_MWh) * EP[:vCP][t, y]
        end
    )

    @expression(EP, eEmissionsByZoneTS[z in Z, t in T], sum(eEmissionsByPlantTS[y,t] for y in intersect(TS, dfGen[(dfGen[!,:Zone].==z),:R_ID])))
        EP[:eEmissionsByPlant] += eEmissionsByPlantTS
        EP[:eEmissionsByZone] += eEmissionsByZoneTS
end

function total_fusion_power_balance_expressions!(EP::Model, inputs::Dict)
    T = 1:inputs["T"]     # Time steps
    Z = 1:inputs["Z"]     # Zones
    dfGen = inputs["dfGen"]
    FUS = get_fus(inputs)

    #Total recirculating power at each timestep
    @expression(EP, eTotalRecircFus[t in T, y in FUS],
                EP[:ePassiveRecircFus][t,y] + EP[:eActiveRecircFus][t,y] + EP[:eStartEnergyFus][t,y])

    # Total recirculating power from fusion in each zone
    gen_in_zone(z) = dfGen[dfGen.Zone .== z, :R_ID]

    FUS_IN_ZONE = [intersect(FUS, gen_in_zone(z)) for z in Z]
    @expression(EP, ePowerBalanceRecircFus[t in T, z in Z],
        -sum(eTotalRecircFus[t,y] for y in FUS_IN_ZONE[z]))

    EP[:ePowerBalance] += ePowerBalanceRecircFus
end

