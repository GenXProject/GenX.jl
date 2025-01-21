@doc raw"""
allamcyclelox!(EP::Model, inputs::Dict, setup::Dict)
This module models the Allam cycle with or without liquid oxygen storage (LOX) tank. 
In this module, the key components of Allam cycle w/ LOX are break down into mutiple components with independent capacity decisions. 

**Important expressions**
1. power balance within an Allam Cycle resource
Consumption of electricity by Air Seperation Unit (ASU) $y, asu$ in time $t$, denoted by $\Pi_{y,asu,t}$, and auxiliary load, denoted by $\Pi_{y,aux,t}$, is subtracted from power generation from the sCO2 turbines, denoted by $\Pi_{y,sco2turbine,t}$

2. power balance between an Allam Cycle resource and the grid
Net power output from Allam Cycle $y$ in time $t$ (net generation - electricity charged from the grid, denoted by $\Theta_{y,z}$), denoted by $\Pi_{y,z}^{net}$, is added to power balance expression `ePowerBalance`

```math
\begin{aligned}
    \Pi_{y,z}^{net} = \Pi_{y,sco2turbine,t} - \Pi_{y,asu,t} - \Pi_{y,aux,t} - \Theta_{y,t}
\end{aligned}
```

**Important constraints**
1. liquid oxygen storage mass balance: the state of the liquid oxygen storage at hour $h$ is determined by the state of the liquid oxygen storage at hour $h-1$, and of the production and consumption of liquid oxygen at hour $h$.
```math
\begin{aligned}
    \Gamma_{y,t} =\Gamma_{y,t-1} + \Pi_{y,asu,t}\$O2_production_rate$ - \frac{\Pi_{y,sco2turbine,t}}{$O2_consumption_rate$_{y}}
\end{aligned}
```

2. power consumption by ASU: when the electricity prices are low, ASU can also use electricity from the grid (\Theta_{y,z}) to produce oxygen and the energy consumption ($\Pi_{y,aux,z}$) by ASU has to be equal or greater than $\Theta_{y,z}$.
```math
\begin{aligned}
    \Pi_{y,aux,t} >= \Theta_{y,t}
\end{aligned}
```

3. all the allam cycle output should be less than the capacity 
```math
\begin{aligned}
    \Pi_{y,sco2turbine,t} <= \Omega_{y,sco2turbine}
    \Pi_{y,aux,t} <= \Omega_{y,aux}
    \Theta_{y,lox,t}^{in} <= \Omega_{y,lox}
    \Theta_{y,lox,t}^{out} <= \Omega_{y,lox}
\end{aligned}
```

4: charging and discharging rate of LOX is determined by the capacity ($\omega_{y,lox}$) and duration ($Duration_{y}$) of LOX
```math
\begin{aligned}
    \frac{\Omega_{y,lox}{/$Duration$_{y}} >= \Theta_{y,lox,t}^{in}
    \frac{\Omega_{y,lox}{/$Duration$_{y}} >= \Theta_{y,lox,t}^{out}
\end{aligned}
```
# 5: call allamcycle_commit!(EP, inputs, setup) and allamcycle_commit!(EP, inputs, setup) for specific investment and operational constraints related to unit commitment
"""
function allamcyclelox!(EP::Model, inputs::Dict, setup::Dict)
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
    WITH_LOX = inputs["WITH_LOX"]                                   # Set of Allam Cycel generators that can use liquid oxygen storage

    # time related 

    p = inputs["hours_per_subperiod"]

    # Allam cycle components
    # by default, i = 1 -> sCO2Turbine; i = 2 -> ASU; i = 3 -> LOX
    sco2turbine, asu, lox = 1, 2, 3
    
    # get component-wise parameter data
    allam_dict = inputs["allam_dict"]

    # Variables
    # retired capacity of Allam cycle 
    @variable(EP, vRET_AllamCycleLOX[y in ALLAM_CYCLE_LOX, i = 1:3]  >= 0)
    # new capacity of Allam cycle
    @variable(EP, vCAP_AllamCycleLOX[y in ALLAM_CYCLE_LOX, i = 1:3]  >= 0)

    # construct a matrix represent the main output of each component (e.g., sCO2 Turbine, air separation unit (ASU), and liquid oxygen storage tank (LOX))
    # y represents the plant, i represents the specfic subcomponents, and t represents the time
    # The main output from sCO2Turbine/ASU/LOX is the gross power output from sCO2 cycle (MWh), power consumption associated with ASU (MWh), and the amout of LOX (tonne) stored in the LOX tank
    @variable(EP, vOutput_AllamcycleLOX[y in ALLAM_CYCLE_LOX, i = 1:3, t = 1:T]  >= 0)

    # Grid export to the system to support ASU
    @variable(EP, vCHARGE_ALLAM[y in ALLAM_CYCLE_LOX, t=1:T] >= 0)

    # Mass and energy balance of Allam Cycle resources
    @variables(EP, begin
        vLOX_in[y in ALLAM_CYCLE_LOX, t=1:T] >= 0 # lox generated by ASU, stored in the storage
        vGOX[y in ALLAM_CYCLE_LOX, t=1:T] >= 0 # gox generated by ASU, used by sCO2 turbines directly
    end)

    # Expressions and constraints of Allam Cycle operations
    # Thermal Energy input of sCO2 turbine at hour t [MMBTU] is determined by the gross power output of sCO2 turbine and the corresponding heat rate
    @expression(EP, eFuel_Allam[y in ALLAM_CYCLE_LOX ,t=1:T],
        gen[y].heatrate_sco2* vOutput_AllamcycleLOX[y, sco2turbine, t])

    # Power consumption assumed by ASU is a function of gnerated LOX
    # Note: it should be noticed that the poweruserate to generate GOX and LOX are differernt.
    @constraint(EP, [y in ALLAM_CYCLE_LOX, t = 1:T], vOutput_AllamcycleLOX[y, asu, t] ==  gen[y].lox_poweruserate_o2 * vLOX_in[y,t] + gen[y].gox_poweruserate_o2 * vGOX[y,t])
    
    # Auxiliary load
    @expression(EP, ePower_other[y in ALLAM_CYCLE_LOX,t=1:T],  gen[y].poweruserate_other * vOutput_AllamcycleLOX[y, sco2turbine, t])
    
    # The amount of LOX feed into oxyfuel cycle should be propotional to the power generated by oxyfuel cycle
    @expression(EP, eLOX_out[y in ALLAM_CYCLE_LOX,t=1:T], gen[y].o2userate * vOutput_AllamcycleLOX[y, sco2turbine, t] - vGOX[y,t])
    @constraint(EP, cLOX_out[y in ALLAM_CYCLE_LOX,t=1:T], eLOX_out[y ,t]>=0)
    
    # Constraint 1: liquid oxygen storage mass balance
    # dynamic of lox storage system
    @constraint(EP, cStore_lox[y in ALLAM_CYCLE_LOX,t=1:T], vOutput_AllamcycleLOX[y, lox, t] == vOutput_AllamcycleLOX[y, lox, hoursbefore(p, t, 1)] + vLOX_in[y, t] - eLOX_out[y, t])

    # Constraint 2: power balance
    # net power output = gross power output from sCO2 - power consumption associated with ASU - auxiliary power
    @expression(EP, eP_Allam[y in ALLAM_CYCLE_LOX, t=1:T], (vOutput_AllamcycleLOX[y, sco2turbine, t] - vOutput_AllamcycleLOX[y, asu, t] - ePower_other[y, t] + vCHARGE_ALLAM[y,t]))
    # link vP, vCHARGE_ALLAM, and eP_Allam
    @constraint(EP, cCharge[y in ALLAM_CYCLE_LOX, t = 1:T], vOutput_AllamcycleLOX[y, asu, t] >= vCHARGE_ALLAM[y,t])
    @constraint(EP, cP_net[y in ALLAM_CYCLE_LOX, t = 1:T], eP_Allam[y, t] == EP[:vP][y,t])
    @expression(EP, ePowerBalanceAllam[t = 1:T, z = 1:Z],
        sum((eP_Allam[y,t] - vCHARGE_ALLAM[y,t])
        for y in intersect(ALLAM_CYCLE_LOX, resources_in_zone_by_rid(gen, z))))
    add_similar_to_expression!(EP[:ePowerBalance], ePowerBalanceAllam)

    # Expressions and constraints related to Allam Cycle costs

    if MultiStage ==1
        @variable(EP, vEXISTINGCAP_AllamCycleLOX[y in ALLAM_CYCLE_LOX, i = 1:3]>=0)
    end

    if MultiStage == 1
        @expression(EP, eExistingCap_AllamCycleLOX[y in ALLAM_CYCLE_LOX, i = 1:3], vEXISTINGCAP_AllamCycleLOX[y,i])
    else
        @expression(EP, eExistingCap_AllamCycleLOX[y in ALLAM_CYCLE_LOX, i = 1:3], allam_dict[y, "existing_cap"][i])
    end

    # Note: Allam Cycle is not compatiable with RETRO for now.
    @expression(EP, eTotalCap_AllamcycleLOX[y in ALLAM_CYCLE_LOX, i in 1:3],
    if y in intersect(NEW_CAP_Allam, RET_CAP_Allam) # Resources eligible for new capacity and retirements 
        if y in COMMIT_Allam
            eExistingCap_AllamcycleLOX[y,i] +
                allam_dict[y,"cap_size"][i] * (EP[:vCAP_AllamCycleLOX][y,i] - EP[:vRETCAP_AllamCycleLOX][y,i])
        else
            eExistingCap_AllamCycleLOX[y, i] + EP[:vCAP_AllamCycleLOX][y, i] - EP[:vRETCAP_AllamCycleLOX][y,i]
        end
    elseif y in setdiff(RET_CAP_Allam, NEW_CAP_Allam) # Resources eligible for only capacity retirements
        if y in COMMIT_Allam
            eExistingCap_AllamCycleLOX[y,i] - allam_dict[y,"cap_size"][i] * EP[:vRETCAP_AllamCycleLOX][y,i]
        else
            eExistingCap_AllamCycleLOX[y,i] - EP[:vRETCAP_AllamCycleLOX][y,i]
        end
    elseif y in setdiff(NEW_CAP_Allam, RET_CAP_Allam) # Resources eligible for new capacity
        if y in COMMIT_Allam
            eExistingCap_AllamCycleLOX[y,i] + allam_dict[y,"cap_size"][i] * (EP[:vCAP_AllamCycleLOX][y,i] )
        else
            eExistingCap_AllamCycleLOX[y,i] + EP[:vCAP_AllamCycleLOX][y,i] 
        end
    else # Resources not eligible for new capacity or retirement
        eExistingCap_AllamCycleLOX[y,i]
    end)

    # LOX storage tank capacity -> if they are not in WITH_LOX
    @constraint(EP, [y in setdiff(ALLAM_CYCLE_LOX, WITH_LOX)], eTotalCap_AllamcycleLOX[y,lox] == 0 )
    # Fixed cost of each component in Allam Cycle w/ LOX
    # Set of generator eligible for new sCO2 turbine
    # Allam Cycle is eligible for unit commitment  
    @expression(EP, eCFix_Allam[y in ALLAM_CYCLE_LOX, i in 1:3],
        if y in NEW_CAP_Allam # Resources eligible for new capacity
            if y in COMMIT_Allam  # Resource eligible for Unit commitment
                allam_dict[y,"inv_cost"][i] * allam_dict[y,"cap_size"][i] * EP[:vCAP_AllamCycleLOX][y, i]+
                allam_dict[y,"fom_cost"][i]  * eTotalCap_AllamcycleLOX[y,i]
            else
                allam_dict[y,"inv_cost"][i] * EP[:vCAP_AllamCycleLOX][y, i]+
                allam_dict[y,"fom_cost"][i] * eTotalCap_AllamcycleLOX[y,i]
            end
        else
            allam_dict[y,"fom_cost"][i]  * eTotalCap_AllamcycleLOX[y,i]
        end)

    # connect eCFix_Allam_Plant to eCFix
    @expression(EP, eCFix_Allam_Plant[y in ALLAM_CYCLE_LOX], sum(EP[:eCFix_Allam][y,i] for i in 1:3))
    @expression(EP, eTotalCFix_Allam, sum(EP[:eCFix_Allam_Plant][y] for y in  ALLAM_CYCLE_LOX ))
    # add this to eTotalCFix
    add_to_expression!(EP[:eTotalCFix], eTotalCFix_Allam)

    # add to Obj
    if MultiStage == 1
        # OPEX multiplier scales fixed costs to account for multiple years between two model stages
        # We divide by OPEXMULT since we are going to multiply the entire objective function by this term later,
        # and we have already accounted for multiple years between stages for fixed costs.
        add_to_expression!(EP[:eObj], 1 / inputs["OPEXMULT"], eTotalCFix_Allam)
    else
        add_to_expression!(EP[:eObj], eTotalCFix_Allam)
    end

    if MultiStage == 1
        # Existing capacity variable is equal to existing capacity specified in the input file
        @constraint(EP, cExistingCap_AllamCycleLOX[y in ALLAM_CYCLE_LOX, i in 1:3], EP[:vEXISTINGCAP_AllamCycleLOX][y,i]== allam_dict[y, "existing_cap"][i])
    end

    # Constraint 3: all the allam cycle output should be less than the capacity
    @constraint(EP, [y in ALLAM_CYCLE_LOX, i in 1:3, t in 1:T], vOutput_AllamcycleLOX[y, i, t] <= eTotalCap_AllamcycleLOX[y,i])
    
    # Constraint 4: the duration of lox
    @constraint(EP, cMaxLoxDuration_out[y in intersect(ids_with_positive(gen, lox_duration), WITH_LOX), t in 1:T], eTotalCap_AllamcycleLOX[y,lox]/lox_duration(gen[y]) >= eLOX_out[y,t])
    @constraint(EP, cMinLoxDuration_out[y in intersect(ids_with_positive(gen, lox_duration), WITH_LOX), t in 1:T], eTotalCap_AllamcycleLOX[y,lox]/lox_duration(gen[y]) >= vLOX_in[y,t])

    # connect eFuel_Allam to vFuel so the fuel cost will be determined in fuel.jl. We don't need to double account 
    # Allam cycle is exluded from the constraint on vFuel in fuel.jl
    @constraint(EP, [y in ALLAM_CYCLE_LOX, t in 1:T], EP[:vFuel][y,t] == eFuel_Allam[y,t])
    
    # add vom
    # variale costs are related to the main output, e.g., gross power output frmo sCO2 turbine
    # power consumption associated with the ASU, and CO2 sequestration costs 
    # variable costs will be mutiplied by inputs["omega"] to be compatiable with time domain reduction

    # variable OM 
    @expression(EP, eCVar_component[y in ALLAM_CYCLE_LOX, i = 1:3, t = 1:T], omega[t] * vOutput_AllamcycleLOX[y,i,t] * allam_dict[y,"vom_cost"][i])
    # sum to annual level 
    @expression(EP, eCVar_Allam[y in ALLAM_CYCLE_LOX], sum(eCVar_component[y,i,t] for i in 1:3 for t in 1:T))
    # sum to zonal-annual level
    @expression(EP, eZonalCVar_Allam[z = 1:Z], sum(eCVar_Allam[y] for y in intersect(ALLAM_CYCLE_LOX, resources_in_zone_by_rid(gen, z))))
    # system level VOM
    @expression(EP, eTotalCVar_Allam, sum(eZonalCVar_Allam[z] for z in 1:Z))
   
    add_to_expression!(EP[:eTotalCVarOut], eTotalCVar_Allam)
    # add to obj
    add_to_expression!(EP[:eObj], EP[:eTotalCVar_Allam])

    # Constraint 5: call allamcycle_commit!(EP, inputs, setup) and allamcycle_commit!(EP, inputs, setup) for specific constraints related to unit commitment
    if setup["UCommit"] > 0 
        allamcycle_commit!(EP, inputs, setup)
    else
        println("Warning: it is not recommended to run Allam Cycele wihtout unit commit. Please set UCommit to 1 in the setting file.")
        allamcycle_no_commit!(EP, inputs, setup)
    end

    # system capacity equal to sCO2 turbine capacity
    @constraint(EP, [y in ALLAM_CYCLE_LOX, t = 1:T], EP[:vCAP][y] == EP[:vCAP_AllamCycleLOX][y, sco2turbine])

    # Expressions related to policies
    # Capacity Reserves Margin policy
    if setup["CapacityReserveMargin"] > 0
        @expression(EP,
            eCapResMarBalanceAllam[res = 1:inputs["NCapacityReserveMargin"], t = 1:T],
            sum(derating_factor(gen[y], tag = res) * (eP_Allam[y, t]-vCHARGE_ALLAM[y,t]) for y in ALLAM_CYCLE_LOX))
        add_similar_to_expression!(EP[:eCapResMarBalance], eCapResMarBalanceAllam)
    end

    # Energy Share Requirements
    if setup["EnergyShareRequirement"] >= 1
        @expression(EP,
            eAllamCycleESR[ESR in 1:inputs["nESR"]],
            sum(inputs["omega"][t] * esr(gen[y], tag = ESR) * (eP_Allam[y, t]-vCHARGE_ALLAM[y,t])
            for y in intersect(ALLAM_CYCLE_LOX, ids_with_policy(gen, esr, tag = ESR)), t in 1:T))
        EP[:eESR] += eAllamCycleESR
    end

    # Maximum Capacity Requirement
    if setup["MaxCapReq"] == 1
        @expression(EP,
            eMaxCapResAllam[maxcap = 1:inputs["NumberOfMaxCapReqs"]],
            sum(EP[:eTotalCap_AllamcycleLOX][y, sco2turbine] 
            for y in intersect(ALLAM_CYCLE_LOX, ids_with_policy(gen, max_cap, tag = maxcap))))
        add_similar_to_expression!(EP[:eMaxCapRes], eMaxCapResAllam)
    end

    # Minimum Capacity Requirement
    if setup["MinCapReq"] == 1
        @expression(EP, eMinCapResAllam[mincap = 1:inputs["NumberOfMinCapReqs"]],
            sum((EP[:eTotalCap_AllamcycleLOX][y, sco2turbine] - 
                 EP[:eTotalCap_AllamcycleLOX][y, asu] * gen[y].lox_poweruserate_o2 -
                 EP[:eTotalCap_AllamcycleLOX][y, asu] * gen[y].gox_poweruserate_o2 -
                 EP[:eTotalCap_AllamcycleLOX][y, asu] * gen[y].poweruserate_other)
                 for y in intersect(ALLAM_CYCLE_LOX, ids_with_policy(gen, min_cap, tag = mincap))))
        add_similar_to_expression!(EP[:eMinCapRes], eMinCapResAllam)
    end

    # Hourly matching constraints
    if setup["HourlyMatching"] == 1
        QUALIFIED_SUPPLY = inputs["QUALIFIED_SUPPLY"]   # Resources that are qualified to contribute to hourly matching constraint
        @expression(EP, eHMAllam[t = 1:T, z = 1:Z],
            -sum(EP[:vCHARGE_ALLAM][y,t] 
            for y in intersect(resources_in_zone_by_rid(gen,z), QUALIFIED_SUPPLY, ALLAM_CYCLE_LOX)))
        add_similar_to_expression!(EP[:eHM], eHMAllam)
    end
end