@doc raw"""
	vre_stor!(EP::Model, inputs::Dict, setup::Dict)

This module enables the modeling of 1) co-located VRE and energy storage technologies, 
and 2) optimized interconnection sizing for VREs. Utility-scale solar PV and/or wind VRE technologies 
can be modeled at the same site with or without storage technologies. Storage resources 
can be charged/discharged behind the meter through the inverter (DC) and through AC charging/discharging 
capabilities. Each resource can be configured to have any combination of the following components: 
solar PV, wind, DC discharging/charging storage, and AC discharging/charging storage resources. For 
storage resources, both long duration energy storage and short-duration energy storage can be modeled, 
via asymmetric or symmetric charging and discharging options. Each resource connects 
to the grid via a grid connection component, which is the only required decision variable 
that each resource must have. If the configured resource has either solar PV and/or DC discharging/charging 
storage capabilities, an inverter decision variable is also created. The full module with the decision 
variables and interactions can be found below. 

![Configurable Co-located VRE and Storage Module Interactions and Decision Variables](../../assets/vre_stor_module.png)
*Figure. Configurable Co-located VRE and Storage Module Interactions and Decision Variables*

This module is split such that functions are called for each configurable component of a co-located resource: 
    ```inverter_vre_stor()```, ```solar_vre_stor!()```, ```wind_vre_stor!()```, ```stor_vre_stor!()```, ```lds_vre_stor!()```, 
    and ```investment_charge_vre_stor!()```. The function ```vre_stor!()``` specifically ensures 
    that all necessary functions are called to activate the appropriate constraints, creates constraints that apply to 
    multiple components (i.e. inverter and grid connection balances and maximums), and activates all of the policies 
    that have been created (minimum capacity requirements, maximum capacity requirements, capacity reserve margins, operating reserves, and
    energy share requirements can all be turned on for this module). Note that not all of these variables are indexed by each co-located VRE and storage resource (for example, some co-located resources 
    may only have a solar PV component and battery technology or just a wind component). Thus, the function ```vre_stor!()``` 
    ensures indexing issues do not arise across the various potential configurations of co-located VRE and storage 
    module but showcases all constraints as if each decision variable (that may be only applicable to certain components) 
    is indexed by each $y \in \mathcal{VS}$ for readability. 

The first constraint is created with the function ```vre_stor!()``` and exists for all resources, 
    regardless of the VRE and storage components that each resource contains and regardless of the policies 
    invoked for the module. This constraint represents the energy balance, ensuring net DC power (discharge 
    of battery, PV generation, and charge of battery) and net AC power (discharge of battery, wind generation, 
    and charge of battery) are equal to the technology's total discharging to and charging from the grid:

```math
\begin{aligned}
    & \Theta_{y,z,t} - \Pi_{y,z,t} = \Theta_{y,z,t}^{wind} + \Theta_{y,z,t}^{ac} - \Pi_{y,z,t}^{ac} + \eta^{inverter}_{y,z} \times (\Theta_{y,z,t}^{pv} + \Theta_{y,z,t}^{dc}) - \frac{\Pi^{dc}_{y,z,t}}{\eta^{inverter}_{y,z}} \\
    & \forall y \in \mathcal{VS}, \forall z \in \mathcal{Z}, \forall t \in \mathcal{T}
\end{aligned}
```

The second constraint is also created with the function ```vre_stor!()``` and exists for all resources, 
    regardless of the VRE and storage components that each resource contains. However, this constraint changes 
    when either or both capacity reserve margins and operating reserves are activated. The following constraint 
    enforces that the maximum grid exports and imports must be less than the grid connection capacity (without any policies):

```math
\begin{aligned}
    & \Theta_{y,z,t} + \Pi_{y,z,t} \leq \Delta^{total}_{y,z} & \quad \forall y \in \mathcal{VS}, \forall z \in \mathcal{Z}, \forall t \in \mathcal{T}
\end{aligned}
```

The second constraint with only capacity reserve margins activated is:
```math
\begin{aligned}
    & \Theta_{y,z,t} + \Pi_{y,z,t} + \Theta^{CRM,ac}_{y,z,t} + \Pi^{CRM,ac}_{y,z,t} + \eta^{inverter}_{y,z} \times \Theta^{CRM,dc}_{y,z,t} + \frac{\Pi^{CRM,dc}_{y,z,t}}{\eta^{inverter}_{y,z}} \\
    & \leq \Delta^{total}_{y,z} \quad \forall y \in \mathcal{VS}, \forall z \in \mathcal{Z}, \forall t \in \mathcal{T}
\end{aligned}
```
The second constraint with only operating reserves activated is:
```math
\begin{aligned}
    & \Theta_{y,z,t} + \Pi_{y,z,t} + f^{ac,dis}_{y,z,t} + r^{ac,dis}_{y,z,t} + f^{ac,cha}_{y,z,t} + f^{wind}_{y,z,t} + r^{wind}_{y,z,t} \\
    & + \eta^{inverter}_{y,z} \times (f^{pv}_{y,z,t} + r^{pv}_{y,z,t} + f^{dc,dis}_{y,z,t} + r^{dc,dis}_{y,z,t}) + \frac{f^{dc,cha}_{y,z,t}}{\eta^{inverter}_{y,z}} \leq \Delta^{total}_{y,z} \quad \forall y \in \mathcal{VS}, \forall z \in \mathcal{Z}, \forall t \in \mathcal{T}
\end{aligned}
```
The second constraint with both capacity reserve margins and operating reserves activated is:
```math
\begin{aligned}
    & \Theta_{y,z,t} + \Pi_{y,z,t} + \Theta^{CRM,ac}_{y,z,t} + \Pi^{CRM,ac}_{y,z,t} + f^{ac,dis}_{y,z,t} + r^{ac,dis}_{y,z,t} + f^{ac,cha}_{y,z,t} + f^{wind}_{y,z,t} + r^{wind}_{y,z,t} \\
    & + \eta^{inverter}_{y,z} \times (\Theta^{CRM,dc}_{y,z,t} + f^{pv}_{y,z,t} + r^{pv}_{y,z,t} + f^{dc,dis}_{y,z,t} + r^{dc,dis}_{y,z,t}) + \frac{\Pi^{CRM,dc}_{y,z,t} + f^{dc,cha}_{y,z,t}}{\eta^{inverter}_{y,z}}  \\
    & \leq \Delta^{total}_{y,z} \quad \forall y \in \mathcal{VS}, \forall z \in \mathcal{Z}, \forall t \in \mathcal{T}
\end{aligned}
```
"""
function vre_stor!(EP::Model, inputs::Dict, setup::Dict)
    println("VRE-Storage Module")

    ### LOAD DATA ###

    # Load generators dataframe, sets, and time periods
    gen = inputs["RESOURCES"]

    T = inputs["T"]                                                 # Number of time steps (hours)
    Z = inputs["Z"]                                                 # Number of zones

    # Load VRE-storage inputs
    VRE_STOR = inputs["VRE_STOR"]                                   # Set of VRE-STOR generators (indices)
    gen_VRE_STOR = gen.VreStorage                                   # Set of VRE-STOR generators (objects)
    SOLAR = inputs["VS_SOLAR"]                                      # Set of VRE-STOR generators with solar-component
    DC = inputs["VS_DC"]                                            # Set of VRE-STOR generators with inverter-component
    WIND = inputs["VS_WIND"]                                        # Set of VRE-STOR generators with wind-component
    STOR = inputs["VS_STOR"]                                        # Set of VRE-STOR generators with storage-component
    ELEC = inputs["VS_ELEC"]                                        # Set of VRE-STOR generators with electrolyzer-component
    NEW_CAP = intersect(VRE_STOR, inputs["NEW_CAP"])                # Set of VRE-STOR generators eligible for new buildout

    # Policy flags
    EnergyShareRequirement = setup["EnergyShareRequirement"]
    CapacityReserveMargin = setup["CapacityReserveMargin"]
    MinCapReq = setup["MinCapReq"]
    MaxCapReq = setup["MaxCapReq"]
    IncludeLossesInESR = setup["IncludeLossesInESR"]
    OperationalReserves = setup["OperationalReserves"]

    by_rid(rid, sym) = by_rid_res(rid, sym, gen_VRE_STOR)

    ### VARIABLES ARE DEFINED IN RESPECTIVE MODULES ###

    ### EXPRESSIONS ###
    ## Power Balance Expressions ##

    # Note: The subtraction of the charging component can be found in STOR function
    @expression(EP, ePowerBalance_VRE_STOR[t = 1:T, z = 1:Z], JuMP.AffExpr())
    gen_VRE_STOR_BY_ZONE = map(1:Z) do z
        return resources_in_zone_by_rid(gen_VRE_STOR, z)
    end
    for t in 1:T, z in 1:Z
        if !isempty(gen_VRE_STOR_BY_ZONE[z])
            for y in gen_VRE_STOR_BY_ZONE[z]
                add_to_expression!(ePowerBalance_VRE_STOR[t, z], EP[:vP][y, t])
            end
        end
    end

    ## Module Expressions ##
    # Inverter AC Balance
    @expression(EP, eInvACBalance[y in VRE_STOR, t = 1:T], JuMP.AffExpr())

    # Grid Exports
    @expression(EP, eGridExport[y in VRE_STOR, t = 1:T], JuMP.AffExpr())

    ### COMPONENT MODULE CONSTRAINTS ###

    # Activate inverter module constraints
    if !isempty(DC)
        inverter_vre_stor!(EP, inputs, setup)
    end

    # Activate solar module constraints
    if !isempty(SOLAR)
        solar_vre_stor!(EP, inputs, setup)
    end

    # Activate wind module constraints
    if !isempty(WIND)
        wind_vre_stor!(EP, inputs, setup)
    end

    # Activate storage module constraints & additional policies
    if !isempty(STOR)
        stor_vre_stor!(EP, inputs, setup)
    end
    # Activate electrolyzer module constraints & additional policies
    if !isempty(ELEC)
        elec_vre_stor!(EP, inputs, setup)
    end

    ### POLICIES AND POWER BALANCE ###

    # Energy Share Requirement
    if EnergyShareRequirement >= 1
        @expression(EP, eESRVREStor[ESR = 1:inputs["nESR"]],
            sum(inputs["omega"][t] * esr_vrestor(gen[y], tag = ESR) * EP[:vP_SOLAR][y, t] *
                by_rid(y, :etainverter)
            for y in intersect(SOLAR, ids_with_policy(gen, esr_vrestor, tag = ESR)),
            t in 1:T)
            +sum(inputs["omega"][t] * esr_vrestor(gen[y], tag = ESR) * EP[:vP_WIND][y, t]
            for y in intersect(WIND, ids_with_policy(gen, esr_vrestor, tag = ESR)),
            t in 1:T))
        add_similar_to_expression!(EP[:eESR], eESRVREStor)
        if IncludeLossesInESR == 1
            @expression(EP, eESRVREStorLosses[ESR = 1:inputs["nESR"]],
                sum(inputs["dfESR"][z, ESR] * sum(EP[:eELOSS_VRE_STOR][y]
                    for y in intersect(STOR, gen_VRE_STOR_BY_ZONE[z]))
                for z in findall(x -> x > 0, inputs["dfESR"][:, ESR])))
            add_similar_to_expression!(EP[:eESR], -1.0, eESRVREStorLosses)
        end
    end
    
    # Capacity Reserve Margin Requirement
    if CapacityReserveMargin > 0
        vre_stor_capres!(EP, inputs, setup)
    end

    # Operational Reserves Requirement
    if OperationalReserves == 1
        vre_stor_operational_reserves!(EP, inputs, setup)
    end

    # Power Balance
    add_similar_to_expression!(EP[:ePowerBalance], ePowerBalance_VRE_STOR)

    ### CONSTRAINTS ###

    # Constraint 1: Energy Balance Constraint
    @constraint(EP, cEnergyBalance[y in VRE_STOR, t = 1:T],
        EP[:vP][y, t]==eInvACBalance[y, t])

    # Constraint 2: Grid Export/Import Maximum
    @constraint(EP, cGridExport[y in VRE_STOR, t = 1:T],
        EP[:vP][y, t] + eGridExport[y, t]<=EP[:eTotalCap][y])

    # Constraint 3: Inverter Export/Import Maximum (implemented in main module due to potential capacity reserve margin and operating reserve constraints)
    @constraint(EP,
        cInverterExport[y in DC, t = 1:T],
        EP[:eInverterExport][y, t]<=EP[:eTotalCap_DC][y])

    # Constraint 4: PV Generation (implemented in main module due to potential capacity reserve margin and operating reserve constraints)
    @constraint(EP,
        cSolarGenMaxS[y in SOLAR, t = 1:T],
        EP[:eSolarGenMaxS][y, t]<=inputs["pP_Max_Solar"][y, t] * EP[:eTotalCap_SOLAR][y])

    # Constraint 5: Wind Generation (implemented in main module due to potential capacity reserve margin and operating reserve constraints)
    @constraint(EP,
        cWindGenMaxW[y in WIND, t = 1:T],
        EP[:eWindGenMaxW][y, t]<=inputs["pP_Max_Wind"][y, t] * EP[:eTotalCap_WIND][y])

    # Constraint 6: Symmetric Storage Resources (implemented in main module due to potential capacity reserve margin and operating reserve constraints)
    @constraint(EP, cChargeDischargeMaxDC[y in inputs["VS_SYM_DC"], t = 1:T],
        EP[:eChargeDischargeMaxDC][y,
            t]<=by_rid(y, :power_to_energy_dc) * EP[:eTotalCap_STOR][y])
    @constraint(EP, cChargeDischargeMaxAC[y in inputs["VS_SYM_AC"], t = 1:T],
        EP[:eChargeDischargeMaxAC][y,
            t]<=by_rid(y, :power_to_energy_ac) * EP[:eTotalCap_STOR][y])

    # Constraint 7: Asymmetric Storage Resources (implemented in main module due to potential capacity reserve margin and operating reserve constraints)
    @constraint(EP,
        cVreStorMaxDischargingDC[y in inputs["VS_ASYM_DC_DISCHARGE"], t = 1:T],
        EP[:eVreStorMaxDischargingDC][y, t]<=EP[:eTotalCapDischarge_DC][y])
    @constraint(EP,
        cVreStorMaxChargingDC[y in inputs["VS_ASYM_DC_CHARGE"], t = 1:T],
        EP[:eVreStorMaxChargingDC][y, t]<=EP[:eTotalCapCharge_DC][y])
    @constraint(EP,
        cVreStorMaxDischargingAC[y in inputs["VS_ASYM_AC_DISCHARGE"], t = 1:T],
        EP[:eVreStorMaxDischargingAC][y, t]<=EP[:eTotalCapDischarge_AC][y])
    @constraint(EP,
        cVreStorMaxChargingAC[y in inputs["VS_ASYM_AC_CHARGE"], t = 1:T],
        EP[:eVreStorMaxChargingAC][y, t]<=EP[:eTotalCapCharge_AC][y])
end

