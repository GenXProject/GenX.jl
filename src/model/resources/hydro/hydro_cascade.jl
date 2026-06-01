@doc raw"""

"""
function hydro_cascade!(EP::Model, inputs::Dict, setup::Dict)
    println("Hydro Cascade Resources Module")

    gen = inputs["RESOURCES"]

    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones

    p = inputs["hours_per_subperiod"] # total number of hours per subperiod

    HYDRO_RES = inputs["HYDRO_RES"]# Set of all reservoir hydro resources, used for common constraints
    HYDRO_RES_KNOWN_CAP = inputs["HYDRO_RES_KNOWN_CAP"] # Reservoir hydro resources modeled with unknown reservoir energy capacity

    STOR_HYDRO_SHORT_DURATION = inputs["STOR_HYDRO_SHORT_DURATION"]
    representative_periods = inputs["REP_PERIOD"]

    START_SUBPERIODS = inputs["START_SUBPERIODS"]
    INTERIOR_SUBPERIODS = inputs["INTERIOR_SUBPERIODS"]

    # Cascade links between reservoirs
    if isempty(inputs["HYDRO_IDS"]) || isempty(inputs["RESERVOIR_IDS"])
        error("CascadeHydro is enabled but HYDRO_IDS or RESERVOIR_IDS are not defined for all reservoir hydro resources. Please define these parameters in the Hydro.csv input file.")
    end
    HYDRO_IDS = inputs["HYDRO_IDS"]
    RESERVOIR_IDS = inputs["RESERVOIR_IDS"]
    BYPASS_TO = inputs["HYDRO_BYPASS_TO"] # Dictionary that returns reservoir y that spills to key reservoir
    DISCHARGE_TO = inputs["HYDRO_DISCHARGE_TO"] # Dictionary that returns reservoir y that discharges to key reservoir
    PUMP_TO = inputs["HYDRO_PUMP_TO"] # Dictionary that returns reservoir y that pumps to key reservoir

    # These variables are used in the ramp-up and ramp-down expressions
    reserves_term = @expression(EP, [y in HYDRO_RES, t in 1:T], 0)
    regulation_term = @expression(EP, [y in HYDRO_RES, t in 1:T], 0)

    if setup["OperationalReserves"] > 0
        HYDRO_RES_REG = intersect(HYDRO_RES, inputs["REG"]) # Set of reservoir hydro resources with regulation reserves
        HYDRO_RES_RSV = intersect(HYDRO_RES, inputs["RSV"]) # Set of reservoir hydro resources with spinning reserves
        regulation_term = @expression(EP, [y in HYDRO_RES, t in 1:T],
            y ∈ HYDRO_RES_REG ? EP[:vREG][y, t] - EP[:vREG][y, hoursbefore(p, t, 1)] : 0)
        reserves_term = @expression(EP, [y in HYDRO_RES, t in 1:T],
            y ∈ HYDRO_RES_RSV ? EP[:vRSV][y, t] : 0)
    end

    ### Variables ###

    # Reservoir hydro storage level of resource "y" at hour "t" on zone "z" - unbounded [Mm^3]
    @variable(EP, vS_HYDRO[y in HYDRO_RES, t = 1:T]>=0)

    # Hydro water discharge (Mm^3/h) from unit y at hour t
    @variable(EP, vDISCHARGE[y in HYDRO_RES, t = 1:T]>=0)

    # Hydro reservoir overflow (water spill) variable [Mm^3/h]
    @variable(EP, vSPILL[y in HYDRO_RES, t = 1:T]>=0)

    # Hydro water bypass (Mm^3/h) from unit y at hour t
    @variable(EP, vBYPASS[y in HYDRO_RES, t = 1:T]>=0)
    
    ### Expressions ###

    ## Power Balance Expressions ##
    @expression(EP, ePowerBalanceHydroRes[t = 1:T, z = 1:Z],
        sum(EP[:vP][y, t] for y in intersect(HYDRO_RES, resources_in_zone_by_rid(gen, z))))
    add_similar_to_expression!(EP[:ePowerBalance], ePowerBalanceHydroRes)

    # Capacity Reserves Margin policy
    if setup["CapacityReserveMargin"] > 0
        @expression(EP,
            eCapResMarBalanceHydro[res = 1:inputs["NCapacityReserveMargin"], t = 1:T],
            sum(derating_factor(gen[y], tag = res) * EP[:vP][y, t] for y in HYDRO_RES))
        add_similar_to_expression!(EP[:eCapResMarBalance], eCapResMarBalanceHydro)
    end

    ### Constratints ###

    if representative_periods > 1 && !isempty(inputs["STOR_HYDRO_LONG_DURATION"])
        CONSTRAINTSET = STOR_HYDRO_SHORT_DURATION
    else
        CONSTRAINTSET = HYDRO_RES
    end

    # End reservoir level >= start reservoir level
    @constraint(EP,
        cHydroReservoirStartEnd[y in CONSTRAINTSET],
        EP[:vS_HYDRO][y, T] >= EP[:vS_HYDRO][y, 1])
    
    # @constraint(EP,
    #     cHydroReservoirStart[y in CONSTRAINTSET, t in START_SUBPERIODS],
    #     EP[:vS_HYDRO][y,t]==EP[:vS_HYDRO][y, hoursbefore(p, t, 1)] -
    #     EP[:vDISCHARGE][y, t] - 
    #     EP[:vSPILL][y, t] +
    #     inputs["pP_Max"][y, t] #+
    #     #(haskey(BYPASS_TO, gen[y].reservoir_id) ?           # Add inflows from upstream reservoir spills
    #     #vSPILL[BYPASS_TO[gen[y].reservoir_id], hoursbefore(p, t, 1)] : 0) +    
    #     #(haskey(DISCHARGE_TO, gen[y].reservoir_id) ?       # Add inflows from upstream reservoir discharges    
    #     #EP[:vDISCHARGE][DISCHARGE_TO[gen[y].reservoir_id], hoursbefore(p, t, 1)] : 0)
    #     )

    ### Constraints commmon to all reservoir hydro (y in set HYDRO_RES) ###
    @constraints(EP,
        begin
            ### NOTE: time coupling constraints in this block do not apply to first hour in each sample period;
            # Energy stored in reservoir at end of each other hour is equal to energy at end of prior hour less generation and spill and + inflows in the current hour
            # The ["pP_Max"][y,t] term here refers to inflows as a fraction of peak discharge power capacity.
            # DEV NOTE: Last inputs["pP_Max"][y,t] term above is inflows; currently part of capacity factors inputs in Generators_variability.csv but should be moved to its own Hydro_inflows.csv input in future.

            # Constraints for reservoir hydro
            cHydroReservoirInterior[y in HYDRO_RES, t in INTERIOR_SUBPERIODS],
            EP[:vS_HYDRO][y, t] == EP[:vS_HYDRO][y, hoursbefore(p, t, 1)] -
                EP[:vDISCHARGE][y, t] - 
                EP[:vSPILL][y, t] - 
                EP[:vBYPASS][y, t] + 
                inputs["pP_Max"][y, t] +                                # Inflow parameter pP_Max     
                (haskey(BYPASS_TO, gen[y].id) ?               # Add inflows from upstream reservoir bypass
                EP[:vBYPASS][BYPASS_TO[gen[y].id], hoursbefore(p, t, 1)] : 0) +    
                (haskey(DISCHARGE_TO, gen[y].id) ?           # Add inflows from upstream reservoir discharges    
                EP[:vDISCHARGE][DISCHARGE_TO[gen[y].id], hoursbefore(p, t, 1)] : 0)

            # Reservoir limits for each reservoir
            cHydroReservoirLimits[y in HYDRO_RES, t in 1:T],
            EP[:vS_HYDRO][y, t] <= reservoir_cap(gen[y])

            # Hydro Power Generation from water discharge for hydro resources
            cHydroGenerationConversion[y in HYDRO_RES, t in 1:T],
            EP[:vP][y, t] == gen[y].e_equivalent * EP[:vDISCHARGE][y, t]   # e_equivalent [kWh/m^3][GWh/Mm^3]. Due to scale_resources_data(), vP is in GW and vDISCHARGE is in Mm^3/h

            
            # DEVNOTE: This should be a function of max discharge, i.e. 1.5-2.0 times q_max
            # Bypass limits
            cBypassLimit[y in HYDRO_RES, t in 1:T],
            vBYPASS[y, t] <= 1.5
            cBypassLimitInitial[y in HYDRO_RES, t in 1:T],
            EP[:vBYPASS][y, 1] == 0

            # Spillage limits
            cSpillLimit[y in HYDRO_RES, t in 1:T],
            vSPILL[y, t] <= 1

            cHydroMaxOutflow[y in HYDRO_RES, t in 1:T],
            EP[:vDISCHARGE][y, t]+ EP[:vSPILL][y,t]+ EP[:vBYPASS][y,t] <=
            EP[:vS_HYDRO][y, hoursbefore(p, t, 1)]

            # cHydroMinFlow[y in HYDRO_RES, t in 1:T],
            # EP[:vDISCHARGE][y, t] + EP[:vSPILL][y, t] + EP[:vBYPASS] >= min_flow(gen[y])  # Min flow in Mm3/h

            # Equations regarding Power
            # Maximum ramp up and down
            cRampUp[y in HYDRO_RES, t in 1:T],
            EP[:vP][y, t] + regulation_term[y, t] + reserves_term[y, t] -
            EP[:vP][y, hoursbefore(p, t, 1)] <=
            ramp_up_fraction(gen[y]) * EP[:eTotalCap][y]
            cRampDown[y in HYDRO_RES, t in 1:T],
            EP[:vP][y, hoursbefore(p, t, 1)] - EP[:vP][y, t] - regulation_term[y, t] +
            reserves_term[y, hoursbefore(p, t, 1)] <=
            ramp_down_fraction(gen[y]) * EP[:eTotalCap][y]
            # Minimum streamflow running requirements (power generation and spills must be >= min value) in all hours
            cHydroMaxPower[y in HYDRO_RES, t in 1:T], EP[:vP][y, t] <= EP[:eTotalCap][y]
        end)

    ### Constraints to limit maximum energy in storage based on known limits on reservoir energy capacity (only for HYDRO_RES_KNOWN_CAP)
    # Maximum water stored in each reservoir must be less than the reservoir caponly applied to HYDRO_RES_KNOWN_CAP
    @constraint(EP,
        cHydroMaxEnergy[y in HYDRO_RES_KNOWN_CAP, t in 1:T],
        EP[:vS_HYDRO][y, t]<= reservoir_cap(gen[y]))

    if setup["OperationalReserves"] == 1
        ### Reserve related constraints for reservoir hydro resources (y in HYDRO_RES), if used
        hydro_res_operational_reserves!(EP, inputs)
    end
    ##CO2 Polcy Module Hydro Res Generation by zone
    @expression(EP, eGenerationByHydroRes[z = 1:Z, t = 1:T], # the unit is GW
        sum(EP[:vP][y, t] for y in intersect(HYDRO_RES, resources_in_zone_by_rid(gen, z))))
    add_similar_to_expression!(EP[:eGenerationByZone], eGenerationByHydroRes)
