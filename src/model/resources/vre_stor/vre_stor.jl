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

The rest of the constraints are dependent upon specific configurable components within the module and are listed below.
"""
function vre_stor!(EP::Model, inputs::Dict, setup::Dict)
    println("VRE-Storage Module")

    ### LOAD DATA ###

    # Load generators dataframe, sets, and time periods
    gen = inputs["RESOURCES"]

    T = inputs["T"]                                                 # Number of time steps (hours)
    Z = inputs["Z"]                                                 # Number of zones

    # Load VRE-storage inputs
    VRE_STOR = inputs["VRE_STOR"]                                 # Set of VRE-STOR generators (indices)
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

    ## 1. Objective Function Expressions ##

    # Separate grid costs
    @expression(EP, eCGrid[y in VRE_STOR],
        if y in NEW_CAP # Resources eligible for new capacity
            inv_cost_per_mwyr(gen[y]) * EP[:vCAP][y] +
            fixed_om_cost_per_mwyr(gen[y]) * EP[:eTotalCap][y]
        else
            fixed_om_cost_per_mwyr(gen[y]) * EP[:eTotalCap][y]
        end)
    @expression(EP, eTotalCGrid, sum(eCGrid[y] for y in VRE_STOR))

    ## 2. Power Balance Expressions ##

    # Note: The subtraction of the charging component can be found in STOR function
    @expression(EP, ePowerBalance_VRE_STOR[t = 1:T, z = 1:Z], JuMP.AffExpr())
    for t in 1:T, z in 1:Z
        if !isempty(resources_in_zone_by_rid(gen_VRE_STOR, z))
            ePowerBalance_VRE_STOR[t, z] += sum(EP[:vP][y, t]
            for y in resources_in_zone_by_rid(gen_VRE_STOR,
                z))
        end
    end

    ## 3. Module Expressions ##

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
        EP[:eESR] += eESRVREStor
        if IncludeLossesInESR == 1
            @expression(EP, eESRVREStorLosses[ESR = 1:inputs["nESR"]],
                sum(inputs["dfESR"][z, ESR] * sum(EP[:eELOSS_VRE_STOR][y]
                    for y in intersect(STOR, resources_in_zone_by_rid(gen_VRE_STOR, z)))
                for z in findall(x -> x > 0, inputs["dfESR"][:, ESR])))
            EP[:eESR] -= eESRVREStorLosses
        end
    end

    # Minimum Capacity Requirement
    if MinCapReq == 1
        @expression(EP, eMinCapResSolar[mincap = 1:inputs["NumberOfMinCapReqs"]],
            sum(by_rid(y, :etainverter) * EP[:eTotalCap_SOLAR][y]
            for y in intersect(SOLAR,
                ids_with_policy(gen_VRE_STOR, min_cap_solar, tag = mincap))))
        EP[:eMinCapRes] += eMinCapResSolar

        @expression(EP, eMinCapResWind[mincap = 1:inputs["NumberOfMinCapReqs"]],
            sum(EP[:eTotalCap_WIND][y]
            for y in intersect(WIND,
                ids_with_policy(gen_VRE_STOR, min_cap_wind, tag = mincap))))
        EP[:eMinCapRes] += eMinCapResWind

        if !isempty(inputs["VS_ASYM_AC_DISCHARGE"])
            @expression(EP, eMinCapResACDis[mincap = 1:inputs["NumberOfMinCapReqs"]],
                sum(EP[:eTotalCapDischarge_AC][y]
                for y in intersect(inputs["VS_ASYM_AC_DISCHARGE"],
                    ids_with_policy(gen_VRE_STOR, min_cap_stor, tag = mincap))))
            EP[:eMinCapRes] += eMinCapResACDis
        end

        if !isempty(inputs["VS_ASYM_DC_DISCHARGE"])
            @expression(EP, eMinCapResDCDis[mincap = 1:inputs["NumberOfMinCapReqs"]],
                sum(EP[:eTotalCapDischarge_DC][y]
                for y in intersect(inputs["VS_ASYM_DC_DISCHARGE"],
                    ids_with_policy(gen_VRE_STOR, min_cap_stor, tag = mincap))))
            EP[:eMinCapRes] += eMinCapResDCDis
        end

        if !isempty(inputs["VS_SYM_AC"])
            @expression(EP, eMinCapResACStor[mincap = 1:inputs["NumberOfMinCapReqs"]],
                sum(by_rid(y, :power_to_energy_ac) * EP[:eTotalCap_STOR][y]
                for y in intersect(inputs["VS_SYM_AC"],
                    ids_with_policy(gen_VRE_STOR, min_cap_stor, tag = mincap))))
            EP[:eMinCapRes] += eMinCapResACStor
        end

        if !isempty(inputs["VS_SYM_DC"])
            @expression(EP, eMinCapResDCStor[mincap = 1:inputs["NumberOfMinCapReqs"]],
                sum(by_rid(y, :power_to_energy_dc) * EP[:eTotalCap_STOR][y]
                for y in intersect(inputs["VS_SYM_DC"],
                    ids_with_policy(gen_VRE_STOR, min_cap_stor, tag = mincap))))
            EP[:eMinCapRes] += eMinCapResDCStor
        end
    end

    # Maximum Capacity Requirement
    if MaxCapReq == 1
        @expression(EP, eMaxCapResSolar[maxcap = 1:inputs["NumberOfMaxCapReqs"]],
            sum(by_rid(y, :etainverter) * EP[:eTotalCap_SOLAR][y]
            for y in intersect(SOLAR,
                ids_with_policy(gen_VRE_STOR, max_cap_solar, tag = maxcap))))
        EP[:eMaxCapRes] += eMaxCapResSolar

        @expression(EP, eMaxCapResWind[maxcap = 1:inputs["NumberOfMaxCapReqs"]],
            sum(EP[:eTotalCap_WIND][y]
            for y in intersect(WIND,
                ids_with_policy(gen_VRE_STOR, max_cap_wind, tag = maxcap))))
        EP[:eMaxCapRes] += eMaxCapResWind

        if !isempty(inputs["VS_ASYM_AC_DISCHARGE"])
            @expression(EP, eMaxCapResACDis[maxcap = 1:inputs["NumberOfMaxCapReqs"]],
                sum(EP[:eTotalCapDischarge_AC][y]
                for y in intersect(inputs["VS_ASYM_AC_DISCHARGE"],
                    ids_with_policy(gen_VRE_STOR, max_cap_stor, tag = maxcap))))
            EP[:eMaxCapRes] += eMaxCapResACDis
        end

        if !isempty(inputs["VS_ASYM_DC_DISCHARGE"])
            @expression(EP, eMaxCapResDCDis[maxcap = 1:inputs["NumberOfMaxCapReqs"]],
                sum(EP[:eTotalCapDischarge_DC][y]
                for y in intersect(inputs["VS_ASYM_DC_DISCHARGE"],
                    ids_with_policy(gen_VRE_STOR, max_cap_stor, tag = maxcap))))
            EP[:eMaxCapRes] += eMaxCapResDCDis
        end

        if !isempty(inputs["VS_SYM_AC"])
            @expression(EP, eMaxCapResACStor[maxcap = 1:inputs["NumberOfMaxCapReqs"]],
                sum(by_rid(y, :power_to_energy_ac) * EP[:eTotalCap_STOR][y]
                for y in intersect(inputs["VS_SYM_AC"],
                    ids_with_policy(gen_VRE_STOR, max_cap_stor, tag = maxcap))))
            EP[:eMaxCapRes] += eMaxCapResACStor
        end

        if !isempty(inputs["VS_SYM_DC"])
            @expression(EP, eMaxCapResDCStor[maxcap = 1:inputs["NumberOfMaxCapReqs"]],
                sum(by_rid(y, :power_to_energy_dc) * EP[:eTotalCap_STOR][y]
                for y in intersect(inputs["VS_SYM_DC"],
                    ids_with_policy(gen_VRE_STOR, max_cap_stor, tag = maxcap))))
            EP[:eMaxCapRes] += eMaxCapResDCStor
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
    EP[:ePowerBalance] += ePowerBalance_VRE_STOR

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

This function defines the decision variables, expressions, and constraints for the inverter component of each co-located VRE and storage generator.

The total inverter capacity of each resource is defined as the sum of the existing inverter capacity plus the newly invested inverter capacity 
    minus any retired inverter capacity:
```math
\begin{aligned}
    & \Delta^{total, inv}_{y,z} = (\overline{\Delta^{inv}_{y,z}} + \Omega^{inv}_{y,z} - \Delta^{inv}_{y,z}) \quad \forall y \in \mathcal{VS}^{inv}, z \in \mathcal{Z}
\end{aligned}
```

One cannot retire more inverter capacity than existing inverter capacity:
```math
\begin{aligned}
    & \Delta^{inv}_{y,z} \leq \overline{\Delta^{inv}_{y,z}}
        \hspace{4 cm} \forall y \in \mathcal{VS}^{inv}, z \in \mathcal{Z}
    \end{aligned}
```

For resources where $\overline{\Omega^{inv}_{y,z}}$ and $\underline{\Omega^{inv}_{y,z}}$ are defined, then we impose constraints on minimum and maximum capacity:
```math
\begin{aligned}
    & \Delta^{total, inv}_{y,z} \leq \overline{\Omega^{inv}_{y,z}}
        \hspace{4 cm}  \forall y \in \mathcal{VS}^{inv}, z \in \mathcal{Z} \\
    & \Delta^{total, inv}_{y,z}  \geq \underline{\Omega^{inv}_{y,z}}
        \hspace{4 cm}  \forall y \in \mathcal{VS}^{inv}, z \in \mathcal{Z}
\end{aligned}
```

The last constraint ensures that the maximum DC grid exports and imports must be less than the inverter capacity. Without any capacity reserve margin or 
    operating reserves, the constraint is:
```math
\begin{aligned}
    & \eta^{inverter}_{y,z} \times (\Theta^{pv}_{y,z,t} + \Theta^{dc}_{y,z,t}) + \frac{\Pi_{y,z,t}^{dc}}{\eta^{inverter}_{y,z}} \leq \Delta^{total, inv}_{y,z} \quad \forall y \in \mathcal{VS}^{inv}, \forall z \in \mathcal{Z}, \forall t \in \mathcal{T}
\end{aligned}
```

With only capacity reserve margins, the maximum DC grid exports and imports constraint becomes:
```math
\begin{aligned}
    & \eta^{inverter}_{y,z} \times (\Theta^{pv}_{y,z,t} + \Theta^{dc}_{y,z,t} + \Theta^{CRM,dc}_{y,z,t}) + \frac{\Pi_{y,z,t}^{dc} + \Pi_{y,z,t}^{CRM,dc}}{\eta^{inverter}_{y,z}} \\
    & \leq \Delta^{total, inv}_{y,z} \quad \forall y \in \mathcal{VS}^{inv}, \forall z \in \mathcal{Z}, \forall t \in \mathcal{T}
\end{aligned}
```

With only operating reserves, the maximum DC grid exports and imports constraint becomes:
```math
\begin{aligned}
    & \eta^{inverter}_{y,z} \times (\Theta^{pv}_{y,z,t} + \Theta^{dc}_{y,z,t} + f^{pv}_{y,z,t} + r^{pv}_{y,z,t} + f^{dc,dis}_{y,z,t} + r^{dc,dis}_{y,z,t}) + \frac{\Pi_{y,z,t}^{dc} + f^{dc,cha}_{y,z,t}}{\eta^{inverter}_{y,z}} \\
    & \leq \Delta^{total, inv}_{y,z} \quad \forall y \in \mathcal{VS}^{inv}, \forall z \in \mathcal{Z}, \forall t \in \mathcal{T}
\end{aligned}
```

With both capacity reserve margins and operating reserves, the maximum DC grid exports and imports constraint becomes:
```math
\begin{aligned}
    & \eta^{inverter}_{y,z} \times (\Theta^{pv}_{y,z,t} + \Theta^{dc}_{y,z,t} + \Theta^{CRM,dc}_{y,z,t} + f^{pv}_{y,z,t} + r^{pv}_{y,z,t} + f^{dc,dis}_{y,z,t} + r^{dc,dis}_{y,z,t}) \\
    & + \frac{\Pi_{y,z,t}^{dc} + \Pi_{y,z,t}^{CRM,dc} + f^{dc,cha}_{y,z,t}}{\eta^{inverter}_{y,z}} \leq \Delta^{total, inv}_{y,z} \quad \forall y \in \mathcal{VS}^{inv}, \forall z \in \mathcal{Z}, \forall t \in \mathcal{T}
\end{aligned}
```

In addition, this function adds investment and fixed O&M related costs related to the inverter capacity to the objective function:
```math
\begin{aligned}
    & 	\sum_{y \in \mathcal{VS}^{inv}} \sum_{z \in \mathcal{Z}}
        \left( (\pi^{INVEST, inv}_{y,z} \times \Omega^{inv}_{y,z})
        + (\pi^{FOM, inv}_{y,z} \times  \Delta^{total,inv}_{y,z})\right)
\end{aligned}
```
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

    ### INVERTER VARIABLES ###

    @variables(EP, begin
        # Inverter capacity 
        vRETDCCAP[y in RET_CAP_DC] >= 0                         # Retired inverter capacity [MW AC]
        vDCCAP[y in NEW_CAP_DC] >= 0                            # New installed inverter capacity [MW AC]
    end)

    if MultiStage == 1
        @variable(EP, vEXISTINGDCCAP[y in DC]>=0)
    end

    ### EXPRESSIONS ###

    # 0. Multistage existing capacity definition
    if MultiStage == 1
        @expression(EP, eExistingCapDC[y in DC], vEXISTINGDCCAP[y])
    else
        @expression(EP, eExistingCapDC[y in DC], by_rid(y, :existing_cap_inverter_mw))
    end

    # 1. Total inverter capacity
    @expression(EP, eTotalCap_DC[y in DC],
        if (y in intersect(NEW_CAP_DC, RET_CAP_DC)) # Resources eligible for new capacity and retirements
            eExistingCapDC[y] + EP[:vDCCAP][y] - EP[:vRETDCCAP][y]
        elseif (y in setdiff(NEW_CAP_DC, RET_CAP_DC)) # Resources eligible for only new capacity
            eExistingCapDC[y] + EP[:vDCCAP][y]
        elseif (y in setdiff(RET_CAP_DC, NEW_CAP_DC)) # Resources eligible for only capacity retirements
            eExistingCapDC[y] - EP[:vRETDCCAP][y]
        else
            eExistingCapDC[y]
        end)

    # 2. Objective function additions

    # Fixed costs for inverter component (if resource is not eligible for new inverter capacity, fixed costs are only O&M costs)
    @expression(EP, eCFixDC[y in DC],
        if y in NEW_CAP_DC # Resources eligible for new capacity
            by_rid(y, :inv_cost_inverter_per_mwyr) * vDCCAP[y] +
            by_rid(y, :fixed_om_inverter_cost_per_mwyr) * eTotalCap_DC[y]
        else
            by_rid(y, :fixed_om_inverter_cost_per_mwyr) * eTotalCap_DC[y]
        end)

    # Sum individual resource contributions
    @expression(EP, eTotalCFixDC, sum(eCFixDC[y] for y in DC))

    if MultiStage == 1
        EP[:eObj] += eTotalCFixDC / inputs["OPEXMULT"]
    else
        EP[:eObj] += eTotalCFixDC
    end

    # 3. Inverter exports expression
    @expression(EP, eInverterExport[y in DC, t = 1:T], JuMP.AffExpr())

    ### CONSTRAINTS ###

    # Constraint 0: Existing capacity variable is equal to existing capacity specified in the input file
    if MultiStage == 1
        @constraint(EP,
            cExistingCapDC[y in DC],
            EP[:vEXISTINGDCCAP][y]==by_rid(y, :existing_cap_inverter_mw))
    end

    # Constraints 1: Retirements and capacity additions
    # Cannot retire more capacity than existing capacity for VRE-STOR technologies
    @constraint(EP, cMaxRet_DC[y = RET_CAP_DC], vRETDCCAP[y]<=eExistingCapDC[y])
    # Constraint on maximum capacity (if applicable) [set input to -1 if no constraint on maximum capacity]
    # DEV NOTE: This constraint may be violated in some cases where Existing_Cap_MW is >= Max_Cap_MW and lead to infeasabilty
    @constraint(EP, cMaxCap_DC[y in ids_with_nonneg(gen_VRE_STOR, max_cap_inverter_mw)],
        eTotalCap_DC[y]<=by_rid(y, :max_cap_inverter_mw))
    # Constraint on Minimum capacity (if applicable) [set input to -1 if no constraint on minimum capacity]
    # DEV NOTE: This constraint may be violated in some cases where Existing_Cap_MW is <= Min_Cap_MW and lead to infeasabilty
    @constraint(EP, cMinCap_DC[y in ids_with_positive(gen_VRE_STOR, min_cap_inverter_mw)],
        eTotalCap_DC[y]>=by_rid(y, :min_cap_inverter_mw))

    # Constraint 2: Inverter Exports Maximum: see main module because capacity reserve margin/operating reserves may alter constraint
end

@doc raw"""
    solar_vre_stor!(EP::Model, inputs::Dict, setup::Dict)

This function defines the decision variables, expressions, and constraints for the solar PV component of each co-located VRE and storage generator.

The total solar PV capacity of each resource is defined as the sum of the existing solar PV capacity plus the newly invested solar PV capacity 
    minus any retired solar PV capacity:
```math
\begin{aligned}
    & \Delta^{total, pv}_{y,z} = (\overline{\Delta^{pv}_{y,z}} + \Omega^{pv}_{y,z} - \Delta^{pv}_{y,z}) \quad \forall y \in \mathcal{VS}^{pv}, z \in \mathcal{Z}
\end{aligned}
```
        
One cannot retire more solar PV capacity than existing solar PV capacity:
```math
\begin{aligned}
    & \Delta^{pv}_{y,z} \leq \overline{\Delta^{pv}_{y,z}}
        \hspace{4 cm} \forall y \in \mathcal{VS}^{pv}, z \in \mathcal{Z}
\end{aligned}
```
        
For resources where $\overline{\Omega^{pv}_{y,z}}$ and $\underline{\Omega^{pv}_{y,z}}$ are defined, then we impose constraints on minimum and maximum capacity:
```math
\begin{aligned}
    & \Delta^{total, pv}_{y,z} \leq \overline{\Omega^{pv}_{y,z}}
        \hspace{4 cm}  \forall y \in \mathcal{VS}^{pv}, z \in \mathcal{Z} \\
    & \Delta^{total, pv}_{y,z}  \geq \underline{\Omega^{pv}_{y,z}}
        \hspace{4 cm}  \forall y \in \mathcal{VS}^{pv}, z \in \mathcal{Z}
\end{aligned}
```
        