@doc raw"""
    inverter_vre_stor!(EP::Model, inputs::Dict, setup::Dict)

Operational inverter helper for VRE-STOR resources.

Initializes `eInverterExport[y,t]` and, in multistage runs, constrains existing
inverter-capacity variables to input data:

```math
vEXISTINGDCCAP_y = \overline{\Delta}^{existing,dc}_y
```

The inverter export limit is enforced in `vre_stor!` via
`eInverterExport[y,t] <= eTotalCap_DC[y]`.
"""
function inverter_vre_stor!(EP::Model, inputs::Dict, setup::Dict)
    println("VRE-STOR Inverter Module")

    ### LOAD DATA ###

    T = inputs["T"]
    DC = inputs["VS_DC"]
    NEW_CAP_DC = inputs["NEW_CAP_DC"]
    RET_CAP_DC = inputs["RET_CAP_DC"]
    gen = inputs["RESOURCES"]
    gen_VRE_STOR = gen.VreStorage

    MultiStage = setup["MultiStage"]

    by_rid(rid, sym) = by_rid_res(rid, sym, gen_VRE_STOR)

    # Inverter exports expression
    @expression(EP, eInverterExport[y in DC, t = 1:T], JuMP.AffExpr())

    ### CONSTRAINTS ###
    # Constraint 0: Existing capacity variable is equal to existing capacity specified in the input file
    if MultiStage == 1
        @constraint(EP,
            cExistingCapDC[y in DC],
            EP[:vEXISTINGDCCAP][y]==by_rid(y, :existing_cap_inverter_mw))
    end
end

@doc raw"""
    solar_vre_stor!(EP::Model, inputs::Dict, setup::Dict)

Operational solar-PV helper for VRE-STOR resources.

Creates dispatch variable `vP_SOLAR`, adds variable O&M cost, and contributes
solar output to inverter AC balance/export expressions.

Defines `eSolarGenMaxS`, later bounded in `vre_stor!` by:

```math
eSolarGenMaxS_{y,t} \le pP\_Max\_Solar_{y,t}\,eTotalCap\_SOLAR_y
```
"""
function solar_vre_stor!(EP::Model, inputs::Dict, setup::Dict)
    println("VRE-STOR Solar Module")

    ### LOAD DATA ###
    gen = inputs["RESOURCES"]
    gen_VRE_STOR = gen.VreStorage

    T = inputs["T"]
    SOLAR = inputs["VS_SOLAR"]

    MultiStage = setup["MultiStage"]

    by_rid(rid, sym) = by_rid_res(rid, sym, gen_VRE_STOR)

    ### VARIABLES ###
    @variable(EP, vP_SOLAR[y in SOLAR, t = 1:T] >=0)

    # Variable costs of "generation" for solar resource "y" during hour "t"
    @expression(EP, eCVarOutSolar[y in SOLAR, t = 1:T],
        inputs["omega"][t]*by_rid(y, :var_om_cost_per_mwh_solar)*by_rid(y, :etainverter)*
        EP[:vP_SOLAR][y, t])
    @expression(EP, eTotalCVarOutSolar, sum(eCVarOutSolar[y, t] for y in SOLAR, t in 1:T))
    add_to_expression!(EP[:eObj], eTotalCVarOutSolar)

    # 3. Inverter Balance, PV Generation Maximum
    @expression(EP, eSolarGenMaxS[y in SOLAR, t = 1:T], JuMP.AffExpr())
    for y in SOLAR, t in 1:T
        add_to_expression!(EP[:eInvACBalance][y, t], by_rid(y, :etainverter), EP[:vP_SOLAR][y, t])
        add_to_expression!(EP[:eInverterExport][y, t], by_rid(y, :etainverter), EP[:vP_SOLAR][y, t])
        add_to_expression!(eSolarGenMaxS[y, t], EP[:vP_SOLAR][y, t])
    end
end

@doc raw"""
    wind_vre_stor!(EP::Model, inputs::Dict, setup::Dict)

Operational wind helper for VRE-STOR resources.

Creates dispatch variable `vP_WIND`, adds variable O&M cost, and contributes wind
output to module AC-balance/export expressions.

Defines `eWindGenMaxW`, later bounded in `vre_stor!` by:

```math
eWindGenMaxW_{y,t} \le pP\_Max\_Wind_{y,t}\,eTotalCap\_WIND_y
```
"""
function wind_vre_stor!(EP::Model, inputs::Dict, setup::Dict)
    println("VRE-STOR Wind Module")

    ### LOAD DATA ###
    gen = inputs["RESOURCES"]
    gen_VRE_STOR = gen.VreStorage

    T = inputs["T"]
    WIND = inputs["VS_WIND"]

    MultiStage = setup["MultiStage"]

    by_rid(rid, sym) = by_rid_res(rid, sym, gen_VRE_STOR)
    ### VARIABLES ###
    @variable(EP, vP_WIND[y in WIND, t = 1:T] >=0)

    # Variable costs of "generation" for wind resource "y" during hour "t"
    @expression(EP,
        eCVarOutWind[y in WIND, t = 1:T],
        inputs["omega"][t]*by_rid(y, :var_om_cost_per_mwh_wind)*EP[:vP_WIND][y, t])
    @expression(EP, eTotalCVarOutWind, sum(eCVarOutWind[y, t] for y in WIND, t in 1:T))
    add_to_expression!(EP[:eObj], eTotalCVarOutWind)

    # 3. Inverter Balance, Wind Generation Maximum
    @expression(EP, eWindGenMaxW[y in WIND, t = 1:T], JuMP.AffExpr())
    for y in WIND, t in 1:T
        add_to_expression!(EP[:eInvACBalance][y, t], EP[:vP_WIND][y, t])
        add_to_expression!(eWindGenMaxW[y, t], EP[:vP_WIND][y, t])
    end
end

@doc raw"""
    stor_vre_stor!(EP::Model, inputs::Dict, setup::Dict)

Operational storage helper for VRE-STOR resources.

Creates storage SOC and charge/discharge variables (DC/AC), adds variable O&M costs,
and builds SOC balance expressions for interior and start-of-subperiod timesteps.

SOC recursion is of the form:

```math
vS_{y,t} = vS_{y,t-1}(1-\eta^{loss}_y)
 - \frac{P^{dc,dis}_{y,t}}{\eta^{dc,dis}_y}
 - \frac{P^{ac,dis}_{y,t}}{\eta^{ac,dis}_y}
 + \eta^{dc,cha}_y P^{dc,cha}_{y,t}
 + \eta^{ac,cha}_y P^{ac,cha}_{y,t}
```

with periodic wrap for start timesteps, upper bounds by `eTotalCap_STOR`, and
power-rate expressions used by symmetric/asymmetric storage limits in `vre_stor!`.

If representative periods and LDS are active, dispatches to `lds_vre_stor!` or
`lds_vre_stor_subperiod!` depending on `setup["Benders"]`.
"""
function stor_vre_stor!(EP::Model, inputs::Dict, setup::Dict)
    println("VRE-STOR Storage Module")

    ### LOAD DATA ###

    T = inputs["T"]
    Z = inputs["Z"]

    gen = inputs["RESOURCES"]
    gen_VRE_STOR = gen.VreStorage

    STOR = inputs["VS_STOR"]
    NEW_CAP_STOR = inputs["NEW_CAP_STOR"]
    RET_CAP_STOR = inputs["RET_CAP_STOR"]
    DC_DISCHARGE = inputs["VS_STOR_DC_DISCHARGE"]
    DC_CHARGE = inputs["VS_STOR_DC_CHARGE"]
    AC_DISCHARGE = inputs["VS_STOR_AC_DISCHARGE"]
    AC_CHARGE = inputs["VS_STOR_AC_CHARGE"]
    VS_SYM_DC = inputs["VS_SYM_DC"]
    VS_SYM_AC = inputs["VS_SYM_AC"]
    VS_LDS = inputs["VS_LDS"]

    START_SUBPERIODS = inputs["START_SUBPERIODS"]
    INTERIOR_SUBPERIODS = inputs["INTERIOR_SUBPERIODS"]
    hours_per_subperiod = inputs["hours_per_subperiod"]     # total number of hours per subperiod
    rep_periods = inputs["REP_PERIOD"]

    MultiStage = setup["MultiStage"]

    by_rid(rid, sym) = by_rid_res(rid, sym, gen_VRE_STOR)

    ### STOR VARIABLES ###

    @variables(EP, begin
        # State of charge variable
        vS_VRE_STOR[y in STOR, t = 1:T] >= 0                  # Storage level of resource "y" at hour "t" [MWh] on zone "z"

        # DC-battery discharge [MWh]
        vP_DC_DISCHARGE[y in DC_DISCHARGE, t = 1:T] >= 0

        # DC-battery charge [MWh]
        vP_DC_CHARGE[y in DC_CHARGE, t = 1:T] >= 0

        # AC-battery discharge [MWh]
        vP_AC_DISCHARGE[y in AC_DISCHARGE, t = 1:T] >= 0

        # AC-battery charge [MWh]
        vP_AC_CHARGE[y in AC_CHARGE, t = 1:T] >= 0

        # Grid-interfacing charge (Energy withdrawn from grid by resource VRE_STOR at hour "t") [MWh]
        vCHARGE_VRE_STOR[y in STOR, t = 1:T] >= 0
    end)
    vCAPENERGY_VS = EP[:vCAPENERGY_VS]
    vRETCAPENERGY_VS = EP[:vRETCAPENERGY_VS]
    if MultiStage == 1
        vEXISTINGCAPENERGY_VS = EP[:vEXISTINGCAPENERGY_VS]
    end
    ### EXPRESSIONS ###
    eExistingCapEnergy_VS = EP[:eExistingCapEnergy_VS]

    # Variable costs of charging DC for VRE-STOR resources "y" during hour "t"
    @expression(EP, eCVar_Charge_DC[y in DC_CHARGE, t = 1:T],
        inputs["omega"][t] * by_rid(y, :var_om_cost_per_mwh_charge_dc) *
        EP[:vP_DC_CHARGE][y, t]/by_rid(y, :etainverter))
    # Variable costs of discharging DC for VRE-STOR resources "y" during hour "t"
    @expression(EP, eCVar_Discharge_DC[y in DC_DISCHARGE, t = 1:T],
        inputs["omega"][t]*by_rid(y, :var_om_cost_per_mwh_discharge_dc)*
        by_rid(y, :etainverter)*EP[:vP_DC_DISCHARGE][y, t])
    # Variable costs of charging AC for VRE-STOR resources "y" during hour "t"
    @expression(EP, eCVar_Charge_AC[y in AC_CHARGE, t = 1:T],
        inputs["omega"][t]*by_rid(y, :var_om_cost_per_mwh_charge_ac)*
        EP[:vP_AC_CHARGE][y, t])
    # Variable costs of discharging AC for VRE-STOR resources "y" during hour "t"
    @expression(EP, eCVar_Discharge_AC[y in AC_DISCHARGE, t = 1:T],
        inputs["omega"][t]*by_rid(y, :var_om_cost_per_mwh_discharge_ac)*
        EP[:vP_AC_DISCHARGE][y, t])

    # Sum individual resource contributions
    @expression(EP,
        eTotalCVarStor,
        sum(eCVar_Charge_DC[y, t] for y in DC_CHARGE, t in 1:T)
        +sum(eCVar_Discharge_DC[y, t] for y in DC_DISCHARGE, t in 1:T)
        +sum(eCVar_Charge_AC[y, t] for y in AC_CHARGE, t in 1:T)
        +sum(eCVar_Discharge_AC[y, t] for y in AC_CHARGE, t in 1:T))
    add_to_expression!(EP[:eObj], eTotalCVarStor)

    # Inverter & Power Balance, SoC Expressions
    # Check for rep_periods > 1 & LDS=1
    if (rep_periods > 1 || haskey(inputs, "SubPeriod_Index")) && !isempty(VS_LDS)
        CONSTRAINTSET = inputs["VS_nonLDS"]
    else
        CONSTRAINTSET = STOR
    end

    # total charging expressions: total storage charge (including both AC and DC) [MWh]
    @expression(EP, eCHARGE_VS_STOR[y in STOR, t = 1:T], JuMP.AffExpr())

    # SoC expressions
    @expression(EP, eSoCBalStart_VRE_STOR[y in CONSTRAINTSET, t in START_SUBPERIODS],
        vS_VRE_STOR[y,
            t + hours_per_subperiod - 1]-self_discharge(gen[y]) *
                                         vS_VRE_STOR[y, t + hours_per_subperiod - 1])
    @expression(EP, eSoCBalInterior_VRE_STOR[y in STOR, t in INTERIOR_SUBPERIODS],
        vS_VRE_STOR[y, t - 1]-self_discharge(gen[y]) * vS_VRE_STOR[y, t - 1])
    # Expression for energy losses related to technologies (increase in effective demand)
    @expression(EP, eELOSS_VRE_STOR[y in STOR], JuMP.AffExpr())

    DC_DISCHARGE_CONSTRAINTSET = intersect(CONSTRAINTSET, DC_DISCHARGE)
    DC_CHARGE_CONSTRAINTSET = intersect(CONSTRAINTSET, DC_CHARGE)
    AC_DISCHARGE_CONSTRAINTSET = intersect(CONSTRAINTSET, AC_DISCHARGE)
    AC_CHARGE_CONSTRAINTSET = intersect(CONSTRAINTSET, AC_CHARGE)
    for t in START_SUBPERIODS
        for y in DC_DISCHARGE_CONSTRAINTSET
            add_to_expression!(eSoCBalStart_VRE_STOR[y, t], -1 / by_rid(y, :eff_down_dc), EP[:vP_DC_DISCHARGE][y, t])
        end
        for y in DC_CHARGE_CONSTRAINTSET
            add_to_expression!(eSoCBalStart_VRE_STOR[y, t], by_rid(y, :eff_up_dc), EP[:vP_DC_CHARGE][y, t])
        end
        for y in AC_DISCHARGE_CONSTRAINTSET
            add_to_expression!(eSoCBalStart_VRE_STOR[y, t], -1 / by_rid(y, :eff_down_ac), EP[:vP_AC_DISCHARGE][y, t])
        end
        for y in AC_CHARGE_CONSTRAINTSET
            add_to_expression!(eSoCBalStart_VRE_STOR[y, t], by_rid(y, :eff_up_ac), EP[:vP_AC_CHARGE][y, t])
        end
    end

    for y in DC_DISCHARGE
        for t in 1:T
            add_to_expression!(EP[:eELOSS_VRE_STOR][y], -inputs["omega"][t] * by_rid(y, :etainverter), vP_DC_DISCHARGE[y, t])
            add_to_expression!(EP[:eInvACBalance][y, t], by_rid(y, :etainverter), vP_DC_DISCHARGE[y, t])
            add_to_expression!(EP[:eInverterExport][y, t], by_rid(y, :etainverter), vP_DC_DISCHARGE[y, t])
        end
        for t in INTERIOR_SUBPERIODS
            add_to_expression!(eSoCBalInterior_VRE_STOR[y, t], -1 / by_rid(y, :eff_down_dc), vP_DC_DISCHARGE[y, t])
        end
    end

    for y in DC_CHARGE
        for t in 1:T
            add_to_expression!(EP[:eELOSS_VRE_STOR][y], inputs["omega"][t] / by_rid(y, :etainverter), vP_DC_CHARGE[y, t])
            add_to_expression!(EP[:eInvACBalance][y, t], -1 / by_rid(y, :etainverter), vP_DC_CHARGE[y, t])
            add_to_expression!(EP[:eCHARGE_VS_STOR][y, t], 1 / by_rid(y, :etainverter), vP_DC_CHARGE[y, t])
            add_to_expression!(EP[:eInverterExport][y, t], 1 / by_rid(y, :etainverter), vP_DC_CHARGE[y, t])
        end
        for t in INTERIOR_SUBPERIODS
            add_to_expression!(eSoCBalInterior_VRE_STOR[y, t], by_rid(y, :eff_up_dc), vP_DC_CHARGE[y, t])
        end
    end

    for y in AC_DISCHARGE
        for t in 1:T
            add_to_expression!(EP[:eELOSS_VRE_STOR][y], -inputs["omega"][t], vP_AC_DISCHARGE[y, t])
            add_to_expression!(EP[:eInvACBalance][y, t], 1, vP_AC_DISCHARGE[y, t])
        end
        for t in INTERIOR_SUBPERIODS
            add_to_expression!(eSoCBalInterior_VRE_STOR[y, t], -1 / by_rid(y, :eff_down_ac), vP_AC_DISCHARGE[y, t])
        end
    end

    for y in AC_CHARGE
        for t in 1:T
            add_to_expression!(EP[:eELOSS_VRE_STOR][y], inputs["omega"][t], vP_AC_CHARGE[y, t])
            add_to_expression!(EP[:eInvACBalance][y, t], -1, vP_AC_CHARGE[y, t])
            add_to_expression!(EP[:eCHARGE_VS_STOR][y, t], vP_AC_CHARGE[y, t])
        end
        for t in INTERIOR_SUBPERIODS
            add_to_expression!(eSoCBalInterior_VRE_STOR[y, t], by_rid(y, :eff_up_ac), vP_AC_CHARGE[y, t])
        end
    end

    for y in STOR, t in 1:T
        add_to_expression!(EP[:eInvACBalance][y, t], vCHARGE_VRE_STOR[y, t])
        add_to_expression!(EP[:eGridExport][y, t], vCHARGE_VRE_STOR[y, t])
    end

    gen_VRE_STOR_BY_ZONE_AND_STOR = map(1:Z) do z
        resources_in_zone = resources_in_zone_by_rid(gen_VRE_STOR, z)
        if isempty(resources_in_zone)
            return resources_in_zone
        end
        return intersect(resources_in_zone, STOR)
    end
    for z in 1:Z, t in 1:T
        if !isempty(gen_VRE_STOR_BY_ZONE_AND_STOR[z])
            for y in gen_VRE_STOR_BY_ZONE_AND_STOR[z]
                add_to_expression!(EP[:ePowerBalance_VRE_STOR][t, z], -1.0, vCHARGE_VRE_STOR[y, t])
            end
        end
    end

    # Energy Share Requirement & CO2 Policy Module

    # From CO2 Policy module
    @expression(EP, eELOSSByZone_VRE_STOR[z = 1:Z],
        sum(EP[:eELOSS_VRE_STOR][y]
        for y in gen_VRE_STOR_BY_ZONE_AND_STOR[z]))
    add_similar_to_expression!(EP[:eELOSSByZone], eELOSSByZone_VRE_STOR)

    ### CONSTRAINTS ###
    # Constraint: State of Charge (energy stored for the next hour)
    @constraint(EP, cSoCBalStart_VRE_STOR[y in CONSTRAINTSET, t in START_SUBPERIODS],
        vS_VRE_STOR[y, t]==eSoCBalStart_VRE_STOR[y, t])
    @constraint(EP, cSoCBalInterior_VRE_STOR[y in STOR, t in INTERIOR_SUBPERIODS],
        vS_VRE_STOR[y, t]==eSoCBalInterior_VRE_STOR[y, t])

    # Constraint: SOC Maximum
    @constraint(EP, cSOCMax[y in STOR, t = 1:T], vS_VRE_STOR[y, t]<=EP[:eTotalCap_STOR][y])

    ### SYMMETRIC RESOURCE CONSTRAINTS ###
    if !isempty(VS_SYM_DC)
        # Constraint 4: Charging + Discharging DC Maximum: see main module because capacity reserve margin/operating reserves may alter constraint
        @expression(EP, eChargeDischargeMaxDC[y in VS_SYM_DC, t = 1:T],
            EP[:vP_DC_DISCHARGE][y, t]+EP[:vP_DC_CHARGE][y, t])
    end

    if !isempty(VS_SYM_AC)
        # Constraint 4: Charging + Discharging AC Maximum: see main module because capacity reserve margin/operating reserves may alter constraint
        @expression(EP, eChargeDischargeMaxAC[y in VS_SYM_AC, t = 1:T],
            EP[:vP_AC_DISCHARGE][y, t]+EP[:vP_AC_CHARGE][y, t])
    end

    if !isempty(inputs["VS_ASYM"])
        VS_ASYM_DC_CHARGE = inputs["VS_ASYM_DC_CHARGE"]
        VS_ASYM_AC_CHARGE = inputs["VS_ASYM_AC_CHARGE"]
        VS_ASYM_DC_DISCHARGE = inputs["VS_ASYM_DC_DISCHARGE"]
        VS_ASYM_AC_DISCHARGE = inputs["VS_ASYM_AC_DISCHARGE"]

        if !isempty(VS_ASYM_DC_DISCHARGE)
            # Constraint: Maximum discharging must be less than discharge power rating
            @expression(EP,
                eVreStorMaxDischargingDC[y in VS_ASYM_DC_DISCHARGE, t = 1:T],
                JuMP.AffExpr())
            for y in VS_ASYM_DC_DISCHARGE, t in 1:T
                add_to_expression!(eVreStorMaxDischargingDC[y, t], EP[:vP_DC_DISCHARGE][y, t])
            end
        end

        if !isempty(VS_ASYM_DC_CHARGE)
            # Constraint: Maximum charging must be less than charge power rating
            @expression(EP,
                eVreStorMaxChargingDC[y in VS_ASYM_DC_CHARGE, t = 1:T],
                JuMP.AffExpr())
            for y in VS_ASYM_DC_CHARGE, t in 1:T
                add_to_expression!(eVreStorMaxChargingDC[y, t], EP[:vP_DC_CHARGE][y, t])
            end
        end

        if !isempty(VS_ASYM_AC_DISCHARGE)
            # Constraint: Maximum discharging rate must be less than discharge power rating
            @expression(EP,
                eVreStorMaxDischargingAC[y in VS_ASYM_AC_DISCHARGE, t = 1:T],
                JuMP.AffExpr())
            for y in VS_ASYM_AC_DISCHARGE, t in 1:T
                add_to_expression!(eVreStorMaxDischargingAC[y, t], EP[:vP_AC_DISCHARGE][y, t])
            end
        end

        if !isempty(VS_ASYM_AC_CHARGE)
            # Constraint 2: Maximum charging rate must be less than charge power rating
            @expression(EP,
                eVreStorMaxChargingAC[y in VS_ASYM_AC_CHARGE, t = 1:T],
                JuMP.AffExpr())
            for y in VS_ASYM_AC_CHARGE, t in 1:T
                add_to_expression!(eVreStorMaxChargingAC[y, t], EP[:vP_AC_CHARGE][y, t])
            end
        end
    end

    ### LONG DURATION ENERGY STORAGE RESOURCE MODULE ###
    if (rep_periods > 1 || haskey(inputs, "SubPeriod_Index")) && !isempty(VS_LDS)
        if setup["Benders"] == 1
            lds_vre_stor_subperiod!(EP, inputs)
        else
            lds_vre_stor!(EP, inputs)
        end
    end
    # Constraint 4: electricity charged from the grid cannot exceed the charging capacity of the storage component in VRE_STOR
    @constraint(EP, cMaxGridConnection[y in STOR, t = 1:T], EP[:vCHARGE_VRE_STOR][y,t] <= EP[:eCHARGE_VS_STOR][y,t])