end

@doc raw"""
	hydro_res_operational_reserves!(EP::Model, inputs::Dict)
This module defines the modified constraints and additional constraints needed when modeling operating reserves

**Modifications when operating reserves are modeled**
When modeling operating reserves, the constraints regarding maximum power flow limits are modified to account for procuring some of the available capacity for frequency regulation ($f_{y,z,t}$) and "updward" operating (or spinning) reserves ($r_{y,z,t}$).
```math
\begin{aligned}
 \Theta_{y,z,t} + f_{y,z,t} +r_{y,z,t}  \leq  \times \Delta^{total}_{y,z}
\hspace{4 cm}  \forall y \in \mathcal{W}, z \in \mathcal{Z}, t\in \mathcal{T}
\end{aligned}
```
The amount of downward frequency regulation reserves cannot exceed the current power output.
```math
\begin{aligned}
 f_{y,z,t} \leq \Theta_{y,z,t}
\hspace{4 cm}  \forall y \in \mathcal{W}, z \in \mathcal{Z}, t \in \mathcal{T}
\end{aligned}
```
The amount of frequency regulation and operating reserves procured in each time step is bounded by the user-specified fraction ($\upsilon^{reg}_{y,z}$,$\upsilon^{rsv}_{y,z}$) of nameplate capacity for each reserve type, reflecting the maximum ramp rate for the hydro resource in whatever time interval defines the requisite response time for the regulation or reserve products (e.g., 5 mins or 15 mins or 30 mins). These response times differ by system operator and reserve product, and so the user should define these parameters in a self-consistent way for whatever system context they are modeling.
```math
\begin{aligned}
f_{y,z,t} \leq \upsilon^{reg}_{y,z} \times \Delta^{total}_{y,z}
\hspace{4 cm}  \forall y \in \mathcal{W}, z \in \mathcal{Z}, t \in \mathcal{T} \\
r_{y,z, t} \leq \upsilon^{rsv}_{y,z}\times \Delta^{total}_{y,z}
\hspace{4 cm}  \forall y \in \mathcal{W}, z \in \mathcal{Z}, t \in \mathcal{T}
\end{aligned}
```
"""
function hydro_res_operational_reserves!(EP::Model, inputs::Dict)
    println("Hydro Reservoir Operational Reserves Module")

    gen = inputs["RESOURCES"]

    T = inputs["T"]     # Number of time steps (hours)

    HYDRO_RES = inputs["HYDRO_RES"]
    REG = inputs["REG"]
    RSV = inputs["RSV"]

    HYDRO_RES_REG = intersect(HYDRO_RES, REG) # Set of reservoir hydro resources with regulation reserves
    HYDRO_RES_RSV = intersect(HYDRO_RES, RSV) # Set of reservoir hydro resources with spinning reserves

    vP = EP[:vP]
    vREG = EP[:vREG]
    vRSV = EP[:vRSV]
    eTotalCap = EP[:eTotalCap]

    max_up_reserves_lhs = extract_time_series_to_expression(vP, HYDRO_RES)
    max_dn_reserves_lhs = extract_time_series_to_expression(vP, HYDRO_RES)

    S = HYDRO_RES_REG
    add_similar_to_expression!(max_up_reserves_lhs[S, :], vREG[S, :])
    add_similar_to_expression!(max_dn_reserves_lhs[S, :], -vREG[S, :])

    S = HYDRO_RES_RSV
    add_similar_to_expression!(max_up_reserves_lhs[S, :], vRSV[S, :])

    @constraint(EP, [y in HYDRO_RES, t in 1:T], max_up_reserves_lhs[y, t]<=eTotalCap[y])
    @constraint(EP, [y in HYDRO_RES, t in 1:T], max_dn_reserves_lhs[y, t]>=0)

    @constraint(EP,
        [y in HYDRO_RES_REG, t in 1:T],
        vREG[y, t]<=reg_max(gen[y]) * eTotalCap[y])
    @constraint(EP,
        [y in HYDRO_RES_RSV, t in 1:T],
        vRSV[y, t]<=rsv_max(gen[y]) * eTotalCap[y])
end