If there is a fixed ratio for capacity (rather than co-optimizing interconnection sizing) of solar PV built to capacity of 
    inverter built ($\eta_{y,z}^{ILR,pv}$), also known as the inverter loading ratio, then we impose the following constraint:
```math
\begin{aligned}
    & \Delta^{total, pv}_{y, z} = \eta^{ILR,pv}_{y, z} \times \Delta^{total, inv}_{y, z} \quad \forall y \in \mathcal{VS}^{pv}, \forall z \in Z
\end{aligned}
```
The last constraint defines the maximum power output in each time step from the solar PV component. Without any  
    operating reserves, the constraint is:
```math
\begin{aligned}
    & \Theta^{pv}_{y, z, t} \leq \rho^{max, pv}_{y, z, t} \times \Delta^{total,pv}_{y, z} \quad \forall y \in \mathcal{VS}^{pv}, \forall z \in Z, \forall t \in T
\end{aligned}
```
        
With operating reserves, the maximum power output in each time step from the solar PV component must account for procuring some of the available capacity for 
    frequency regulation ($f^{pv}_{y,z,t}$) and upward operating (spinning) reserves ($r^{pv}_{y,z,t}$):
```math
\begin{aligned}
    & \Theta^{pv}_{y, z, t} + f^{pv}_{y,z,t} + r^{pv}_{y,z,t} \leq \rho^{max, pv}_{y, z, t} \times \Delta^{total,pv}_{y, z} \quad \forall y \in \mathcal{VS}^{pv}, \forall z \in Z, \forall t \in T
\end{aligned}
```

In addition, this function adds investment, fixed O&M, and variable O&M costs related to the solar PV capacity to the objective function:
```math
\begin{aligned}
    & 	\sum_{y \in \mathcal{VS}^{pv}} \sum_{z \in \mathcal{Z}}
        \left( (\pi^{INVEST, pv}_{y,z} \times \Omega^{pv}_{y,z}) + (\pi^{FOM, pv}_{y,z} \times  \Delta^{total,pv}_{y,z}) \right) \\
    &   + \sum_{y \in \mathcal{VS}^{pv}} \sum_{z \in \mathcal{Z}} \sum_{t \in \mathcal{T}} (\pi^{VOM, pv}_{y,z} \times \eta^{inverter}_{y,z} \times \Theta^{pv}_{y,z,t})
\end{aligned}
```
"""
function solar_vre_stor!(EP::Model, inputs::Dict, setup::Dict)
    println("VRE-STOR Solar Module")

    ### LOAD DATA ###
    gen = inputs["RESOURCES"]
    gen_VRE_STOR = gen.VreStorage

    T = inputs["T"]
    SOLAR = inputs["VS_SOLAR"]

    NEW_CAP_SOLAR = inputs["NEW_CAP_SOLAR"]
    RET_CAP_SOLAR = inputs["RET_CAP_SOLAR"]

    MultiStage = setup["MultiStage"]

    by_rid(rid, sym) = by_rid_res(rid, sym, gen_VRE_STOR)

    ### SOLAR VARIABLES ###

    @variables(EP, begin
        vRETSOLARCAP[y in RET_CAP_SOLAR] >= 0                         # Retired solar capacity [MW DC]
        vSOLARCAP[y in NEW_CAP_SOLAR] >= 0                            # New installed solar capacity [MW DC]

        # Solar-component generation [MWh]
        vP_SOLAR[y in SOLAR, t = 1:T] >= 0
    end)

    if MultiStage == 1
        @variable(EP, vEXISTINGSOLARCAP[y in SOLAR]>=0)
    end

    ### EXPRESSIONS ###

    # 0. Multistage existing capacity definition
    if MultiStage == 1
        @expression(EP, eExistingCapSolar[y in SOLAR], vEXISTINGSOLARCAP[y])
    else
        @expression(EP, eExistingCapSolar[y in SOLAR], by_rid(y, :existing_cap_solar_mw))
    end

    # 1. Total solar capacity
    @expression(EP, eTotalCap_SOLAR[y in SOLAR],
        if (y in intersect(NEW_CAP_SOLAR, RET_CAP_SOLAR)) # Resources eligible for new capacity and retirements
            eExistingCapSolar[y] + EP[:vSOLARCAP][y] - EP[:vRETSOLARCAP][y]
        elseif (y in setdiff(NEW_CAP_SOLAR, RET_CAP_SOLAR)) # Resources eligible for only new capacity
            eExistingCapSolar[y] + EP[:vSOLARCAP][y]
        elseif (y in setdiff(RET_CAP_SOLAR, NEW_CAP_SOLAR)) # Resources eligible for only capacity retirements
            eExistingCapSolar[y] - EP[:vRETSOLARCAP][y]
        else
            eExistingCapSolar[y]
        end)

    # 2. Objective function additions

    # Fixed costs for solar resources (if resource is not eligible for new solar capacity, fixed costs are only O&M costs)
    @expression(EP, eCFixSolar[y in SOLAR],
        if y in NEW_CAP_SOLAR # Resources eligible for new capacity
            by_rid(y, :inv_cost_solar_per_mwyr) * vSOLARCAP[y] +
            by_rid(y, :fixed_om_solar_cost_per_mwyr) * eTotalCap_SOLAR[y]
        else
            by_rid(y, :fixed_om_solar_cost_per_mwyr) * eTotalCap_SOLAR[y]
        end)
    @expression(EP, eTotalCFixSolar, sum(eCFixSolar[y] for y in SOLAR))

    if MultiStage == 1
        EP[:eObj] += eTotalCFixSolar / inputs["OPEXMULT"]
    else
        EP[:eObj] += eTotalCFixSolar
    end

    # Variable costs of "generation" for solar resource "y" during hour "t"
    @expression(EP, eCVarOutSolar[y in SOLAR, t = 1:T],
        inputs["omega"][t]*by_rid(y, :var_om_cost_per_mwh_solar)*by_rid(y, :etainverter)*
        EP[:vP_SOLAR][y, t])
    @expression(EP, eTotalCVarOutSolar, sum(eCVarOutSolar[y, t] for y in SOLAR, t in 1:T))
    EP[:eObj] += eTotalCVarOutSolar

    # 3. Inverter Balance, PV Generation Maximum
    @expression(EP, eSolarGenMaxS[y in SOLAR, t = 1:T], JuMP.AffExpr())
    for y in SOLAR, t in 1:T
        EP[:eInvACBalance][y, t] += by_rid(y, :etainverter) * EP[:vP_SOLAR][y, t]
        EP[:eInverterExport][y, t] += by_rid(y, :etainverter) * EP[:vP_SOLAR][y, t]
        eSolarGenMaxS[y, t] += EP[:vP_SOLAR][y, t]
    end

    ### CONSTRAINTS ###

    # Constraint 0: Existing capacity variable is equal to existing capacity specified in the input file
    if MultiStage == 1
        @constraint(EP,
            cExistingCapSolar[y in SOLAR],
            EP[:vEXISTINGSOLARCAP][y]==by_rid(y, :existing_cap_solar_mw))
    end

    # Constraints 1: Retirements and capacity additions
    # Cannot retire more capacity than existing capacity for VRE-STOR technologies
    @constraint(EP, cMaxRet_Solar[y = RET_CAP_SOLAR], vRETSOLARCAP[y]<=eExistingCapSolar[y])
    # Constraint on maximum capacity (if applicable) [set input to -1 if no constraint on maximum capacity]
    # DEV NOTE: This constraint may be violated in some cases where Existing_Cap_MW is >= Max_Cap_MW and lead to infeasabilty
    @constraint(EP, cMaxCap_Solar[y in ids_with_nonneg(gen_VRE_STOR, max_cap_solar_mw)],
        eTotalCap_SOLAR[y]<=by_rid(y, :max_cap_solar_mw))
    # Constraint on Minimum capacity (if applicable) [set input to -1 if no constraint on minimum capacity]
    # DEV NOTE: This constraint may be violated in some cases where Existing_Cap_MW is <= Min_Cap_MW and lead to infeasabilty
    @constraint(EP, cMinCap_Solar[y in ids_with_positive(gen_VRE_STOR, min_cap_solar_mw)],
        eTotalCap_SOLAR[y]>=by_rid(y, :min_cap_solar_mw))

    # Constraint 2: PV Generation: see main module because operating reserves may alter constraint

    # Constraint 3: Inverter Ratio between solar capacity and grid
    @constraint(EP,
        cInverterRatio_Solar[y in ids_with_positive(gen_VRE_STOR, inverter_ratio_solar)],
        EP[:eTotalCap_SOLAR][y]==by_rid(y, :inverter_ratio_solar) * EP[:eTotalCap_DC][y])
end

@doc raw"""
    wind_vre_stor!(EP::Model, inputs::Dict, setup::Dict)

This function defines the decision variables, expressions, and constraints for the wind component of each co-located VRE and storage generator.

The total wind capacity of each resource is defined as the sum of the existing wind capacity plus the newly invested wind capacity 
    minus any retired wind capacity:
```math
\begin{aligned}
    & \Delta^{total, wind}_{y,z} = (\overline{\Delta^{wind}_{y,z}} + \Omega^{wind}_{y,z} - \Delta^{wind}_{y,z}) \quad \forall y \in \mathcal{VS}^{wind}, z \in \mathcal{Z}
\end{aligned}
```

One cannot retire more wind capacity than existing wind capacity:
```math
\begin{aligned}
    & \Delta^{wind}_{y,z} \leq \overline{\Delta^{wind}_{y,z}}
        \hspace{4 cm} \forall y \in \mathcal{VS}^{wind}, z \in \mathcal{Z}
\end{aligned}
```
        
For resources where $\overline{\Omega^{wind}_{y,z}}$ and $\underline{\Omega^{wind}_{y,z}}$ are defined, then we impose constraints on minimum and maximum capacity:
```math
\begin{aligned}
    & \Delta^{total, wind}_{y,z} \leq \overline{\Omega^{wind}_{y,z}}
        \hspace{4 cm}  \forall y \in \mathcal{VS}^{wind}, z \in \mathcal{Z} \\
    & \Delta^{total, wind}_{y,z}  \geq \underline{\Omega^{wind}_{y,z}}
        \hspace{4 cm}  \forall y \in \mathcal{VS}^{wind}, z \in \mathcal{Z}
\end{aligned}
```
        
If there is a fixed ratio for capacity (rather than co-optimizing interconnection sizing) of wind built to capacity of grid connection built ($\eta_{y,z}^{ILR,wind}$), 
    then we impose the following constraint:
```math
\begin{aligned}
    & \Delta^{total, wind}_{y, z} = \eta^{ILR,wind}_{y, z} \times \Delta^{total}_{y, z} \quad \forall y \in \mathcal{VS}^{wind}, \forall z \in Z
\end{aligned}
```
The last constraint defines the maximum power output in each time step from the wind component. Without any  
    operating reserves, the constraint is:
```math
\begin{aligned}
    & \Theta^{wind}_{y, z, t} \leq \rho^{max, wind}_{y, z, t} \times \Delta^{total,wind}_{y, z} \quad \forall y \in \mathcal{VS}^{wind}, \forall z \in Z, \forall t \in T
\end{aligned}
```
        
With operating reserves, the maximum power output in each time step from the wind component must account for procuring some of the available capacity for 
    frequency regulation ($f^{wind}_{y,z,t}$) and upward operating (spinning) reserves ($r^{wind}_{y,z,t}$):
```math
\begin{aligned}
    & \Theta^{wind}_{y, z, t} + f^{wind}_{y,z,t} + r^{wind}_{y,z,t} \leq \rho^{max, wind}_{y, z, t} \times \Delta^{total,wind}_{y, z} \quad \forall y \in \mathcal{VS}^{wind}, \forall z \in Z, \forall t \in T
\end{aligned}
```

In addition, this function adds investment, fixed O&M, and variable O&M costs related to the wind capacity to the objective function:
```math
\begin{aligned}
    & 	\sum_{y \in \mathcal{VS}^{wind}} \sum_{z \in \mathcal{Z}}
        \left( (\pi^{INVEST, wind}_{y,z} \times \Omega^{wind}_{y,z}) + (\pi^{FOM, wind}_{y,z} \times  \Delta^{total,wind}_{y,z}) \right) \\
    &   + \sum_{y \in \mathcal{VS}^{wind}} \sum_{z \in \mathcal{Z}} \sum_{t \in \mathcal{T}} (\pi^{VOM, wind}_{y,z} \times \Theta^{wind}_{y,z,t})
\end{aligned}
```
"""
function wind_vre_stor!(EP::Model, inputs::Dict, setup::Dict)
    println("VRE-STOR Wind Module")

    ### LOAD DATA ###
    gen = inputs["RESOURCES"]
    gen_VRE_STOR = gen.VreStorage

    T = inputs["T"]
    WIND = inputs["VS_WIND"]
    NEW_CAP_WIND = inputs["NEW_CAP_WIND"]
    RET_CAP_WIND = inputs["RET_CAP_WIND"]

    MultiStage = setup["MultiStage"]

    by_rid(rid, sym) = by_rid_res(rid, sym, gen_VRE_STOR)

    ### WIND VARIABLES ###

    @variables(EP, begin
        # Wind capacity 
        vRETWINDCAP[y in RET_CAP_WIND] >= 0                         # Retired wind capacity [MW AC]
        vWINDCAP[y in NEW_CAP_WIND] >= 0                            # New installed wind capacity [MW AC]

        # Wind-component generation [MWh]
        vP_WIND[y in WIND, t = 1:T] >= 0
    end)

    if MultiStage == 1
        @variable(EP, vEXISTINGWINDCAP[y in WIND]>=0)
    end

    ### EXPRESSIONS ###

    # 0. Multistage existing capacity definition
    if MultiStage == 1
        @expression(EP, eExistingCapWind[y in WIND], vEXISTINGWINDCAP[y])
    else
        @expression(EP, eExistingCapWind[y in WIND], by_rid(y, :existing_cap_wind_mw))
    end

    # 1. Total wind capacity
    @expression(EP, eTotalCap_WIND[y in WIND],
        if (y in intersect(NEW_CAP_WIND, RET_CAP_WIND)) # Resources eligible for new capacity and retirements
            eExistingCapWind[y] + EP[:vWINDCAP][y] - EP[:vRETWINDCAP][y]
        elseif (y in setdiff(NEW_CAP_WIND, RET_CAP_WIND)) # Resources eligible for only new capacity
            eExistingCapWind[y] + EP[:vWINDCAP][y]
        elseif (y in setdiff(RET_CAP_WIND, NEW_CAP_WIND)) # Resources eligible for only capacity retirements
            eExistingCapWind[y] - EP[:vRETWINDCAP][y]
        else
            eExistingCapWind[y]
        end)

    # 2. Objective function additions

    # Fixed costs for wind resources (if resource is not eligible for new wind capacity, fixed costs are only O&M costs)
    @expression(EP, eCFixWind[y in WIND],
        if y in NEW_CAP_WIND # Resources eligible for new capacity
            by_rid(y, :inv_cost_wind_per_mwyr) * vWINDCAP[y] +
            by_rid(y, :fixed_om_wind_cost_per_mwyr) * eTotalCap_WIND[y]
        else
            by_rid(y, :fixed_om_wind_cost_per_mwyr) * eTotalCap_WIND[y]
        end)
    @expression(EP, eTotalCFixWind, sum(eCFixWind[y] for y in WIND))

    if MultiStage == 1
        EP[:eObj] += eTotalCFixWind / inputs["OPEXMULT"]
    else
        EP[:eObj] += eTotalCFixWind
    end

    # Variable costs of "generation" for wind resource "y" during hour "t"
    @expression(EP,
        eCVarOutWind[y in WIND, t = 1:T],
        inputs["omega"][t]*by_rid(y, :var_om_cost_per_mwh_wind)*EP[:vP_WIND][y, t])
    @expression(EP, eTotalCVarOutWind, sum(eCVarOutWind[y, t] for y in WIND, t in 1:T))
    EP[:eObj] += eTotalCVarOutWind

    # 3. Inverter Balance, Wind Generation Maximum
    @expression(EP, eWindGenMaxW[y in WIND, t = 1:T], JuMP.AffExpr())
    for y in WIND, t in 1:T
        EP[:eInvACBalance][y, t] += EP[:vP_WIND][y, t]
        eWindGenMaxW[y, t] += EP[:vP_WIND][y, t]
    end

    ### CONSTRAINTS ###

    # Constraint 0: Existing capacity variable is equal to existing capacity specified in the input file
    if MultiStage == 1
        @constraint(EP,
            cExistingCapWind[y in WIND],
            EP[:vEXISTINGWINDCAP][y]==by_rid(y, :existing_cap_wind_mw))
    end

    # Constraints 1: Retirements and capacity additions
    # Cannot retire more capacity than existing capacity for VRE-STOR technologies
    @constraint(EP, cMaxRet_Wind[y = RET_CAP_WIND], vRETWINDCAP[y]<=eExistingCapWind[y])
    # Constraint on maximum capacity (if applicable) [set input to -1 if no constraint on maximum capacity]
    # DEV NOTE: This constraint may be violated in some cases where Existing_Cap_MW is >= Max_Cap_MW and lead to infeasabilty
    @constraint(EP, cMaxCap_Wind[y in ids_with_nonneg(gen_VRE_STOR, max_cap_wind_mw)],
        eTotalCap_WIND[y]<=by_rid(y, :max_cap_wind_mw))
    # Constraint on Minimum capacity (if applicable) [set input to -1 if no constraint on minimum capacity]
    # DEV NOTE: This constraint may be violated in some cases where Existing_Cap_MW is <= Min_Cap_MW and lead to infeasabilty
    @constraint(EP, cMinCap_Wind[y in ids_with_positive(gen_VRE_STOR, min_cap_wind_mw)],
        eTotalCap_WIND[y]>=by_rid(y, :min_cap_wind_mw))

    # Constraint 2: Wind Generation: see main module because capacity reserve margin/operating reserves may alter constraint

    # Constraint 3: Inverter Ratio between wind capacity and grid
    @constraint(EP,
        cInverterRatio_Wind[y in ids_with_positive(gen_VRE_STOR, inverter_ratio_wind)],
        EP[:eTotalCap_WIND][y]==by_rid(y, :inverter_ratio_wind) * EP[:eTotalCap][y])
end

@doc raw"""
    stor_vre_stor!(EP::Model, inputs::Dict, setup::Dict)