end

@doc raw"""
    elec_vre_stor!(EP::Model, inputs::Dict)

Operational electrolyzer helper for VRE-STOR resources.

Creates electrolyzer power variable `vP_ELEC`, couples it into inverter AC balance
(as load), and enforces:

- intertemporal ramp-up/ramp-down limits scaled by `eTotalCap_ELEC`
- minimum power (`min_power_elec * eTotalCap_ELEC`)
- maximum power (`vP_ELEC <= eTotalCap_ELEC`)

Also builds `eElecGenMaxE` for module-level maximum-load tracking.
"""
function elec_vre_stor!(EP::Model, inputs::Dict, setup::Dict)
    println("VRE-STOR Electrolyzer Module")

    ### LOAD DATA ###
    gen = inputs["RESOURCES"]
    gen_VRE_STOR = gen.VreStorage

    T = inputs["T"]
    ELEC = inputs["VS_ELEC"]
    NEW_CAP_ELEC = inputs["NEW_CAP_ELEC"]
    RET_CAP_ELEC = inputs["RET_CAP_ELEC"]

    MultiStage = setup["MultiStage"]

    by_rid(rid, sym) = by_rid_res(rid, sym, gen_VRE_STOR)

    ### VARIABLES ###
    @variable(EP, vP_ELEC[y in ELEC, t = 1:T] >=0)
   
    # Inverter Balance, Electrolyzer Generation Maximum
    @expression(EP, eElecGenMaxE[y in ELEC, t = 1:T], JuMP.AffExpr())
    for y in ELEC, t in 1:T
        add_to_expression!(EP[:eInvACBalance][y, t], -1.0, EP[:vP_ELEC][y, t])
        add_to_expression!(eElecGenMaxE[y, t], EP[:vP_ELEC][y, t])
    end

    ### CONSTRAINTS ###
    # Constraint: Maximum ramp up and down between consecutive hours
    p = inputs["hours_per_subperiod"] #total number of hours per subperiod
    @constraints(EP,
        begin
            ## Maximum ramp up between consecutive hours
            [y in ELEC, t in 1:T],
            EP[:vP_ELEC][y, t] - EP[:vP_ELEC][y, hoursbefore(p, t, 1)] <=
            by_rid(y, :ramp_up_percentage_elec) * EP[:eTotalCap_ELEC][y]

            ## Maximum ramp down between consecutive hours
            [y in ELEC, t in 1:T],
            EP[:vP_ELEC][y, hoursbefore(p, t, 1)] - EP[:vP_ELEC][y, t] <=
            by_rid(y, :ramp_dn_percentage_elec) * EP[:eTotalCap_ELEC][y]
        end)

    # Constraint: Minimum and maximum power output constraints (Constraints #3-4)
    # Electrolyzers currently do not contribute to operating reserves, so there is not
    # special case (for Reserves == 1) here.
    # Could allow them to contribute as a curtailable demand in future.
    @constraints(EP,
        begin
            # Minimum stable power generated per technology "y" at hour "t" Min_Power
            [y in ELEC, t in 1:T],
            EP[:vP_ELEC][y, t] >= by_rid(y, :min_power_elec) * EP[:eTotalCap_ELEC][y]

            # Maximum power generated per technology "y" at hour "t"
            [y in ELEC, t in 1:T], EP[:vP_ELEC][y, t] <= EP[:eTotalCap_ELEC][y]
        end)
end

@doc raw"""
    lds_vre_stor!(EP::Model, inputs::Dict)

Non-Benders long-duration-storage linkage for VRE-STOR resources.

Creates inter-period SOC variables (`vSOCw_VRE_STOR`, `vdSOC_VRE_STOR`) and enforces
representative-period start SOC consistency, cross-period recursion, and upper bounds
by installed storage energy capacity.
"""
function lds_vre_stor!(EP::Model, inputs::Dict)
    println("VRE-STOR LDS Module")

    ### LOAD DATA ###

    VS_LDS = inputs["VS_LDS"]
    gen = inputs["RESOURCES"]
    gen_VRE_STOR = gen.VreStorage

    REP_PERIOD = inputs["REP_PERIOD"]  # Number of representative periods
    dfPeriodMap = inputs["Period_Map"] # Dataframe that maps modeled periods to representative periods
    NPeriods = size(inputs["Period_Map"])[1] # Number of modeled periods
    hours_per_subperiod = inputs["hours_per_subperiod"] #total number of hours per subperiod
    MODELED_PERIODS_INDEX = 1:NPeriods
    REP_PERIODS_INDEX = MODELED_PERIODS_INDEX[dfPeriodMap[!, :Rep_Period] .== MODELED_PERIODS_INDEX]

    by_rid(rid, sym) = by_rid_res(rid, sym, gen_VRE_STOR)

    ### LDS VARIABLES ###

    @variables(EP, begin
        # State of charge of storage at beginning of each modeled period n
        vSOCw_VRE_STOR[y in VS_LDS, n in MODELED_PERIODS_INDEX] >= 0

        # Build up in storage inventory over each representative period w (can be pos or neg)
        vdSOC_VRE_STOR[y in VS_LDS, w = 1:REP_PERIOD]
    end)

    ### EXPRESSIONS ###

    # Note: tw_min = hours_per_subperiod*(w-1)+1; tw_max = hours_per_subperiod*w
    @expression(EP, eVreStorSoCBalLongDurationStorageStart[y in VS_LDS, w = 1:REP_PERIOD],
        (1 -
         self_discharge(gen[y]))*(EP[:vS_VRE_STOR][y, hours_per_subperiod * w] -
                                  EP[:vdSOC_VRE_STOR][y, w]))

    DC_DISCHARGE_CONSTRAINTSET = intersect(inputs["VS_STOR_DC_DISCHARGE"], VS_LDS)
    DC_CHARGE_CONSTRAINTSET = intersect(inputs["VS_STOR_DC_CHARGE"], VS_LDS)
    AC_DISCHARGE_CONSTRAINTSET = intersect(inputs["VS_STOR_AC_DISCHARGE"], VS_LDS)
    AC_CHARGE_CONSTRAINTSET = intersect(inputs["VS_STOR_AC_CHARGE"], VS_LDS)
    for w in 1:REP_PERIOD
        for y in DC_DISCHARGE_CONSTRAINTSET
            add_to_expression!(EP[:eVreStorSoCBalLongDurationStorageStart][y, w],
                -1 / by_rid(y, :eff_down_dc), EP[:vP_DC_DISCHARGE][y, hours_per_subperiod * (w - 1) + 1])
        end

        for y in DC_CHARGE_CONSTRAINTSET
            add_to_expression!(EP[:eVreStorSoCBalLongDurationStorageStart][y, w],
                by_rid(y, :eff_up_dc), EP[:vP_DC_CHARGE][y, hours_per_subperiod * (w - 1) + 1])
        end

        for y in AC_DISCHARGE_CONSTRAINTSET
            add_to_expression!(EP[:eVreStorSoCBalLongDurationStorageStart][y, w],
                -1 / by_rid(y, :eff_down_ac), EP[:vP_AC_DISCHARGE][y, hours_per_subperiod * (w - 1) + 1])
        end

        for y in AC_CHARGE_CONSTRAINTSET
            add_to_expression!(EP[:eVreStorSoCBalLongDurationStorageStart][y, w],
                by_rid(y, :eff_up_ac), EP[:vP_AC_CHARGE][y, hours_per_subperiod * (w - 1) + 1])
        end
    end

    ### CONSTRAINTS ### 

    # Constraint 1: Link the state of charge between the start of periods for LDS resources
    @constraint(EP, cVreStorSoCBalLongDurationStorageStart[y in VS_LDS, w = 1:REP_PERIOD],
        EP[:vS_VRE_STOR][y,
            hours_per_subperiod * (w - 1) + 1]==EP[:eVreStorSoCBalLongDurationStorageStart][y, w])

    # Constraint 2: Storage at beginning of period w = storage at beginning of period w-1 + storage built up in period w (after n representative periods)
    # Multiply storage build up term from prior period with corresponding weight
    @constraint(EP,
        cVreStorSoCBalLongDurationStorage[y in VS_LDS, r in MODELED_PERIODS_INDEX],
        EP[:vSOCw_VRE_STOR][y,
            mod1(r + 1, NPeriods)]==EP[:vSOCw_VRE_STOR][y, r] +
                                    EP[:vdSOC_VRE_STOR][
            y, dfPeriodMap[r, :Rep_Period_Index]])

    # Constraint 3: Storage at beginning of each modeled period cannot exceed installed energy capacity
    @constraint(EP,
        cVreStorSoCBalLongDurationStorageUpper[y in VS_LDS, r in MODELED_PERIODS_INDEX],
        EP[:vSOCw_VRE_STOR][y, r]<=EP[:eTotalCap_STOR][y])

    # Constraint 4: Initial storage level for representative periods must also adhere to sub-period storage inventory balance
    # Initial storage = Final storage - change in storage inventory across representative period
    @constraint(EP,
        cVreStorSoCBalLongDurationStorageSub[y in VS_LDS, r in REP_PERIODS_INDEX],
        EP[:vSOCw_VRE_STOR][y,r]==EP[:vS_VRE_STOR][
            y, hours_per_subperiod * dfPeriodMap[r, :Rep_Period_Index]]
                -
                EP[:vdSOC_VRE_STOR][y, dfPeriodMap[r, :Rep_Period_Index]])
