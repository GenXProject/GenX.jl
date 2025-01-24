@doc raw"""
    allamcycle_commit!(EP::Model, inputs::Dict, setup::Dict)

This function defines the operating constraints for allam cycle power plants subject to unit commitment constraints on power plant start-ups and shut-down decision ($y \in UC$).
The capacity investment decisions and commitment and cycling (start-up, shut-down) of ASU and sCO2 turbine in allam cycle power systems are similar to constraints defined in thermal_commit.jl
Operaional constraints include start-up, max ramping up/donw, max up/down time, min power level, and operational reserves.
"""
function allamcycle_commit!(EP::Model, inputs::Dict, setup::Dict)
    # Load generators dataframe, sets, and time periods
    gen = inputs["RESOURCES"]
    T = inputs["T"]                                                 # Number of time steps (hours)
    Z = inputs["Z"]                                                 # Number of zones
    MultiStage = setup["MultiStage"]
    omega = inputs["omega"]

    # Load Allam Cycle related inputs 
    ALLAM_CYCLE_LOX = inputs["ALLAM_CYCLE_LOX"]                     # Set of Allam Cycle generators (indices)
    NEW_CAP_Allam = intersect(inputs["NEW_CAP"], ALLAM_CYCLE_LOX)
    RET_CAP_Allam = intersect(inputs["RET_CAP"], ALLAM_CYCLE_LOX)
    COMMIT_Allam = setup["UCommit"] > 0 ? ALLAM_CYCLE_LOX : Int[]
    WITH_LOX = inputs["WITH_LOX"]

    # time related
    START_SUBPERIODS = inputs["START_SUBPERIODS"]
    INTERIOR_SUBPERIODS = inputs["INTERIOR_SUBPERIODS"]
    p = inputs["hours_per_subperiod"]

    # Allam cycle components
    # by default, i = 1 -> sCO2Turbine; i = 2 -> ASU; i = 3 -> LOX
    sco2turbine, asu, lox = 1, 2, 3
    
    # get component-wise data
    allam_dict = inputs["allam_dict"]


    ## Decision variables for unit commitment
    @variable(EP, vCOMMIT_Allam[y in ALLAM_CYCLE_LOX, i in 1:2, t=1:T] >= 0)
    # startup event variable
    @variable(EP, vSTART_Allam[y in ALLAM_CYCLE_LOX, i in 1:2, t=1:T] >= 0)
    # shutdown event variable
    @variable(EP, vSHUT_Allam[y in ALLAM_CYCLE_LOX, i in 1:2, t=1:T] >= 0)
    ### Expressions ###
    ## Objective Function Expressions ##
    # start up costs associated with sCO2 turbine and ASU
    # Startup costs for resource "y" during hour "t"   
    @expression(EP, eCStart_Allam[y in COMMIT_Allam , t=1:T], sum(omega[t]*(allam_dict[y,"start_cost"][i]*vSTART_Allam[y,i,t]) for i in 1:2))
    @expression(EP, eTotalCStart_Allam_T[t = 1:T], sum(eCStart_Allam[y,t] for y in COMMIT_Allam))
    @expression(EP, eTotalCStart_Allam, sum(eTotalCStart_Allam_T[t] for t in 1:T))
    add_to_expression!(EP[:eTotalCStart], eTotalCStart_Allam)
    # since start up costs only related to COMMIT (Thermal units) so we don't need to connect CStart_Allam to eCStart
    # add start cost to objective function
    add_to_expression!(EP[:eObj], eTotalCStart_Allam)

    # Start up fuel for each component
    @variable(EP, vStartFuel_Allam[y in COMMIT_Allam , i in 1:2, t = 1:T]>=0)
    @constraint(EP, cStartFuel_Allam[y in COMMIT_Allam, i in 1:2, t = 1:T],
        EP[:vStartFuel_Allam][y, i, t] - allam_dict[y,"cap_size"][i] * EP[:vSTART_Allam][y,i, t] * allam_dict[y, "start_fuel"][i] .==0)
    # Start up fuel for each plant
    @expression(EP, eStartFuel_Allam[y in COMMIT_Allam , t = 1:T], sum(vStartFuel_Allam[y,i, t] for i in 1:2) )
    # Connect start up fuel here to vStartFuel
    @constraint(EP, [y in COMMIT_Allam , t = 1:T], EP[:vStartFuel][y,t] == eStartFuel_Allam[y,t])

    ## Declaration of integer/binary variables
    if setup["UCommit"] == 1 # Integer UC constraints
        for y in ALLAM_CYCLE_LOX
            for i in 1:2
                set_integer.(vCOMMIT_Allam[y,i,:])
                set_integer.(vSTART_Allam[y,i,:])
                set_integer.(vSHUT_Allam[y,i,:])
                if y in RET_CAP_Allam 
                    set_integer(EP[:vRETCAP_AllamCycleLOX][y,i])
                end
                if y in NEW_CAP_Allam
                    set_integer(EP[:vCAP_AllamCycleLOX][y,i])
                end
            end
        end
    end #END unit commitment configuration

    ### Constraints ###
    ### Capacitated limits on unit commitment decision variables (Constraints #1-3)
    @constraints(EP, begin
        [y in ALLAM_CYCLE_LOX, i in 1:2 , t=1:T], vCOMMIT_Allam[y,i,t] <= EP[:eTotalCap_AllamcycleLOX][y,i]/allam_dict[y, "cap_size"][i]
        [y in ALLAM_CYCLE_LOX, i in 1:2 , t=1:T], vSTART_Allam[y,i,t] <= EP[:eTotalCap_AllamcycleLOX][y,i]/allam_dict[y, "cap_size"][i]
        [y in ALLAM_CYCLE_LOX, i in 1:2 , t=1:T], vSHUT_Allam[y,i,t] <= EP[:eTotalCap_AllamcycleLOX][y,i]/allam_dict[y, "cap_size"][i]
    end)


    # Commitment state constraint linking startup and shutdown decisions (Constraint #4)
    @constraints(EP, begin
        [y in ALLAM_CYCLE_LOX, i in 1:2, t = 1:T], vCOMMIT_Allam[y,i,t] == vCOMMIT_Allam[y,i,hoursbefore(p, t, 1)] + vSTART_Allam[y,i,t] - vSHUT_Allam[y,i,t]
    end)

    ### Maximum ramp up and down between consecutive hours (Constraints #5-6
    # Links last time step with first time step, ensuring position in hour 1 is within eligible ramp of final hour position
    # rampup constraints
    @constraint(EP,[y in ALLAM_CYCLE_LOX, i in 1:2, t = 1:T],
        EP[:vOutput_AllamcycleLOX][y,i,t]-EP[:vOutput_AllamcycleLOX][y,i,hoursbefore(p, t, 1)] <= allam_dict[y, "ramp_up"][i]*allam_dict[y, "cap_size"][i]*(vCOMMIT_Allam[y,i,t]-vSTART_Allam[y,i,t])
            + min(1,max(allam_dict[y, "min_power"][i],allam_dict[y, "ramp_up"][i]))*allam_dict[y, "cap_size"][i]*vSTART_Allam[y,i,t]
            -allam_dict[y, "min_power"][i]*allam_dict[y, "cap_size"][i]*vSHUT_Allam[y,i,t])

    # rampdown constraints
    @constraint(EP,[y in ALLAM_CYCLE_LOX, i in 1:2, t = 1:T],
        EP[:vOutput_AllamcycleLOX][y,i,hoursbefore(p, t, 1)]-EP[:vOutput_AllamcycleLOX][y,i,t] <=allam_dict[y, "ramp_dn"][i]*allam_dict[y, "cap_size"][i]*(vCOMMIT_Allam[y,i,t]-vSTART_Allam[y,i,t])
            -allam_dict[y, "min_power"][i]*allam_dict[y, "cap_size"][i]*vSTART_Allam[y,i,t]
            + min(1,max(allam_dict[y, "min_power"][i],allam_dict[y, "ramp_dn"][i]))*allam_dict[y, "cap_size"][i]*vSHUT_Allam[y,i,t])

    ### Minimum and maximum power output constraints 
    @constraints(EP, begin
        # Minimum stable power generated per technology "y" at hour "t" > Min power
        [y in ALLAM_CYCLE_LOX, i in 1:2, t=1:T], EP[:vOutput_AllamcycleLOX][y,i,t] >= allam_dict[y, "min_power"][i]*allam_dict[y, "cap_size"][i]*vCOMMIT_Allam[y,i,t]
    # Maximum power generated per technology "y" at hour "t" < Max power
        [y in ALLAM_CYCLE_LOX, i in 1:2, t=1:T], EP[:vOutput_AllamcycleLOX][y,i,t] <= allam_dict[y, "cap_size"][i]*vCOMMIT_Allam[y,i,t]
    end)

    ### Minimum up and down times 
    for y in ALLAM_CYCLE_LOX
        for i in 1:2
            ## up time
            Up_Time = Int(floor(allam_dict[y, "up_time"][i]))
            Up_Time_HOURS = [] # Set of hours in the summation term of the maximum up time constraint for the first subperiod of each representative period
            for s in START_SUBPERIODS
                Up_Time_HOURS = union(Up_Time_HOURS, (s+1):(s+Up_Time-1))
            end

            @constraints(EP, begin
                # cUpTimeInterior: Constraint looks back over last n hours, where n = allam_dict[y, "up_time"][i])
                [t in setdiff(INTERIOR_SUBPERIODS,Up_Time_HOURS)], vCOMMIT_Allam[y,i,t] >= sum(vSTART_Allam[y,i,e] for e=(t-allam_dict[y, "up_time"][i]):t)

                # cUpTimeWrap: If n is greater than the number of subperiods left in the period, constraint wraps around to first hour of time series
                # cUpTimeWrap constraint equivalant to: sum(vSTART_Allam[y,e] for e=(t-((t%p)-1):t))+sum(vSTART_Allam[y,e] for e=(p_max-(allam_dict[y, "up_time"][i])-(t%p))):p_max)
                [t in Up_Time_HOURS], vCOMMIT_Allam[y,i,t] >= sum(vSTART_Allam[y,i,e] for e=(t-((t%p)-1):t))+sum(vSTART_Allam[y,i,e] for e=((t+p-(t%p))-(allam_dict[y, "up_time"][i]-(t%p))):(t+p-(t%p)))

                # cUpTimeStart:
                # NOTE: Expression t+p-(t%p) is equivalant to "p_max"
                [t in START_SUBPERIODS], vCOMMIT_Allam[y,i,t] >= vSTART_Allam[y,i,t]+sum(vSTART_Allam[y,i,e] for e=(hoursbefore(p, t, 1)-(allam_dict[y, "up_time"][i]-1)):hoursbefore(p, t, 1))
            end)

            ## down time
            Down_Time = Int(floor(allam_dict[y, "down_time"][i]))
            Down_Time_HOURS = [] # Set of hours in the summation term of the maximum down time constraint for the first subperiod of each representative period
            for s in START_SUBPERIODS
                Down_Time_HOURS = union(Down_Time_HOURS, (s+1):(s+Down_Time-1))
            end

            # Constraint looks back over last n hours, where n = allam_dict[y, "down_time"][i]
            # TODO: Replace LHS of constraints in this block with eNumPlantsOffline[y,t]
            @constraints(EP, begin
                # cDownTimeInterior: Constraint looks back over last n hours, where n = inputs["pDMS_Time"][y]
                [t in setdiff(INTERIOR_SUBPERIODS,Down_Time_HOURS)], EP[:eTotalCap_AllamcycleLOX][y,i]/allam_dict[y, "cap_size"][i]-vCOMMIT_Allam[y,i,t] >= sum(vSHUT_Allam[y,i,e] for e=(t-allam_dict[y, "down_time"][i]):t)

                # cDownTimeWrap: If n is greater than the number of subperiods left in the period, constraint wraps around to first hour of time series
                # cDownTimeWrap constraint equivalant to: eTotalCap_AllamcycleLOX[y,i]/allam_dict[y, "cap_size"][i]-vCOMMIT_Allam[y,t] >= sum(vSHUT_Allam[y,e] for e=(t-((t%p)-1):t))+sum(vSHUT_Allam[y,e] for e=(p_max-(allam_dict[y, "down_time"][i]-(t%p))):p_max)
                [t in Down_Time_HOURS], EP[:eTotalCap_AllamcycleLOX][y,i]/allam_dict[y, "cap_size"][i]-vCOMMIT_Allam[y,i,t] >= sum(vSHUT_Allam[y,i,e] for e=(t-((t%p)-1):t))+sum(vSHUT_Allam[y,i,e] for e=((t+p-(t%p))-(allam_dict[y, "down_time"][i]-(t%p))):(t+p-(t%p)))

                # cDownTimeStart:
                # NOTE: Expression t+p-(t%p) is equivalant to "p_max"
                [t in START_SUBPERIODS], EP[:eTotalCap_AllamcycleLOX][y,i]/allam_dict[y, "cap_size"][i]-vCOMMIT_Allam[y,i,t]  >= vSHUT_Allam[y,i,t]+sum(vSHUT_Allam[y,i,e] for e=(hoursbefore(p, t, 1)-(allam_dict[y, "down_time"][i]-1)):hoursbefore(p, t, 1))
            end)
        end
    end
    # operational reserve
    # operational reserve is based on the sCO2 turbines instead of the whole system
    if setup["OperationalReserves"] > 0
        # 
        @variable(EP, vP_Allam[y in ALLAM_CYCLE_LOX, t=1:T])
        @constraint(EP, [y in ALLAM_CYCLE_LOX, t in 1:T], vP_Allam[y,t]==EP[:eP_Allam][y,t])
        ALLAM_REG = intersect(ALLAM_CYCLE_LOX, inputs["REG"]) # Set of allam cycle resources with regulation reserves
        ALLAM_RSV = intersect(ALLAM_CYCLE_LOX, inputs["RSV"]) # Set of allam cycle resources with spinning reserves

        vREG = EP[:vREG]
        vRSV = EP[:vRSV]

        max_power(y, t) = inputs["pP_Max"][y, t]
        commit(y, t) = allam_dict[y,"cap_size"][sco2turbine] * EP[:vCOMMIT_Allam][y, sco2turbine, t]
        
        # Maximum regulation and reserve contributions
        @constraint(EP, cREG_AllamCycle_Max[y in ALLAM_REG, t in 1:T],
            vREG[y, t]<=max_power(y, t) * reg_max(gen[y]) * commit(y, t))
        @constraint(EP, cRSV_AllamCycle_Max[y in ALLAM_RSV, t in 1:T],
            vRSV[y, t]<=max_power(y, t) * rsv_max(gen[y]) * commit(y, t))
    
        # Minimum stable power generated per technology "y" at hour "t" and contribution to regulation must be > min power
        expr = extract_time_series_to_expression(EP[:vP_Allam], ALLAM_CYCLE_LOX)
        add_similar_to_expression!(expr[ALLAM_REG, :], -vREG[ALLAM_REG, :])
        @constraint(EP, cREG_AllamCycle_Min[y in ALLAM_CYCLE_LOX, t in 1:T],
            expr[y, t]>=allam_dict[y, "min_power"][sco2turbine] * commit(y, t))
    
        # Maximum power generated per technology "y" at hour "t"  and contribution to regulation and reserves up must be < max power
        expr = extract_time_series_to_expression(EP[:vP_Allam], ALLAM_CYCLE_LOX)
        add_similar_to_expression!(expr[ALLAM_REG, :], vREG[ALLAM_REG, :])
        add_similar_to_expression!(expr[ALLAM_RSV, :], vRSV[ALLAM_RSV, :])
        @constraint(EP, 
            [y in ALLAM_CYCLE_LOX, t in 1:T],
            expr[y, t]<=max_power(y, t) * commit(y, t))
    end
end