This function defines the decision variables, expressions, and constraints for the storage component of each co-located VRE and storage generator.
    A wide range of energy storage devices (all $y \in \mathcal{VS}^{stor}$) can be modeled in GenX, using one of two generic storage formulations: 
    (1) storage technologies with symmetric charge and discharge capacity (all $y \in \mathcal{VS}^{sym,dc} \cup y \in \mathcal{VS}^{sym,ac}$), 
    such as lithium-ion batteries and most other electrochemical storage devices that use the same components for both charge and discharge; and 
    (2) storage technologies that employ distinct and potentially asymmetric charge and discharge capacities (all $y \in \mathcal{VS}^{asym,dc,dis} \cup 
    y \in \mathcal{VS}^{asym,dc,cha} \cup y \in \mathcal{VS}^{asym,ac,dis} \cup y \in \mathcal{VS}^{asym,ac,cha}$), 
    such as most thermal storage technologies or hydrogen electrolysis/storage/fuel cell or combustion turbine systems. The following constraints 
    apply to all storage resources, $y \in \mathcal{VS}^{stor}$, regardless of whether or not the storage has symmetric or asymmetric
    charging/discharging capabilities or varying durations of discharge. 

The total storage energy capacity of each resource is defined as the sum of the existing 
    storage energy capacity plus the newly invested storage energy capacity minus any retired storage energy capacity:
```math
\begin{aligned}
    & \Delta^{total,energy}_{y,z} = (\overline{\Delta^{energy}_{y,z}}+\Omega^{energy}_{y,z}-\Delta^{energy}_{y,z}) \quad \forall y \in \mathcal{VS}^{stor}, z \in \mathcal{Z}
\end{aligned}
```

One cannot retire more energy capacity than existing energy capacity:
```math
\begin{aligned}
    &\Delta^{energy}_{y,z} \leq \overline{\Delta^{energy}_{y,z}}
            \hspace{4 cm}  \forall y \in \mathcal{VS}^{stor}, z \in \mathcal{Z}
\end{aligned}
```
        
For resources where $\overline{\Omega_{y,z}^{energy}}$ and $\underline{\Omega_{y,z}^{energy}}$ are defined, then we impose constraints on minimum and maximum energy capacity:
```math
\begin{aligned}
    & \Delta^{total,energy}_{y,z} \leq \overline{\Omega}^{energy}_{y,z}
        \hspace{4 cm}  \forall y \in \mathcal{VS}^{stor}, z \in \mathcal{Z} \\
    & \Delta^{total,energy}_{y,z}  \geq \underline{\Omega}^{energy}_{y,z}
        \hspace{4 cm}  \forall y \in \mathcal{VS}^{stor}, z \in \mathcal{Z}
\end{aligned}
```

The following two constraints track the state of charge of the storage resources at the end of each time period, relating the volume of energy stored at the end of the time period, $\Gamma_{y,z,t}$, 
    to the state of charge at the end of the prior time period, $\Gamma_{y,z,t-1}$, the DC and AC charge and discharge decisions in the current time period, $\Pi^{dc}_{y,z,t}, \Pi^{ac}_{y,z,t}, \Theta^{dc}_{y,z,t}, \Theta^{ac}_{y,z,t}$, 
    and the self discharge rate for the storage resource (if any), $\eta_{y,z}^{loss}$. When modeling the entire year as a single chronological period with total number of time steps of $\tau^{period}$, 
    storage inventory in the first time step is linked to storage inventory at the last time step of the period representing the year. Alternatively, when modeling the entire year with multiple representative periods, 
    this constraint relates storage inventory in the first timestep of the representative period with the inventory at the last time step of the representative period, where each representative period is made of 
    $\tau^{period}$ time steps. In this implementation, energy exchange between representative periods is not permitted. When modeling representative time periods, GenX enables modeling of long duration 
    energy storage which tracks state of charge between representative periods enable energy to be moved throughout the year. If there is more than one representative period and ```LDS_VRE_STOR=1``` has been enabled for 
    resources in ```Vre_and_stor_data.csv```, this function calls ```lds_vre_stor!()``` to enable this feature. The first of these two constraints enforces storage inventory balance for interior time 
    steps $(t \in \mathcal{T}^{interior})$, while the second enforces storage balance constraint for the initial time step $(t \in \mathcal{T}^{start})$:
```math
\begin{aligned}
	&  \Gamma_{y,z,t} = \Gamma_{y,z,t-1} - \frac{\Theta^{dc}_{y,z,t}}{\eta_{y,z}^{discharge,dc}} - \frac{\Theta^{ac}_{y,z,t}}{\eta_{y,z}^{discharge,ac}} + \eta_{y,z}^{charge,dc} \times \Pi^{dc}_{y,z,t} + \eta_{y,z}^{charge,ac} \times \Pi^{ac}_{y,z,t} \\
    & - \eta_{y,z}^{loss} \times \Gamma_{y,z,t-1}  \quad \forall y \in \mathcal{VS}^{stor}, z \in \mathcal{Z}, t \in \mathcal{T}^{interior}\\
	&  \Gamma_{y,z,t} = \Gamma_{y,z,t+\tau^{period}-1} - \frac{\Theta^{dc}_{y,z,t}}{\eta_{y,z}^{discharge,dc}} - \frac{\Theta^{ac}_{y,z,t}}{\eta_{y,z}^{discharge,ac}} + \eta_{y,z}^{charge,dc} \times \Pi^{dc}_{y,z,t} + \eta_{y,z}^{charge,ac} \times \Pi^{ac}_{y,z,t} \\
    & - \eta_{y,z}^{loss} \times \Gamma_{y,z,t+\tau^{period}-1}  \quad \forall y \in \mathcal{VS}^{stor}, z \in \mathcal{Z}, t \in \mathcal{T}^{start}
\end{aligned}
```

This constraint limits the volume of energy stored at any time, $\Gamma_{y,z,t}$, to be less than the installed energy storage capacity, $\Delta^{total, energy}_{y,z}$. 
```math
\begin{aligned}
	&  \Gamma_{y,z,t} \leq \Delta^{total, energy}_{y,z} & \quad \forall y \in \mathcal{VS}^{stor}, z \in \mathcal{Z}, t \in \mathcal{T}
\end{aligned}
```

The last constraint limits the volume of energy exported from the grid to the storage at any time, $\Pi_{y,z,t}$, to be less than the electricity charged to the energy storage component, $\Pi_{y,z,t}^{ac} + \frac{\Pi^{dc}_{y,z,t}}{\eta^{inverter}_{y,z}}$. 
```math
\begin{aligned}
    & \Pi_{y,z,t} = \Pi_{y,z,t}^{ac} + \frac{\Pi^{dc}_{y,z,t}}{\eta^{inverter}_{y,z}}
\end{aligned}
```

The next set of constraints only apply to symmetric storage resources (all $y \in \mathcal{VS}^{sym,dc} \cup y \in \mathcal{VS}^{sym,ac}$). 
    For storage technologies with symmetric charge and discharge capacity (all $y \in \mathcal{VS}^{sym,dc}  \cup y \in \mathcal{VS}^{sym,ac}$), 
    since storage resources generally represent a 'cluster' of multiple similar storage devices of the same type/cost in the same zone, GenX 
    permits storage resources to simultaneously charge and discharge (as some units could be charging while others discharge). The 
    simultaneous sum of DC and AC charge, $\Pi^{dc}_{y,z,t}, \Pi^{ac}_{y,z,t}$, and discharge, $\Theta^{dc}_{y,z,t}, \Theta^{ac}_{y,z,t}$, is limited 
    by the total installed energy capacity, $\Delta^{total, energy}_{o,z}$, multiplied by the power to energy ratio, $\mu_{y,z}^{dc,stor}, 
    \mu_{y,z}^{ac,stor}$. Without any capacity reserve margin constraints or operating reserves, the symmetric AC and DC storage resources are constrained as:
```math
\begin{aligned}
	&  \Theta^{dc}_{y,z,t} + \Pi^{dc}_{y,z,t} \leq \mu^{dc,stor}_{y,z} \times \Delta^{total,energy}_{y,z} \quad \forall y \in \mathcal{VS}^{sym,dc}, z \in \mathcal{Z}, t \in \mathcal{T} \\
    &  \Theta^{ac}_{y,z,t} + \Pi^{ac}_{y,z,t} \leq \mu^{ac,stor}_{y,z} \times \Delta^{total,energy}_{y,z} \quad \forall y \in \mathcal{VS}^{sym,ac}, z \in \mathcal{Z}, t \in \mathcal{T}
\end{aligned}
```

Symmetric storage resources with only capacity reserve margin constraints follow a similar constraint that incorporates the 'virtual' discharging 
    and charging that occurs and limits the simultaneously charging, discharging, virtual charging, and virtual discharging of the battery resource: 
```math
\begin{aligned}
    &  \Theta^{dc}_{y,z,t} + \Theta^{CRM,dc}_{y,z,t} + \Pi^{dc}_{y,z,t} + \Pi^{CRM,dc}_{y,z,t} \\
    &  \leq \mu^{dc,stor}_{y,z} \times \Delta^{total,energy}_{y,z} \quad \forall y \in \mathcal{VS}^{sym,dc}, z \in \mathcal{Z}, t \in \mathcal{T} \\
    &  \Theta^{ac}_{y,z,t} + \Theta^{CRM,ac}_{y,z,t} + \Pi^{ac}_{y,z,t} + \Pi^{CRM,ac}_{y,z,t} \\
    &   \leq \mu^{ac,stor}_{y,z} \times \Delta^{total,energy}_{y,z} \quad \forall y \in \mathcal{VS}^{sym,ac}, z \in \mathcal{Z}, t \in \mathcal{T}
\end{aligned}
```

Symmetric storage resources only subject to operating reserves have additional variables to represent contributions of frequency regulation and upwards operating reserves while the storage is charging DC or AC 
    ($f^{dc,cha}_{y,z,t}, f^{ac,cha}_{y,z,t}$) and discharging DC or AC ($f^{dc,dis}_{y,z,t}, f^{ac,dis}_{y,z,t}, r^{dc,dis}_{y,z,t}, r^{ac,dis}_{y,z,t}$). Note that as storage resources can contribute to regulation and 
    reserves while either charging or discharging, the proxy variables $f^{dc,cha}_{y,z,t}, f^{ac,cha}_{y,z,t}, f^{dc,dis}_{y,z,t}, f^{ac,dis}_{y,z,t}, r^{dc,dis}_{y,z,t}, r^{ac,dis}_{y,z,t}$ are created for storage 
    components.
```math
\begin{aligned}
    &  \Theta^{dc}_{y,z,t} + f^{dc,dis}_{y,z,t} + r^{dc,dis}_{y,z,t} + \Pi^{dc}_{y,z,t} + f^{dc,cha}_{y,z,t} \\
    &    \leq \mu^{dc,stor}_{y,z} \times \Delta^{total,energy}_{y,z} \quad \forall y \in \mathcal{VS}^{sym,dc}, z \in \mathcal{Z}, t \in \mathcal{T} \\
    &  \Theta^{ac}_{y,z,t} + f^{ac,dis}_{y,z,t} + r^{ac,dis}_{y,z,t} + \Pi^{ac}_{y,z,t} + f^{ac,cha}_{y,z,t} \\
    &    \leq \mu^{ac,stor}_{y,z} \times \Delta^{total,energy}_{y,z} \quad \forall y \in \mathcal{VS}^{sym,ac}, z \in \mathcal{Z}, t \in \mathcal{T}
\end{aligned}
```

For symmetric storage resources with both capacity reserve margin and operating reserves, DC and AC resources are subject to the following constraints:
```math
\begin{aligned}
    &  \Theta^{dc}_{y,z,t} + \Theta^{CRM,dc}_{y,z,t} + f^{dc,dis}_{y,z,t} + r^{dc,dis}_{y,z,t} + \Pi^{dc}_{y,z,t} + \Pi^{CRM,dc}_{y,z,t} + f^{dc,cha}_{y,z,t} \\
    &    \leq \mu^{dc,stor}_{y,z} \times \Delta^{total,energy}_{y,z} \quad \forall y \in \mathcal{VS}^{sym,dc}, z \in \mathcal{Z}, t \in \mathcal{T} \\
    &  \Theta^{ac}_{y,z,t} + \Theta^{CRM,ac}_{y,z,t} + f^{ac,dis}_{y,z,t} + r^{ac,dis}_{y,z,t} + \Pi^{ac}_{y,z,t} + \Pi^{CRM,ac}_{y,z,t} + f^{ac,cha}_{y,z,t} \\
    &    \leq \mu^{ac,stor}_{y,z} \times \Delta^{total,energy}_{y,z} \quad \forall y \in \mathcal{VS}^{sym,ac}, z \in \mathcal{Z}, t \in \mathcal{T}
\end{aligned}
```

Long duration energy storage constraints are activated by the function ```lds_vre_stor!()```. Asymmetric storage resource constraints are activated by the function 
    ```investment_charge_vre_stor!()```.