end

@doc raw"""
    lds_vre_stor_subperiod!(EP::Model, inputs::Dict)

Benders subproblem LDS helper for VRE-STOR resources.

Builds subproblem-period SOC linking constraints between beginning and end of the
representative period and introduces bounded slack variables to preserve feasibility
in decomposition iterations.
"""
function lds_vre_stor_subperiod!(EP::Model, inputs::Dict)
    println("VRE-STOR LDS Subperiod Module")

    ### LOAD DATA ###

    VS_LDS = inputs["VS_LDS"]
    gen = inputs["RESOURCES"]
    gen_VRE_STOR = gen.VreStorage

    w = inputs["SubPeriod"];

	r = inputs["SubPeriod_Index"]

    REP_PERIOD = inputs["REP_PERIOD"]  # Number of representative periods
    dfPeriodMap = inputs["Period_Map"] # Dataframe that maps modeled periods to representative periods
    NPeriods = size(inputs["Period_Map"])[1] # Number of modeled periods
    hours_per_subperiod = inputs["hours_per_subperiod"] #total number of hours per subperiod
    MODELED_PERIODS_INDEX = 1:NPeriods
    REP_PERIODS_INDEX = MODELED_PERIODS_INDEX[dfPeriodMap[!, :Rep_Period] .== MODELED_PERIODS_INDEX]

    by_rid(rid, sym) = by_rid_res(rid, sym, gen_VRE_STOR)

    ### LDS VARIABLES ###
    @variables(EP, begin
        # State of charge of storage at beginning of the period r
        vSOCw_VRE_STOR[y in VS_LDS, [r]] >= 0

        # Build up in storage inventory over each representative period w (can be pos or neg)
        vdSOC_VRE_STOR[y in VS_LDS, [w]]
    end)

    @variable(EP, vVreStor_LDS_Start_slack[[w], y in VS_LDS])
    @variable(EP, vVreStor_LDS_Sub_slack[y in VS_LDS, [r]])
    @constraint(EP,cVreStor_SlackLDS_Start_Up[[w], y in VS_LDS],vVreStor_LDS_Start_slack[w,y] <= EP[:vVRE_STOR_LDS_SLACK_MAX][1])
	@constraint(EP,cVreStor_SlackLDS_Start_Lo[[w], y in VS_LDS],-vVreStor_LDS_Start_slack[w,y]<= EP[:vVRE_STOR_LDS_SLACK_MAX][1])
	@constraint(EP,cVreStor_SlackLDS_Sub_Up[y in VS_LDS, [r]],vVreStor_LDS_Sub_slack[y,r]<= EP[:vVRE_STOR_LDS_SLACK_MAX][1])
	@constraint(EP,cVreStor_SlackLDS_Sub_Lo[y in VS_LDS, [r]],-vVreStor_LDS_Sub_slack[y,r]<= EP[:vVRE_STOR_LDS_SLACK_MAX][1])

    ### EXPRESSIONS ###

    # Note: tw_min = hours_per_subperiod*(w-1)+1; tw_max = hours_per_subperiod*w
    @expression(EP, eVreStorSoCBalLongDurationStorageStart[y in VS_LDS, [w]],
        (1 -
         self_discharge(gen[y]))*(EP[:vS_VRE_STOR][y, hours_per_subperiod] -
                                  EP[:vdSOC_VRE_STOR][y, w]))

    DC_DISCHARGE_CONSTRAINTSET = intersect(inputs["VS_STOR_DC_DISCHARGE"], VS_LDS)
    DC_CHARGE_CONSTRAINTSET = intersect(inputs["VS_STOR_DC_CHARGE"], VS_LDS)
    AC_DISCHARGE_CONSTRAINTSET = intersect(inputs["VS_STOR_AC_DISCHARGE"], VS_LDS)
    AC_CHARGE_CONSTRAINTSET = intersect(inputs["VS_STOR_AC_CHARGE"], VS_LDS)

    for y in DC_DISCHARGE_CONSTRAINTSET
        add_to_expression!(EP[:eVreStorSoCBalLongDurationStorageStart][y, w],
            -1 / by_rid(y, :eff_down_dc), EP[:vP_DC_DISCHARGE][y, 1])
    end

    for y in DC_CHARGE_CONSTRAINTSET
        add_to_expression!(EP[:eVreStorSoCBalLongDurationStorageStart][y, w],
            by_rid(y, :eff_up_dc), EP[:vP_DC_CHARGE][y, 1])
    end

    for y in AC_DISCHARGE_CONSTRAINTSET
        add_to_expression!(EP[:eVreStorSoCBalLongDurationStorageStart][y, w],
            -1 / by_rid(y, :eff_down_ac), EP[:vP_AC_DISCHARGE][y, 1])
    end

    for y in AC_CHARGE_CONSTRAINTSET
        add_to_expression!(EP[:eVreStorSoCBalLongDurationStorageStart][y, w],
            by_rid(y, :eff_up_ac), EP[:vP_AC_CHARGE][y, 1])
    end

    ### CONSTRAINTS ### 

    # Constraint 1: Link the state of charge between the start of periods for LDS resources
    @constraint(EP, cVreStorSoCBalLongDurationStorageStart[y in VS_LDS, [w]],
        EP[:vS_VRE_STOR][y, 1]==EP[:eVreStorSoCBalLongDurationStorageStart][y, w] + vVreStor_LDS_Start_slack[w, y])

    # Constraint 2: Initial storage level for representative periods must also adhere to sub-period storage inventory balance
    # Initial storage = Final storage - change in storage inventory across representative period
    @constraint(EP,
        cVreStorSoCBalLongDurationStorageSub[y in VS_LDS, [r]],
        EP[:vSOCw_VRE_STOR][y,r]==EP[:vS_VRE_STOR][
            y, hours_per_subperiod]
                -
                EP[:vdSOC_VRE_STOR][y, dfPeriodMap[r, :Rep_Period_Index]] + vVreStor_LDS_Sub_slack[y, r])
end

@doc raw"""
    lds_vre_stor_planning!(EP::Model, inputs::Dict)

Planning-side LDS helper for VRE-STOR resources.

Creates inter-period SOC carryover variables and enforces recursion across modeled
periods:

```math
vSOCw_{y,r+1} = vSOCw_{y,r} + vdSOC_{y,f(r)}
```

with an upper bound by installed storage-energy capacity `eTotalCap_STOR`.
"""
function lds_vre_stor_planning!(EP::Model, inputs::Dict)
    println("VRE-STOR LDS Planning Module")

    ### LOAD DATA ###

    VS_LDS = inputs["VS_LDS"]
    gen = inputs["RESOURCES"]
    gen_VRE_STOR = gen.VreStorage

    REP_PERIOD = inputs["REP_PERIOD"]  # Number of representative periods
    dfPeriodMap = inputs["Period_Map"] # Dataframe that maps modeled periods to representative periods
    NPeriods = size(inputs["Period_Map"])[1] # Number of modeled periods
    hours_per_subperiod = inputs["hours_per_subperiod"] #total number of hours per subperiod
    MODELED_PERIODS_INDEX = 1:NPeriods
    REP_PERIODS_INDEX = MODELED_PERIODS_INDEX[dfPeriodMap[!, :Rep_Period] .== MODELED_PERIODS_INDEX]

    by_rid(rid, sym) = by_rid_res(rid, sym, gen_VRE_STOR)

    ### LDS VARIABLES ###

    @variables(EP, begin
        # State of charge of storage at beginning of each modeled period n
        vSOCw_VRE_STOR[y in VS_LDS, n in MODELED_PERIODS_INDEX] >= 0

        # Build up in storage inventory over each representative period w (can be pos or neg)
        vdSOC_VRE_STOR[y in VS_LDS, w = 1:REP_PERIOD]
    end)

    ### CONSTRAINTS ### 

    # Constraint 1: Storage at beginning of period w = storage at beginning of period w-1 + storage built up in period w (after n representative periods)
    # Multiply storage build up term from prior period with corresponding weight
    @constraint(EP,
        cVreStorSoCBalLongDurationStorage[y in VS_LDS, r in MODELED_PERIODS_INDEX],
        EP[:vSOCw_VRE_STOR][y,
            mod1(r + 1, NPeriods)]==EP[:vSOCw_VRE_STOR][y, r] +
                                    EP[:vdSOC_VRE_STOR][
            y, dfPeriodMap[r, :Rep_Period_Index]])

    # Constraint 2: Storage at beginning of each modeled period cannot exceed installed energy capacity
    @constraint(EP,
        cVreStorSoCBalLongDurationStorageUpper[y in VS_LDS, r in MODELED_PERIODS_INDEX],
        EP[:vSOCw_VRE_STOR][y, r]<=EP[:eTotalCap_STOR][y])
end


