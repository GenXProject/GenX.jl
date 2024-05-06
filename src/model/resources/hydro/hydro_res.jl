@doc raw"""
	hydro_res!(EP::Model, inputs::Dict, setup::Dict)
This module defines the operational constraints for reservoir hydropower plants.
Hydroelectric generators with water storage reservoirs ($y \in \mathcal{W}$) are effectively modeled as energy storage devices that cannot charge from the grid and instead receive exogenous inflows to their storage reservoirs, reflecting stream flow inputs. For resources with unknown reservoir capacity ($y \in \mathcal{W}^{nocap}$), their operation is parametrized by their generation efficiency, $\eta_{y,z}^{down}$, and energy inflows to the reservoir at every time-step, represented as a fraction of the total power capacity,($\rho^{max}_{y,z,t}$).  In case reservoir capacity is known ($y \in \mathcal{W}^{cap}$), an additional parameter, $\mu^{stor}_{y,z}$, referring to the ratio of energy capacity to discharge power capacity, is used to define the available reservoir storage capacity.

**Storage inventory balance**
Reservoir hydro systems are governed by the storage inventory balance constraint given below. This constraint enforces that energy level of the reservoir resource $y$ and zone $z$ in time step $t$ ($\Gamma_{y,z,t}$) is defined as the sum of the reservoir level in the previous time step, less the amount of electricity generated, $\Theta_{y,z,t}$ (accounting for the generation efficiency, $\eta_{y,z}^{down}$), minus any spillage $\varrho_{y,z,t}$, plus the hourly inflows into the reservoir (equal to the installed reservoir discharged capacity times the normalized hourly inflow parameter $\rho^{max}_{y,z, t}$).
```math
\begin{aligned}
&\Gamma_{y,z,t} = \Gamma_{y,z,t-1} -\frac{1}{\eta_{y,z}^{down}}\Theta_{y,z,t} - \varrho_{y,z,t} + \rho^{max}_{y,z,t} \times \Delta^{total}_{y,z}  \hspace{.1 cm}  \forall y \in \mathcal{W}, z \in \mathcal{Z}, t \in \mathcal{T}^{interior} \\
&\Gamma_{y,z,t} = \Gamma_{y,z,t+\tau^{period}-1} -\frac{1}{\eta_{y,z}^{down}}\Theta_{y,z,t} - \varrho_{y,z,t} + \rho^{max}_{y,z,t} \times \Delta^{total}_{y,z}  \hspace{.1 cm}  \forall y \in \mathcal{W}, z \in \mathcal{Z}, t \in \mathcal{T}^{start}
\end{aligned}
```
We implement time-wrapping to endogenize the definition of the intial state prior to the first period with the following assumption. If time step $t$ is the first time step of the year then storage inventory at $t$ is defined based on last time step of the year. Alternatively, if time step $t$ is the first time step of a representative period, then storage inventory at $t$ is defined based on the last time step of the representative period. Thus, when using representative periods, the storage balance constraint for hydro resources does not allow for energy exchange between representative periods.
Note: in future updates, an option to model hydro resources with large reservoirs that can transfer energy across sample periods will be implemented, similar to the functions for modeling long duration energy storage in ```long_duration_storage.jl```.

**Ramping Limits**
The following constraints enforce hourly changes in power output (ramps down and ramps up) to be less than the maximum ramp rates ($\kappa^{down}_{y,z}$ and $\kappa^{up}_{y,z}$ ) in per unit terms times the total installed capacity of technology y ($\Delta^{total}_{y,z}$).
```math
\begin{aligned}
&\Theta_{y,z,t} + f_{y,z,t} + r_{y,z,t} - \Theta_{y,z,t-1} - f_{y,z,t-1} \leq \kappa^{up}_{y,z} \times \Delta^{total}_{y,z}
\hspace{2 cm}  \forall y \in \mathcal{W}, z \in \mathcal{Z}, t \in \mathcal{T}
\end{aligned}
```
```math
\begin{aligned}
&\Theta_{y,z,t-1} + f_{y,z,t-1}  + r_{y,z,t-1} - \Theta_{y,z,t} - f_{y,z,t}\leq \kappa^{down}_{y,z} \Delta^{total}_{y,z}
\hspace{2 cm}  \forall y \in \mathcal{W}, z \in \mathcal{Z}, t \in \mathcal{T}
\end{aligned}
```
Ramping constraints are enforced for all time steps except the first time step of the year or first time of each representative period when using representative periods to model grid operations.

**Power generation and stream flow bounds**
Electricity production plus total spilled power from hydro resources is constrained to always be above a minimum output parameter, $\rho^{min}_{y,z}$, to represent operational constraints related to minimum stream flows or other demands for water from hydro reservoirs. Electricity production is constrained by either the the net installed capacity or by the energy level in the reservoir in the prior time step, whichever is more binding. For the latter constraint, the constraint for the first time step of the year (or the first time step of each representative period) is implemented based on energy storage level in last time step of the year (or last time step of each representative period).
```math
\begin{aligned}
&\Theta_{y,z,t} + \varrho_{y,z,t}  \geq \rho^{min}_{y,z} \times \Delta^{total}_{y,z}
\hspace{2 cm}  \forall y \in \mathcal{W}, z \in \mathcal{Z}, t \in \mathcal{T}
\end{aligned}
```
```math
\begin{aligned}
\Theta_{y,t}  \leq \times \Delta^{total}_{y,z}
\hspace{4 cm}  \forall y \in \mathcal{W}, z \in \mathcal{Z}, t\in \mathcal{T}
\end{aligned}
```
```math
\begin{aligned}
\Theta_{y,z,t} \leq  \Gamma_{y,t-1}
\hspace{4 cm}  \forall y \in \mathcal{W}, z \in \mathcal{Z}, t\in \mathcal{T}
\end{aligned}
```

**Reservoir energy capacity constraint**
In case the reservoir capacity is known ($y \in W^{cap}$), then an additional constraint enforces the total stored energy in each time step to be less than or equal to the available reservoir capacity. Here, the reservoir capacity is defined multiplying the parameter, $\mu^{stor}_{y,z}$ with the available power capacity.
```math
\begin{aligned}
\Gamma_{y,z, t} \leq \mu^{stor}_{y,z}\times \Delta^{total}_{y,z}
\hspace{4 cm}  \forall y \in \mathcal{W}^{cap}, z \in \mathcal{Z}, t\in \mathcal{T}
\end{aligned}
```
"""
function hydro_res!(EP::Model, inputs::Dict, setup::Dict)
    println("Hydro Reservoir Core Resources Module")

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

    # Reservoir hydro storage level of resource "y" at hour "t" [MWh] on zone "z" - unbounded
    @variable(EP, vS_HYDRO[y in HYDRO_RES, t = 1:T]>=0)

    # Hydro reservoir overflow (water spill) variable
    @variable(EP, vSPILL[y in HYDRO_RES, t = 1:T]>=0)

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

    @constraint(EP,
        cHydroReservoirStart[y in CONSTRAINTSET, t in START_SUBPERIODS],
        EP[:vS_HYDRO][y,
            t]==EP[:vS_HYDRO][y, hoursbefore(p, t, 1)] -
                (1 / efficiency_down(gen[y]) * EP[:vP][y, t]) - vSPILL[y, t] +
                inputs["pP_Max"][y, t] * EP[:eTotalCap][y])

    ### Constraints commmon to all reservoir hydro (y in set HYDRO_RES) ###
    @constraints(EP,
        begin
            ### NOTE: time coupling constraints in this block do not apply to first hour in each sample period;
            # Energy stored in reservoir at end of each other hour is equal to energy at end of prior hour less generation and spill and + inflows in the current hour
            # The ["pP_Max"][y,t] term here refers to inflows as a fraction of peak discharge power capacity.
            # DEV NOTE: Last inputs["pP_Max"][y,t] term above is inflows; currently part of capacity factors inputs in Generators_variability.csv but should be moved to its own Hydro_inflows.csv input in future.

            # Constraints for reservoir hydro
            cHydroReservoirInterior[y in HYDRO_RES, t in INTERIOR_SUBPERIODS],
            EP[:vS_HYDRO][y, t] == (EP[:vS_HYDRO][y, hoursbefore(p, t, 1)] -
             (1 / efficiency_down(gen[y]) * EP[:vP][y, t]) - vSPILL[y, t] +
             inputs["pP_Max"][y, t] * EP[:eTotalCap][y])

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
            cHydroMinFlow[y in HYDRO_RES, t in 1:T],
            EP[:vP][y, t] + EP[:vSPILL][y, t] >= min_power(gen[y]) * EP[:eTotalCap][y]
            # DEV NOTE: When creating new hydro inputs, should rename Min_Power with Min_flow or similar for clarity since this includes spilled water as well

            # Maximum discharging rate must be less than power rating OR available stored energy at start of hour, whichever is less
            # DEV NOTE: We do not currently account for hydro power plant outages - leave it for later to figure out if we should.
            # DEV NOTE (CONTD): If we defin pPMax as hourly availability of the plant and define inflows as a separate parameter, then notation will be consistent with its use for other resources
            cHydroMaxPower[y in HYDRO_RES, t in 1:T], EP[:vP][y, t] <= EP[:eTotalCap][y]
            cHydroMaxOutflow[y in HYDRO_RES, t in 1:T],
            EP[:vP][y, t] <= EP[:vS_HYDRO][y, hoursbefore(p, t, 1)]
        end)

    ### Constraints to limit maximum energy in storage based on known limits on reservoir energy capacity (only for HYDRO_RES_KNOWN_CAP)
    # Maximum energy stored in reservoir must be less than energy capacity in all hours - only applied to HYDRO_RES_KNOWN_CAP
    @constraint(EP,
        cHydroMaxEnergy[y in HYDRO_RES_KNOWN_CAP, t in 1:T],
        EP[:vS_HYDRO][y, t]<=hydro_energy_to_power_ratio(gen[y]) * EP[:eTotalCap][y])

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