In addition, this function adds investment, fixed O&M, and variable O&M costs related to the storage capacity to the objective function:
```math
\begin{aligned}
    & 	\sum_{y \in \mathcal{VS}^{stor}} \sum_{z \in \mathcal{Z}}
        \left( (\pi^{INVEST, energy}_{y,z} \times \Omega^{energy}_{y,z}) + (\pi^{FOM, energy}_{y,z} \times  \Delta^{total,energy}_{y,z}) \right) \\
    &   + \sum_{y \in \mathcal{VS}^{sym,dc} \cup \mathcal{VS}^{asym,dc,dis}} \sum_{z \in \mathcal{Z}} \sum_{t \in \mathcal{T}} (\pi^{VOM,dc,dis}_{y,z} \times \eta^{inverter}_{y,z} \times \Theta^{dc}_{y,z,t}) \\
    &   + \sum_{y \in \mathcal{VS}^{sym,dc} \cup \mathcal{VS}^{asym,dc,cha}} \sum_{z \in \mathcal{Z}} \sum_{t \in \mathcal{T}} (\pi^{VOM,dc,cha}_{y,z} \times \frac{\Pi^{dc}_{y,z,t}}{\eta^{inverter}_{y,z}}) \\
    &   + \sum_{y \in \mathcal{VS}^{sym,ac} \cup \mathcal{VS}^{asym,ac,dis}} \sum_{z \in \mathcal{Z}} \sum_{t \in \mathcal{T}} (\pi^{VOM,ac,dis}_{y,z} \times \Theta^{ac}_{y,z,t}) \\
    &   + \sum_{y \in \mathcal{VS}^{sym,ac} \cup \mathcal{VS}^{asym,ac,cha}} \sum_{z \in \mathcal{Z}} \sum_{t \in \mathcal{T}} (\pi^{VOM,ac,cha}_{y,z} \times \Pi^{ac}_{y,z,t})
\end{aligned}
```
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
        # Storage energy capacity
        vCAPENERGY_VS[y in NEW_CAP_STOR] >= 0              # Energy storage reservoir capacity (MWh capacity) built for VRE storage [MWh]
        vRETCAPENERGY_VS[y in RET_CAP_STOR] >= 0           # Energy storage reservoir capacity retired for VRE storage [MWh]

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

    if MultiStage == 1
        @variable(EP, vEXISTINGCAPENERGY_VS[y in STOR]>=0)
    end

    ### EXPRESSIONS ###

    # 0. Multistage existing capacity definition
    if MultiStage == 1
        @expression(EP, eExistingCapEnergy_VS[y in STOR], vEXISTINGCAPENERGY_VS[y])
    else
        @expression(EP, eExistingCapEnergy_VS[y in STOR], existing_cap_mwh(gen[y]))
    end

    # 1. Total storage energy capacity
    @expression(EP, eTotalCap_STOR[y in STOR],
        if (y in intersect(NEW_CAP_STOR, RET_CAP_STOR)) # Resources eligible for new capacity and retirements
            eExistingCapEnergy_VS[y] + EP[:vCAPENERGY_VS][y] - EP[:vRETCAPENERGY_VS][y]
        elseif (y in setdiff(NEW_CAP_STOR, RET_CAP_STOR)) # Resources eligible for only new capacity
            eExistingCapEnergy_VS[y] + EP[:vCAPENERGY_VS][y]
        elseif (y in setdiff(RET_CAP_STOR, NEW_CAP_STOR)) # Resources eligible for only capacity retirements
            eExistingCapEnergy_VS[y] - EP[:vRETCAPENERGY_VS][y]
        else
            eExistingCapEnergy_VS[y]
        end)

    # 2. Objective function additions

    # Fixed costs for storage resources (if resource is not eligible for new energy capacity, fixed costs are only O&M costs)
    @expression(EP, eCFixEnergy_VS[y in STOR],
        if y in NEW_CAP_STOR # Resources eligible for new capacity
            inv_cost_per_mwhyr(gen[y]) * vCAPENERGY_VS[y] +
            fixed_om_cost_per_mwhyr(gen[y]) * eTotalCap_STOR[y]
        else
            fixed_om_cost_per_mwhyr(gen[y]) * eTotalCap_STOR[y]
        end)
    @expression(EP, eTotalCFixStor, sum(eCFixEnergy_VS[y] for y in STOR))

    if MultiStage == 1
        EP[:eObj] += eTotalCFixStor / inputs["OPEXMULT"]
    else
        EP[:eObj] += eTotalCFixStor
    end

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
    EP[:eObj] += eTotalCVarStor

    # 3. Inverter & Power Balance, SoC Expressions

    # Check for rep_periods > 1 & LDS=1
    if rep_periods > 1 && !isempty(VS_LDS)
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
            eSoCBalStart_VRE_STOR[y, t] -= EP[:vP_DC_DISCHARGE][y, t] /
                                           by_rid(y, :eff_down_dc)
        end
        for y in DC_CHARGE_CONSTRAINTSET
            eSoCBalStart_VRE_STOR[y, t] += by_rid(y, :eff_up_dc) * EP[:vP_DC_CHARGE][y, t]
        end
        for y in AC_DISCHARGE_CONSTRAINTSET
            eSoCBalStart_VRE_STOR[y, t] -= EP[:vP_AC_DISCHARGE][y, t] /
                                           by_rid(y, :eff_down_ac)
        end
        for y in AC_CHARGE_CONSTRAINTSET
            eSoCBalStart_VRE_STOR[y, t] += by_rid(y, :eff_up_ac) * EP[:vP_AC_CHARGE][y, t]
        end
    end

    for y in DC_DISCHARGE
        EP[:eELOSS_VRE_STOR][y] -= sum(inputs["omega"][t] * vP_DC_DISCHARGE[y, t] *
                                       by_rid(y, :etainverter) for t in 1:T)
        for t in 1:T
            EP[:eInvACBalance][y, t] += by_rid(y, :etainverter) * vP_DC_DISCHARGE[y, t]
            EP[:eInverterExport][y, t] += by_rid(y, :etainverter) * vP_DC_DISCHARGE[y, t]
        end
        for t in INTERIOR_SUBPERIODS
            eSoCBalInterior_VRE_STOR[y, t] -= EP[:vP_DC_DISCHARGE][y, t] /
                                              by_rid(y, :eff_down_dc)
        end
    end

    for y in DC_CHARGE
        EP[:eELOSS_VRE_STOR][y] += sum(inputs["omega"][t] * vP_DC_CHARGE[y, t] /
                                       by_rid(y, :etainverter) for t in 1:T)
        for t in 1:T
            EP[:eInvACBalance][y, t] -= vP_DC_CHARGE[y, t] / by_rid(y, :etainverter)
            EP[:eCHARGE_VS_STOR][y, t] += vP_DC_CHARGE[y, t] / by_rid(y, :etainverter)
            EP[:eInverterExport][y, t] += vP_DC_CHARGE[y, t] / by_rid(y, :etainverter)
        end
        for t in INTERIOR_SUBPERIODS
            eSoCBalInterior_VRE_STOR[y, t] += by_rid(y, :eff_up_dc) *
                                              EP[:vP_DC_CHARGE][y, t]
        end
    end

    for y in AC_DISCHARGE
        EP[:eELOSS_VRE_STOR][y] -= sum(inputs["omega"][t] * vP_AC_DISCHARGE[y, t]
        for t in 1:T)
        for t in 1:T
            EP[:eInvACBalance][y, t] += vP_AC_DISCHARGE[y, t]
        end
        for t in INTERIOR_SUBPERIODS
            eSoCBalInterior_VRE_STOR[y, t] -= EP[:vP_AC_DISCHARGE][y, t] /
                                              by_rid(y, :eff_down_ac)
        end
    end

    for y in AC_CHARGE
        EP[:eELOSS_VRE_STOR][y] += sum(inputs["omega"][t] * vP_AC_CHARGE[y, t] for t in 1:T)
        for t in 1:T
            EP[:eInvACBalance][y, t] -= vP_AC_CHARGE[y, t]
            EP[:eCHARGE_VS_STOR][y, t] += vP_AC_CHARGE[y, t]
        end
        for t in INTERIOR_SUBPERIODS
            eSoCBalInterior_VRE_STOR[y, t] += by_rid(y, :eff_up_ac) *
                                              EP[:vP_AC_CHARGE][y, t]
        end
    end

    for y in STOR, t in 1:T
        EP[:eInvACBalance][y, t] += vCHARGE_VRE_STOR[y, t]
        EP[:eGridExport][y, t] += vCHARGE_VRE_STOR[y, t]
    end

    for z in 1:Z, t in 1:T
        if !isempty(resources_in_zone_by_rid(gen_VRE_STOR, z))
            EP[:ePowerBalance_VRE_STOR][t, z] -= sum(vCHARGE_VRE_STOR[y, t]
            for y in intersect(resources_in_zone_by_rid(gen_VRE_STOR,
                    z),
                STOR))
        end
    end

    # 4. Energy Share Requirement & CO2 Policy Module

    # From CO2 Policy module
    @expression(EP, eELOSSByZone_VRE_STOR[z = 1:Z],
        sum(EP[:eELOSS_VRE_STOR][y]
        for y in intersect(resources_in_zone_by_rid(gen_VRE_STOR, z), STOR)))
    add_similar_to_expression!(EP[:eELOSSByZone], eELOSSByZone_VRE_STOR)

    ### CONSTRAINTS ###

    # Constraint 0: Existing capacity variable is equal to existing capacity specified in the input file
    if MultiStage == 1
        @constraint(EP,
            cExistingCapEnergy_VS[y in STOR],
            EP[:vEXISTINGCAPENERGY_VS][y]==existing_cap_mwh(gen[y]))
    end

    # Constraints 1: Retirements and capacity additions
    # Cannot retire more capacity than existing capacity for VRE-STOR technologies
    @constraint(EP,
        cMaxRet_Stor[y = RET_CAP_STOR],
        vRETCAPENERGY_VS[y]<=eExistingCapEnergy_VS[y])
    # Constraint on maximum capacity (if applicable) [set input to -1 if no constraint on maximum capacity]
    # DEV NOTE: This constraint may be violated in some cases where Existing_Cap_MW is >= Max_Cap_MW and lead to infeasabilty
    @constraint(EP, cMaxCap_Stor[y in intersect(ids_with_nonneg(gen, max_cap_mwh), STOR)],
        eTotalCap_STOR[y]<=max_cap_mwh(gen[y]))
    # Constraint on minimum capacity (if applicable) [set input to -1 if no constraint on minimum capacity]
    # DEV NOTE: This constraint may be violated in some cases where Existing_Cap_MW is <= Min_Cap_MW and lead to infeasabilty
    @constraint(EP, cMinCap_Stor[y in intersect(ids_with_positive(gen, min_cap_mwh), STOR)],
        eTotalCap_STOR[y]>=min_cap_mwh(gen[y]))

    # Constraint 2: SOC Maximum
    @constraint(EP, cSOCMax[y in STOR, t = 1:T], vS_VRE_STOR[y, t]<=eTotalCap_STOR[y])

    # Constraint 3: State of Charge (energy stored for the next hour)
    @constraint(EP, cSoCBalStart_VRE_STOR[y in CONSTRAINTSET, t in START_SUBPERIODS],
        vS_VRE_STOR[y, t]==eSoCBalStart_VRE_STOR[y, t])
    @constraint(EP, cSoCBalInterior_VRE_STOR[y in STOR, t in INTERIOR_SUBPERIODS],
        vS_VRE_STOR[y, t]==eSoCBalInterior_VRE_STOR[y, t])

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

    ### ASYMMETRIC RESOURCE MODULE ###
    if !isempty(inputs["VS_ASYM"])
        investment_charge_vre_stor!(EP, inputs, setup)
    end

    ### LONG DURATION ENERGY STORAGE RESOURCE MODULE ###
    if rep_periods > 1 && !isempty(VS_LDS)
        lds_vre_stor!(EP, inputs)
    end

    # Constraint 4: electricity charged from the grid cannot exceed the charging capacity of the storage component in VRE_STOR
    @constraint(EP, [y in STOR, t = 1:T], vCHARGE_VRE_STOR[y,t] <= eCHARGE_VS_STOR[y,t])
end

@doc raw"""
    elec_vre_stor!(EP::Model, inputs::Dict)

This function defines the decision variables, expressions, and constraints for the electrolyzer component of each co-located ELC, VRE, and storage generator.
    
The total electrolyzer capacity of each resource is defined as the sum of the existing 
    electrolyzer capacity plus the newly invested electrolyzer capacity minus any retired electrolyzer capacity:
```math
\begin{aligned}
    & \Delta^{total,elec}_{y,z} = (\overline{\Delta^{elec}_{y,z}}+\Omega^{elec}_{y,z}-\Delta^{elec}_{y,z}) \quad \forall y \in \mathcal{VS}^{elec}, z \in \mathcal{Z}
\end{aligned}
```

One cannot retire more energy capacity than existing elec capacity:
```math
\begin{aligned}
    &\Delta^{elec}_{y,z} \leq \overline{\Delta^{elec}_{y,z}}
            \hspace{4 cm}  \forall y \in \mathcal{VS}^{elec}, z \in \mathcal{Z}
\end{aligned}
```
        
For resources where $\overline{\Omega_{y,z}^{elec}}$ and $\underline{\Omega_{y,z}^{elec}}$ are defined, then we impose constraints on minimum and maximum energy capacity:
```math
\begin{aligned}
    & \Delta^{total,elec}_{y,z} \leq \overline{\Omega}^{elec}_{y,z}
        \hspace{4 cm}  \forall y \in \mathcal{VS}^{elec}, z \in \mathcal{Z} \\
    & \Delta^{total,elec}_{y,z}  \geq \underline{\Omega}^{elec}_{y,z}
        \hspace{4 cm}  \forall y \in \mathcal{VS}^{elec}, z \in \mathcal{Z}
\end{aligned}
```
Constraint 2 applies ramping constraints on electrolyzers where consumption of electricity by electrolyzer $y$ in time $t$ is denoted by $\Pi_{y,z}$ and the rampping constraints are denoated by $\kappa_{y}$.
```math
\begin{aligned}
	\Pi_{y,t-1} - \Pi_{y,t} \leq \kappa_{y}^{down} \Delta^{\text{total}}_{y}, \hspace{1cm} \forall y \in \mathcal{EL}, \forall t \in \mathcal{T}
\end{aligned}
```

```math
\begin{aligned}
	\Pi_{y,t} - \Pi_{y,t-1} \leq \kappa_{y}^{up} \Delta^{\text{total}}_{y} \hspace{1cm} \forall y \in \mathcal{EL}, \forall t \in \mathcal{T}
\end{aligned}
```

In constraint 3, electrolyzers are bound by the following limits on maximum and minimum power output. Maximum power output is 100% in this case.

```math
\begin{aligned}
	\Pi_{y,t} \geq \rho^{min}_{y} \times \Delta^{total}_{y}
	\hspace{1cm} \forall y \in \mathcal{EL}, \forall t \in \mathcal{T}
\end{aligned}
```

```math
\begin{aligned}
	\Theta_{y,t} \leq \Pi^{total}_{y}
	\hspace{1cm} \forall y \in \mathcal{EL}, \forall t \in \mathcal{T}
\end{aligned}
```
The regional demand requirement is included in electrolyzer.jl
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

    ### ELEC VARIABLES ###

    @variables(EP, begin
        # Electrolyzer capacity 
        vRETELECCAP[y in RET_CAP_ELEC] >= 0                         # Retired electrolyzer capacity [MW AC]
        vELECCAP[y in NEW_CAP_ELEC] >= 0                            # New installed electrolyzer capacity [MW AC]

        # Electrolyzer-component generation [MWh]
        vP_ELEC[y in ELEC, t = 1:T] >= 0
    end)

    if MultiStage == 1
        @variable(EP, vEXISTINGELECCAP[y in ELEC]>=0)
    end

    ### EXPRESSIONS ###

    # 0. Multistage existing capacity definition
    if MultiStage == 1
        @expression(EP, eExistingCapElec[y in ELEC], vEXISTINGELECCAP[y])
    else
        @expression(EP, eExistingCapElec[y in ELEC], by_rid(y, :existing_cap_elec_mw))
    end

    # 1. Total electrolyzer capacity
    @expression(EP, eTotalCap_ELEC[y in ELEC],
        if (y in intersect(NEW_CAP_ELEC, RET_CAP_ELEC)) # Resources eligible for new capacity and retirements
            eExistingCapElec[y] + EP[:vELECCAP][y] - EP[:vRETELECCAP][y]
        elseif (y in setdiff(NEW_CAP_ELEC, RET_CAP_ELEC)) # Resources eligible for only new capacity
            eExistingCapElec[y] + EP[:vELECCAP][y]
        elseif (y in setdiff(RET_CAP_ELEC, NEW_CAP_ELEC)) # Resources eligible for only capacity retirements
            eExistingCapElec[y] - EP[:vRETELECCAP][y]
        else
            eExistingCapElec[y]
        end)

    # 2. Objective function additions

    # Fixed costs for electrolyzer resources (if resource is not eligible for new electrolyzer capacity, fixed costs are only O&M costs)
    @expression(EP, eCFixElec[y in ELEC],
        if y in NEW_CAP_ELEC # Resources eligible for new capacity
            by_rid(y, :inv_cost_elec_per_mwyr) * vELECCAP[y] +
            by_rid(y, :fixed_om_elec_cost_per_mwyr) * eTotalCap_ELEC[y]
        else
            by_rid(y, :fixed_om_elec_cost_per_mwyr) * eTotalCap_ELEC[y]
        end)
    @expression(EP, eTotalCFixElec, sum(eCFixElec[y] for y in ELEC))

    if MultiStage == 1
        EP[:eObj] += eTotalCFixElec / inputs["OPEXMULT"]
    else
        EP[:eObj] += eTotalCFixElec
    end

    # No variable costs of "generation" for electrolyzer resource

    # 3. Inverter Balance, Electrolyzer Generation Maximum
    @expression(EP, eElecGenMaxE[y in ELEC, t = 1:T], JuMP.AffExpr())
    for y in ELEC, t in 1:T
        EP[:eInvACBalance][y, t] -= EP[:vP_ELEC][y, t]
        eElecGenMaxE[y, t] += EP[:vP_ELEC][y, t]
    end

    ### CONSTRAINTS ###

    # Constraint 0: Existing capacity variable is equal to existing capacity specified in the input file
    if MultiStage == 1
        @constraint(EP, cExistingCapElec[y in ELEC],
            EP[:vEXISTINGELECCAP][y]==by_rid(y, :existing_cap_elec_mw))
    end

    # Constraints 1: Retirements and capacity additions
    # Cannot retire more capacity than existing capacity for VRE-STOR technologies
    @constraint(EP, cMaxRet_Elec[y = RET_CAP_ELEC], vRETELECCAP[y]<=eExistingCapElec[y])
    # Constraint on maximum capacity (if applicable) [set input to -1 if no constraint on maximum capacity]
    # DEV NOTE: This constraint may be violated in some cases where Existing_Cap_MW is >= Max_Cap_MW and lead to infeasabilty
    @constraint(EP, cMaxCap_Elec[y in ids_with_nonneg(gen_VRE_STOR, max_cap_elec_mw)],
        eTotalCap_ELEC[y]<=by_rid(y, :max_cap_elec_mw))
    # Constraint on Minimum capacity (if applicable) [set input to -1 if no constraint on minimum capacity]
    # DEV NOTE: This constraint may be violated in some cases where Existing_Cap_MW is <= Min_Cap_MW and lead to infeasabilty
    @constraint(EP, cMinCap_Elec[y in ids_with_positive(gen_VRE_STOR, min_cap_elec_mw)],
        eTotalCap_ELEC[y]>=by_rid(y, :min_cap_elec_mw))

    # Constraint 2: Maximum ramp up and down between consecutive hours
    p = inputs["hours_per_subperiod"] #total number of hours per subperiod
    @constraints(EP,
        begin
            ## Maximum ramp up between consecutive hours
            [y in ELEC, t in 1:T],
            EP[:vP_ELEC][y, t] - EP[:vP_ELEC][y, hoursbefore(p, t, 1)] <=
            by_rid(y, :ramp_up_percentage_elec) * eTotalCap_ELEC[y]

            ## Maximum ramp down between consecutive hours
            [y in ELEC, t in 1:T],
            EP[:vP_ELEC][y, hoursbefore(p, t, 1)] - EP[:vP_ELEC][y, t] <=
            by_rid(y, :ramp_dn_percentage_elec) * eTotalCap_ELEC[y]
        end)

    # Constraint 3: Minimum and maximum power output constraints (Constraints #3-4)
    # Electrolyzers currently do not contribute to operating reserves, so there is not
    # special case (for Reserves == 1) here.
    # Could allow them to contribute as a curtailable demand in future.
    @constraints(EP,
        begin
            # Minimum stable power generated per technology "y" at hour "t" Min_Power
            [y in ELEC, t in 1:T],
            EP[:vP_ELEC][y, t] >= by_rid(y, :min_power_elec) * eTotalCap_ELEC[y]

            # Maximum power generated per technology "y" at hour "t"
            [y in ELEC, t in 1:T], EP[:vP_ELEC][y, t] <= eTotalCap_ELEC[y]
        end)
end

@doc raw"""
    lds_vre_stor!(EP::Model, inputs::Dict)

This function defines the decision variables, expressions, and constraints for any 
    long duration energy storage component of each co-located VRE and storage generator (
    there is more than one representative period and ```LDS_VRE_STOR=1``` in the ```Vre_and_stor_data.csv```). 

These constraints follow the same formulation that is outlined by the function ```long_duration_storage!()``` 
    in the storage module. One constraint changes, which links the state of charge between the start of periods 
    for long duration energy storage resources because there are options to charge and discharge these resources 
    through AC and DC capabilities. The main linking constraint changes to:

```math
\begin{aligned}
    & \Gamma_{y,z,(m-1)\times \tau^{period}+1 } =\left(1-\eta_{y,z}^{loss}\right) \times \left(\Gamma_{y,z,m\times \tau^{period}} -\Delta Q_{y,z,m}\right) \\
    & - \frac{\Theta^{dc}_{y,z,(m-1) \times \tau^{period}+1}}{\eta_{y,z}^{discharge,dc}} - \frac{\Theta^{ac}_{y,z,(m-1)\times \tau^{period}+1}}{\eta_{y,z}^{discharge,ac}} \\
    & + \eta_{y,z}^{charge,dc} \times \Pi^{dc}_{y,z,(m-1)\times \tau^{period}+1} + \eta_{y,z}^{charge,ac} \times \Pi^{ac}_{y,z,(m-1)\times \tau^{period}+1} \quad \forall y \in \mathcal{VS}^{LDES}, z \in \mathcal{Z}, m \in \mathcal{M}
\end{aligned}
```
    
The rest of the long duration energy storage constraints are copied and applied to the co-located VRE and storage module for any 
    long duration energy storage resources $y \in \mathcal{VS}^{LDES}$ from the long-duration storage module. Capacity reserve margin constraints for 
    long duration energy storage resources are further elaborated upon in ```vre_stor_capres!()```.
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
            EP[:eVreStorSoCBalLongDurationStorageStart][y, w] -= EP[:vP_DC_DISCHARGE][y,
                hours_per_subperiod * (w - 1) + 1] / by_rid(y, :eff_down_dc)
        end

        for y in DC_CHARGE_CONSTRAINTSET
            EP[:eVreStorSoCBalLongDurationStorageStart][y, w] += by_rid(y, :eff_up_dc) *
                                                                 EP[:vP_DC_CHARGE][y,
                hours_per_subperiod * (w - 1) + 1]
        end

        for y in AC_DISCHARGE_CONSTRAINTSET
            EP[:eVreStorSoCBalLongDurationStorageStart][y, w] -= EP[:vP_AC_DISCHARGE][y,
                hours_per_subperiod * (w - 1) + 1] / by_rid(y, :eff_down_ac)
        end

        for y in AC_CHARGE_CONSTRAINTSET
            EP[:eVreStorSoCBalLongDurationStorageStart][y, w] += by_rid(y, :eff_up_ac) *
                                                                 EP[:vP_AC_CHARGE][y,
                hours_per_subperiod * (w - 1) + 1]
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
    investment_charge_vre_stor!(EP::Model, inputs::Dict, setup::Dict)