@doc raw"""
    vre_stor_capres!(EP::Model, inputs::Dict, setup::Dict)

Capacity-reserve-margin coupling for VRE-STOR operations.

Creates virtual CRM charge/discharge variables (`vCAPRES_*`) and reserve SOC
(`vCAPRES_VS_VRE_STOR`), enforces virtual SOC dynamics, and couples reserve SOC as a
lower bound on operational SOC.

Adds CRM terms into module expressions (`eGridExport`, `eInverterExport`,
`eSolarGenMaxS`, `eWindGenMaxW`, storage rate expressions) and contributes CRM capacity
terms to `eCapResMarBalance`.

When `StorageVirtualDischarge == 1`, it adds virtual charge/discharge penalty terms to
`eObj`. For LDS resources, dispatches to `lds_vre_stor_capres_subperiod!` in Benders
mode and `lds_vre_stor_capres!` otherwise.
"""
function vre_stor_capres!(EP::Model, inputs::Dict, setup::Dict)
    println("VRE-STOR Capacity Reserve Margin Module")

    ### LOAD DATA ###

    T = inputs["T"]
    gen = inputs["RESOURCES"]
    gen_VRE_STOR = gen.VreStorage
    STOR = inputs["VS_STOR"]
    DC_DISCHARGE = inputs["VS_STOR_DC_DISCHARGE"]
    DC_CHARGE = inputs["VS_STOR_DC_CHARGE"]
    AC_DISCHARGE = inputs["VS_STOR_AC_DISCHARGE"]
    AC_CHARGE = inputs["VS_STOR_AC_CHARGE"]
    VS_ASYM_DC_CHARGE = inputs["VS_ASYM_DC_CHARGE"]
    VS_ASYM_AC_CHARGE = inputs["VS_ASYM_AC_CHARGE"]
    VS_ASYM_DC_DISCHARGE = inputs["VS_ASYM_DC_DISCHARGE"]
    VS_ASYM_AC_DISCHARGE = inputs["VS_ASYM_AC_DISCHARGE"]
    VS_SYM_DC = inputs["VS_SYM_DC"]
    VS_SYM_AC = inputs["VS_SYM_AC"]
    VS_LDS = inputs["VS_LDS"]

    START_SUBPERIODS = inputs["START_SUBPERIODS"]
    INTERIOR_SUBPERIODS = inputs["INTERIOR_SUBPERIODS"]
    hours_per_subperiod = inputs["hours_per_subperiod"]     # total number of hours per subperiod
    rep_periods = inputs["REP_PERIOD"]

    virtual_discharge_cost = inputs["VirtualChargeDischargeCost"]
    StorageVirtualDischarge = setup["StorageVirtualDischarge"]

    by_rid(rid, sym) = by_rid_res(rid, sym, gen_VRE_STOR)

    ### VARIABLES ###

    @variables(EP, begin
        # Virtual DC discharge contributing to capacity reserves at timestep t for VRE-storage cluster y
        vCAPRES_DC_DISCHARGE[y in DC_DISCHARGE, t = 1:T] >= 0

        # Virtual AC discharge contributing to capacity reserves at timestep t for VRE-storage cluster y
        vCAPRES_AC_DISCHARGE[y in AC_DISCHARGE, t = 1:T] >= 0

        # Virtual DC charge contributing to capacity reserves at timestep t for VRE-storage cluster y
        vCAPRES_DC_CHARGE[y in DC_CHARGE, t = 1:T] >= 0

        # Virtual AC charge contributing to capacity reserves at timestep t for VRE-storage cluster y
        vCAPRES_AC_CHARGE[y in AC_CHARGE, t = 1:T] >= 0

        # Total state of charge being held in reserve at timestep t for VRE-storage cluster y
        vCAPRES_VS_VRE_STOR[y in STOR, t = 1:T] >= 0
    end)

    ### EXPRESSIONS ###

    # 1. Inverter & Power Balance, SoC Expressions

    # Check for rep_periods > 1 & LDS=1
    if (rep_periods > 1 || haskey(inputs, "SubPeriod_Index")) && !isempty(VS_LDS)
        CONSTRAINTSET = inputs["VS_nonLDS"]
    else
        CONSTRAINTSET = STOR
    end

    # Virtual State of Charge Expressions
    @expression(EP, eVreStorVSoCBalStart[y in CONSTRAINTSET, t in START_SUBPERIODS],
        EP[:vCAPRES_VS_VRE_STOR][y,
            t + hours_per_subperiod - 1]
        -self_discharge(gen[y]) * EP[:vCAPRES_VS_VRE_STOR][y, t + hours_per_subperiod - 1])
    @expression(EP, eVreStorVSoCBalInterior[y in STOR, t in INTERIOR_SUBPERIODS],
        EP[:vCAPRES_VS_VRE_STOR][y,
            t - 1]
        -self_discharge(gen[y]) * EP[:vCAPRES_VS_VRE_STOR][y, t - 1])

    DC_DISCHARGE_CONSTRAINTSET = intersect(CONSTRAINTSET, DC_DISCHARGE)
    DC_CHARGE_CONSTRAINTSET = intersect(CONSTRAINTSET, DC_CHARGE)
    AC_DISCHARGE_CONSTRAINTSET = intersect(CONSTRAINTSET, AC_DISCHARGE)
    AC_CHARGE_CONSTRAINTSET = intersect(CONSTRAINTSET, AC_CHARGE)
    for t in START_SUBPERIODS
        for y in DC_DISCHARGE_CONSTRAINTSET
            add_to_expression!(eVreStorVSoCBalStart[y, t], 1 / by_rid(y, :eff_down_dc), EP[:vCAPRES_DC_DISCHARGE][y, t])
        end
        for y in DC_CHARGE_CONSTRAINTSET
            add_to_expression!(eVreStorVSoCBalStart[y, t], -by_rid(y, :eff_up_dc), EP[:vCAPRES_DC_CHARGE][y, t])
        end
        for y in AC_DISCHARGE_CONSTRAINTSET
            add_to_expression!(eVreStorVSoCBalStart[y, t], 1 / by_rid(y, :eff_down_ac), EP[:vCAPRES_AC_DISCHARGE][y, t])
        end
        for y in AC_CHARGE_CONSTRAINTSET
            add_to_expression!(eVreStorVSoCBalStart[y, t], -by_rid(y, :eff_up_ac), EP[:vCAPRES_AC_CHARGE][y, t])
        end
    end

    for t in INTERIOR_SUBPERIODS
        for y in DC_DISCHARGE
            add_to_expression!(eVreStorVSoCBalInterior[y, t], 1 / by_rid(y, :eff_down_dc), EP[:vCAPRES_DC_DISCHARGE][y, t])
        end
        for y in DC_CHARGE
            add_to_expression!(eVreStorVSoCBalInterior[y, t], -by_rid(y, :eff_up_dc), EP[:vCAPRES_DC_CHARGE][y, t])
        end
        for y in AC_DISCHARGE
            add_to_expression!(eVreStorVSoCBalInterior[y, t], 1 / by_rid(y, :eff_down_ac), EP[:vCAPRES_AC_DISCHARGE][y, t])
        end
        for y in AC_CHARGE
            add_to_expression!(eVreStorVSoCBalInterior[y, t], -by_rid(y, :eff_up_ac), EP[:vCAPRES_AC_CHARGE][y, t])
        end
    end

    # Inverter & grid connection export additions
    for t in 1:T
        for y in DC_DISCHARGE
            add_to_expression!(EP[:eInverterExport][y, t], by_rid(y, :etainverter), vCAPRES_DC_DISCHARGE[y, t])
            add_to_expression!(EP[:eGridExport][y, t], by_rid(y, :etainverter), vCAPRES_DC_DISCHARGE[y, t])
        end
        for y in DC_CHARGE
            add_to_expression!(EP[:eInverterExport][y, t], 1 / by_rid(y, :etainverter), vCAPRES_DC_CHARGE[y, t])
            add_to_expression!(EP[:eGridExport][y, t], 1 / by_rid(y, :etainverter), vCAPRES_DC_CHARGE[y, t])
        end
        for y in AC_DISCHARGE
            add_to_expression!(EP[:eGridExport][y, t], vCAPRES_AC_DISCHARGE[y, t])
        end
        for y in AC_CHARGE
            add_to_expression!(EP[:eGridExport][y, t], vCAPRES_AC_CHARGE[y, t])
        end

        # Asymmetric and symmetric storage contributions
        for y in VS_ASYM_DC_DISCHARGE
            add_to_expression!(EP[:eVreStorMaxDischargingDC][y, t], vCAPRES_DC_DISCHARGE[y, t])
        end
        for y in VS_ASYM_AC_DISCHARGE
            add_to_expression!(EP[:eVreStorMaxDischargingAC][y, t], vCAPRES_AC_DISCHARGE[y, t])
        end
        for y in VS_ASYM_DC_CHARGE
            add_to_expression!(EP[:eVreStorMaxChargingDC][y, t], vCAPRES_DC_CHARGE[y, t])
        end
        for y in VS_ASYM_AC_CHARGE
            add_to_expression!(EP[:eVreStorMaxChargingAC][y, t], vCAPRES_AC_CHARGE[y, t])
        end
        for y in VS_SYM_DC
            add_to_expression!(EP[:eChargeDischargeMaxDC][y, t], vCAPRES_DC_DISCHARGE[y, t])
            add_to_expression!(EP[:eChargeDischargeMaxDC][y, t], vCAPRES_DC_CHARGE[y, t])
        end
        for y in VS_SYM_AC
            add_to_expression!(EP[:eChargeDischargeMaxAC][y, t], vCAPRES_AC_DISCHARGE[y, t])
            add_to_expression!(EP[:eChargeDischargeMaxAC][y, t], vCAPRES_AC_CHARGE[y, t])
        end
    end

    ### CONSTRAINTS ###
    # Constraint 1: Links energy held in reserve in first time step with decisions in last time step of each subperiod
    # We use a modified formulation of this constraint (cVSoCBalLongDurationStorageStart) when modeling multiple representative periods and long duration storage
    @constraint(EP, cVreStorVSoCBalStart[y in CONSTRAINTSET, t in START_SUBPERIODS],
        vCAPRES_VS_VRE_STOR[y, t]==eVreStorVSoCBalStart[y, t])
    # Energy held in reserve for the next hour
    @constraint(EP, cVreStorVSoCBalInterior[y in STOR, t in INTERIOR_SUBPERIODS],
        vCAPRES_VS_VRE_STOR[y, t]==eVreStorVSoCBalInterior[y, t])

    # Constraint 2: Energy held in reserve acts as a lower bound on the total energy held in storage
    @constraint(EP,
        cVreStorSOCMinCapRes[y in STOR, t = 1:T],
        EP[:vS_VRE_STOR][y, t]>=vCAPRES_VS_VRE_STOR[y, t])

    # Constraint 3: Add capacity reserve margin contributions from VRE-STOR resources to capacity reserve margin constraint
    nCRMZones = inputs["NCapacityReserveMargin"]
    capresfactor = inputs["DERATING_FACTOR"]
    @expression(EP,
        eCapResMarBalanceStor_VRE_STOR[res = 1:nCRMZones, t = 1:T],
        (sum(capresfactor[y, res] * by_rid(y, :etainverter) *
             inputs["pP_Max_Solar"][y, t] * EP[:eTotalCap_SOLAR][y]
         for y in inputs["VS_SOLAR"])
         +
         sum(capresfactor[y, res] * inputs["pP_Max_Wind"][y, t] *
             EP[:eTotalCap_WIND][y] for y in inputs["VS_WIND"])
         +
         sum(capresfactor[y, res] * by_rid(y, :etainverter) *
             (EP[:vP_DC_DISCHARGE][y, t]) for y in DC_DISCHARGE)
         +
         sum(capresfactor[y, res] * (EP[:vP_AC_DISCHARGE][y, t])
         for y in AC_DISCHARGE)
         -
         sum(capresfactor[y, res] * (EP[:vP_DC_CHARGE][y, t]) /
             by_rid(y, :etainverter)
        for y in DC_CHARGE)
        -sum(capresfactor[y, res] * (EP[:vP_AC_CHARGE][y, t])
        for y in AC_CHARGE)))
    if StorageVirtualDischarge > 0
        @expression(EP,
            eCapResMarBalanceStor_VRE_STOR_Virtual[
                res = 1:nCRMZones,
                t = 1:T],
            (sum(capresfactor[y, res] * by_rid(y, :etainverter) *
                 (vCAPRES_DC_DISCHARGE[y, t]) for y in DC_DISCHARGE)
             +
             sum(capresfactor[y, res] * (vCAPRES_AC_DISCHARGE[y, t])
            for y in AC_DISCHARGE)
             -
             sum(capresfactor[y, res] * (vCAPRES_DC_CHARGE[y, t]) /
                 by_rid(y, :etainverter)
            for y in DC_CHARGE)
            -sum(capresfactor[y, res] * (vCAPRES_AC_CHARGE[y, t])
            for y in AC_CHARGE)))
        add_similar_to_expression!(eCapResMarBalanceStor_VRE_STOR,
            eCapResMarBalanceStor_VRE_STOR_Virtual)
    end
    add_similar_to_expression!(EP[:eCapResMarBalance], EP[:eCapResMarBalanceStor_VRE_STOR])

    ### OBJECTIVE FUNCTION ADDITIONS ###

    #Variable costs of DC "virtual charging" for technologies "y" during hour "t" in zone "z"
    @expression(EP, eCVar_Charge_DC_virtual[y in DC_CHARGE, t = 1:T],
        inputs["omega"][t] * virtual_discharge_cost *
        vCAPRES_DC_CHARGE[y, t]/by_rid(y, :etainverter))
    @expression(EP,
        eTotalCVar_Charge_DC_T_virtual[t = 1:T],
        sum(eCVar_Charge_DC_virtual[y, t] for y in DC_CHARGE))
    @expression(EP,
        eTotalCVar_Charge_DC_virtual,
        sum(eTotalCVar_Charge_DC_T_virtual[t] for t in 1:T))
    add_to_expression!(EP[:eObj], eTotalCVar_Charge_DC_virtual)

    #Variable costs of DC "virtual discharging" for technologies "y" during hour "t" in zone "z"
    @expression(EP, eCVar_Discharge_DC_virtual[y in DC_DISCHARGE, t = 1:T],
        inputs["omega"][t]*virtual_discharge_cost*by_rid(y, :etainverter)*
        vCAPRES_DC_DISCHARGE[y, t])
    @expression(EP,
        eTotalCVar_Discharge_DC_T_virtual[t = 1:T],
        sum(eCVar_Discharge_DC_virtual[y, t] for y in DC_DISCHARGE))
    @expression(EP,
        eTotalCVar_Discharge_DC_virtual,
        sum(eTotalCVar_Discharge_DC_T_virtual[t] for t in 1:T))
    add_to_expression!(EP[:eObj], eTotalCVar_Discharge_DC_virtual)

    #Variable costs of AC "virtual charging" for technologies "y" during hour "t" in zone "z"
    @expression(EP, eCVar_Charge_AC_virtual[y in AC_CHARGE, t = 1:T],
        inputs["omega"][t]*virtual_discharge_cost*vCAPRES_AC_CHARGE[y, t])
    @expression(EP,
        eTotalCVar_Charge_AC_T_virtual[t = 1:T],
        sum(eCVar_Charge_AC_virtual[y, t] for y in AC_CHARGE))
    @expression(EP,
        eTotalCVar_Charge_AC_virtual,
        sum(eTotalCVar_Charge_AC_T_virtual[t] for t in 1:T))
    add_to_expression!(EP[:eObj], eTotalCVar_Charge_AC_virtual)

    #Variable costs of AC "virtual discharging" for technologies "y" during hour "t" in zone "z"
    @expression(EP, eCVar_Discharge_AC_virtual[y in AC_DISCHARGE, t = 1:T],
        inputs["omega"][t]*virtual_discharge_cost*vCAPRES_AC_DISCHARGE[y, t])
    @expression(EP,
        eTotalCVar_Discharge_AC_T_virtual[t = 1:T],
        sum(eCVar_Discharge_AC_virtual[y, t] for y in AC_DISCHARGE))
    @expression(EP,
        eTotalCVar_Discharge_AC_virtual,
        sum(eTotalCVar_Discharge_AC_T_virtual[t] for t in 1:T))
    add_to_expression!(EP[:eObj], eTotalCVar_Discharge_AC_virtual)

    ### LONG DURATION ENERGY STORAGE CAPACITY RESERVE MARGIN MODULE ###
    if (rep_periods > 1 || haskey(inputs, "SubPeriod_Index")) && !isempty(VS_LDS)
        if setup["Benders"] == 1
            lds_vre_stor_capres_subperiod!(EP, inputs)
        else
            lds_vre_stor_capres!(EP, inputs)
        end
    end
end


