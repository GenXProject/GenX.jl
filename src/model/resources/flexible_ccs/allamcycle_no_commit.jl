@doc raw"""
allamcycle_no_commit!(EP::Model, inputs::Dict, setup::Dict)
This function defines the operating constraints for allam cycle power plants subject to unit commitment constraints on power plant start-ups and shut-down decision ($y \in UC$).
The capacity investment decisions and commitment and cycling (start-up, shut-down) of ASU and sCO2 turbine in allam cycle power systems are similar to constraints defined in thermal_no_commit.jl
Operaional constraints include max ramping up/donw, min power level, and operational reserves.
"""
function allamcycle_no_commit!(EP::Model, inputs::Dict, setup::Dict)
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
    NO_COMMIT_Allam = setup["UCommit"] == 0 ? ALLAM_CYCLE_LOX : Int[]
    WITH_LOX = inputs["WITH_LOX"]

    # time related 
    p = inputs["hours_per_subperiod"]

    # Allam cycle components
    # by default, i = 1 -> sCO2Turbine; i = 2 -> ASU; i = 3 -> LOX
    sco2turbine, asu, lox = 1, 2, 3
    
    # get component-wise data
    allam_dict = inputs["allam_dict"]

    ### Maximum ramp up and down between consecutive hours 
    # rampup constraints
    @constraint(EP,[y in ALLAM_CYCLE_LOX, i in 1:2, t in 1:T],
        EP[:vOutput_AllamcycleLOX][y,i,t] - EP[:vOutput_AllamcycleLOX][y,i,hoursbefore(p, t,1)] <=
        allam_dict[y, "ramp_up"][i] * EP[:eTotalCap_AllamcycleLOX][y,i])

    # rampdown constraints
    @constraint(EP,[y in ALLAM_CYCLE_LOX, i in 1:2, t in 1:T],
        EP[:vOutput_AllamcycleLOX][y,i,hoursbefore(p, t,1)] - EP[:vOutput_AllamcycleLOX][y,i,t] <=
        allam_dict[y, "ramp_dn"][i] * EP[:eTotalCap_AllamcycleLOX][y,i])

    ### Minimum and maximum power output constraints
    @constraints(EP, begin
        # Minimum stable power generated per technology "y" at hour "t" > Min power
        [y in ALLAM_CYCLE_LOX, i in 1:2, t=1:T], EP[:vOutput_AllamcycleLOX][y,i,t] >= allam_dict[y, "min_power"][i]*EP[:eTotalCap_AllamcycleLOX][y,i]
    # Maximum power generated per technology "y" at hour "t" < Max power
        [y in ALLAM_CYCLE_LOX, i in 1:2, t=1:T], EP[:vOutput_AllamcycleLOX][y,i,t] <= EP[:eTotalCap_AllamcycleLOX][y,i]
    end)

    # operational reserve
    # operational reserve is based on the sCO2 turbines instead of the whole system
    if setup["OperationalReserves"] > 0
        @variable(EP, vP_Allam[y in ALLAM_CYCLE_LOX, t=1:T])
        @constraint(EP, [y in ALLAM_CYCLE_LOX, t in 1:T], vP_Allam[y,t]==EP[:eP_Allam][y,t])
        
        ALLAM_REG = intersect(ALLAM_CYCLE_LOX, inputs["REG"]) # Set of allam cycle resources with regulation reserves
        ALLAM_RSV = intersect(ALLAM_CYCLE_LOX, inputs["RSV"]) # Set of allam cycle resources with spinning reserves

        vREG = EP[:vREG]
        vRSV = EP[:vRSV]
        eTotalCap = EP[:eTotalCap_AllamcycleLOX]
    
        max_power(y, t) = inputs["pP_Max"][y, t]
    
        # Maximum regulation and reserve contributions
        @constraint(EP,
            [y in ALLAM_REG, t in 1:T],
            vREG[y, t]<=max_power(y, t) * reg_max(gen[y]) * eTotalCap[y,sco2turbine])
        @constraint(EP,
            [y in ALLAM_RSV, t in 1:T],
            vRSV[y, t]<=max_power(y, t) * rsv_max(gen[y]) * eTotalCap[y,sco2turbine])
    
        # Minimum stable power generated per technology "y" at hour "t" and contribution to regulation must be > min power
        expr = extract_time_series_to_expression(EP[:vP_Allam], ALLAM_CYCLE_LOX)
        add_similar_to_expression!(expr[ALLAM_REG, :], -vRSV[ALLAM_REG, :])
        @constraint(EP,
            [y in ALLAM_CYCLE_LOX, t in 1:T],
            expr[y, t]>=allam_dict[y, "min_power"][sco2turbine] * eTotalCap[y,sco2turbine])
    
        # Maximum power generated per technology "y" at hour "t"  and contribution to regulation and reserves up must be < max power
        expr = extract_time_series_to_expression(EP[:vP_Allam], ALLAM_CYCLE_LOX)
        add_similar_to_expression!(expr[ALLAM_REG, :], vREG[ALLAM_REG, :])
        add_similar_to_expression!(expr[ALLAM_RSV, :], vRSV[ALLAM_RSV, :])
        @constraint(EP,
            [y in ALLAM_CYCLE_LOX, t in 1:T],
            expr[y, t]<=max_power(y, t) * eTotalCap[y,sco2turbine])
    end
end