This function activates the decision variables and constraints for asymmetric storage resources (independent charge
    and discharge power capacities (any STOR flag = 2)). For asymmetric storage resources, the function is enabled so charging 
    and discharging can occur either through DC or AC capabilities. For example, a storage resource can be asymmetrically charged 
    and discharged via DC capabilities or a storage resource could be charged via AC capabilities and discharged through DC capabilities. 
    This module is configured such that both AC and DC charging (or discharging) cannot simultaneously occur.

The total charge/discharge DC and AC capacities of each resource are defined as the sum of the existing charge/discharge DC and AC capacities plus 
    the newly invested charge/discharge DC and AC capacities minus any retired charge/discharge DC and AC capacities:

```math
\begin{aligned}
    & \Delta^{total,dc,dis}_{y,z} =(\overline{\Delta^{dc,dis}_{y,z}}+\Omega^{dc,dis}_{y,z}-\Delta^{dc,dis}_{y,z}) \quad \forall y \in \mathcal{VS}^{asym,dc,dis}, z \in \mathcal{Z} \\
    & \Delta^{total,dc,cha}_{y,z} =(\overline{\Delta^{dc,cha}_{y,z}}+\Omega^{dc,cha}_{y,z}-\Delta^{dc,cha}_{y,z}) \quad \forall y \in \mathcal{VS}^{asym,dc,cha}, z \in \mathcal{Z} \\
    & \Delta^{total,ac,dis}_{y,z} =(\overline{\Delta^{ac,dis}_{y,z}}+\Omega^{ac,dis}_{y,z}-\Delta^{ac,dis}_{y,z}) \quad \forall y \in \mathcal{VS}^{asym,ac,dis}, z \in \mathcal{Z} \\
    & \Delta^{total,ac,cha}_{y,z} =(\overline{\Delta^{ac,cha}_{y,z}}+\Omega^{ac,cha}_{y,z}-\Delta^{ac,cha}_{y,z}) \quad \forall y \in \mathcal{VS}^{asym,ac,cha}, z \in \mathcal{Z}
\end{aligned}
```

One cannot retire more capacity than existing capacity:
```math
\begin{aligned}
    &\Delta^{dc,dis}_{y,z} \leq \overline{\Delta^{dc,dis}_{y,z}}
        \hspace{4 cm}  \forall y \in \mathcal{VS}^{asym,dc,dis}, z \in \mathcal{Z} \\
    &\Delta^{dc,cha}_{y,z} \leq \overline{\Delta^{dc,cha}_{y,z}}
        \hspace{4 cm}  \forall y \in \mathcal{VS}^{asym,dc,cha}, z \in \mathcal{Z} \\
    &\Delta^{ac,dis}_{y,z} \leq \overline{\Delta^{ac,dis}_{y,z}}
        \hspace{4 cm}  \forall y \in \mathcal{VS}^{asym,ac,dis}, z \in \mathcal{Z} \\
    &\Delta^{ac,cha}_{y,z} \leq \overline{\Delta^{ac,cha}_{y,z}}
        \hspace{4 cm}  \forall y \in \mathcal{VS}^{asym,ac,cha}, z \in \mathcal{Z}
\end{aligned}
```

For resources where $\overline{\Omega_{y,z}^{dc,dis}}, \overline{\Omega_{y,z}^{dc,cha}}, \overline{\Omega_{y,z}^{ac,dis}}, \overline{\Omega_{y,z}^{ac,cha}}$ 
    and $\underline{\Omega_{y,z}^{dc,dis}}, \underline{\Omega_{y,z}^{dc,cha}}, \underline{\Omega_{y,z}^{ac,dis}}, \underline{\Omega_{y,z}^{ac, cha}}$ are defined, 
    then we impose constraints on minimum and maximum charge/discharge DC and AC power capacity:
```math
\begin{aligned}
    & \Delta^{total,dc,dis}_{y,z} \leq \overline{\Omega}^{dc,dis}_{y,z}
        \hspace{4 cm}  \forall y \in \mathcal{VS}^{asym,dc,dis}, z \in \mathcal{Z} \\
    & \Delta^{total,dc,dis}_{y,z}  \geq \underline{\Omega}^{dc,dis}_{y,z}
        \hspace{4 cm}  \forall y \in \mathcal{VS}^{asym,dc,dis}, z \in \mathcal{Z} \\
    & \Delta^{total,dc,cha}_{y,z} \leq \overline{\Omega}^{dc,cha}_{y,z}
        \hspace{4 cm}  \forall y \in \mathcal{VS}^{asym,dc,cha}, z \in \mathcal{Z} \\
    & \Delta^{total,dc,cha}_{y,z}  \geq \underline{\Omega}^{dc,cha}_{y,z}
        \hspace{4 cm}  \forall y \in \mathcal{VS}^{asym,dc,cha}, z \in \mathcal{Z} \\
    & \Delta^{total,ac,dis}_{y,z} \leq \overline{\Omega}^{ac,dis}_{y,z}
        \hspace{4 cm}  \forall y \in \mathcal{VS}^{asym,ac,dis}, z \in \mathcal{Z} \\
    & \Delta^{total,ac,dis}_{y,z}  \geq \underline{\Omega}^{ac,dis}_{y,z}
        \hspace{4 cm}  \forall y \in \mathcal{VS}^{asym,ac,dis}, z \in \mathcal{Z} \\
    & \Delta^{total,ac,cha}_{y,z} \leq \overline{\Omega}^{ac,cha}_{y,z}
        \hspace{4 cm}  \forall y \in \mathcal{VS}^{asym,ac,cha}, z \in \mathcal{Z} \\
    & \Delta^{total,ac,cha}_{y,z}  \geq \underline{\Omega}^{ac,cha}_{y,z}
        \hspace{4 cm}  \forall y \in \mathcal{VS}^{asym,ac,cha}, z \in \mathcal{Z} \\
\end{aligned}
```

Furthermore, for storage technologies with asymmetric charge and discharge capacities (all $y \in \mathcal{VS}^{asym,dc,dis}, 
    y \in \mathcal{VS}^{asym,dc,cha}, y \in \mathcal{VS}^{asym,ac,dis}, y \in \mathcal{VS}^{asym,ac,cha}$), the charge rate, 
    $\Pi^{dc}_{y,z,t}, \Pi^{ac}_{y,z,t}$, is constrained by the total installed charge capacity, $\Delta^{total,dc,cha}_{y,z}, 
    \Delta^{total,ac,cha}_{y,z}$. Similarly the discharge rate, $\Theta^{dc}_{y,z,t}, \Theta^{ac}_{y,z,t}$, is constrained by the 
    total installed discharge capacity, $\Delta^{total,dc,dis}_{y,z}, \Delta^{total,ac,dis}_{y,z}$. Without any activated 
    capacity reserve margin policies or operating reserves, the constraints are as follows:
```math
\begin{aligned}
    &  \Theta^{dc}_{y,z,t} \leq \Delta^{total,dc,dis}_{y,z} \quad \forall y \in \mathcal{VS}^{asym,dc,dis}, z \in \mathcal{Z}, t \in \mathcal{T} \\
	&  \Pi^{dc}_{y,z,t} \leq \Delta^{total,dc,cha}_{y,z} \quad \forall y \in \mathcal{VS}^{asym,dc,cha}, z \in \mathcal{Z}, t \in \mathcal{T} \\
    &  \Theta^{ac}_{y,z,t} \leq \Delta^{total,ac,dis}_{y,z} \quad \forall y \in \mathcal{VS}^{asym,ac,dis}, z \in \mathcal{Z}, t \in \mathcal{T} \\
	&  \Pi^{ac}_{y,z,t} \leq \Delta^{total,ac,cha}_{y,z} \quad \forall y \in \mathcal{VS}^{asym,ac,cha}, z \in \mathcal{Z}, t \in \mathcal{T} \\
\end{aligned}
```

Adding only the capacity reserve margin constraints, the asymmetric charge and discharge DC and AC rates plus the 'virtual' charge and discharge DC and AC rates are 
    constrained by the total installed charge and discharge DC and AC capacities:
```math
\begin{aligned}
    &  \Theta^{dc}_{y,z,t} + \Theta^{CRM,dc}_{y,z,t} \leq \Delta^{total,dc,dis}_{y,z} \quad \forall y \in \mathcal{VS}^{asym,dc,dis}, z \in \mathcal{Z}, t \in \mathcal{T} \\
	&  \Pi^{dc}_{y,z,t} + \Pi^{CRM,dc}_{y,z,t} \leq \Delta^{total,dc,cha}_{y,z} \quad \forall y \in \mathcal{VS}^{asym,dc,cha}, z \in \mathcal{Z}, t \in \mathcal{T} \\
    &  \Theta^{ac}_{y,z,t} + \Theta^{CRM,ac}_{y,z,t} \leq \Delta^{total,ac,dis}_{y,z} \quad \forall y \in \mathcal{VS}^{asym,ac,dis}, z \in \mathcal{Z}, t \in \mathcal{T} \\
	&  \Pi^{ac}_{y,z,t} + \Pi^{CRM,ac}_{y,z,t} \leq \Delta^{total,ac,cha}_{y,z} \quad \forall y \in \mathcal{VS}^{asym,ac,cha}, z \in \mathcal{Z}, t \in \mathcal{T} \\
\end{aligned}
```

Adding only the operating reserve constraints, the asymmetric charge and discharge DC and AC rates plus the contributions to frequency regulation and operating reserves (both DC and AC) are 
    constrained by the total installed charge and discharge DC and AC capacities:
```math
\begin{aligned}
    &  \Theta^{dc}_{y,z,t} + f^{dc,dis}_{y,z,t} + r^{dc,dis}_{y,z,t} \leq \Delta^{total,dc,dis}_{y,z} \quad \forall y \in \mathcal{VS}^{asym,dc,dis}, z \in \mathcal{Z}, t \in \mathcal{T} \\
	&  \Pi^{dc}_{y,z,t} + f^{dc,cha}_{y,z,t} \leq \Delta^{total,dc,cha}_{y,z} \quad \forall y \in \mathcal{VS}^{asym,dc,cha}, z \in \mathcal{Z}, t \in \mathcal{T} \\
    &  \Theta^{ac}_{y,z,t} + f^{ac,dis}_{y,z,t} + r^{ac,dis}_{y,z,t} \leq \Delta^{total,ac,dis}_{y,z} \quad \forall y \in \mathcal{VS}^{asym,ac,dis}, z \in \mathcal{Z}, t \in \mathcal{T} \\
	&  \Pi^{ac}_{y,z,t} + f^{ac,cha}_{y,z,t} \leq \Delta^{total,ac,cha}_{y,z} \quad \forall y \in \mathcal{VS}^{asym,ac,cha}, z \in \mathcal{Z}, t \in \mathcal{T} \\
\end{aligned}
```

With both capacity reserve margin and operating reserve constraints, the asymmetric charge and discharge DC and AC rate constraints follow: 
```math
\begin{aligned}
    &  \Theta^{dc}_{y,z,t} + \Theta^{CRM,dc}_{y,z,t} + f^{dc,dis}_{y,z,t} + r^{dc,dis}_{y,z,t} \leq \Delta^{total,dc,dis}_{y,z} \quad \forall y \in \mathcal{VS}^{asym,dc,dis}, z \in \mathcal{Z}, t \in \mathcal{T} \\
	&  \Pi^{dc}_{y,z,t} + \Pi^{CRM,dc}_{y,z,t} + f^{dc,cha}_{y,z,t} \leq \Delta^{total,dc,cha}_{y,z} \quad \forall y \in \mathcal{VS}^{asym,dc,cha}, z \in \mathcal{Z}, t \in \mathcal{T} \\
    &  \Theta^{ac}_{y,z,t} + \Theta^{CRM,ac}_{y,z,t} + f^{ac,dis}_{y,z,t} + r^{ac,dis}_{y,z,t} \leq \Delta^{total,ac,dis}_{y,z} \quad \forall y \in \mathcal{VS}^{asym,ac,dis}, z \in \mathcal{Z}, t \in \mathcal{T} \\
	&  \Pi^{ac}_{y,z,t} + \Pi^{CRM,ac}_{y,z,t} + f^{ac,cha}_{y,z,t} \leq \Delta^{total,ac,cha}_{y,z} \quad \forall y \in \mathcal{VS}^{asym,ac,cha}, z \in \mathcal{Z}, t \in \mathcal{T} \\
\end{aligned}
```