@doc raw"""
    lds_vre_stor_capres!(EP::Model, inputs::Dict)

Non-Benders LDS CRM linkage for VRE-STOR resources.

Creates inter-period reserve-SOC variables and constraints linking reserve SOC across
representative periods, plus lower-bound coupling with `vSOCw_VRE_STOR`.
"""
function lds_vre_stor_capres!(EP::Model, inputs::Dict)
    ### LOAD DATA ###

    REP_PERIOD = inputs["REP_PERIOD"]  # Number of representative periods
    dfPeriodMap = inputs["Period_Map"] # Dataframe that maps modeled periods to representative periods
    NPeriods = size(inputs["Period_Map"])[1] # Number of modeled periods
    MODELED_PERIODS_INDEX = 1:NPeriods
    REP_PERIODS_INDEX = MODELED_PERIODS_INDEX[dfPeriodMap[!, :Rep_Period] .== MODELED_PERIODS_INDEX]
    NON_REP_PERIODS_INDEX = setdiff(MODELED_PERIODS_INDEX, REP_PERIODS_INDEX)

    T = inputs["T"]
    gen = inputs["RESOURCES"]
    gen_VRE_STOR = gen.VreStorage
    STOR = inputs["VS_STOR"]
    DC_DISCHARGE = inputs["VS_STOR_DC_DISCHARGE"]
    DC_CHARGE = inputs["VS_STOR_DC_CHARGE"]
    AC_DISCHARGE = inputs["VS_STOR_AC_DISCHARGE"]
    AC_CHARGE = inputs["VS_STOR_AC_CHARGE"]
    VS_ASYM_DC_CHARGE = inputs["VS_ASYM_DC_CHARGE"]
    VS_ASYM_AC_CHARGE = inputs["VS_ASYM_AC_CHARGE"]
    VS_ASYM_DC_DISCHARGE = inputs["VS_ASYM_DC_DISCHARGE"]
    VS_ASYM_AC_DISCHARGE = inputs["VS_ASYM_AC_DISCHARGE"]
    VS_SYM_DC = inputs["VS_SYM_DC"]
    VS_SYM_AC = inputs["VS_SYM_AC"]
    VS_LDS = inputs["VS_LDS"]

    START_SUBPERIODS = inputs["START_SUBPERIODS"]
    INTERIOR_SUBPERIODS = inputs["INTERIOR_SUBPERIODS"]
    hours_per_subperiod = inputs["hours_per_subperiod"]     # total number of hours per subperiod

    virtual_discharge_cost = inputs["VirtualChargeDischargeCost"]
    
    by_rid(rid, sym) = by_rid_res(rid, sym, gen_VRE_STOR)

    ### VARIABLES ###

    @variables(EP,
        begin
            # State of charge held in reserve for storage at beginning of each modeled period n
            vCAPCONTRSTOR_VSOCw_VRE_STOR[y in VS_LDS, n in MODELED_PERIODS_INDEX] >= 0

            # Build up in storage inventory held in reserve over each representative period w (can be pos or neg)
            vCAPCONTRSTOR_VdSOC_VRE_STOR[y in VS_LDS, w = 1:REP_PERIOD]
        end)

    @variable(EP, vVRESTOR_CAPRES_LDS_Start_slack[w = 1:REP_PERIOD, y in VS_LDS])
    @variable(EP, vVRESTOR_CAPRES_LDS_Sub_slack[y in VS_LDS, r in REP_PERIODS_INDEX])
    @constraint(EP,cVRESTOR_CAPRES_SlackLDS_Start_Up[w = 1:REP_PERIOD, y in VS_LDS],vVRESTOR_CAPRES_LDS_Start_slack[w,y] <= EP[:vVRE_STOR_LDS_SLACK_MAX][1])
    @constraint(EP,cVRESTOR_CAPRES_SlackLDS_Start_Lo[w = 1:REP_PERIOD, y in VS_LDS],-vVRESTOR_CAPRES_LDS_Start_slack[w,y]<= EP[:vVRE_STOR_LDS_SLACK_MAX][1])
    @constraint(EP,cVRESTOR_CAPRES_SlackLDS_Sub_Up[y in VS_LDS, r in REP_PERIODS_INDEX],vVRESTOR_CAPRES_LDS_Sub_slack[y,r]<= EP[:vVRE_STOR_LDS_SLACK_MAX][1])
    @constraint(EP,cVRESTOR_CAPRES_SlackLDS_Sub_Lo[y in VS_LDS, r in REP_PERIODS_INDEX],-vVRESTOR_CAPRES_LDS_Sub_slack[y,r]<= EP[:vVRE_STOR_LDS_SLACK_MAX][1])

    ### EXPRESSIONS ###

    @expression(EP,
        eVreStorVSoCBalLongDurationStorageStart[y in VS_LDS, w = 1:REP_PERIOD],
        (1 -
            self_discharge(gen[y]))*(EP[:vCAPRES_VS_VRE_STOR][y, hours_per_subperiod * w] -
                                    vCAPCONTRSTOR_VdSOC_VRE_STOR[y, w]))

    DC_DISCHARGE_CONSTRAINTSET = intersect(DC_DISCHARGE, VS_LDS)
    DC_CHARGE_CONSTRAINTSET = intersect(DC_CHARGE, VS_LDS)
    AC_DISCHARGE_CONSTRAINTSET = intersect(AC_DISCHARGE, VS_LDS)
    AC_CHARGE_CONSTRAINTSET = intersect(AC_CHARGE, VS_LDS)
    for w in 1:REP_PERIOD
        for y in DC_DISCHARGE_CONSTRAINTSET
            add_to_expression!(eVreStorVSoCBalLongDurationStorageStart[y, w],
                1 / by_rid(y, :eff_down_dc), EP[:vCAPRES_DC_DISCHARGE][y, hours_per_subperiod * (w - 1) + 1])
        end
        for y in DC_CHARGE_CONSTRAINTSET
            add_to_expression!(eVreStorVSoCBalLongDurationStorageStart[y, w], -by_rid(y, :eff_up_dc),
                EP[:vCAPRES_DC_CHARGE][y, hours_per_subperiod * (w - 1) + 1])
        end
        for y in AC_DISCHARGE_CONSTRAINTSET
            add_to_expression!(eVreStorVSoCBalLongDurationStorageStart[y, w],
                1 / by_rid(y, :eff_down_ac), EP[:vCAPRES_AC_DISCHARGE][y, hours_per_subperiod * (w - 1) + 1])
        end
        for y in AC_CHARGE_CONSTRAINTSET
            add_to_expression!(eVreStorVSoCBalLongDurationStorageStart[y, w], -by_rid(y, :eff_up_ac),
                EP[:vCAPRES_AC_CHARGE][y, hours_per_subperiod * (w - 1) + 1])
        end
    end

    ### CONSTRAINTS ###

    # # Additional constraints to prevent violation of SoC limits in non-representative periods
    # if setup["LDSAdditionalConstraints"] == 1 && !isempty(NON_REP_PERIODS_INDEX)
    #     # Maximum positive storage inventory change within subperiod
    #     @variable(EP, vCAPCONTRSTOR_VSOCw_VRE_STOR[y in VS_LDS, w=1:REP_PERIOD] >= 0)

    #     # Maximum negative storage inventory change within subperiod
    #     @variable(EP, vCAPCONTRSTOR_VdSOC_VRE_STOR[y in VS_LDS, w=1:REP_PERIOD] <= 0)
    # end


    # Constraint 1: Links last time step with first time step, ensuring position in hour 1 is within eligible change from final hour position
    # Modified initial virtual state of storage for long duration storage - initialize wth value carried over from last period
    # Alternative to cVSoCBalStart constraint which is included when modeling multiple representative periods and long duration storage
    # Note: tw_min = hours_per_subperiod*(w-1)+1; tw_max = hours_per_subperiod*w
    @constraint(EP,
        cVreStorVSoCBalLongDurationStorageStart[y in VS_LDS, w = 1:REP_PERIOD],
        EP[:vCAPRES_VS_VRE_STOR][y,
            hours_per_subperiod * (w - 1) + 1]==eVreStorVSoCBalLongDurationStorageStart[y, w] + vVRESTOR_CAPRES_LDS_Start_slack[w, y])

    # Constraint 2: Storage held in reserve at beginning of period w = storage at beginning of period w-1 + storage built up in period w (after n representative periods)
    # Multiply storage build up term from prior period with corresponding weight
    @constraint(EP,
        cVreStorVSoCBalLongDurationStorage[y in VS_LDS, r in MODELED_PERIODS_INDEX],
        vCAPCONTRSTOR_VSOCw_VRE_STOR[y,
            mod1(r + 1, NPeriods)]==vCAPCONTRSTOR_VSOCw_VRE_STOR[y, r] +
                                    vCAPCONTRSTOR_VdSOC_VRE_STOR[
            y, dfPeriodMap[r, :Rep_Period_Index]])

    # Constraint 3: Initial reserve storage level for representative periods must also adhere to sub-period storage inventory balance
    # Initial storage = Final storage - change in storage inventory across representative period
    @constraint(EP,
        cVreStorVSoCBalLongDurationStorageSub[y in VS_LDS, r in REP_PERIODS_INDEX],
        vCAPCONTRSTOR_VSOCw_VRE_STOR[y,r]==EP[:vCAPRES_VS_VRE_STOR][y,
            hours_per_subperiod * dfPeriodMap[r, :Rep_Period_Index]] -
                vCAPCONTRSTOR_VdSOC_VRE_STOR[y, dfPeriodMap[r, :Rep_Period_Index]] + vVRESTOR_CAPRES_LDS_Sub_slack[y, r])

    # Constraint 4: Energy held in reserve at the beginning of each modeled period acts as a lower bound on the total energy held in storage
    @constraint(EP,
        cSOCMinCapResLongDurationStorage[y in VS_LDS, r in MODELED_PERIODS_INDEX],
        EP[:vSOCw_VRE_STOR][y, r]>=vCAPCONTRSTOR_VSOCw_VRE_STOR[y, r])
end

@doc raw"""
    lds_vre_stor_capres_subperiod!(EP::Model, inputs::Dict)

Benders subproblem LDS CRM linkage for VRE-STOR resources.

Builds reserve-SOC start/end linking constraints for the active subperiod and includes
bounded slack variables used to preserve decomposition feasibility.
"""
function lds_vre_stor_capres_subperiod!(EP::Model, inputs::Dict)
    println("VRE-STOR LDS Subperiod Capacity Reserve Margin Module")
    ### LOAD DATA ###
    w = inputs["SubPeriod"];
	r = inputs["SubPeriod_Index"]

    REP_PERIOD = inputs["REP_PERIOD"]  # Number of representative periods
    dfPeriodMap = inputs["Period_Map"] # Dataframe that maps modeled periods to representative periods
    NPeriods = size(inputs["Period_Map"])[1] # Number of modeled periods
    MODELED_PERIODS_INDEX = 1:NPeriods

    T = inputs["T"]
    gen = inputs["RESOURCES"]
    gen_VRE_STOR = gen.VreStorage
    STOR = inputs["VS_STOR"]
    DC_DISCHARGE = inputs["VS_STOR_DC_DISCHARGE"]
    DC_CHARGE = inputs["VS_STOR_DC_CHARGE"]
    AC_DISCHARGE = inputs["VS_STOR_AC_DISCHARGE"]
    AC_CHARGE = inputs["VS_STOR_AC_CHARGE"]
    VS_ASYM_DC_CHARGE = inputs["VS_ASYM_DC_CHARGE"]
    VS_ASYM_AC_CHARGE = inputs["VS_ASYM_AC_CHARGE"]
    VS_ASYM_DC_DISCHARGE = inputs["VS_ASYM_DC_DISCHARGE"]
    VS_ASYM_AC_DISCHARGE = inputs["VS_ASYM_AC_DISCHARGE"]
    VS_SYM_DC = inputs["VS_SYM_DC"]
    VS_SYM_AC = inputs["VS_SYM_AC"]
    VS_LDS = inputs["VS_LDS"]

    START_SUBPERIODS = inputs["START_SUBPERIODS"]
    INTERIOR_SUBPERIODS = inputs["INTERIOR_SUBPERIODS"]
    hours_per_subperiod = inputs["hours_per_subperiod"]     # total number of hours per subperiod

    virtual_discharge_cost = inputs["VirtualChargeDischargeCost"]

    by_rid(rid, sym) = by_rid_res(rid, sym, gen_VRE_STOR)

    ### VARIABLES ###
    @variables(EP,
        begin
            # State of charge held in reserve for storage at beginning of each modeled period n
            vCAPCONTRSTOR_VSOCw_VRE_STOR[y in VS_LDS, [r]] >= 0

            # Build up in storage inventory held in reserve over each representative period w (can be pos or neg)
            vCAPCONTRSTOR_VdSOC_VRE_STOR[y in VS_LDS, [w]]
        end)

    @variable(EP, vVRESTOR_CAPRES_LDS_Start_slack[[w], y in VS_LDS])
    @variable(EP, vVRESTOR_CAPRES_LDS_Sub_slack[y in VS_LDS,[r]])
    @constraint(EP,cVRESTOR_CAPRES_SlackLDS_Start_Up[[w], y in VS_LDS],vVRESTOR_CAPRES_LDS_Start_slack[w,y] <= EP[:vVRE_STOR_LDS_SLACK_MAX][1])
    @constraint(EP,cVRESTOR_CAPRES_SlackLDS_Start_Lo[[w], y in VS_LDS],-vVRESTOR_CAPRES_LDS_Start_slack[w,y]<= EP[:vVRE_STOR_LDS_SLACK_MAX][1])
    @constraint(EP,cVRESTOR_CAPRES_SlackLDS_Sub_Up[y in VS_LDS, [r]],vVRESTOR_CAPRES_LDS_Sub_slack[y,r]<= EP[:vVRE_STOR_LDS_SLACK_MAX][1])
    @constraint(EP,cVRESTOR_CAPRES_SlackLDS_Sub_Lo[y in VS_LDS, [r]],-vVRESTOR_CAPRES_LDS_Sub_slack[y,r]<= EP[:vVRE_STOR_LDS_SLACK_MAX][1])
    ### EXPRESSIONS ###

    @expression(EP,
        eVreStorVSoCBalLongDurationStorageStart[y in VS_LDS, [w]],
        (1 -
            self_discharge(gen[y]))*(EP[:vCAPRES_VS_VRE_STOR][y, hours_per_subperiod] -
                                    vCAPCONTRSTOR_VdSOC_VRE_STOR[y, w]))

    DC_DISCHARGE_CONSTRAINTSET = intersect(DC_DISCHARGE, VS_LDS)
    DC_CHARGE_CONSTRAINTSET = intersect(DC_CHARGE, VS_LDS)
    AC_DISCHARGE_CONSTRAINTSET = intersect(AC_DISCHARGE, VS_LDS)
    AC_CHARGE_CONSTRAINTSET = intersect(AC_CHARGE, VS_LDS)
    for y in DC_DISCHARGE_CONSTRAINTSET
        add_to_expression!(eVreStorVSoCBalLongDurationStorageStart[y, w],
            1 / by_rid(y, :eff_down_dc), EP[:vCAPRES_DC_DISCHARGE][y, 1])
    end
    for y in DC_CHARGE_CONSTRAINTSET
        add_to_expression!(eVreStorVSoCBalLongDurationStorageStart[y, w], -by_rid(y, :eff_up_dc),
            EP[:vCAPRES_DC_CHARGE][y, 1])
    end
    for y in AC_DISCHARGE_CONSTRAINTSET
        add_to_expression!(eVreStorVSoCBalLongDurationStorageStart[y, w],
            1 / by_rid(y, :eff_down_ac), EP[:vCAPRES_AC_DISCHARGE][y, 1])
    end
    for y in AC_CHARGE_CONSTRAINTSET
        add_to_expression!(eVreStorVSoCBalLongDurationStorageStart[y, w], -by_rid(y, :eff_up_ac),
            EP[:vCAPRES_AC_CHARGE][y, 1])
    end

    ### CONSTRAINTS ###

    # Constraint 1: Links last time step with first time step, ensuring position in hour 1 is within eligible change from final hour position
    # Modified initial virtual state of storage for long duration storage - initialize wth value carried over from last period
    # Alternative to cVSoCBalStart constraint which is included when modeling multiple representative periods and long duration storage
    # Note: tw_min = hours_per_subperiod*(w-1)+1; tw_max = hours_per_subperiod*w
    @constraint(EP,
        cVreStorVSoCBalLongDurationStorageStart[y in VS_LDS, [w]],
        EP[:vCAPRES_VS_VRE_STOR][y, 1]==eVreStorVSoCBalLongDurationStorageStart[y, w] + vVRESTOR_CAPRES_LDS_Start_slack[w, y])

    # Constraint 2: Initial reserve storage level for representative periods must also adhere to sub-period storage inventory balance
    # Initial storage = Final storage - change in storage inventory across representative period
    @constraint(EP,
        cVreStorVSoCBalLongDurationStorageSub[y in VS_LDS, [r]],
        vCAPCONTRSTOR_VSOCw_VRE_STOR[y,r]==EP[:vCAPRES_VS_VRE_STOR][y,
            hours_per_subperiod] -
                vCAPCONTRSTOR_VdSOC_VRE_STOR[y, w] + vVRESTOR_CAPRES_LDS_Sub_slack[y, r])
