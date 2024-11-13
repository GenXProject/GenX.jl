@doc raw"""
ccs_solvent_storage!(EP::Model, inputs::Dict, setup::Dict)
This module models the flexible ccs with solvent storage tank. 
In this module, the key components of a flexible CCS gas plant are break down into mutiple components with independent capacity decisions:
 - gas turbines
 - steam turbines
 - CO2 absorber
 - CO2 compressor
 - CO2 regenerator
 - rich solvent storage tank
 - lean solvent storage tank 

**Important expressions**
1. Fuel flow
```math
\begin{aligned}
    \Pi_{y,z}^{net} = \Pi_{y,sco2turbine,t} - \Pi_{y,asu,t} - \Pi_{y,aux,t} - \Theta_{y,t}
\end{aligned}
```

2. CO2 flow

3. Steam flow

4. Power flow

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

3. all the CCS_SS cycle output should be less than the capacity 
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
# 5: call CCS_SScycle_commit!(EP, inputs, setup) and CCS_SScycle_commit!(EP, inputs, setup) for specific investment and operational constraints related to unit commitment
"""
function ccs_solvent_storage!(EP::Model, inputs::Dict, setup::Dict)
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

    RET_CAP = inputs["RET_CAP"]
    NEW_CAP = inputs["NEW_CAP"]

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

    # construct a matrix represent the main output of each component
    # y represents the plant, i represents the specfic subcomponents, and t represents the time
    # The main output from gas turbine is the gross power output (MWh), 
    # from steam turbine net power (MWh),
    # from absorber is captured CO2 (ton),
    # from compressor is the energy consumption from the compression process (MWh),
    # from regenerator is the amount of CO2 (ton),
    # from the solvent storage tank (rich/lean) is the mass of rich/lean solvents stored.

    @variable(EP, vOutput_CCS_SS[y in CCS_SOLVENT_STORAGE, i = 1:7, t = 1:T] >= 0)

    # retired capacity
    @variable(EP, vRETCAP_CCS_SS[y in intersect(CCS_SOLVENT_STORAGE, RET_CAP), i = 1:7]  >= 0)
    # new capacity
    @variable(EP, vCAP_CCS_SS[y in intersect(CCS_SOLVENT_STORAGE, NEW_CAP), i = 1:7]  >= 0)
    # make system capacity equal to the total capacity of the gas turbine and steam turbine capacity
    @constraint(EP, [y in intersect(CCS_SOLVENT_STORAGE, NEW_CAP), t = 1:T], EP[:vCAP][y] == EP[:vCAP_CCS_SS][y, gasturbine] + EP[:vCAP_CCS_SS][y, steamturbine])
    @constraint(EP, [y in intersect(CCS_SOLVENT_STORAGE, RET_CAP), t = 1:T], EP[:vRETCAP][y] == EP[:vRETCAP_CCS_SS][y, gasturbine] + EP[:vRETCAP_CCS_SS][y, steamturbine])

    if MultiStage ==1
        @variable(EP, vEXISTINGCAP_CCS_SS[y in CCS_SOLVENT_STORAGE, i = 1:7]>=0)
    end

    if MultiStage == 1
        @expression(EP, eExistingCap_CCS_SS[y in CCS_SOLVENT_STORAGE, i = 1:7], vEXISTINGCAP_CCS_SS[y,i])
                # Existing capacity variable is equal to existing capacity specified in the input file
        @constraint(EP, cExistingCap_CCS_SS[y in CCS_SOLVENT_STORAGE, i in 1:7], EP[:vEXISTINGCAP_CCS_SS][y,i]== CCS_SS_dict[y, "existing_cap"][i])

    else
        @expression(EP, eExistingCap_CCS_SS[y in CCS_SOLVENT_STORAGE, i = 1:7], solvent_storage_dict[y, "existing_cap"][i])
    end

    # Note: CCS_SOLVENT_STORAGE is not compatiable with RETRO for now.
    @expression(EP, eTotalCap_CCS_SS[y in CCS_SOLVENT_STORAGE, i in 1:7],
    if y in intersect(NEW_CAP_CCS_SS, RET_CAP_CCS_SS) # Resources eligible for new capacity and retirements 
        if y in COMMIT_CCS_SS
            eExistingCap_CCS_SS[y,i] +
                solvent_storage_dict[y,"cap_size"][i] * (EP[:vCAP_CCS_SS][y,i] - EP[:vRETCAP_CCS_SS][y,i])
        else
            eExistingCap_CCS_SS[y, i] + EP[:vCAP_CCS_SS][y, i] - EP[:vRETCAP_CCS_SS][y,i]
        end
    elseif y in setdiff(RET_CAP_CCS_SS, NEW_CAP_CCS_SS) # Resources eligible for only capacity retirements
        if y in COMMIT_CCS_SS
            eExistingCap_CCS_SS[y,i] - solvent_storage_dict[y,"cap_size"][i] * EP[:vRETCAP_CCS_SS][y,i]
        else
            eExistingCap_CCS_SS[y,i] - EP[:vRETCAP_CCS_SS][y,i]
        end
    elseif y in setdiff(NEW_CAP_CCS_SS, RET_CAP_CCS_SS) # Resources eligible for new capacity
        if y in COMMIT_CCS_SS
            eExistingCap_CCS_SS[y,i] + solvent_storage_dict[y,"cap_size"][i] * (EP[:vCAP_CCS_SS][y,i] )
        else
            eExistingCap_CCS_SS[y,i] + EP[:vCAP_CCS_SS][y,i] 
        end
    else # Resources not eligible for new capacity or retirement
        eExistingCap_CCS_SS[y,i]
    end)

    # Fixed cost of each component in CCS_SOLVENT_STORAGE
    @expression(EP, eCFix_CCS_SS[y in CCS_SOLVENT_STORAGE, i in 1:7],
        if y in NEW_CAP_CCS_SS # Resources eligible for new capacity
            if y in COMMIT_CCS_SS  # Resource eligible for Unit commitment
                solvent_storage_dict[y,"inv_cost"][i] * solvent_storage_dict[y,"cap_size"][i] * EP[:vCAP_CCS_SS][y, i]+
                solvent_storage_dict[y,"fom_cost"][i]  * eTotalCap_CCS_SS[y,i]
            else
                solvent_storage_dict[y,"inv_cost"][i] * EP[:vCAP_CCS_SS][y, i]+
                solvent_storage_dict[y,"fom_cost"][i] * eTotalCap_CCS_SS[y,i]
            end
        else
            solvent_storage_dict[y,"fom_cost"][i]  * eTotalCap_CCS_SS[y,i]
        end)

    # connect eCFix_CCS_SS_Plant to eCFix
    @expression(EP, eCFix_CCS_SS_Plant[y in CCS_SOLVENT_STORAGE], sum(EP[:eCFix_CCS_SS][y,i] for i in 1:7))
    @expression(EP, eTotalCFix_CCS_SS, sum(EP[:eCFix_CCS_SS_Plant][y] for y in CCS_SOLVENT_STORAGE))
    # add this to eTotalCFix
    add_to_expression!(EP[:eTotalCFix], eTotalCFix_CCS_SS)

    # add to Obj
    if MultiStage == 1
        # OPEX multiplier scales fixed costs to account for multiple years between two model stages
        # We divide by OPEXMULT since we are going to multiply the entire objective function by this term later,
        # and we have already accounted for multiple years between stages for fixed costs.
        add_to_expression!(EP[:eObj], 1 / inputs["OPEXMULT"], eTotalCFix_CCS_SS)
    else
        add_to_expression!(EP[:eObj], eTotalCFix_CCS_SS)
    end

    if MultiStage == 1
        # Existing capacity variable is equal to existing capacity specified in the input file
        @constraint(EP, cExistingCap_CCS_SS[y in CCS_SOLVENT_STORAGE, i in 1:7], EP[:vEXISTINGCAP_CCS_SS][y,i]== solvent_storage_dict[y, "existing_cap"][i])
    end

    # add vom
    # variable OM 
    @expression(EP, eCVar_CCS_SS_unit[y in CCS_SOLVENT_STORAGE, i = 1:5, t = 1:T], omega[t] * vOutput_CCS_SS[y,i,t] * solvent_storage_dict[y,"vom_cost"][i])
    # sum to annual level 
    @expression(EP, eCVar_CCS_SS[y in CCS_SOLVENT_STORAGE], sum(EP[:eCVar_CCS_SS_unit][y,i,t] for i in 1:5 for t in 1:T))
    # sum to zonal-annual level
    @expression(EP, eZonalCVar_CCS_SS[z = 1:Z], sum(EP[:eCVar_CCS_SS][y] for y in intersect(CCS_SOLVENT_STORAGE, resources_in_zone_by_rid(gen, z))))
    # system level VOM
    @expression(EP, eTotalCVar_CCS_SS, sum(EP[:eZonalCVar_CCS_SS][z] for z in 1:Z))

    add_to_expression!(EP[:eTotalCVarOut], EP[:eTotalCVar_CCS_SS])
    # add to obj
    add_to_expression!(EP[:eObj], EP[:eTotalCVar_CCS_SS])

    if setup["UCommit"] > 0
        ccs_solvent_storage_commit!(EP, inputs, setup)
    else
        println("Warning: it is not recommended to run CCS_SOLVENT_STORAGE wihtout unit commit. Please set UCommit to 1 in the setting file.")
        ccs_solvent_storage_no_commit!(EP, inputs, setup)
    end

    # Expressions and constraints of CCS_SOLVENT_STORAGE operations
    # assuming that unit commit constraints are applied
    @constraint(EP, [y in CCS_SOLVENT_STORAGE, i in 1:7, t in 1:T], vOutput_CCS_SS[y, i, t] <= eTotalCap_CCS_SS[y,i])

    # 1. Flow of fuels
    @expression(EP, eFuel_CCS_SS[y in CCS_SOLVENT_STORAGE, t = 1:T],
        gen[y].heatrate_mmbtu_per_mwh_gasturbine * vOutput_CCS_SS[y, gasturbine, t])
    @constraint(EP, [y in CCS_SOLVENT_STORAGE, t = 1:T], EP[:vFuel][y, t] == EP[:eFuel_CCS_SS][y,t])

    # 2. Flow of CO2
    # 2.1 CO2 flue from the gas turbine (ton)
    @expression(EP, eEmissionsByPlant_gasturbine[y in CCS_SOLVENT_STORAGE, t = 1:T],
                EP[:vFuel][y, t] * inputs["fuel_CO2"][fuel(gen[y])])
    @expression(EP, eEmissionsByPlant_Start_gasturbine[y in CCS_SOLVENT_STORAGE, t = 1:T],
                EP[:eStartFuel][y, t] * inputs["fuel_CO2"][fuel(gen[y])])
    # 2.2 CO2 captured by absorbers (ton)
    @constraint(EP, cEmissionsCaptured_absorber[y in CCS_SOLVENT_STORAGE, t = 1:T],
                EP[:vOutput_CCS_SS][y, absorber, t] <= EP[:eEmissionsByPlant_gasturbine][y, t] * gen[y].co2_capture_fraction + 
                EP[:eEmissionsByPlant_Start_gasturbine][y, t] * gen[y].co2_capture_fraction_startup)
    # 2.3 CO2 released to the atmosphere (ton)
    @expression(EP, eEmissionsByPlant_CCS_SS[y in CCS_SOLVENT_STORAGE, t = 1:T],
                EP[:eEmissionsByPlant_gasturbine][y, t] + EP[:eEmissionsByPlant_Start_gasturbine][y, t] - EP[:vOutput_CCS_SS][y, absorber, t])

    # 2.4 CO2 balance in the solvent Storage
    # rich during the interior hours
    @constraint(EP, cSolvent_rich_inter[y in CCS_SOLVENT_STORAGE, t in INTERIOR_SUBPERIODS], 
                EP[:vOutput_CCS_SS][y, solventstorage_rich, t] == EP[:vOutput_CCS_SS][y, solventstorage_rich, t-1] + 
                                                                  EP[:vOutput_CCS_SS][y, absorber,t] / gen[y].co2_loading_ton_per_ton_solvent - 
                                                                  EP[:vOutput_CCS_SS][y, regenerator,t] / gen[y].co2_loading_ton_per_ton_solvent)
    # rich during the startup hours
    @constraint(EP, cSolvent_rich_start[y in CCS_SOLVENT_STORAGE, t in START_SUBPERIODS], 
                EP[:vOutput_CCS_SS][y, solventstorage_rich, t] == EP[:vOutput_CCS_SS][y, solventstorage_rich, hoursbefore(p, t, 1)] + 
                                                                  EP[:vOutput_CCS_SS][y, absorber,t] / gen[y].co2_loading_ton_per_ton_solvent - 
                                                                  EP[:vOutput_CCS_SS][y, regenerator,t] / gen[y].co2_loading_ton_per_ton_solvent)
    # lean during the interior hours
    @constraint(EP, cSolvent_lean_inter[y in CCS_SOLVENT_STORAGE, t in INTERIOR_SUBPERIODS], 
                EP[:vOutput_CCS_SS][y, solventstorage_lean, t] == EP[:vOutput_CCS_SS][y, solventstorage_lean, t-1] - 
                                                                  EP[:vOutput_CCS_SS][y, absorber,t] / gen[y].co2_loading_ton_per_ton_solvent + 
                                                                  EP[:vOutput_CCS_SS][y, regenerator,t] / gen[y].co2_loading_ton_per_ton_solvent)
    # lean during the startup hours
    @constraint(EP, cSolvent_lean_start[y in CCS_SOLVENT_STORAGE, t in START_SUBPERIODS], 
                EP[:vOutput_CCS_SS][y, solventstorage_lean, t] == EP[:vOutput_CCS_SS][y, solventstorage_lean, hoursbefore(p, t, 1)] - 
                                                                  EP[:vOutput_CCS_SS][y, absorber,t] / gen[y].co2_loading_ton_per_ton_solvent + 
                                                                  EP[:vOutput_CCS_SS][y, regenerator,t] / gen[y].co2_loading_ton_per_ton_solvent)
    # 2.5 CO2 regenerated in the regenerator: EP[:vOutput_CCS_SS[y, regenerator, t]]

    # 2.6 CO2 compressed and stored after the compressor: EP[:vOutput_CCS_SS[y, compressor, t]]
    @expression(EP, ePlantCCO2Sequestration_compressor[y in CCS_SOLVENT_STORAGE],   # CO2 storage and transport costs by plant
            sum(omega[t] * EP[:vOutput_CCS_SS][y, compressor, t] *
                ccs_disposal_cost_per_metric_ton(gen[y]) for t in 1:T))
    @expression(EP, eZonalCCO2Sequestration_compressor[z = 1:Z],   # CO2 storage and transport costs by zone
            sum(ePlantCCO2Sequestration_compressor[y]
            for y in intersect(resources_in_zone_by_rid(gen, z), CCS_SOLVENT_STORAGE)))
    @expression(EP, eTotaleCCO2Sequestration_compressor,
            sum(eZonalCCO2Sequestration_compressor[z] for z in 1:Z))
    add_to_expression!(EP[:eObj], EP[:eTotaleCCO2Sequestration_compressor])

    # 3. Flow of steam
    # 3.1 Generated by the steam turbine
    @expression(EP, eSteam_high[y in CCS_SOLVENT_STORAGE, t = 1:T],
                EP[:vFuel][y,t] * gen[y].steamrate_high_percentage)
    @expression(EP, eSteam_mid[y in CCS_SOLVENT_STORAGE, t = 1:T],
                EP[:vFuel][y,t] * gen[y].steamrate_mid_percentage)
    @expression(EP, eSteam_low[y in CCS_SOLVENT_STORAGE, t = 1:T],
                EP[:vFuel][y,t] * gen[y].steamrate_low_percentage)
    # 3.2 Consumed by the regenerator
    @expression(EP, eSteam_compressor[y in CCS_SOLVENT_STORAGE, t = 1:T],
                EP[:vOutput_CCS_SS][y,compressor, t] * gen[y].steamuserate_mmbtu_per_ton)

    # 4. Flow of power
    # 4.1 Generated by the gas turbine: EP[:vOutput_CCS_SS][y, gasturbine, t]]
    # 4.2 Generated by the steam turbine: EP[:vOutput_CCS_SS][y, steamturbine, t]]
    @expression(EP, ePower_steamturbine_high[y in CCS_SOLVENT_STORAGE, t = 1:T],
                EP[:eSteam_high][y, t] / gen[y].heatrate_mmbtu_per_mwh_steamturbine_high)
    @expression(EP, ePower_steamturbine_mid[y in CCS_SOLVENT_STORAGE, t = 1:T],
                EP[:eSteam_mid][y, t] / gen[y].heatrate_mmbtu_per_mwh_steamturbine_mid)
    @expression(EP, ePower_steamturbine_low[y in CCS_SOLVENT_STORAGE, t = 1:T],
                (EP[:eSteam_high][y, t] - EP[:eSteam_compressor][y ,t]) / gen[y].heatrate_mmbtu_per_mwh_steamturbine_low)
    @constraint(EP, cPower_steamturbine[y in CCS_SOLVENT_STORAGE, t = 1:T],
                EP[:vOutput_CCS_SS][y, steamturbine, t] == EP[:ePower_steamturbine_high][y, t] + EP[:ePower_steamturbine_mid][y, t] + EP[:ePower_steamturbine_low][y, t])
    # 4.3 Consumed by the absorber    
    @expression(EP, ePower_absorber[y in CCS_SOLVENT_STORAGE, t = 1:T],
                EP[:vOutput_CCS_SS][y, absorber, t] * gen[y].poweruserate_mwh_per_ton_co2_absorber)
    # 4.4 Consumed by the compressor
    @expression(EP, ePower_compressor[y in CCS_SOLVENT_STORAGE, t = 1:T],
                EP[:vOutput_CCS_SS][y, compressor, t] * gen[y].poweruserate_mwh_per_ton_co2_compressor)
    # 4.5 Consumed by other auxiliary loads
    @expression(EP, ePower_other[y in CCS_SOLVENT_STORAGE, t = 1:T],
                EP[:vFuel][y, t] * gen[y].poweruserate_mwh_per_mmbtu_fuel_other)
    # 4.6 Blancen between the CCS_SOLVENT_STORAGE and the grid
    @variable(EP, vCHARGE_CCS_SS[y in CCS_SOLVENT_STORAGE, t = 1:T] >= 0)  # Grid export to the system
    @constraint(EP, cCharge[y in CCS_SOLVENT_STORAGE, t = 1:T],
                EP[:ePower_absorber][y, t] + EP[:ePower_compressor][y, t] + EP[:ePower_other][y, t] >= vCHARGE_CCS_SS[y, t])
    # link vP, vCHARGE_CCS_SS, and eP_CCS_SS
    @expression(EP, eP_CCS_SS[y in CCS_SOLVENT_STORAGE, t=1:T], 
                EP[:vOutput_CCS_SS][y, gasturbine, t] + EP[:vOutput_CCS_SS][y, steamturbine, t] - EP[:ePower_absorber][y, t] - 
                EP[:ePower_compressor][y, t] - EP[:ePower_other][y, t] + vCHARGE_CCS_SS[y, t])
    @constraint(EP, cP[y in CCS_SOLVENT_STORAGE, t = 1:T], eP_CCS_SS[y, t] == EP[:vP][y,t])
    @expression(EP, ePowerBalance_CCS_SS[t = 1:T, z = 1:Z],
                sum(EP[:eP_CCS_SS][y, t] - EP[:vCHARGE_CCS_SS][y, t]
                for y in intersect(CCS_SOLVENT_STORAGE, resources_in_zone_by_rid(gen, z))))
    add_similar_to_expression!(EP[:ePowerBalance], ePowerBalance_CCS_SS)

    # Expressions related to policies
    # Capacity Reserves Margin policy
    if setup["CapacityReserveMargin"] > 0
        @expression(EP,
            eCapResMarBalanceCCS_SS[res = 1:inputs["NCapacityReserveMargin"], t = 1:T],
            sum(derating_factor(gen[y], tag = res) * (eP_CCS_SS[y, t] - vCHARGE_CCS_SS[y,t]) for y in CCS_SOLVENT_STORAGE))
        add_similar_to_expression!(EP[:eCapResMarBalance], eCapResMarBalanceCCS_SS)
    end

    # Energy Share Requirements
    if setup["EnergyShareRequirement"] >= 1
        @expression(EP,
            eCCS_SS_ESR[ESR in 1:inputs["nESR"]],
            sum(inputs["omega"][t] * esr(gen[y], tag = ESR) * (eP_CCS_SS[y, t] - vCHARGE_CCS_SS[y,t])
            for y in intersect(CCS_SOLVENT_STORAGE, ids_with_policy(gen, esr, tag = ESR)), t in 1:T))
        EP[:eESR] += eCCS_SS_ESR
    end

    # Maximum Capacity Requirement
    if setup["MaxCapReq"] == 1
        @expression(EP,
            eMaxCapResCCS_SS[maxcap = 1:inputs["NumberOfMaxCapReqs"]],
            sum(EP[:eTotalCap_CCS_SS][y, gasturbine] + EP[:eTotalCap_CCS_SS][y, steamturbine]
            for y in intersect(CCS_SOLVENT_STORAGE, ids_with_policy(gen, max_cap, tag = maxcap))))
        add_similar_to_expression!(EP[:eMaxCapRes], eMaxCapResCCS_SS)
    end

    # Minimum Capacity Requirement
    if setup["MinCapReq"] == 1
        @expression(EP, eMinCapResCCS_SS[mincap = 1:inputs["NumberOfMinCapReqs"]],
            sum((EP[:eTotalCap_CCS_SS][y, gasturbine] + EP[:eTotalCap_CCS_SS][y, steamturbine] - 
                 EP[:eTotalCap_CCS_SS][y, absorber] * gen[y].poweruserate_mwh_per_ton_co2_absorber -
                 EP[:eTotalCap_CCS_SS][y, compressor] * gen[y].poweruserate_mwh_per_ton_co2_compressor -
                 EP[:eTotalCap_CCS_SS][y, gasturbine] * gen[y].heatrate_mmbtu_per_mwh_gasturbine * gen[y].poweruserate_mwh_per_mmbtu_fuel_other)
                 for y in intersect(CCS_SOLVENT_STORAGE, ids_with_policy(gen, min_cap, tag = mincap))))
        add_similar_to_expression!(EP[:eMinCapRes], eMinCapResCCS_SS)
    end

    # Hydrogen production supply is added to electrolyzer.jl

end