In addition, this function adds investment and fixed O&M costs related to charge/discharge AC and DC capacities to the objective function:
```math
\begin{aligned}
    & 	\sum_{y \in \mathcal{VS}^{asym,dc,dis} } \sum_{z \in \mathcal{Z}}
        \left( (\pi^{INVEST,dc,dis}_{y,z} \times \Omega^{dc,dis}_{y,z})
        + (\pi^{FOM,dc,dis}_{y,z} \times \Delta^{total,dc,dis}_{y,z})\right) \\
    & 	+ \sum_{y \in \mathcal{VS}^{asym,dc,cha} } \sum_{z \in \mathcal{Z}}
        \left( (\pi^{INVEST,dc,cha}_{y,z} \times \Omega^{dc,cha}_{y,z})
        + (\pi^{FOM,dc,cha}_{y,z} \times \Delta^{total,dc,cha}_{y,z})\right) \\
    & 	+ \sum_{y \in \mathcal{VS}^{asym,ac,dis} } \sum_{z \in \mathcal{Z}}
        \left( (\pi^{INVEST,ac,dis}_{y,z} \times \Omega^{ac,dis}_{y,z})
        + (\pi^{FOM,ac,dis}_{y,z} \times \Delta^{total,ac,dis}_{y,z})\right) \\
    & 	+ \sum_{y \in \mathcal{VS}^{asym,ac,cha} } \sum_{z \in \mathcal{Z}}
        \left( (\pi^{INVEST,ac,cha}_{y,z} \times \Omega^{ac,cha}_{y,z})
        + (\pi^{FOM,ac,cha}_{y,z} \times \Delta^{total,ac,cha}_{y,z})\right)
\end{aligned}
```
"""
function investment_charge_vre_stor!(EP::Model, inputs::Dict, setup::Dict)
    println("VRE-STOR Charge Investment Module")

    ### LOAD INPUTS ###
    gen = inputs["RESOURCES"]
    gen_VRE_STOR = gen.VreStorage

    T = inputs["T"]
    VS_ASYM_DC_CHARGE = inputs["VS_ASYM_DC_CHARGE"]
    VS_ASYM_AC_CHARGE = inputs["VS_ASYM_AC_CHARGE"]
    VS_ASYM_DC_DISCHARGE = inputs["VS_ASYM_DC_DISCHARGE"]
    VS_ASYM_AC_DISCHARGE = inputs["VS_ASYM_AC_DISCHARGE"]

    NEW_CAP_CHARGE_DC = inputs["NEW_CAP_CHARGE_DC"]
    RET_CAP_CHARGE_DC = inputs["RET_CAP_CHARGE_DC"]
    NEW_CAP_CHARGE_AC = inputs["NEW_CAP_CHARGE_AC"]
    RET_CAP_CHARGE_AC = inputs["RET_CAP_CHARGE_AC"]
    NEW_CAP_DISCHARGE_DC = inputs["NEW_CAP_DISCHARGE_DC"]
    RET_CAP_DISCHARGE_DC = inputs["RET_CAP_DISCHARGE_DC"]
    NEW_CAP_DISCHARGE_AC = inputs["NEW_CAP_DISCHARGE_AC"]
    RET_CAP_DISCHARGE_AC = inputs["RET_CAP_DISCHARGE_AC"]

    MultiStage = setup["MultiStage"]

    by_rid(rid, sym) = by_rid_res(rid, sym, gen_VRE_STOR)

    if !isempty(VS_ASYM_DC_DISCHARGE)
        MAX_DC_DISCHARGE = intersect(
            ids_with_nonneg(gen_VRE_STOR, max_cap_discharge_dc_mw),
            VS_ASYM_DC_DISCHARGE)
        MIN_DC_DISCHARGE = intersect(
            ids_with_positive(gen_VRE_STOR,
                min_cap_discharge_dc_mw),
            VS_ASYM_DC_DISCHARGE)

        ### VARIABLES ###
        @variables(EP, begin
            vCAPDISCHARGE_DC[y in NEW_CAP_DISCHARGE_DC] >= 0            # Discharge capacity DC component built for VRE storage [MW]
            vRETCAPDISCHARGE_DC[y in RET_CAP_DISCHARGE_DC] >= 0         # Discharge capacity DC component retired for VRE storage [MW]
        end)

        if MultiStage == 1
            @variable(EP, vEXISTINGCAPDISCHARGEDC[y in VS_ASYM_DC_DISCHARGE]>=0)
        end

        ### EXPRESSIONS ###

        # 0. Multistage existing capacity definition
        if MultiStage == 1
            @expression(EP,
                eExistingCapDischargeDC[y in VS_ASYM_DC_DISCHARGE],
                vEXISTINGCAPDISCHARGEDC[y])
        else
            @expression(EP,
                eExistingCapDischargeDC[y in VS_ASYM_DC_DISCHARGE],
                by_rid(y, :existing_cap_discharge_dc_mw))
        end

        # 1. Total storage discharge DC capacity
        @expression(EP, eTotalCapDischarge_DC[y in VS_ASYM_DC_DISCHARGE],
            if (y in intersect(NEW_CAP_DISCHARGE_DC, RET_CAP_DISCHARGE_DC))
                eExistingCapDischargeDC[y] + EP[:vCAPDISCHARGE_DC][y] -
                EP[:vRETCAPDISCHARGE_DC][y]
            elseif (y in setdiff(NEW_CAP_DISCHARGE_DC, RET_CAP_DISCHARGE_DC))
                eExistingCapDischargeDC[y] + EP[:vCAPDISCHARGE_DC][y]
            elseif (y in setdiff(RET_CAP_DISCHARGE_DC, NEW_CAP_DISCHARGE_DC))
                eExistingCapDischargeDC[y] - EP[:vRETCAPDISCHARGE_DC][y]
            else
                eExistingCapDischargeDC[y]
            end)

        # 2. Objective Function Additions

        # If resource is not eligible for new discharge DC capacity, fixed costs are only O&M costs
        @expression(EP, eCFixDischarge_DC[y in VS_ASYM_DC_DISCHARGE],
            if y in NEW_CAP_DISCHARGE_DC # Resources eligible for new discharge DC capacity
                by_rid(y, :inv_cost_discharge_dc_per_mwyr) * vCAPDISCHARGE_DC[y] +
                by_rid(y, :fixed_om_cost_discharge_dc_per_mwyr) * eTotalCapDischarge_DC[y]
            else
                by_rid(y, :fixed_om_cost_discharge_dc_per_mwyr) * eTotalCapDischarge_DC[y]
            end)

        # Sum individual resource contributions to fixed costs to get total fixed costs
        @expression(EP,
            eTotalCFixDischarge_DC,
            sum(EP[:eCFixDischarge_DC][y] for y in VS_ASYM_DC_DISCHARGE))

        if MultiStage == 1
            EP[:eObj] += eTotalCFixDischarge_DC / inputs["OPEXMULT"]
        else
            EP[:eObj] += eTotalCFixDischarge_DC
        end

        ### CONSTRAINTS ###

        # Constraint 0: Existing capacity variable is equal to existing capacity specified in the input file
        if MultiStage == 1
            @constraint(EP,
                cExistingCapDischargeDC[y in VS_ASYM_DC_DISCHARGE],
                EP[:vEXISTINGCAPDISCHARGEDC][y]==by_rid(y, :existing_cap_discharge_dc_mw))
        end

        # Constraints 1: Retirements and capacity additions
        # Cannot retire more discharge DC capacity than existing discharge capacity
        @constraint(EP,
            cVreStorMaxRetDischargeDC[y in RET_CAP_DISCHARGE_DC],
            vRETCAPDISCHARGE_DC[y]<=eExistingCapDischargeDC[y])
        # Constraint on maximum discharge DC capacity (if applicable) [set input to -1 if no constraint on maximum discharge capacity]
        # DEV NOTE: This constraint may be violated in some cases where Existing_Charge_Cap_MW is >= Max_Charge_Cap_MWh and lead to infeasabilty
        @constraint(EP,
            cVreStorMaxCapDischargeDC[y in MAX_DC_DISCHARGE],
            eTotalCapDischarge_DC[y]<=by_rid(y, :Max_Cap_Discharge_DC_MW))
        # Constraint on minimum discharge DC capacity (if applicable) [set input to -1 if no constraint on minimum discharge capacity]
        # DEV NOTE: This constraint may be violated in some cases where Existing_Charge_Cap_MW is <= Min_Charge_Cap_MWh and lead to infeasabilty
        @constraint(EP,
            cVreStorMinCapDischargeDC[y in MIN_DC_DISCHARGE],
            eTotalCapDischarge_DC[y]>=by_rid(y, :Min_Cap_Discharge_DC_MW))

        # Constraint 2: Maximum discharging must be less than discharge power rating
        @expression(EP,
            eVreStorMaxDischargingDC[y in VS_ASYM_DC_DISCHARGE, t = 1:T],
            JuMP.AffExpr())
        for y in VS_ASYM_DC_DISCHARGE, t in 1:T
            eVreStorMaxDischargingDC[y, t] += EP[:vP_DC_DISCHARGE][y, t]
        end
    end

    if !isempty(VS_ASYM_DC_CHARGE)
        MAX_DC_CHARGE = intersect(ids_with_nonneg(gen_VRE_STOR, max_cap_charge_dc_mw),
            VS_ASYM_DC_CHARGE)
        MIN_DC_CHARGE = intersect(ids_with_positive(gen_VRE_STOR, min_cap_charge_dc_mw),
            VS_ASYM_DC_CHARGE)

        ### VARIABLES ###
        @variables(EP, begin
            vCAPCHARGE_DC[y in NEW_CAP_CHARGE_DC] >= 0               # Charge capacity DC component built for VRE storage [MW]
            vRETCAPCHARGE_DC[y in RET_CAP_CHARGE_DC] >= 0            # Charge capacity DC component retired for VRE storage [MW]
        end)

        if MultiStage == 1
            @variable(EP, vEXISTINGCAPCHARGEDC[y in VS_ASYM_DC_CHARGE]>=0)
        end

        ### EXPRESSIONS ###

        # 0. Multistage existing capacity definition
        if MultiStage == 1
            @expression(EP,
                eExistingCapChargeDC[y in VS_ASYM_DC_CHARGE],
                vEXISTINGCAPCHARGEDC[y])
        else
            @expression(EP,
                eExistingCapChargeDC[y in VS_ASYM_DC_CHARGE],
                by_rid(y, :existing_cap_charge_dc_mw))
        end

        # 1. Total storage charge DC capacity
        @expression(EP, eTotalCapCharge_DC[y in VS_ASYM_DC_CHARGE],
            if (y in intersect(NEW_CAP_CHARGE_DC, RET_CAP_CHARGE_DC))
                eExistingCapChargeDC[y] + EP[:vCAPCHARGE_DC][y] - EP[:vRETCAPCHARGE_DC][y]
            elseif (y in setdiff(NEW_CAP_CHARGE_DC, RET_CAP_CHARGE_DC))
                eExistingCapChargeDC[y] + EP[:vCAPCHARGE_DC][y]
            elseif (y in setdiff(RET_CAP_CHARGE_DC, NEW_CAP_CHARGE_DC))
                eExistingCapChargeDC[y] - EP[:vRETCAPCHARGE_DC][y]
            else
                eExistingCapChargeDC[y]
            end)

        # 2. Objective Function Additions

        # If resource is not eligible for new charge DC capacity, fixed costs are only O&M costs
        @expression(EP, eCFixCharge_DC[y in VS_ASYM_DC_CHARGE],
            if y in NEW_CAP_CHARGE_DC # Resources eligible for new charge DC capacity
                by_rid(y, :inv_cost_charge_dc_per_mwyr) * vCAPCHARGE_DC[y] +
                by_rid(y, :fixed_om_cost_charge_dc_per_mwyr) * eTotalCapCharge_DC[y]
            else
                by_rid(y, :fixed_om_cost_charge_dc_per_mwyr) * eTotalCapCharge_DC[y]
            end)

        # Sum individual resource contributions to fixed costs to get total fixed costs
        @expression(EP,
            eTotalCFixCharge_DC,
            sum(EP[:eCFixCharge_DC][y] for y in VS_ASYM_DC_CHARGE))

        if MultiStage == 1
            EP[:eObj] += eTotalCFixCharge_DC / inputs["OPEXMULT"]
        else
            EP[:eObj] += eTotalCFixCharge_DC
        end

        ### CONSTRAINTS ###

        # Constraint 0: Existing capacity variable is equal to existing capacity specified in the input file
        if MultiStage == 1
            @constraint(EP,
                cExistingCapChargeDC[y in VS_ASYM_DC_CHARGE],
                EP[:vEXISTINGCAPCHARGEDC][y]==by_rid(y, :Existing_Cap_Charge_DC_MW))
        end

        # Constraints 1: Retirements and capacity additions
        # Cannot retire more charge DC capacity than existing charge capacity
        @constraint(EP,
            cVreStorMaxRetChargeDC[y in RET_CAP_CHARGE_DC],
            vRETCAPCHARGE_DC[y]<=eExistingCapChargeDC[y])
        # Constraint on maximum charge DC capacity (if applicable) [set input to -1 if no constraint on maximum charge capacity]
        # DEV NOTE: This constraint may be violated in some cases where Existing_Charge_Cap_MW is >= Max_Charge_Cap_MWh and lead to infeasabilty
        @constraint(EP,
            cVreStorMaxCapChargeDC[y in MAX_DC_CHARGE],
            eTotalCapCharge_DC[y]<=by_rid(y, :max_cap_charge_dc_mw))
        # Constraint on minimum charge DC capacity (if applicable) [set input to -1 if no constraint on minimum charge capacity]
        # DEV NOTE: This constraint may be violated in some cases where Existing_Charge_Cap_MW is <= Min_Charge_Cap_MWh and lead to infeasabilty
        @constraint(EP,
            cVreStorMinCapChargeDC[y in MIN_DC_CHARGE],
            eTotalCapCharge_DC[y]>=by_rid(y, :min_cap_charge_dc_mw))

        # Constraint 2: Maximum charging must be less than charge power rating
        @expression(EP,
            eVreStorMaxChargingDC[y in VS_ASYM_DC_CHARGE, t = 1:T],
            JuMP.AffExpr())
        for y in VS_ASYM_DC_CHARGE, t in 1:T
            eVreStorMaxChargingDC[y, t] += EP[:vP_DC_CHARGE][y, t]
        end
    end

    if !isempty(VS_ASYM_AC_DISCHARGE)
        MAX_AC_DISCHARGE = intersect(
            ids_with_nonneg(gen_VRE_STOR, max_cap_discharge_ac_mw),
            VS_ASYM_AC_DISCHARGE)
        MIN_AC_DISCHARGE = intersect(
            ids_with_positive(gen_VRE_STOR,
                min_cap_discharge_ac_mw),
            VS_ASYM_AC_DISCHARGE)

        ### VARIABLES ###
        @variables(EP, begin
            vCAPDISCHARGE_AC[y in NEW_CAP_DISCHARGE_AC] >= 0            # Discharge capacity AC component built for VRE storage [MW]
            vRETCAPDISCHARGE_AC[y in RET_CAP_DISCHARGE_AC] >= 0         # Discharge capacity AC component retired for VRE storage [MW]
        end)

        if MultiStage == 1
            @variable(EP, vEXISTINGCAPDISCHARGEAC[y in VS_ASYM_AC_DISCHARGE]>=0)
        end

        ### EXPRESSIONS ###

        # 0. Multistage existing capacity definition
        if MultiStage == 1
            @expression(EP,
                eExistingCapDischargeAC[y in VS_ASYM_AC_DISCHARGE],
                vEXISTINGCAPDISCHARGEAC[y])
        else
            @expression(EP,
                eExistingCapDischargeAC[y in VS_ASYM_AC_DISCHARGE],
                by_rid(y, :existing_cap_discharge_ac_mw))
        end

        # 1. Total storage discharge AC capacity
        @expression(EP, eTotalCapDischarge_AC[y in VS_ASYM_AC_DISCHARGE],
            if (y in intersect(NEW_CAP_DISCHARGE_AC, RET_CAP_DISCHARGE_AC))
                eExistingCapDischargeAC[y] + EP[:vCAPDISCHARGE_AC][y] -
                EP[:vRETCAPDISCHARGE_AC][y]
            elseif (y in setdiff(NEW_CAP_DISCHARGE_AC, RET_CAP_DISCHARGE_AC))
                eExistingCapDischargeAC[y] + EP[:vCAPDISCHARGE_AC][y]
            elseif (y in setdiff(RET_CAP_DISCHARGE_AC, NEW_CAP_DISCHARGE_AC))
                eExistingCapDischargeAC[y] - EP[:vRETCAPDISCHARGE_AC][y]
            else
                eExistingCapDischargeAC[y]
            end)

        # 2. Objective Function Additions

        # If resource is not eligible for new discharge AC capacity, fixed costs are only O&M costs
        @expression(EP, eCFixDischarge_AC[y in VS_ASYM_AC_DISCHARGE],
            if y in NEW_CAP_DISCHARGE_AC # Resources eligible for new discharge AC capacity
                by_rid(y, :inv_cost_discharge_ac_per_mwyr) * vCAPDISCHARGE_AC[y] +
                by_rid(y, :fixed_om_cost_discharge_ac_per_mwyr) * eTotalCapDischarge_AC[y]
            else
                by_rid(y, :fixed_om_cost_discharge_ac_per_mwyr) * eTotalCapDischarge_AC[y]
            end)

        # Sum individual resource contributions to fixed costs to get total fixed costs
        @expression(EP,
            eTotalCFixDischarge_AC,
            sum(EP[:eCFixDischarge_AC][y] for y in VS_ASYM_AC_DISCHARGE))

        if MultiStage == 1
            EP[:eObj] += eTotalCFixDischarge_AC / inputs["OPEXMULT"]
        else
            EP[:eObj] += eTotalCFixDischarge_AC
        end

        ### CONSTRAINTS ###

        # Constraint 0: Existing capacity variable is equal to existing capacity specified in the input file
        if MultiStage == 1
            @constraint(EP,
                cExistingCapDischargeAC[y in VS_ASYM_AC_DISCHARGE],
                EP[:vEXISTINGCAPDISCHARGEAC][y]==by_rid(y, :existing_cap_discharge_ac_mw))
        end

        # Constraints 1: Retirements and capacity additions
        # Cannot retire more discharge AC capacity than existing charge capacity
        @constraint(EP,
            cVreStorMaxRetDischargeAC[y in RET_CAP_DISCHARGE_AC],
            vRETCAPDISCHARGE_AC[y]<=eExistingCapDischargeAC[y])
        # Constraint on maximum discharge AC capacity (if applicable) [set input to -1 if no constraint on maximum charge capacity]
        # DEV NOTE: This constraint may be violated in some cases where Existing_Charge_Cap_MW is >= Max_Charge_Cap_MWh and lead to infeasabilty
        @constraint(EP,
            cVreStorMaxCapDischargeAC[y in MAX_AC_DISCHARGE],
            eTotalCapDischarge_AC[y]<=by_rid(y, :max_cap_discharge_ac_mw))
        # Constraint on minimum discharge AC capacity (if applicable) [set input to -1 if no constraint on minimum charge capacity]
        # DEV NOTE: This constraint may be violated in some cases where Existing_Charge_Cap_MW is <= Min_Charge_Cap_MWh and lead to infeasabilty
        @constraint(EP,
            cVreStorMinCapDischargeAC[y in MIN_AC_DISCHARGE],
            eTotalCapDischarge_AC[y]>=by_rid(y, :min_cap_discharge_ac_mw))

        # Constraint 2: Maximum discharging rate must be less than discharge power rating
        @expression(EP,
            eVreStorMaxDischargingAC[y in VS_ASYM_AC_DISCHARGE, t = 1:T],
            JuMP.AffExpr())
        for y in VS_ASYM_AC_DISCHARGE, t in 1:T
            eVreStorMaxDischargingAC[y, t] += EP[:vP_AC_DISCHARGE][y, t]
        end
    end

    if !isempty(VS_ASYM_AC_CHARGE)
        MAX_AC_CHARGE = intersect(ids_with_nonneg(gen_VRE_STOR, max_cap_charge_ac_mw),
            VS_ASYM_AC_CHARGE)
        MIN_AC_CHARGE = intersect(ids_with_positive(gen_VRE_STOR, min_cap_charge_ac_mw),
            VS_ASYM_AC_CHARGE)

        ### VARIABLES ###
        @variables(EP, begin
            vCAPCHARGE_AC[y in NEW_CAP_CHARGE_AC] >= 0               # Charge capacity AC component built for VRE storage [MW]
            vRETCAPCHARGE_AC[y in RET_CAP_CHARGE_AC] >= 0            # Charge capacity AC component retired for VRE storage [MW]
        end)

        if MultiStage == 1
            @variable(EP, vEXISTINGCAPCHARGEAC[y in VS_ASYM_AC_CHARGE]>=0)
        end

        ### EXPRESSIONS ###

        # 0. Multistage existing capacity definition
        if MultiStage == 1
            @expression(EP,
                eExistingCapChargeAC[y in VS_ASYM_AC_CHARGE],
                vEXISTINGCAPCHARGEAC[y])
        else
            @expression(EP,
                eExistingCapChargeAC[y in VS_ASYM_AC_CHARGE],
                by_rid(y, :existing_cap_charge_ac_mw))
        end

        # 1. Total storage charge AC capacity
        @expression(EP, eTotalCapCharge_AC[y in VS_ASYM_AC_CHARGE],
            if (y in intersect(NEW_CAP_CHARGE_AC, RET_CAP_CHARGE_AC))
                eExistingCapChargeAC[y] + EP[:vCAPCHARGE_AC][y] - EP[:vRETCAPCHARGE_AC][y]
            elseif (y in setdiff(NEW_CAP_CHARGE_AC, RET_CAP_CHARGE_AC))
                eExistingCapChargeAC[y] + EP[:vCAPCHARGE_AC][y]
            elseif (y in setdiff(RET_CAP_CHARGE_AC, NEW_CAP_CHARGE_AC))
                eExistingCapChargeAC[y] - EP[:vRETCAPCHARGE_AC][y]
            else
                eExistingCapChargeAC[y]
            end)

        # 2. Objective Function Additions

        # If resource is not eligible for new charge AC capacity, fixed costs are only O&M costs
        @expression(EP, eCFixCharge_AC[y in VS_ASYM_AC_CHARGE],
            if y in NEW_CAP_CHARGE_AC # Resources eligible for new charge AC capacity
                by_rid(y, :inv_cost_charge_ac_per_mwyr) * vCAPCHARGE_AC[y] +
                by_rid(y, :fixed_om_cost_charge_ac_per_mwyr) * eTotalCapCharge_AC[y]
            else
                by_rid(y, :fixed_om_cost_charge_ac_per_mwyr) * eTotalCapCharge_AC[y]
            end)

        # Sum individual resource contributions to fixed costs to get total fixed costs
        @expression(EP,
            eTotalCFixCharge_AC,
            sum(EP[:eCFixCharge_AC][y] for y in VS_ASYM_AC_CHARGE))

        if MultiStage == 1
            EP[:eObj] += eTotalCFixCharge_AC / inputs["OPEXMULT"]
        else
            EP[:eObj] += eTotalCFixCharge_AC
        end

        ### CONSTRAINTS ###

        # Constraint 0: Existing capacity variable is equal to existing capacity specified in the input file
        if MultiStage == 1
            @constraint(EP,
                cExistingCapChargeAC[y in VS_ASYM_AC_CHARGE],
                EP[:vEXISTINGCAPCHARGEAC][y]==by_rid(y, :existing_cap_charge_ac_mw))
        end

        # Constraints 1: Retirements and capacity additions
        # Cannot retire more charge AC capacity than existing charge capacity
        @constraint(EP,
            cVreStorMaxRetChargeAC[y in RET_CAP_CHARGE_AC],
            vRETCAPCHARGE_AC[y]<=eExistingCapChargeAC[y])
        # Constraint on maximum charge AC capacity (if applicable) [set input to -1 if no constraint on maximum charge capacity]
        # DEV NOTE: This constraint may be violated in some cases where Existing_Charge_Cap_MW is >= Max_Charge_Cap_MWh and lead to infeasabilty
        @constraint(EP,
            cVreStorMaxCapChargeAC[y in MAX_AC_CHARGE],
            eTotalCapCharge_AC[y]<=by_rid(y, :max_cap_charge_ac_mw))
        # Constraint on minimum charge AC capacity (if applicable) [set input to -1 if no constraint on minimum charge capacity]
        # DEV NOTE: This constraint may be violated in some cases where Existing_Charge_Cap_MW is <= Min_Charge_Cap_MWh and lead to infeasabilty
        @constraint(EP,
            cVreStorMinCapChargeAC[y in MIN_AC_CHARGE],
            eTotalCapCharge_AC[y]>=by_rid(y, :min_cap_charge_ac_mw))

        # Constraint 2: Maximum charging rate must be less than charge power rating
        @expression(EP,
            eVreStorMaxChargingAC[y in VS_ASYM_AC_CHARGE, t = 1:T],
            JuMP.AffExpr())
        for y in VS_ASYM_AC_CHARGE, t in 1:T
            eVreStorMaxChargingAC[y, t] += EP[:vP_AC_CHARGE][y, t]
        end
    end
end

@doc raw"""
    vre_stor_capres!(EP::Model, inputs::Dict, setup::Dict)

