@doc raw"""
	ccs_solvent_storage_commit!(EP::Model, inputs::Dict, setup::Dict)

This function defines the operating constraints for ccs_solvent_storage power plants subject to unit commitment constraints on power plant start-ups and shut-down decision ($y \in UC$).

We model capacity investment decisions and commitment and cycling (start-up, shut-down) of ccs_solvent_storage power plants silimar to all other thermal generators using the integer clustering technique developed in [Palmintier, 2011](https://pennstate.pure.elsevier.com/en/publications/impact-of-unit-commitment-constraints-on-generation-expansion-pla), [Palmintier, 2013](https://dspace.mit.edu/handle/1721.1/79147), and [Palmintier, 2014](https://ieeexplore.ieee.org/document/6684593). In a typical binary unit commitment formulation, each unit is either on or off. With the clustered unit commitment formulation, one or more cluster(s) of similar generators are clustered by type and zone (typically using heat rate and fixed O\&M cost to create clusters), and the integer commitment state variable for each cluster varies from zero to the number of units in the cluster, $\frac{\Delta^{total}_{y,z}}{\Omega^{size}_{y,z}}$. As discussed in \cite{Palmintier2014}, this approach replaces the large set of binary commitment decisions and associated constraints, which scale directly with the number of individual units, with a smaller set of integer commitment states and  constraints, one for each cluster $y$. The dimensionality of the problem thus scales with the number of units of a given type in each zone, rather than by the number of discrete units, significantly improving computational efficiency. However, this method entails the simplifying assumption that all clustered units have identical parameters (e.g., capacity size, ramp rates, heat rate) and that all committed units in a given time step $t$ are operating at the same power output per unit.

Subcomponents that are turned on and off at the same time are aggregated to simplify the model
Out of 7 sub-components in a CCS with solvent storage system, only 3 groups of unit commitment decisions are used:
Group 1: combine cycle turbines +including gas and steam turbines
Group 2: regenerator and compressors
Group 3: abosorber
"""
function ccs_solvent_storage_commit!(EP::Model, inputs::Dict, setup::Dict)
    # Load generators dataframe, sets, and time periods
    gen = inputs["RESOURCES"]
    T = inputs["T"]                                                 # Number of time steps (hours)
    Z = inputs["Z"]                                                 # Number of zones
    MultiStage = setup["MultiStage"]
    omega = inputs["omega"]

    # Load CCS with SOLVENT STORAGE related inputs 
    CCS_SOLVENT_STORAGE = inputs["CCS_SOLVENT_STORAGE"]             # Set of CCS_Solvent_Storage generators (indices)
    NEW_CAP_CCS_SS = intersect(inputs["NEW_CAP"], CCS_SOLVENT_STORAGE)  # SS stands for solvent storage
    RET_CAP_CCS_SS = intersect(inputs["RET_CAP"], CCS_SOLVENT_STORAGE)
    COMMIT_CCS_SS = setup["UCommit"] > 0 ? CCS_SOLVENT_STORAGE : Int[]

    # time related 
    START_SUBPERIODS = inputs["START_SUBPERIODS"]                   # start
    INTERIOR_SUBPERIODS = inputs["INTERIOR_SUBPERIODS"]             # interiors
    p = inputs["hours_per_subperiod"]

    # components of ccs generators with solvent storage
    # by default, i = 1 -> gas turbine; i = 2 -> steam turbine;
    #             i = 3 -> absorber; i = 4 -> compressor; i = 5 -> regenerator;
    #             i = 6 -> rich solvent storage; i = 7 -> lean solvent storage
    gasturbine, steamturbine, absorber, compressor, regenerator, solventstorage_rich, solventstorage_lean = 1, 2, 3, 4, 5, 6, 7
    
    # get component-wise parameter data
    solvent_storage_dict = inputs["solvent_storage_dict"]

    ## Decision variables for unit commitment
    # Subcomponents that are turned on and off at the same time are aggregated to simplify the model
    # i = 1 -> combine cycle turbines, including gas and steam turbines
    # i = 4 -> regenerator and compressors
    # i = 3 -> abosorber

    @variable(EP, vCOMMIT_CCS_SS[y in COMMIT_CCS_SS, i in [1, 3, 4], t = 1:T] >= 0)
    # startup event variable
    @variable(EP, vSTART_CCS_SS[y in COMMIT_CCS_SS, i in [1, 3, 4], t = 1:T] >= 0)
    # shutdown event variable
    @variable(EP, vSHUT_CCS_SS[y in COMMIT_CCS_SS, i in [1, 3, 4], t = 1:T] >= 0)

    ## Declaration of integer/binary variables
    if setup["UCommit"] == 1 # Integer UC constraints
        for y in COMMIT_CCS_SS
            for i in [1, 3, 4]
                set_integer.(vCOMMIT_CCS_SS[y,i,:])
                set_integer.(vSTART_CCS_SS[y,i,:])
                set_integer.(vSHUT_CCS_SS[y,i,:])
            end
        end
    end

    # costs associated with start-ups
    @expression(EP, eCStart_CCS_SS[y in COMMIT_CCS_SS , t=1:T], 
                sum(omega[t] * (solvent_storage_dict[y, "start_cost"][i] * vSTART_CCS_SS[y,i,t]) for i in [1, 3, 4]))
    @expression(EP, eTotalCStart_CCS_SS_T[t = 1:T], sum(EP[:eCStart_CCS_SS][y,t] for y in COMMIT_CCS_SS))
    @expression(EP, eTotalCStart_CCS_SS, sum(eTotalCStart_CCS_SS_T[t] for t in 1:T))
    add_to_expression!(EP[:eTotalCStart], eTotalCStart_CCS_SS)
    # since start up costs only related to COMMIT (Thermal units) so we don't need to connect CStart_CCS_SS to eCStart
    # add start cost to objective function
    add_to_expression!(EP[:eObj], eTotalCStart_CCS_SS)

    # fuel consumption associated with start-ups, only applied to turbines
    @variable(EP, vStartFuel_CCS_SS[y in COMMIT_CCS_SS, t = 1:T] >= 0)
    @constraint(EP, cStartFuel_CCS_SS[y in COMMIT_CCS_SS, t = 1:T],
        EP[:vStartFuel_CCS_SS][y, t] == solvent_storage_dict[y,"cap_size"][gasturbine] * EP[:vSTART_CCS_SS][y, gasturbine, t] * solvent_storage_dict[y, "start_fuel"][gasturbine])
    # Connect start up fuel here to vStartFuel
    @constraint(EP, [y in COMMIT_CCS_SS , t = 1:T], EP[:vStartFuel][y,t] == vStartFuel_CCS_SS[y,t])

    # Unit commitment constraints
    # Capacity limits on unit commitment decision variables (Constraints #1-3)
    @constraints(EP, begin
                [y in COMMIT_CCS_SS, i in [1, 3, 4] , t=1:T], vCOMMIT_CCS_SS[y,i,t] <= EP[:eTotalCap_CCS_SS][y,i]/solvent_storage_dict[y, "cap_size"][i]
                [y in COMMIT_CCS_SS, i in [1, 3, 4] , t=1:T], vSTART_CCS_SS[y,i,t] <= EP[:eTotalCap_CCS_SS][y,i]/solvent_storage_dict[y, "cap_size"][i]
                [y in COMMIT_CCS_SS, i in [1, 3, 4] , t=1:T], vSHUT_CCS_SS[y,i,t] <= EP[:eTotalCap_CCS_SS][y,i]/solvent_storage_dict[y, "cap_size"][i]
    end)

    # Commitment state constraint linking startup and shutdown decisions (Constraint #4)
    @constraint(EP, cCommit_CCS_SS[y in COMMIT_CCS_SS, i in [1, 3, 4], t = 1:T], 
                EP[:vCOMMIT_CCS_SS][y,i,t] == EP[:vCOMMIT_CCS_SS][y,i,hoursbefore(p, t, 1)] + EP[:vSTART_CCS_SS][y,i,t] - EP[:vSHUT_CCS_SS][y,i,t])

    ### Maximum ramp up and down between consecutive hours (Constraints #5-6)
    # rampup constraints
    @constraint(EP,[y in COMMIT_CCS_SS, i in [1, 3, 4], t = 1:T],
        EP[:vOutput_CCS_SS][y,i,t]-EP[:vOutput_CCS_SS][y,i,hoursbefore(p, t, 1)] <= solvent_storage_dict[y, "ramp_up"][i]*solvent_storage_dict[y, "cap_size"][i]*(vCOMMIT_CCS_SS[y,i,t]-vSTART_CCS_SS[y,i,t])
            + min(1,max(solvent_storage_dict[y, "min_power"][i],solvent_storage_dict[y, "ramp_up"][i]))*solvent_storage_dict[y, "cap_size"][i]*vSTART_CCS_SS[y,i,t]
            -solvent_storage_dict[y, "min_power"][i]*solvent_storage_dict[y, "cap_size"][i]*vSHUT_CCS_SS[y,i,t])

    # rampdown constraints
    @constraint(EP,[y in COMMIT_CCS_SS, i in [1, 3, 4], t = 1:T],
        EP[:vOutput_CCS_SS][y,i,hoursbefore(p, t, 1)]-EP[:vOutput_CCS_SS][y,i,t] <=solvent_storage_dict[y, "ramp_dn"][i]*solvent_storage_dict[y, "cap_size"][i]*(vCOMMIT_CCS_SS[y,i,t]-vSTART_CCS_SS[y,i,t])
            -solvent_storage_dict[y, "min_power"][i]*solvent_storage_dict[y, "cap_size"][i]*vSTART_CCS_SS[y,i,t]
            + min(1,max(solvent_storage_dict[y, "min_power"][i],solvent_storage_dict[y, "ramp_dn"][i]))*solvent_storage_dict[y, "cap_size"][i]*vSHUT_CCS_SS[y,i,t])

    ### Minimum and maximum power output constraints (Constraints #7 & 8)
    @constraints(EP, begin
        [y in COMMIT_CCS_SS, i in [1, 3, 4], t=1:T], EP[:vOutput_CCS_SS][y,i,t] >= solvent_storage_dict[y, "min_power"][i]*solvent_storage_dict[y, "cap_size"][i]*vCOMMIT_CCS_SS[y,i,t]
        [y in COMMIT_CCS_SS, i in [1, 3, 4], t=1:T], EP[:vOutput_CCS_SS][y,i,t] <= solvent_storage_dict[y, "cap_size"][i]*vCOMMIT_CCS_SS[y,i,t]
    end)

    ### Minimum up and down times (Constraints #9 & 10)
    for y in COMMIT_CCS_SS
        for i in [1, 3, 4]
            ## up time
            Up_Time = Int(floor(solvent_storage_dict[y, "up_time"][i]))
            Up_Time_HOURS = [] # Set of hours in the summation term of the maximum up time constraint for the first subperiod of each representative period
            for s in START_SUBPERIODS
                Up_Time_HOURS = union(Up_Time_HOURS, (s+1):(s+Up_Time-1))
            end

            @constraints(EP, begin
                # cUpTimeInterior: Constraint looks back over last n hours, where n = solvent_storage_dict[y, "up_time"][i])
                [t in setdiff(INTERIOR_SUBPERIODS,Up_Time_HOURS)], vCOMMIT_CCS_SS[y,i,t] >= sum(vSTART_CCS_SS[y,i,e] for e=(t-solvent_storage_dict[y, "up_time"][i]):t)
                # cUpTimeWrap: If n is greater than the number of subperiods left in the period, constraint wraps around to first hour of time series
                [t in Up_Time_HOURS], vCOMMIT_CCS_SS[y,i,t] >= sum(vSTART_CCS_SS[y,i,e] for e=(t-((t%p)-1):t))+sum(vSTART_CCS_SS[y,i,e] for e=((t+p-(t%p))-(solvent_storage_dict[y, "up_time"][i]-(t%p))):(t+p-(t%p)))
                # cUpTimeStart:
                # NOTE: Expression t+p-(t%p) is equivalant to "p_max"
                [t in START_SUBPERIODS], vCOMMIT_CCS_SS[y,i,t] >= vSTART_CCS_SS[y,i,t]+sum(vSTART_CCS_SS[y,i,e] for e=(hoursbefore(p, t, 1)-(solvent_storage_dict[y, "up_time"][i]-1)):hoursbefore(p, t, 1))
            end)

            ## down time
            Down_Time = Int(floor(solvent_storage_dict[y, "down_time"][i]))
            Down_Time_HOURS = [] # Set of hours in the summation term of the maximum down time constraint for the first subperiod of each representative period
            for s in START_SUBPERIODS
                Down_Time_HOURS = union(Down_Time_HOURS, (s+1):(s+Down_Time-1))
            end

            # Constraint looks back over last n hours, where n = solvent_storage_dict[y, "down_time"][i]
            @constraints(EP, begin
                # cDownTimeInterior: Constraint looks back over last n hours, where n = inputs["pDMS_Time"][y]
                [t in setdiff(INTERIOR_SUBPERIODS,Down_Time_HOURS)], EP[:eTotalCap_CCS_SS][y,i]/solvent_storage_dict[y, "cap_size"][i]-vCOMMIT_CCS_SS[y,i,t] >= sum(vSHUT_CCS_SS[y,i,e] for e=(t-solvent_storage_dict[y, "down_time"][i]):t)
                # cDownTimeWrap: If n is greater than the number of subperiods left in the period, constraint wraps around to first hour of time series
                [t in Down_Time_HOURS], EP[:eTotalCap_CCS_SS][y,i]/solvent_storage_dict[y, "cap_size"][i]-vCOMMIT_CCS_SS[y,i,t] >= sum(vSHUT_CCS_SS[y,i,e] for e=(t-((t%p)-1):t))+sum(vSHUT_CCS_SS[y,i,e] for e=((t+p-(t%p))-(solvent_storage_dict[y, "down_time"][i]-(t%p))):(t+p-(t%p)))
                # cDownTimeStart:
                # NOTE: Expression t+p-(t%p) is equivalant to "p_max"
                [t in START_SUBPERIODS], EP[:eTotalCap_CCS_SS][y,i]/solvent_storage_dict[y, "cap_size"][i]-vCOMMIT_CCS_SS[y,i,t]  >= vSHUT_CCS_SS[y,i,t]+sum(vSHUT_CCS_SS[y,i,e] for e=(hoursbefore(p, t, 1)-(solvent_storage_dict[y, "down_time"][i]-1)):hoursbefore(p, t, 1))
            end)
        end
    end

    # operational reserve  (Constraints #11)
    # operational reserve is based on the combine cycle turbine instead of the whole system
    if setup["OperationalReserves"] > 0
        @variable(EP, vP_CCS_SS[y in COMMIT_CCS_SS, t=1:T])
        @constraint(EP, [y in COMMIT_CCS_SS, t in 1:T], vP_CCS_SS[y,t]==EP[:eP_CCS_SS][y,t])
        CCS_SS_REG = intersect(COMMIT_CCS_SS, inputs["REG"]) # Set of COMMIT_CCS_SS resources with regulation reserves
        CCS_SS_RSV = intersect(COMMIT_CCS_SS, inputs["RSV"]) # Set of COMMIT_CCS_SS resources with spinning reserves

        max_power(y, t) = inputs["pP_Max"][y, t]
        commit(y, t) = (solvent_storage_dict[y,"cap_size"][gasturbine] + solvent_storage_dict[y,"cap_size"][steamturbine]) * EP[:vCOMMIT_CCS_SS][y, gasturbine, t]
        
        # Maximum regulation and reserve contributions
        @constraint(EP, cREG_CCS_SS_Max[y in CCS_SS_REG, t in 1:T],
            EP[:vREG][y, t]<=max_power(y, t) * reg_max(gen[y]) * commit(y, t))
        @constraint(EP, cRSV_CCS_SS_Max[y in CCS_SS_RSV, t in 1:T],
            EP[:vRSV][y, t]<=max_power(y, t) * rsv_max(gen[y]) * commit(y, t))
    
        # Minimum stable power generated per technology "y" at hour "t" and contribution to regulation must be > min power
        expr = extract_time_series_to_expression(EP[:vP_CCS_SS], COMMIT_CCS_SS)
        add_similar_to_expression!(expr[CCS_SS_REG, :], -EP[:vREG][CCS_SS_REG, :])
        @constraint(EP, cREG_CCS_SS_Min[y in COMMIT_CCS_SS, t in 1:T],
            expr[y, t]>=solvent_storage_dict[y, "min_power"][gasturbine] * commit(y, t))
    
        # Maximum power generated per technology "y" at hour "t"  and contribution to regulation and reserves up must be < max power
        expr = extract_time_series_to_expression(EP[:vP_CCS_SS], COMMIT_CCS_SS)
        add_similar_to_expression!(expr[CCS_SS_REG, :], EP[:vREG][CCS_SS_REG, :])
        add_similar_to_expression!(expr[CCS_SS_RSV, :], EP[:vRSV][CCS_SS_RSV, :])
        @constraint(EP, 
            [y in COMMIT_CCS_SS, t in 1:T],
            expr[y, t]<=max_power(y, t) * commit(y, t))
    end
end