end

@doc raw"""
    lds_vre_stor_capres_planning!(EP::Model, inputs::Dict)

Planning-side LDS CRM linkage for VRE-STOR resources.

Creates reserve-SOC carryover variables and enforces inter-period recursion and
lower-bound coupling to planning SOC:

```math
vCAPCONTRSTOR\_VSOCw_{y,r+1} = vCAPCONTRSTOR\_VSOCw_{y,r} + vCAPCONTRSTOR\_VdSOC_{y,f(r)}
```

```math
vSOCw\_VRE\_STOR_{y,r} \ge vCAPCONTRSTOR\_VSOCw\_VRE\_STOR_{y,r}
```
"""
function lds_vre_stor_capres_planning!(EP::Model, inputs::Dict)
    ### LOAD DATA ###

    REP_PERIOD = inputs["REP_PERIOD"]  # Number of representative periods
    dfPeriodMap = inputs["Period_Map"] # Dataframe that maps modeled periods to representative periods
    NPeriods = size(inputs["Period_Map"])[1] # Number of modeled periods
    MODELED_PERIODS_INDEX = 1:NPeriods
    REP_PERIODS_INDEX = MODELED_PERIODS_INDEX[dfPeriodMap[!, :Rep_Period] .== MODELED_PERIODS_INDEX]

    T = inputs["T"]
    gen = inputs["RESOURCES"]
    gen_VRE_STOR = gen.VreStorage
    STOR = inputs["VS_STOR"]
    DC_DISCHARGE = inputs["VS_STOR_DC_DISCHARGE"]
    DC_CHARGE = inputs["VS_STOR_DC_CHARGE"]
    AC_DISCHARGE = inputs["VS_STOR_AC_DISCHARGE"]
    AC_CHARGE = inputs["VS_STOR_AC_CHARGE"]
    VS_ASYM_DC_CHARGE = inputs["VS_ASYM_DC_CHARGE"]
    VS_ASYM_AC_CHARGE = inputs["VS_ASYM_AC_CHARGE"]
    VS_ASYM_DC_DISCHARGE = inputs["VS_ASYM_DC_DISCHARGE"]
    VS_ASYM_AC_DISCHARGE = inputs["VS_ASYM_AC_DISCHARGE"]
    VS_SYM_DC = inputs["VS_SYM_DC"]
    VS_SYM_AC = inputs["VS_SYM_AC"]
    VS_LDS = inputs["VS_LDS"]

    START_SUBPERIODS = inputs["START_SUBPERIODS"]
    INTERIOR_SUBPERIODS = inputs["INTERIOR_SUBPERIODS"]
    hours_per_subperiod = inputs["hours_per_subperiod"]     # total number of hours per subperiod

    virtual_discharge_cost = inputs["VirtualChargeDischargeCost"]

    ### VARIABLES ###

    @variables(EP,
        begin
            # State of charge held in reserve for storage at beginning of each modeled period n
            vCAPCONTRSTOR_VSOCw_VRE_STOR[y in VS_LDS, n in MODELED_PERIODS_INDEX] >= 0

            # Build up in storage inventory held in reserve over each representative period w (can be pos or neg)
            vCAPCONTRSTOR_VdSOC_VRE_STOR[y in VS_LDS, w = 1:REP_PERIOD]
        end)

    ### CONSTRAINTS ###

    # Constraint 1: Storage held in reserve at beginning of period w = storage at beginning of period w-1 + storage built up in period w (after n representative periods)
    # Multiply storage build up term from prior period with corresponding weight
    @constraint(EP,
        cVreStorVSoCBalLongDurationStorage[y in VS_LDS, r in MODELED_PERIODS_INDEX],
        vCAPCONTRSTOR_VSOCw_VRE_STOR[y,
            mod1(r + 1, NPeriods)]==vCAPCONTRSTOR_VSOCw_VRE_STOR[y, r] +
                                    vCAPCONTRSTOR_VdSOC_VRE_STOR[
            y, dfPeriodMap[r, :Rep_Period_Index]])

    # Constraint 2: Energy held in reserve at the beginning of each modeled period acts as a lower bound on the total energy held in storage
    @constraint(EP,
        cSOCMinCapResLongDurationStorage[y in VS_LDS, r in MODELED_PERIODS_INDEX],
        EP[:vSOCw_VRE_STOR][y, r]>=vCAPCONTRSTOR_VSOCw_VRE_STOR[y, r])
end