This function activates capacity reserve margin constraints for co-located VRE and storage resources. The capacity reserve margin 
    formulation for GenX is further elaborated upon in ```cap_reserve_margin!()```. For co-located resources ($y \in \mathcal{VS}$), 
    the available capacity to contribute to the capacity reserve margin is the net injection into the transmission network (which 
    can come from the solar PV, wind, and/or storage component) plus the net virtual injection corresponding to charge held in reserve 
    (which can only come from the storage component), derated by the derating factor. If a capacity reserve margin is modeled, variables 
    for virtual charge DC, $\Pi^{CRM, dc}_{y,z,t}$, virtual charge AC, $\Pi^{CRM, ac}_{y,z,t}$, virtual discharge DC, $\Theta^{CRM, dc}_{y,z,t}$, 
    virtual discharge AC, $\Theta^{CRM, ac}_{o,z,t}$, and virtual state of charge, $\Gamma^{CRM}_{y,z,t}$, are created to represent contributions that a storage device makes to 
    the capacity reserve margin without actually generating power. These represent power that the storage device could have discharged 
    or consumed if called upon to do so, based on its available state of charge. Importantly, a dedicated set of variables 
    and constraints are created to ensure that any virtual contributions to the capacity reserve margin could be made as 
    actual charge/discharge if necessary without affecting system operations in any other timesteps (similar to the standalone 
    storage capacity reserve margin constraints). 

If a capacity reserve margin is modeled, then the following constraints track the relationship between the virtual charge variables, 
    $\Pi^{CRM,dc}_{y,z,t}, \Pi^{CRM,ac}_{y,z,t}$, virtual discharge variables, $\Theta^{CRM, dc}_{y,z,t}, \Theta^{CRM, ac}_{y,z,t}$, 
    and the virtual state of charge, $\Gamma^{CRM}_{y,z,t}$, representing the amount of state of charge that must be held in reserve 
    to enable these virtual capacity reserve margin contributions and ensuring that the storage device could deliver its pledged 
    capacity if called upon to do so without affecting its operations in other timesteps. $\Gamma^{CRM}_{y,z,t}$ is tracked similarly 
    to the devices' overall state of charge based on its value in the previous timestep and the virtual charge and discharge in the 
    current timestep. Unlike the regular state of charge, virtual discharge $\Theta^{CRM,dc}_{y,z,t}, \Theta^{CRM,ac}_{y,z,t}$ increases 
    $\Gamma^{CRM}_{y,z,t}$ (as more charge must be held in reserve to support more virtual discharge), and the virtual charge 
    $\Pi^{CRM,dc}_{y,z,t}, \Pi^{CRM,ac}_{y,z,t}$ reduces $\Gamma^{CRM}_{y,z,t}$. Similar to the state of charge constraints in the 
    ```stor_vre_stor!()``` function, the first of these two constraints enforces storage inventory balance for interior time 
    steps $(t \in \mathcal{T}^{interior})$, while the second enforces storage balance constraint for the initial time step $(t \in \mathcal{T}^{start})$:
```math
\begin{aligned}
	& \Gamma^{CRM}_{y,z,t} = \Gamma^{CRM}_{y,z,t-1} + \frac{\Theta^{CRM, dc}_{y,z,t}}{\eta_{y,z}^{discharge,dc}} + \frac{\Theta^{CRM,ac}_{y,z,t}}{\eta_{y,z}^{discharge,ac}} - \eta_{y,z}^{charge,dc} \times \Pi^{CRM,dc}_{y,z,t} - \eta_{y,z}^{charge,ac} \times \Pi^{CRM, ac}_{y,z,t} \\
    & - \eta_{y,z}^{loss} \times \Gamma^{CRM}_{y,z,t-1}  \quad \forall y \in \mathcal{VS}^{stor}, z \in \mathcal{Z}, t \in \mathcal{T}^{interior}\\
    &  \Gamma^{CRM}_{y,z,t} = \Gamma^{CRM}_{y,z,t+\tau^{period}-1} + \frac{\Theta^{CRM,dc}_{y,z,t}}{\eta_{y,z}^{discharge,dc}} + \frac{\Theta^{CRM,ac}_{y,z,t}}{\eta_{y,z}^{discharge,ac}} - \eta_{y,z}^{charge,dc} \times \Pi^{CRM,dc}_{y,z,t} - \eta_{y,z}^{charge,ac} \times \Pi^{CRM,ac}_{y,z,t} \\
    & - \eta_{y,z}^{loss} \times \Gamma^{CRM}_{y,z,t+\tau^{period}-1}  \quad \forall y \in \mathcal{VS}^{stor}, z \in \mathcal{Z}, t \in \mathcal{T}^{start}
\end{aligned}
```
The energy held in reserve, $\Gamma^{CRM}_{y,z,t}$, also acts as a lower bound on the overall state of charge $\Gamma_{y,z,t}$. This ensures 
    that the storage device cannot use state of charge that would not have been available had it been called on to actually contribute its 
    pledged virtual discharge at some earlier timestep. This relationship is described by the following constraint (as also outlined in 
    the storage module):
```math
\begin{aligned}
	&  \Gamma_{y,z,t} \geq \Gamma^{CRM}_{y,z,t} \quad \forall y \in \mathcal{VS}^{stor}, z \in \mathcal{Z}, t \in \mathcal{T} \\
\end{aligned}
```
The overall contribution of the co-located VRE and storage resources to the system's capacity reserve margin in timestep $t$ is equal to 
    (including both actual and virtual DC and AC charge and discharge):
```math
\begin{aligned}
	& \sum_{y \in \mathcal{VS}^{pv}} (\epsilon_{y,z,p}^{CRM} \times \eta^{inverter}_{y,z} \times \rho^{max,pv}_{y,z,t} \times \Delta^{total,pv}_{y,z}) \\
    & + \sum_{y \in \mathcal{VS}^{wind}} (\epsilon_{y,z,p}^{CRM} \times \rho^{max,wind}_{y,z,t} \times \Delta^{total,wind}_{y,z}) \\
    & + \sum_{y \in \mathcal{VS}^{sym,dc} \cup \mathcal{VS}^{asym,dc,dis}} (\epsilon_{y,z,p}^{CRM} \times \eta^{inverter}_{y,z} \times (\Theta^{dc}_{y,z,t} + \Theta^{CRM,dc}_{y,z,t})) \\
    & + \sum_{y \in \mathcal{VS}^{sym,ac} \cup \mathcal{VS}^{asym,ac,dis}} (\epsilon_{y,z,p}^{CRM} \times (\Theta^{ac}_{y,z,t} + \Theta^{CRM,ac}_{y,z,t})) \\
    & - \sum_{y \in \mathcal{VS}^{sym,dc} \cup \mathcal{VS}^{asym,dc,cha}} (\epsilon_{y,z,p}^{CRM} \times \frac{\Pi^{dc}_{y,z,t} + \Pi^{CRM,dc}_{y,z,t}}{\eta^{inverter}_{y,z}}) \\
    & - \sum_{y \in \mathcal{VS}^{sym,dc} \cup \mathcal{VS}^{asym,dc,cha}} (\epsilon_{y,z,p}^{CRM} \times (\Pi^{ac}_{y,z,t} + \Pi^{CRM,ac}_{y,z,t}))
\end{aligned}
```

If long duration energy storage resources exist, a separate but similar set of variables and constraints is used to track the evolution of energy held 
    in reserves across representative periods, which is elaborated upon in the ```long_duration_storage!()``` function. 
    The main linking constraint follows (due to the capabilities of virtual DC and AC discharging and charging):

```math
\begin{aligned}
    & \Gamma^{CRM}_{y,z,(m-1)\times \tau^{period}+1} = \left(1-\eta_{y,z}^{loss}\right)\times \left(\Gamma^{CRM}_{y,z,m\times \tau^{period}} -\Delta Q_{y,z,m}\right)  \\
    & + \frac{\Theta^{CRM,dc}_{y,z,(m-1)\times \tau^{period}+1}}{\eta_{y,z}^{discharge,dc}} + \frac{\Theta^{CRM,ac}_{y,z,(m-1)\times \tau^{period}+1}}{\eta_{y,z}^{discharge,ac}} \\
    & - \eta_{y,z}^{charge,dc} \times \Pi^{CRM,dc}_{y,z,(m-1)\times \tau^{period}+1} - \eta_{y,z}^{charge,ac} \times \Pi^{CRM,ac}_{y,z,(m-1)\times \tau^{period}+1} \\
    & \forall y \in \mathcal{VS}^{LDES}, z \in \mathcal{Z}, m \in \mathcal{M}
\end{aligned}
```

All other constraints are identical to those used to track the actual state of charge, except with the new variables for the representation of 'virtual' 
    state of charge, build up storage inventory and state of charge at the beginning of each period. 
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
    if rep_periods > 1 && !isempty(VS_LDS)
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
            eVreStorVSoCBalStart[y, t] += EP[:vCAPRES_DC_DISCHARGE][y, t] /
                                          by_rid(y, :eff_down_dc)
        end
        for y in DC_CHARGE_CONSTRAINTSET
            eVreStorVSoCBalStart[y, t] -= by_rid(y, :eff_up_dc) *
                                          EP[:vCAPRES_DC_CHARGE][y, t]
        end
        for y in AC_DISCHARGE_CONSTRAINTSET
            eVreStorVSoCBalStart[y, t] += EP[:vCAPRES_AC_DISCHARGE][y, t] /
                                          by_rid(y, :eff_down_ac)
        end
        for y in AC_CHARGE_CONSTRAINTSET
            eVreStorVSoCBalStart[y, t] -= by_rid(y, :eff_up_ac) *
                                          EP[:vCAPRES_AC_CHARGE][y, t]
        end
    end

    for t in INTERIOR_SUBPERIODS
        for y in DC_DISCHARGE
            eVreStorVSoCBalInterior[y, t] += EP[:vCAPRES_DC_DISCHARGE][y, t] /
                                             by_rid(y, :eff_down_dc)
        end
        for y in DC_CHARGE
            eVreStorVSoCBalInterior[y, t] -= by_rid(y, :eff_up_dc) *
                                             EP[:vCAPRES_DC_CHARGE][y, t]
        end
        for y in AC_DISCHARGE
            eVreStorVSoCBalInterior[y, t] += EP[:vCAPRES_AC_DISCHARGE][y, t] /
                                             by_rid(y, :eff_down_ac)
        end
        for y in AC_CHARGE
            eVreStorVSoCBalInterior[y, t] -= by_rid(y, :eff_up_ac) *
                                             EP[:vCAPRES_AC_CHARGE][y, t]
        end
    end

    # Inverter & grid connection export additions
    for t in 1:T
        for y in DC_DISCHARGE
            EP[:eInverterExport][y, t] += by_rid(y, :etainverter) *
                                          vCAPRES_DC_DISCHARGE[y, t]
            EP[:eGridExport][y, t] += by_rid(y, :etainverter) * vCAPRES_DC_DISCHARGE[y, t]
        end
        for y in DC_CHARGE
            EP[:eInverterExport][y, t] += vCAPRES_DC_CHARGE[y, t] / by_rid(y, :etainverter)
            EP[:eGridExport][y, t] += vCAPRES_DC_CHARGE[y, t] / by_rid(y, :etainverter)
        end
        for y in AC_DISCHARGE
            EP[:eGridExport][y, t] += vCAPRES_AC_DISCHARGE[y, t]
        end
        for y in AC_CHARGE
            EP[:eGridExport][y, t] += vCAPRES_AC_CHARGE[y, t]
        end

        # Asymmetric and symmetric storage contributions
        for y in VS_ASYM_DC_DISCHARGE
            EP[:eVreStorMaxDischargingDC][y, t] += vCAPRES_DC_DISCHARGE[y, t]
        end
        for y in VS_ASYM_AC_DISCHARGE
            EP[:eVreStorMaxDischargingAC][y, t] += vCAPRES_AC_DISCHARGE[y, t]
        end
        for y in VS_ASYM_DC_CHARGE
            EP[:eVreStorMaxChargingDC][y, t] += vCAPRES_DC_CHARGE[y, t]
        end
        for y in VS_ASYM_AC_CHARGE
            EP[:eVreStorMaxChargingAC][y, t] += vCAPRES_AC_CHARGE[y, t]
        end
        for y in VS_SYM_DC
            EP[:eChargeDischargeMaxDC][y, t] += (vCAPRES_DC_DISCHARGE[y, t]
                                                 +
                                                 vCAPRES_DC_CHARGE[y, t])
        end
        for y in VS_SYM_AC
            EP[:eChargeDischargeMaxAC][y, t] += (vCAPRES_AC_DISCHARGE[y, t]
                                                 +
                                                 vCAPRES_AC_CHARGE[y, t])
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
    @expression(EP,
        eCapResMarBalanceStor_VRE_STOR[res = 1:inputs["NCapacityReserveMargin"], t = 1:T],
        (sum(derating_factor(gen[y], tag = res) * by_rid(y, :etainverter) *
             inputs["pP_Max_Solar"][y, t] * EP[:eTotalCap_SOLAR][y]
         for y in inputs["VS_SOLAR"])
         +
         sum(derating_factor(gen[y], tag = res) * inputs["pP_Max_Wind"][y, t] *
             EP[:eTotalCap_WIND][y] for y in inputs["VS_WIND"])
         +
         sum(derating_factor(gen[y], tag = res) * by_rid(y, :etainverter) *
             (EP[:vP_DC_DISCHARGE][y, t]) for y in DC_DISCHARGE)
         +
         sum(derating_factor(gen[y], tag = res) * (EP[:vP_AC_DISCHARGE][y, t])
         for y in AC_DISCHARGE)
         -
         sum(derating_factor(gen[y], tag = res) * (EP[:vP_DC_CHARGE][y, t]) /
             by_rid(y, :etainverter)
        for y in DC_CHARGE)
        -sum(derating_factor(gen[y], tag = res) * (EP[:vP_AC_CHARGE][y, t])
        for y in AC_CHARGE)))
    if StorageVirtualDischarge > 0
        @expression(EP,
            eCapResMarBalanceStor_VRE_STOR_Virtual[
                res = 1:inputs["NCapacityReserveMargin"],
                t = 1:T],
            (sum(derating_factor(gen[y], tag = res) * by_rid(y, :etainverter) *
                 (vCAPRES_DC_DISCHARGE[y, t]) for y in DC_DISCHARGE)
             +
             sum(derating_factor(gen[y], tag = res) * (vCAPRES_AC_DISCHARGE[y, t])
            for y in AC_DISCHARGE)
             -
             sum(derating_factor(gen[y], tag = res) * (vCAPRES_DC_CHARGE[y, t]) /
                 by_rid(y, :etainverter)
            for y in DC_CHARGE)
            -sum(derating_factor(gen[y], tag = res) * (vCAPRES_AC_CHARGE[y, t])
            for y in AC_CHARGE)))
        add_similar_to_expression!(eCapResMarBalanceStor_VRE_STOR,
            eCapResMarBalanceStor_VRE_STOR_Virtual)
    end
    EP[:eCapResMarBalance] += EP[:eCapResMarBalanceStor_VRE_STOR]

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
    EP[:eObj] += eTotalCVar_Charge_DC_virtual

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
    EP[:eObj] += eTotalCVar_Discharge_DC_virtual

    #Variable costs of AC "virtual charging" for technologies "y" during hour "t" in zone "z"
    @expression(EP, eCVar_Charge_AC_virtual[y in AC_CHARGE, t = 1:T],
        inputs["omega"][t]*virtual_discharge_cost*vCAPRES_AC_CHARGE[y, t])
    @expression(EP,
        eTotalCVar_Charge_AC_T_virtual[t = 1:T],
        sum(eCVar_Charge_AC_virtual[y, t] for y in AC_CHARGE))
    @expression(EP,
        eTotalCVar_Charge_AC_virtual,
        sum(eTotalCVar_Charge_AC_T_virtual[t] for t in 1:T))
    EP[:eObj] += eTotalCVar_Charge_AC_virtual

    #Variable costs of AC "virtual discharging" for technologies "y" during hour "t" in zone "z"
    @expression(EP, eCVar_Discharge_AC_virtual[y in AC_DISCHARGE, t = 1:T],
        inputs["omega"][t]*virtual_discharge_cost*vCAPRES_AC_DISCHARGE[y, t])
    @expression(EP,
        eTotalCVar_Discharge_AC_T_virtual[t = 1:T],
        sum(eCVar_Discharge_AC_virtual[y, t] for y in AC_DISCHARGE))
    @expression(EP,
        eTotalCVar_Discharge_AC_virtual,
        sum(eTotalCVar_Discharge_AC_T_virtual[t] for t in 1:T))
    EP[:eObj] += eTotalCVar_Discharge_AC_virtual

    ### LONG DURATION ENERGY STORAGE CAPACITY RESERVE MARGIN MODULE ###
    if rep_periods > 1 && !isempty(VS_LDS)

        ### LOAD DATA ###

        REP_PERIOD = inputs["REP_PERIOD"]  # Number of representative periods
        dfPeriodMap = inputs["Period_Map"] # Dataframe that maps modeled periods to representative periods
        NPeriods = size(inputs["Period_Map"])[1] # Number of modeled periods
        MODELED_PERIODS_INDEX = 1:NPeriods
        REP_PERIODS_INDEX = MODELED_PERIODS_INDEX[dfPeriodMap[!, :Rep_Period] .== MODELED_PERIODS_INDEX]

        ### VARIABLES ###

        @variables(EP,
            begin
                # State of charge held in reserve for storage at beginning of each modeled period n
                vCAPCONTRSTOR_VSOCw_VRE_STOR[y in VS_LDS, n in MODELED_PERIODS_INDEX] >= 0

                # Build up in storage inventory held in reserve over each representative period w (can be pos or neg)
                vCAPCONTRSTOR_VdSOC_VRE_STOR[y in VS_LDS, w = 1:REP_PERIOD]
            end)

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
                eVreStorVSoCBalLongDurationStorageStart[y, w] += EP[:vCAPRES_DC_DISCHARGE][
                    y,
                    hours_per_subperiod * (w - 1) + 1] / by_rid(y, :eff_down_dc)
            end
            for y in DC_CHARGE_CONSTRAINTSET
                eVreStorVSoCBalLongDurationStorageStart[y, w] -= by_rid(y, :eff_up_dc) *
                                                                 EP[:vCAPRES_DC_CHARGE][y,
                    hours_per_subperiod * (w - 1) + 1]
            end
            for y in AC_DISCHARGE_CONSTRAINTSET
                eVreStorVSoCBalLongDurationStorageStart[y, w] += EP[:vCAPRES_AC_DISCHARGE][
                    y,
                    hours_per_subperiod * (w - 1) + 1] / by_rid(y, :eff_down_ac)
            end
            for y in AC_CHARGE_CONSTRAINTSET
                eVreStorVSoCBalLongDurationStorageStart[y, w] -= by_rid(y, :eff_up_ac) *
                                                                 EP[:vCAPRES_AC_CHARGE][y,
                    hours_per_subperiod * (w - 1) + 1]
            end
        end

        ### CONSTRAINTS ###

        # Constraint 1: Links last time step with first time step, ensuring position in hour 1 is within eligible change from final hour position
        # Modified initial virtual state of storage for long duration storage - initialize wth value carried over from last period
        # Alternative to cVSoCBalStart constraint which is included when modeling multiple representative periods and long duration storage
        # Note: tw_min = hours_per_subperiod*(w-1)+1; tw_max = hours_per_subperiod*w
        @constraint(EP,
            cVreStorVSoCBalLongDurationStorageStart[y in VS_LDS, w = 1:REP_PERIOD],
            EP[:vCAPRES_VS_VRE_STOR][y,
                hours_per_subperiod * (w - 1) + 1]==eVreStorVSoCBalLongDurationStorageStart[y, w])

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
                    vCAPCONTRSTOR_VdSOC_VRE_STOR[y, dfPeriodMap[r, :Rep_Period_Index]])

        # Constraint 4: Energy held in reserve at the beginning of each modeled period acts as a lower bound on the total energy held in storage
        @constraint(EP,
            cSOCMinCapResLongDurationStorage[y in VS_LDS, r in MODELED_PERIODS_INDEX],
            EP[:vSOCw_VRE_STOR][y, r]>=vCAPCONTRSTOR_VSOCw_VRE_STOR[y, r])
    end
end

@doc raw"""
    vre_stor_operational_reserves!(EP::Model, inputs::Dict, setup::Dict)

This function activates either or both frequency regulation and operating reserve options for co-located 
    VRE-storage resources. Co-located VRE and storage resources ($y \in \mathcal{VS}$) have six pairs of 
    auxilary variables to reflect contributions to regulation and reserves when generating electricity from 
    solar PV or wind resources, DC charging and discharging from storage resources, and AC charging and 
    discharging from storage resources. The primary variables ($f_{y,z,t}$ & $r_{y,z,t}$) becomes equal to the sum
    of these auxilary variables as follows:
```math
\begin{aligned}
    &  f_{y,z,t} = f^{pv}_{y,z,t} + f^{wind}_{y,z,t} + f^{dc,dis}_{y,z,t} + f^{dc,cha}_{y,z,t} + f^{ac,dis}_{y,z,t} + f^{ac,cha}_{y,z,t} & \quad \forall y \in \mathcal{VS}, z \in \mathcal{Z}, t \in \mathcal{T}\\
    &  r_{y,z,t} = r^{pv}_{y,z,t} + r^{wind}_{y,z,t} + r^{dc,dis}_{y,z,t} + r^{dc,cha}_{y,z,t} + r^{ac,dis}_{y,z,t} + r^{ac,cha}_{y,z,t} & \quad \forall y \in \mathcal{VS}, z \in \mathcal{Z}, t \in \mathcal{T}\\
\end{aligned}
```

Furthermore, the frequency regulation and operating reserves require the maximum contribution from the entire resource
    to be a specified fraction of the installed grid connection capacity:
```math
\begin{aligned}
    f_{y,z,t} \leq \upsilon^{reg}_{y,z} \times \Delta^{total}_{y,z}
    \hspace{4 cm}  \forall y \in \mathcal{VS}, z \in \mathcal{Z}, t \in \mathcal{T} \\
    r_{y,z,t} \leq \upsilon^{rsv}_{y,z}\times \Delta^{total}_{y,z}
    \hspace{4 cm}  \forall y \in \mathcal{VS}, z \in \mathcal{Z}, t \in \mathcal{T}
    \end{aligned}
```

The following constraints follow if the configurable co-located resource has any type of storage component. 
    When charging, reducing the DC and AC charge rate is contributing to upwards reserve and frequency regulation as 
    it drops net demand. As such, the sum of the DC and AC charge rate plus contribution to regulation and reserves 
    up must be greater than zero. Additionally, the DC and AC discharge rate plus the contribution to regulation must 
    be greater than zero:
```math
\begin{aligned}
    &  \Pi^{dc}_{y,z,t} - f^{dc,cha}_{y,z,t} - r^{dc,cha}_{y,z,t} \geq 0 & \quad \forall y \in \mathcal{VS}^{sym,dc} \cup \mathcal{VS}^{asym,dc,cha}, z \in \mathcal{Z}, t \in \mathcal{T}\\
    &  \Pi^{ac}_{y,z,t} - f^{ac,cha}_{y,z,t} - r^{ac,cha}_{y,z,t} \geq 0 & \quad \forall y \in \mathcal{VS}^{sym,ac} \cup \mathcal{VS}^{asym,ac,cha}, z \in \mathcal{Z}, t \in \mathcal{T}\\
    &  \Theta^{dc}_{y,z,t} - f^{dc,dis}_{y,z,t} \geq 0 & \quad \forall y \in \mathcal{VS}^{sym,dc} \cup \mathcal{VS}^{asym,dc,dis}, z \in \mathcal{Z}, t \in \mathcal{T} \\
    &  \Theta^{ac}_{y,z,t} - f^{ac,dis}_{y,z,t} \geq 0 & \quad \forall y \in \mathcal{VS}^{sym,ac} \cup \mathcal{VS}^{asym,ac,dis}, z \in \mathcal{Z}, t \in \mathcal{T}
\end{aligned}
```

Additionally, when reserves are modeled, the maximum DC and AC charge rate and contribution to regulation while charging can be 
    no greater than the available energy storage capacity, or the difference between the total energy storage capacity, 
    $\Delta^{total, energy}_{y,z}$, and the state of charge at the end of the previous time period, $\Gamma_{y,z,t-1}$, 
    while accounting for charging losses $\eta_{y,z}^{charge,dc}, \eta_{y,z}^{charge,ac}$. Note that for storage to contribute 
    to reserves down while charging, the storage device must be capable of increasing the charge rate (which increases net load):
```math
\begin{aligned}
    &  \eta_{y,z}^{charge,dc} \times (\Pi^{dc}_{y,z,t} + f^{dc,cha}_{o,z,t}) + \eta_{y,z}^{charge,ac} \times (\Pi^{ac}_{y,z,t} + f^{ac,cha}_{o,z,t}) \\
    & \leq \Delta^{energy, total}_{y,z} - \Gamma_{y,z,t-1} \quad \forall y \in \mathcal{VS}^{stor}, z \in \mathcal{Z}, t \in \mathcal{T}
\end{aligned}
```

Finally, the maximum DC and AC discharge rate and contributions to the frequency regulation and operating reserves must be 
    less than the state of charge in the previous time period, $\Gamma_{y,z,t-1}$. Without any capacity reserve margin policies activated, 
    the constraint is as follows:
```math
\begin{aligned}
    &  \frac{\Theta^{dc}_{y,z,t}+f^{dc,dis}_{y,z,t}+r^{dc,dis}_{y,z,t}}{\eta_{y,z}^{discharge,dc}} + \frac{\Theta^{ac}_{y,z,t}+f^{ac,dis}_{y,z,t}+r^{ac,dis}_{y,z,t}}{\eta_{y,z}^{discharge,ac}} \\
    & \leq \Gamma_{y,z,t-1} \quad \forall y \in \mathcal{VS}^{stor}, z \in \mathcal{Z}, t \in \mathcal{T}
\end{aligned}
```

With the capacity reserve margin policies, the maximum DC and AC discharge rate accounts for both contributions to the capacity reserve 
    margin and operating reserves as follows:
```math
\begin{aligned}
    &  \frac{\Theta^{dc}_{y,z,t}+\Theta^{CRM,dc}_{y,z,t}+f^{dc,dis}_{y,z,t}+r^{dc,dis}_{y,z,t}}{\eta_{y,z}^{discharge,dc}} + \frac{\Theta^{ac}_{y,z,t}+\Theta^{CRM,ac}_{y,z,t}+f^{ac,dis}_{y,z,t}+r^{ac,dis}_{y,z,t}}{\eta_{y,z}^{discharge,ac}} \\
    & \leq \Gamma_{y,z,t-1} \quad \forall y \in \mathcal{VS}^{stor}, z \in \mathcal{Z}, t \in \mathcal{T}
\end{aligned}
```

Lastly, if the co-located resource has a variable renewable energy component, the solar PV and wind resource can also contribute to frequency regulation reserves  
    and must be greater than zero:
```math
\begin{aligned}
    &  \Theta^{pv}_{y,z,t} - f^{pv}_{y,z,t} \geq 0 & \quad \forall y \in \mathcal{VS}^{pv}, z \in \mathcal{Z}, t \in \mathcal{T} \\
    &  \Theta^{wind}_{y,z,t} - f^{wind}_{y,z,t} \geq 0 & \quad \forall y \in \mathcal{VS}^{wind}, z \in \mathcal{Z}, t \in \mathcal{T}
\end{aligned}
```
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
            eDischargeDCMin[y, t] += EP[:vP_DC_DISCHARGE][y, t]
            eDischargeMax[y, t] += EP[:vP_DC_DISCHARGE][y, t] / by_rid(y, :eff_down_dc)
        end

        for y in DC_CHARGE
            eChargeDCMin[y, t] += EP[:vP_DC_CHARGE][y, t]
            eChargeMax[y, t] += by_rid(y, :eff_up_dc) * EP[:vP_DC_CHARGE][y, t]
        end

        for y in AC_DISCHARGE
            eDischargeACMin[y, t] += EP[:vP_AC_DISCHARGE][y, t]
            eDischargeMax[y, t] += EP[:vP_AC_DISCHARGE][y, t] / by_rid(y, :eff_down_ac)
        end

        for y in AC_CHARGE
            eChargeACMin[y, t] += EP[:vP_AC_CHARGE][y, t]
            eChargeMax[y, t] += by_rid(y, :eff_up_ac) * EP[:vP_AC_CHARGE][y, t]
        end

        for y in SOLAR_REG
            eVreStorRegOnlyBalance[y, t] += by_rid(y, :etainverter) * vREG_SOLAR[y, t]
            EP[:eGridExport][y, t] += by_rid(y, :etainverter) * vREG_SOLAR[y, t]
            EP[:eInverterExport][y, t] += by_rid(y, :etainverter) * vREG_SOLAR[y, t]
            EP[:eSolarGenMaxS][y, t] += vREG_SOLAR[y, t]
        end
        for y in SOLAR_RSV
            eVreStorRsvOnlyBalance[y, t] += by_rid(y, :etainverter) * vRSV_SOLAR[y, t]
            EP[:eGridExport][y, t] += by_rid(y, :etainverter) * vRSV_SOLAR[y, t]
            EP[:eInverterExport][y, t] += by_rid(y, :etainverter) * vRSV_SOLAR[y, t]
            EP[:eSolarGenMaxS][y, t] += vRSV_SOLAR[y, t]
        end

        for y in WIND_REG
            eVreStorRegOnlyBalance[y, t] += vREG_WIND[y, t]
            EP[:eGridExport][y, t] += vREG_WIND[y, t]
            EP[:eWindGenMaxW][y, t] += vREG_WIND[y, t]
        end
        for y in WIND_RSV
            eVreStorRsvOnlyBalance[y, t] += vRSV_WIND[y, t]
            EP[:eGridExport][y, t] += vRSV_WIND[y, t]
            EP[:eWindGenMaxW][y, t] += vRSV_WIND[y, t]
        end

        for y in DC_DISCHARGE_REG
            eVreStorRegOnlyBalance[y, t] += by_rid(y, :etainverter) *
                                            vREG_DC_Discharge[y, t]
            eDischargeDCMin[y, t] -= vREG_DC_Discharge[y, t]
            eDischargeMax[y, t] += EP[:vREG_DC_Discharge][y, t] / by_rid(y, :eff_down_dc)
            EP[:eGridExport][y, t] += by_rid(y, :etainverter) * vREG_DC_Discharge[y, t]
            EP[:eInverterExport][y, t] += by_rid(y, :etainverter) * vREG_DC_Discharge[y, t]
        end
        for y in DC_DISCHARGE_RSV
            eVreStorRsvOnlyBalance[y, t] += by_rid(y, :etainverter) *
                                            vRSV_DC_Discharge[y, t]
            eDischargeMax[y, t] += EP[:vRSV_DC_Discharge][y, t] / by_rid(y, :eff_down_dc)
            EP[:eGridExport][y, t] += by_rid(y, :etainverter) * vRSV_DC_Discharge[y, t]
            EP[:eInverterExport][y, t] += by_rid(y, :etainverter) * vRSV_DC_Discharge[y, t]
        end

        for y in DC_CHARGE_REG
            eVreStorRegOnlyBalance[y, t] += vREG_DC_Charge[y, t] / by_rid(y, :etainverter)
            eChargeDCMin[y, t] -= vREG_DC_Charge[y, t]
            eChargeMax[y, t] += by_rid(y, :eff_up_dc) * EP[:vREG_DC_Charge][y, t]
            EP[:eGridExport][y, t] += vREG_DC_Charge[y, t] / by_rid(y, :etainverter)
            EP[:eInverterExport][y, t] += vREG_DC_Charge[y, t] / by_rid(y, :etainverter)
        end
        for y in DC_CHARGE_RSV
            eVreStorRsvOnlyBalance[y, t] += vRSV_DC_Charge[y, t] / by_rid(y, :etainverter)
            eChargeDCMin[y, t] -= vRSV_DC_Charge[y, t]
        end

        for y in AC_DISCHARGE_REG
            eVreStorRegOnlyBalance[y, t] += vREG_AC_Discharge[y, t]
            eDischargeACMin[y, t] -= vREG_AC_Discharge[y, t]
            eDischargeMax[y, t] += EP[:vREG_AC_Discharge][y, t] / by_rid(y, :eff_down_ac)
            EP[:eGridExport][y, t] += vREG_AC_Discharge[y, t]
        end
        for y in AC_DISCHARGE_RSV
            eVreStorRsvOnlyBalance[y, t] += vRSV_AC_Discharge[y, t]
            eDischargeMax[y, t] += EP[:vRSV_AC_Discharge][y, t] / by_rid(y, :eff_down_ac)
            EP[:eGridExport][y, t] += vRSV_AC_Discharge[y, t]
        end

        for y in AC_CHARGE_REG
            eVreStorRegOnlyBalance[y, t] += vREG_AC_Charge[y, t]
            eChargeACMin[y, t] -= vREG_AC_Charge[y, t]
            eChargeMax[y, t] += by_rid(y, :eff_down_ac) * EP[:vREG_AC_Charge][y, t]
            EP[:eGridExport][y, t] += vREG_AC_Charge[y, t]
        end
        for y in AC_CHARGE_RSV
            eVreStorRsvOnlyBalance[y, t] += vRSV_AC_Charge[y, t]
            eChargeACMin[y, t] -= vRSV_AC_Charge[y, t]
        end

        for y in VS_SYM_DC_REG
            EP[:eChargeDischargeMaxDC][y, t] += (vREG_DC_Discharge[y, t]
                                                 +
                                                 vREG_DC_Charge[y, t])
        end
        for y in VS_SYM_DC_RSV
            EP[:eChargeDischargeMaxDC][y, t] += vRSV_DC_Discharge[y, t]
        end

        for y in VS_SYM_AC_REG
            EP[:eChargeDischargeMaxAC][y, t] += (vREG_AC_Discharge[y, t]
                                                 +
                                                 vREG_AC_Charge[y, t])
        end
        for y in VS_SYM_AC_RSV
            EP[:eChargeDischargeMaxAC][y, t] += vRSV_AC_Discharge[y, t]
        end

        for y in VS_ASYM_DC_DISCHARGE_REG
            EP[:eVreStorMaxDischargingDC][y, t] += vREG_DC_Discharge[y, t]
        end
        for y in VS_ASYM_DC_DISCHARGE_RSV
            EP[:eVreStorMaxDischargingDC][y, t] += vRSV_DC_Discharge[y, t]
        end

        for y in VS_ASYM_DC_CHARGE_REG
            EP[:eVreStorMaxChargingDC][y, t] += vREG_DC_Charge[y, t]
        end

        for y in VS_ASYM_AC_DISCHARGE_REG
            EP[:eVreStorMaxDischargingAC][y, t] += vREG_AC_Discharge[y, t]
        end
        for y in VS_ASYM_AC_DISCHARGE_RSV
            EP[:eVreStorMaxDischargingAC][y, t] += vRSV_AC_Discharge[y, t]
        end

        for y in VS_ASYM_AC_CHARGE_REG
            EP[:eVreStorMaxChargingAC][y, t] += vREG_AC_Charge[y, t]
        end
    end

    if CapacityReserveMargin > 0
        for t in 1:T
            for y in DC_DISCHARGE
                eDischargeMax[y, t] += EP[:vCAPRES_DC_DISCHARGE][y, t] /
                                       by_rid(y, :eff_down_dc)
            end
            for y in AC_DISCHARGE
                eDischargeMax[y, t] += EP[:vCAPRES_AC_DISCHARGE][y, t] /
                                       by_rid(y, :eff_down_ac)
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