@doc raw"""
    vre_stor_operational_reserves!(EP::Model, inputs::Dict, setup::Dict)

Operational reserve coupling for VRE-STOR resources.

Creates technology-channel reserve variables for solar, wind, and storage charge/
discharge modes, links them to resource-level `vREG`/`vRSV`, and enforces reserve
share limits against installed grid capacity:

```math
vREG_{y,t} \le reg\_max_y\,eTotalCap_y,
\qquad
vRSV_{y,t} \le rsv\_max_y\,eTotalCap_y
```

Adds reserve terms into module expressions and enforces storage energy-feasibility
constraints (charge headroom and discharge energy availability), including CRM virtual
terms when CRM is enabled.
"""
function vre_stor_operational_reserves!(EP::Model, inputs::Dict, setup::Dict)
    println("VRE-STOR Operational Reserves Module")

    ### LOAD DATA & CREATE SETS ###

    gen = inputs["RESOURCES"]
    gen_VRE_STOR = gen.VreStorage

    T = inputs["T"]
    VRE_STOR = inputs["VRE_STOR"]
    STOR = inputs["VS_STOR"]
    DC_DISCHARGE = inputs["VS_STOR_DC_DISCHARGE"]
    DC_CHARGE = inputs["VS_STOR_DC_CHARGE"]
    AC_DISCHARGE = inputs["VS_STOR_AC_DISCHARGE"]
    AC_CHARGE = inputs["VS_STOR_AC_CHARGE"]
    SOLAR = inputs["VS_SOLAR"]
    WIND = inputs["VS_WIND"]
    VS_ASYM_DC_CHARGE = inputs["VS_ASYM_DC_CHARGE"]
    VS_ASYM_AC_CHARGE = inputs["VS_ASYM_AC_CHARGE"]
    VS_ASYM_DC_DISCHARGE = inputs["VS_ASYM_DC_DISCHARGE"]
    VS_ASYM_AC_DISCHARGE = inputs["VS_ASYM_AC_DISCHARGE"]
    VS_SYM_DC = inputs["VS_SYM_DC"]
    VS_SYM_AC = inputs["VS_SYM_AC"]

    p = inputs["hours_per_subperiod"]

    CapacityReserveMargin = setup["CapacityReserveMargin"]

    VRE_STOR_REG_RSV = intersect(VRE_STOR, inputs["REG"], inputs["RSV"])                    # Set of VRE-STOR resources with both REG and RSV reserves
    VRE_STOR_REG = intersect(VRE_STOR, inputs["REG"])                                       # Set of VRE-STOR resources with REG reserves
    VRE_STOR_RSV = intersect(VRE_STOR, inputs["RSV"])                                       # Set of VRE-STOR resources with RSV reserves
    VRE_STOR_REG_ONLY = setdiff(VRE_STOR_REG, VRE_STOR_RSV)                                 # Set of VRE-STOR resources only with REG reserves
    VRE_STOR_RSV_ONLY = setdiff(VRE_STOR_RSV, VRE_STOR_REG)                                 # Set of VRE-STOR resources only with RSV reserves

    SOLAR_REG = intersect(SOLAR, inputs["REG"])                                             # Set of solar resources with REG reserves
    SOLAR_RSV = intersect(SOLAR, inputs["RSV"])                                             # Set of solar resources with RSV reserves
    WIND_REG = intersect(WIND, inputs["REG"])                                               # Set of wind resources with REG reserves
    WIND_RSV = intersect(WIND, inputs["RSV"])                                               # Set of wind resources with RSV reserves

    STOR_REG = intersect(STOR, inputs["REG"])                                               # Set of storage resources with REG reserves
    STOR_RSV = intersect(STOR, inputs["RSV"])                                               # Set of storage resources with RSV reserves
    STOR_REG_RSV_UNION = union(STOR_REG, STOR_RSV)                                          # Set of storage resources with either or both REG and RSV reserves
    DC_DISCHARGE_REG = intersect(DC_DISCHARGE, STOR_REG)                                    # Set of DC discharge resources with REG reserves
    DC_DISCHARGE_RSV = intersect(DC_DISCHARGE, STOR_RSV)                                    # Set of DC discharge resources with RSV reserves
    AC_DISCHARGE_REG = intersect(AC_DISCHARGE, STOR_REG)                                    # Set of AC discharge resources with REG reserves
    AC_DISCHARGE_RSV = intersect(AC_DISCHARGE, STOR_RSV)                                    # Set of AC discharge resources with RSV reserves
    DC_CHARGE_REG = intersect(DC_CHARGE, STOR_REG)                                          # Set of DC charge resources with REG reserves
    DC_CHARGE_RSV = intersect(DC_CHARGE, STOR_RSV)                                          # Set of DC charge resources with RSV reserves
    AC_CHARGE_REG = intersect(AC_CHARGE, STOR_REG)                                          # Set of AC charge resources with REG reserves
    AC_CHARGE_RSV = intersect(AC_CHARGE, STOR_RSV)                                          # Set of AC charge resources with RSV reserves
    VS_ASYM_DC_DISCHARGE_REG = intersect(VS_ASYM_DC_DISCHARGE, STOR_REG)                    # Set of asymmetric DC discharge resources with REG reserves
    VS_ASYM_DC_DISCHARGE_RSV = intersect(VS_ASYM_DC_DISCHARGE, STOR_RSV)                    # Set of asymmetric DC discharge resources with RSV reserves
    VS_ASYM_DC_CHARGE_REG = intersect(VS_ASYM_DC_CHARGE, STOR_REG)                          # Set of asymmetric DC charge resources with REG reserves
    VS_ASYM_AC_DISCHARGE_REG = intersect(VS_ASYM_AC_DISCHARGE, STOR_REG)                    # Set of asymmetric AC discharge resources with REG reserves
    VS_ASYM_AC_DISCHARGE_RSV = intersect(VS_ASYM_AC_DISCHARGE, STOR_RSV)                    # Set of asymmetric AC discharge resources with RSV reserves
    VS_ASYM_AC_CHARGE_REG = intersect(VS_ASYM_AC_CHARGE, STOR_REG)                          # Set of asymmetric AC charge resources with REG reserves
    VS_SYM_DC_REG = intersect(VS_SYM_DC, STOR_REG)                                          # Set of symmetric DC resources with REG reserves
    VS_SYM_DC_RSV = intersect(VS_SYM_DC, STOR_RSV)                                          # Set of symmetric DC resources with RSV reserves
    VS_SYM_AC_REG = intersect(VS_SYM_AC, STOR_REG)                                          # Set of symmetric AC resources with REG reserves
    VS_SYM_AC_RSV = intersect(VS_SYM_AC, STOR_RSV)                                          # Set of symmetric AC resources with RSV reserves

    by_rid(rid, sym) = by_rid_res(rid, sym, gen_VRE_STOR)

    ### VARIABLES ###

    @variables(EP, begin
        # Contribution to regulation (primary reserves), assumed to be symmetric (up & down directions equal)
        vREG_SOLAR[y in SOLAR_REG, t = 1:T] >= 0
        vREG_WIND[y in WIND_REG, t = 1:T] >= 0
        vREG_DC_Discharge[y in DC_DISCHARGE_REG, t = 1:T] >= 0
        vREG_DC_Charge[y in DC_CHARGE_REG, t = 1:T] >= 0
        vREG_AC_Discharge[y in AC_DISCHARGE_REG, t = 1:T] >= 0
        vREG_AC_Charge[y in AC_CHARGE_REG, t = 1:T] >= 0

        # Contribution to operating reserves (secondary reserves or contingency reserves); only model upward reserve requirements
        vRSV_SOLAR[y in SOLAR_RSV, t = 1:T] >= 0
        vRSV_WIND[y in WIND_RSV, t = 1:T] >= 0
        vRSV_DC_Discharge[y in DC_DISCHARGE_RSV, t = 1:T] >= 0
        vRSV_DC_Charge[y in DC_CHARGE_RSV, t = 1:T] >= 0
        vRSV_AC_Discharge[y in AC_DISCHARGE_RSV, t = 1:T] >= 0
        vRSV_AC_Charge[y in AC_CHARGE_RSV, t = 1:T] >= 0
    end)

    ### EXPRESSIONS ###

    @expression(EP, eVreStorRegOnlyBalance[y in VRE_STOR_REG, t = 1:T], JuMP.AffExpr())
    @expression(EP, eVreStorRsvOnlyBalance[y in VRE_STOR_RSV, t = 1:T], JuMP.AffExpr())
    @expression(EP, eDischargeDCMin[y in DC_DISCHARGE, t = 1:T], JuMP.AffExpr())
    @expression(EP, eChargeDCMin[y in DC_CHARGE, t = 1:T], JuMP.AffExpr())
    @expression(EP, eDischargeACMin[y in AC_DISCHARGE, t = 1:T], JuMP.AffExpr())
    @expression(EP, eChargeACMin[y in AC_CHARGE, t = 1:T], JuMP.AffExpr())
    @expression(EP, eChargeMax[y in STOR_REG_RSV_UNION, t = 1:T], JuMP.AffExpr())
    @expression(EP, eDischargeMax[y in STOR_REG_RSV_UNION, t = 1:T], JuMP.AffExpr())

    for t in 1:T
        for y in DC_DISCHARGE
            add_to_expression!(eDischargeDCMin[y, t], EP[:vP_DC_DISCHARGE][y, t])
            add_to_expression!(eDischargeMax[y, t], 1 / by_rid(y, :eff_down_dc), EP[:vP_DC_DISCHARGE][y, t])
        end

        for y in DC_CHARGE
            add_to_expression!(eChargeDCMin[y, t], EP[:vP_DC_CHARGE][y, t])
            add_to_expression!(eChargeMax[y, t], by_rid(y, :eff_up_dc), EP[:vP_DC_CHARGE][y, t])
        end

        for y in AC_DISCHARGE
            add_to_expression!(eDischargeACMin[y, t], EP[:vP_AC_DISCHARGE][y, t])
            add_to_expression!(eDischargeMax[y, t], 1 / by_rid(y, :eff_down_ac), EP[:vP_AC_DISCHARGE][y, t])
        end

        for y in AC_CHARGE
            add_to_expression!(eChargeACMin[y, t], EP[:vP_AC_CHARGE][y, t])
            add_to_expression!(eChargeMax[y, t], by_rid(y, :eff_up_ac), EP[:vP_AC_CHARGE][y, t])
        end

        for y in SOLAR_REG
            add_to_expression!(eVreStorRegOnlyBalance[y, t], by_rid(y, :etainverter), vREG_SOLAR[y, t])
            add_to_expression!(EP[:eGridExport][y, t], by_rid(y, :etainverter), vREG_SOLAR[y, t])
            add_to_expression!(EP[:eInverterExport][y, t], by_rid(y, :etainverter), vREG_SOLAR[y, t])
            add_to_expression!(EP[:eSolarGenMaxS][y, t], vREG_SOLAR[y, t])
        end
        for y in SOLAR_RSV
            add_to_expression!(eVreStorRsvOnlyBalance[y, t], by_rid(y, :etainverter), vRSV_SOLAR[y, t])
            add_to_expression!(EP[:eGridExport][y, t], by_rid(y, :etainverter), vRSV_SOLAR[y, t])
            add_to_expression!(EP[:eInverterExport][y, t], by_rid(y, :etainverter), vRSV_SOLAR[y, t])
            add_to_expression!(EP[:eSolarGenMaxS][y, t], vRSV_SOLAR[y, t])
        end

        for y in WIND_REG
            add_to_expression!(eVreStorRegOnlyBalance[y, t], vREG_WIND[y, t])
            add_to_expression!(EP[:eGridExport][y, t], vREG_WIND[y, t])
            add_to_expression!(EP[:eWindGenMaxW][y, t], vREG_WIND[y, t])
        end
        for y in WIND_RSV
            add_to_expression!(eVreStorRsvOnlyBalance[y, t], vRSV_WIND[y, t])
            add_to_expression!(EP[:eGridExport][y, t], vRSV_WIND[y, t])
            add_to_expression!(EP[:eWindGenMaxW][y, t], vRSV_WIND[y, t])
        end

        for y in DC_DISCHARGE_REG
            add_to_expression!(eVreStorRegOnlyBalance[y, t], by_rid(y, :etainverter),
                vREG_DC_Discharge[y, t])
            add_to_expression!(eDischargeDCMin[y, t], -1.0, vREG_DC_Discharge[y, t])
            add_to_expression!(eDischargeMax[y, t], 1 / by_rid(y, :eff_down_dc),
                EP[:vREG_DC_Discharge][y, t])
            add_to_expression!(EP[:eGridExport][y, t], by_rid(y, :etainverter),
                vREG_DC_Discharge[y, t])
            add_to_expression!(EP[:eInverterExport][y, t], by_rid(y, :etainverter),
                vREG_DC_Discharge[y, t])
        end
        for y in DC_DISCHARGE_RSV
            add_to_expression!(eVreStorRsvOnlyBalance[y, t], by_rid(y, :etainverter),
                vRSV_DC_Discharge[y, t])
            add_to_expression!(eDischargeMax[y, t], 1 / by_rid(y, :eff_down_dc),
                EP[:vRSV_DC_Discharge][y, t])
            add_to_expression!(EP[:eGridExport][y, t], by_rid(y, :etainverter),
                vRSV_DC_Discharge[y, t])
            add_to_expression!(EP[:eInverterExport][y, t], by_rid(y, :etainverter),
                vRSV_DC_Discharge[y, t])
        end

        for y in DC_CHARGE_REG
            add_to_expression!(eVreStorRegOnlyBalance[y, t], 1 / by_rid(y, :etainverter), vREG_DC_Charge[y, t])
            add_to_expression!(eChargeDCMin[y, t], -1.0, vREG_DC_Charge[y, t])
            add_to_expression!(eChargeMax[y, t], by_rid(y, :eff_up_dc),
                EP[:vREG_DC_Charge][y, t])
            add_to_expression!(EP[:eGridExport][y, t], 1 / by_rid(y, :etainverter),
                vREG_DC_Charge[y, t])
            add_to_expression!(EP[:eInverterExport][y, t], 1 / by_rid(y, :etainverter),
                vREG_DC_Charge[y, t])
        end
        for y in DC_CHARGE_RSV
            add_to_expression!(eVreStorRsvOnlyBalance[y, t], 1 / by_rid(y, :etainverter), vRSV_DC_Charge[y, t])
            add_to_expression!(eChargeDCMin[y, t], -1.0, vRSV_DC_Charge[y, t])
        end

        for y in AC_DISCHARGE_REG
            add_to_expression!(eVreStorRegOnlyBalance[y, t], vREG_AC_Discharge[y, t])
            add_to_expression!(eDischargeACMin[y, t], -1.0, vREG_AC_Discharge[y, t])
            add_to_expression!(eDischargeMax[y, t], 1 / by_rid(y, :eff_down_ac),
                EP[:vREG_AC_Discharge][y, t])
            add_to_expression!(EP[:eGridExport][y, t], vREG_AC_Discharge[y, t])
        end
        for y in AC_DISCHARGE_RSV
            add_to_expression!(eVreStorRsvOnlyBalance[y, t], vRSV_AC_Discharge[y, t])
            add_to_expression!(eDischargeMax[y, t], 1 / by_rid(y, :eff_down_ac),
                EP[:vRSV_AC_Discharge][y, t])
            add_to_expression!(EP[:eGridExport][y, t], vRSV_AC_Discharge[y, t])
        end

        for y in AC_CHARGE_REG
            add_to_expression!(eVreStorRegOnlyBalance[y, t], vREG_AC_Charge[y, t])
            add_to_expression!(eChargeACMin[y, t], -1.0, vREG_AC_Charge[y, t])
            add_to_expression!(eChargeMax[y, t], by_rid(y, :eff_down_ac),
                EP[:vREG_AC_Charge][y, t])
            add_to_expression!(EP[:eGridExport][y, t], vREG_AC_Charge[y, t])
        end
        for y in AC_CHARGE_RSV
            add_to_expression!(eVreStorRsvOnlyBalance[y, t], vRSV_AC_Charge[y, t])
            add_to_expression!(eChargeACMin[y, t], -1.0, vRSV_AC_Charge[y, t])
        end

        for y in VS_SYM_DC_REG
            add_to_expression!(EP[:eChargeDischargeMaxDC][y, t], vREG_DC_Discharge[y, t])
            add_to_expression!(EP[:eChargeDischargeMaxDC][y, t], vREG_DC_Charge[y, t])
        end
        for y in VS_SYM_DC_RSV
            add_to_expression!(EP[:eChargeDischargeMaxDC][y, t], vRSV_DC_Discharge[y, t])
        end

        for y in VS_SYM_AC_REG
            add_to_expression!(EP[:eChargeDischargeMaxAC][y, t], vREG_AC_Discharge[y, t])
            add_to_expression!(EP[:eChargeDischargeMaxAC][y, t], vREG_AC_Charge[y, t])
        end
        for y in VS_SYM_AC_RSV
            add_to_expression!(EP[:eChargeDischargeMaxAC][y, t], vRSV_AC_Discharge[y, t])
        end

        for y in VS_ASYM_DC_DISCHARGE_REG
            add_to_expression!(EP[:eVreStorMaxDischargingDC][y, t], vREG_DC_Discharge[y, t])
        end
        for y in VS_ASYM_DC_DISCHARGE_RSV
            add_to_expression!(EP[:eVreStorMaxDischargingDC][y, t], vRSV_DC_Discharge[y, t])
        end

        for y in VS_ASYM_DC_CHARGE_REG
            add_to_expression!(EP[:eVreStorMaxChargingDC][y, t], vREG_DC_Charge[y, t])
        end

        for y in VS_ASYM_AC_DISCHARGE_REG
            add_to_expression!(EP[:eVreStorMaxDischargingAC][y, t], vREG_AC_Discharge[y, t])
        end
        for y in VS_ASYM_AC_DISCHARGE_RSV
            add_to_expression!(EP[:eVreStorMaxDischargingAC][y, t], vRSV_AC_Discharge[y, t])
        end

        for y in VS_ASYM_AC_CHARGE_REG
            add_to_expression!(EP[:eVreStorMaxChargingAC][y, t], vREG_AC_Charge[y, t])
        end
    end

    if CapacityReserveMargin > 0
        for t in 1:T
            for y in DC_DISCHARGE
                add_to_expression!(eDischargeMax[y, t], 1 / by_rid(y, :eff_down_dc),
                    EP[:vCAPRES_DC_DISCHARGE][y, t])
            end
            for y in AC_DISCHARGE
                add_to_expression!(eDischargeMax[y, t], 1 / by_rid(y, :eff_down_ac),
                    EP[:vCAPRES_AC_DISCHARGE][y, t])
            end
        end
    end

    ### CONSTRAINTS ### 

    # Frequency regulation and operating reserves for all co-located VRE-STOR resources
    if !isempty(VRE_STOR_REG_RSV)
        @constraints(EP,
            begin
                # Maximum VRE-STOR contribution to reserves is a specified fraction of installed grid connection capacity
                [y in VRE_STOR_REG_RSV, t = 1:T],
                EP[:vREG][y, t] <= reg_max(gen[y]) * EP[:eTotalCap][y]
                [y in VRE_STOR_REG_RSV, t = 1:T],
                EP[:vRSV][y, t] <= rsv_max(gen[y]) * EP[:eTotalCap][y]

                # Actual contribution to regulation and reserves is sum of auxilary variables
                [y in VRE_STOR_REG_RSV, t = 1:T],
                EP[:vREG][y, t] == eVreStorRegOnlyBalance[y, t]
                [y in VRE_STOR_REG_RSV, t = 1:T],
                EP[:vRSV][y, t] == eVreStorRsvOnlyBalance[y, t]
            end)
    end
    if !isempty(VRE_STOR_REG_ONLY)
        @constraints(EP,
            begin
                # Maximum VRE-STOR contribution to reserves is a specified fraction of installed grid connection capacity
                [y in VRE_STOR_REG_ONLY, t = 1:T],
                EP[:vREG][y, t] <= reg_max(gen[y]) * EP[:eTotalCap][y]

                # Actual contribution to regulation is sum of auxilary variables
                [y in VRE_STOR_REG_ONLY, t = 1:T],
                EP[:vREG][y, t] == eVreStorRegOnlyBalance[y, t]
            end)
    end
    if !isempty(VRE_STOR_RSV_ONLY)
        @constraints(EP,
            begin
                # Maximum VRE-STOR contribution to reserves is a specified fraction of installed grid connection capacity
                [y in VRE_STOR_RSV_ONLY, t = 1:T],
                EP[:vRSV][y, t] <= rsv_max(gen[y]) * EP[:eTotalCap][y]

                # Actual contribution to reserves is sum of auxilary variables
                [y in VRE_STOR_RSV_ONLY, t = 1:T],
                EP[:vRSV][y, t] == eVreStorRsvOnlyBalance[y, t]
            end)
    end

    # Frequency regulation and operating reserves for VRE-STOR resources with a VRE component
    if !isempty(SOLAR_REG)
        @constraints(EP,
            begin
                # Maximum generation and contribution to reserves up must be greater than zero
                [y in SOLAR_REG, t = 1:T], EP[:vP_SOLAR][y, t] - EP[:vREG_SOLAR][y, t] >= 0
            end)
    end

    if !isempty(WIND_REG)
        @constraints(EP,
            begin
                # Maximum generation and contribution to reserves up must be greater than zero
                [y in WIND_REG, t = 1:T], EP[:vP_WIND][y, t] - EP[:vREG_WIND][y, t] >= 0
            end)
    end

    # Frequency regulation and operating reserves for VRE-STOR resources with a storage component
    if !isempty(STOR_REG_RSV_UNION)
        @constraints(EP,
            begin
                # Maximum DC charging rate plus contribution to reserves up must be greater than zero
                # Note: when charging, reducing charge rate is contributing to upwards reserve & regulation as it drops net demand
                [y in DC_CHARGE, t = 1:T], eChargeDCMin[y, t] >= 0

                # Maximum AC charging rate plus contribution to reserves up must be greater than zero
                # Note: when charging, reducing charge rate is contributing to upwards reserve & regulation as it drops net demand
                [y in AC_CHARGE, t = 1:T], eChargeACMin[y, t] >= 0

                # Maximum DC discharging rate and contribution to reserves down must be greater than zero
                # Note: when discharging, reducing discharge rate is contributing to downwards regulation as it drops net supply
                [y in DC_DISCHARGE, t = 1:T], eDischargeDCMin[y, t] >= 0

                # Maximum AC discharging rate and contribution to reserves down must be greater than zero
                # Note: when discharging, reducing discharge rate is contributing to downwards regulation as it drops net supply
                [y in AC_DISCHARGE, t = 1:T], eDischargeACMin[y, t] >= 0

                # Maximum charging rate plus contributions must be less than available storage capacity
                [y in STOR_REG_RSV_UNION, t = 1:T],
                eChargeMax[y, t] <=
                EP[:eTotalCap_STOR][y] - EP[:vS_VRE_STOR][y, hoursbefore(p, t, 1)]

                # Maximum discharging rate and contributions must be less than the available stored energy in prior period
                # wrapping from end of sample period to start of sample period for energy capacity constraint
                [y in STOR_REG_RSV_UNION, t = 1:T],
                eDischargeMax[y, t] <= EP[:vS_VRE_STOR][y, hoursbefore(p, t, 1)]
            end)
    end

    # Total system reserve constraints
    @expression(EP,
        eRegReqVreStor[t = 1:T],
        inputs["pReg_Req_VRE"] *
        sum(inputs["pP_Max_Solar"][y, t] * EP[:eTotalCap_SOLAR][y] *
            by_rid(y, :etainverter)
        for y in SOLAR_REG)
        +inputs["pReg_Req_VRE"] *
         sum(inputs["pP_Max_Wind"][y, t] * EP[:eTotalCap_WIND][y] for y in WIND_REG))
    @expression(EP,
        eRsvReqVreStor[t = 1:T],
        inputs["pRsv_Req_VRE"] *
        sum(inputs["pP_Max_Solar"][y, t] * EP[:eTotalCap_SOLAR][y] *
            by_rid(y, :etainverter)
        for y in SOLAR_RSV)
        +inputs["pRsv_Req_VRE"] *
         sum(inputs["pP_Max_Wind"][y, t] * EP[:eTotalCap_WIND][y] for y in WIND_RSV))

    if !isempty(VRE_STOR_REG)
        @constraint(EP,
            cRegVreStor[t = 1:T],
            sum(EP[:vREG][y, t]
            for y in inputs["REG"])>=EP[:eRegReq][t] +
                                     eRegReqVreStor[t])
    end
    if !isempty(VRE_STOR_RSV)
        @constraint(EP,
            cRsvReqVreStor[t = 1:T],
            sum(EP[:vRSV][y, t] for y in inputs["RSV"]) +
            EP[:vUNMET_RSV][t]>=EP[:eRsvReq][t] + eRsvReqVreStor[t])
    end
end
