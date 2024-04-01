@doc raw"""
	thermal_no_commit!(EP::Model, inputs::Dict, setup::Dict)

This function defines the operating constraints for thermal power plants NOT subject to unit commitment constraints on power plant start-ups and shut-down decisions ($y \in H \setminus UC$).

**Ramping limits**

Thermal resources not subject to unit commitment ($y \in H \setminus UC$) adhere instead to the following ramping limits on hourly changes in power output:

```math
\begin{aligned}
	\Theta_{y,z,t-1} - \Theta_{y,z,t} \leq \kappa_{y,z}^{down} \Delta^{\text{total}}_{y,z} \hspace{1cm} \forall y \in \mathcal{H \setminus UC}, \forall z \in \mathcal{Z}, \forall t \in \mathcal{T}
\end{aligned}
```

```math
\begin{aligned}
	\Theta_{y,z,t} - \Theta_{y,z,t-1} \leq \kappa_{y,z}^{up} \Delta^{\text{total}}_{y,z} \hspace{1cm} \forall y \in \mathcal{H \setminus UC}, \forall z \in \mathcal{Z}, \forall t \in \mathcal{T}
\end{aligned}
```
(See Constraints 1-2 in the code)

This set of time-coupling constraints wrap around to ensure the power output in the first time step of each year (or each representative period), $t \in \mathcal{T}^{start}$, is within the eligible ramp of the power output in the final time step of the year (or each representative period), $t+\tau^{period}-1$.

**Minimum and maximum power output**

When not modeling regulation and reserves, thermal units not subject to unit commitment decisions are bound by the following limits on maximum and minimum power output:

```math
\begin{aligned}
	\Theta_{y,z,t} \geq \rho^{min}_{y,z} \times \Delta^{total}_{y,z}
	\hspace{1cm} \forall y \in \mathcal{H \setminus UC}, \forall z \in \mathcal{Z}, \forall t \in \mathcal{T}
\end{aligned}
```

```math
\begin{aligned}
	\Theta_{y,z,t} \leq \rho^{max}_{y,z,t} \times \Delta^{total}_{y,z}
	\hspace{1cm} \forall y \in \mathcal{H \setminus UC}, \forall z \in \mathcal{Z}, \forall t \in \mathcal{T}
\end{aligned}
```
(See Constraints 3-4 in the code)
"""
function thermal_no_commit!(EP::Model, inputs::Dict, setup::Dict)
    println("Thermal (No Unit Commitment) Resources Module")

    gen = inputs["RESOURCES"]

    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones

    p = inputs["hours_per_subperiod"] #total number of hours per subperiod

    THERM_NO_COMMIT = inputs["THERM_NO_COMMIT"]

    ### Expressions ###

    ## Power Balance Expressions ##
    @expression(EP, ePowerBalanceThermNoCommit[t = 1:T, z = 1:Z],
        sum(EP[:vP][y, t]
            for y in intersect(THERM_NO_COMMIT, resources_in_zone_by_rid(gen, z))))
    add_similar_to_expression!(EP[:ePowerBalance], ePowerBalanceThermNoCommit)

    ### Constraints ###

    ### Maximum ramp up and down between consecutive hours (Constraints #1-2)
    @constraints(EP,
        begin

            ## Maximum ramp up between consecutive hours
            [y in THERM_NO_COMMIT, t in 1:T],
            EP[:vP][y, t] - EP[:vP][y, hoursbefore(p, t, 1)] <=
            ramp_up_fraction(gen[y]) * EP[:eTotalCap][y]

            ## Maximum ramp down between consecutive hours
            [y in THERM_NO_COMMIT, t in 1:T],
            EP[:vP][y, hoursbefore(p, t, 1)] - EP[:vP][y, t] <=
            ramp_down_fraction(gen[y]) * EP[:eTotalCap][y]
        end)

    ### Minimum and maximum power output constraints (Constraints #3-4)
    if setup["OperationalReserves"] == 1
        # If modeling with regulation and reserves, constraints are established by thermal_no_commit_operational_reserves() function below
        thermal_no_commit_operational_reserves!(EP, inputs)
    else
        @constraints(EP,
            begin
                # Minimum stable power generated per technology "y" at hour "t" Min_Power
                [y in THERM_NO_COMMIT, t = 1:T],
                EP[:vP][y, t] >= min_power(gen[y]) * EP[:eTotalCap][y]

                # Maximum power generated per technology "y" at hour "t"
                [y in THERM_NO_COMMIT, t = 1:T],
                EP[:vP][y, t] <= inputs["pP_Max"][y, t] * EP[:eTotalCap][y]
            end)
    end
    # END Constraints for thermal resources not subject to unit commitment
end

@doc raw"""
	thermal_no_commit_operational_reserves!(EP::Model, inputs::Dict)

This function is called by the ```thermal_no_commit()``` function when regulation and reserves constraints are active and defines reserve related constraints for thermal power plants not subject to unit commitment constraints on power plant start-ups and shut-down decisions.

**Maximum contributions to frequency regulation and reserves**

Thermal units not subject to unit commitment adhere instead to the following constraints on maximum reserve and regulation contributions:

```math
\begin{aligned}
	f_{y,z,t} \leq \upsilon^{reg}_{y,z} \times \rho^{max}_{y,z,t} \Delta^{\text{total}}_{y,z} \hspace{1cm} \forall y \in \mathcal{H \setminus UC}, \forall z \in \mathcal{Z}, \forall t \in \mathcal{T}
\end{aligned}
```

```math
\begin{aligned}
	r_{y,z,t} \leq \upsilon^{rsv}_{y,z} \times \rho^{max}_{y,z,t} \Delta^{\text{total}}_{y,z} \hspace{1cm} \forall y \in \mathcal{H \setminus UC}, \forall z \in \mathcal{Z}, \forall t \in \mathcal{T}
\end{aligned}
```

where $f_{y,z,t}$ is the frequency regulation contribution limited by the maximum regulation contribution $\upsilon^{reg}_{y,z}$, and $r_{y,z,t}$ is the reserves contribution limited by the maximum reserves contribution $\upsilon^{rsv}_{y,z}$. Limits on reserve contributions reflect the maximum ramp rate for the thermal resource in whatever time interval defines the requisite response time for the regulation or reserve products (e.g., 5 mins or 15 mins or 30 mins). These response times differ by system operator and reserve product, and so the user should define these parameters in a self-consistent way for whatever system context they are modeling.

**Minimum and maximum power output**

When modeling regulation and spinning reserves, thermal units not subject to unit commitment are bound by the following limits on maximum and minimum power output:

```math
\begin{aligned}
	\Theta_{y,z,t} - f_{y,z,t} \geq \rho^{min}_{y,z} \times \Delta^{\text{total}}_{y,z}
	\hspace{1cm} \forall y \in \mathcal{H \setminus UC}, \forall z \in \mathcal{Z}, \forall t \in \mathcal{T}
\end{aligned}
```

```math
\begin{aligned}
	\Theta_{y,z,t} + f_{y,z,t} + r_{y,z,t} \leq \rho^{max}_{y,z,t} \times \Delta^{\text{total}}_{y,z}
	\hspace{1cm} \forall y \in \mathcal{H \setminus UC}, \forall z \in \mathcal{Z}, \forall t \in \mathcal{T}
\end{aligned}
```

Note there are multiple versions of these constraints in the code in order to avoid creation of unecessary constraints and decision variables for thermal units unable to provide regulation and/or reserves contributions due to input parameters (e.g. ```Reg_Max=0``` and/or ```RSV_Max=0```).
"""
function thermal_no_commit_operational_reserves!(EP::Model, inputs::Dict)
    println("Thermal No Commit Reserves Module")

    gen = inputs["RESOURCES"]

    T = inputs["T"]     # Number of time steps (hours)

    THERM_NO_COMMIT = setdiff(inputs["THERM_ALL"], inputs["COMMIT"])

    REG = intersect(THERM_NO_COMMIT, inputs["REG"]) # Set of thermal resources with regulation reserves
    RSV = intersect(THERM_NO_COMMIT, inputs["RSV"]) # Set of thermal resources with spinning reserves

    vP = EP[:vP]
    vREG = EP[:vREG]
    vRSV = EP[:vRSV]
    eTotalCap = EP[:eTotalCap]

    max_power(y, t) = inputs["pP_Max"][y, t]

    # Maximum regulation and reserve contributions
    @constraint(EP,
        [y in REG, t in 1:T],
        vREG[y, t]<=max_power(y, t) * reg_max(gen[y]) * eTotalCap[y])
    @constraint(EP,
        [y in RSV, t in 1:T],
        vRSV[y, t]<=max_power(y, t) * rsv_max(gen[y]) * eTotalCap[y])

    # Minimum stable power generated per technology "y" at hour "t" and contribution to regulation must be > min power
    expr = extract_time_series_to_expression(vP, THERM_NO_COMMIT)
    add_similar_to_expression!(expr[REG, :], -vREG[REG, :])
    @constraint(EP,
        [y in THERM_NO_COMMIT, t in 1:T],
        expr[y, t]>=min_power(gen[y]) * eTotalCap[y])

    # Maximum power generated per technology "y" at hour "t"  and contribution to regulation and reserves up must be < max power
    expr = extract_time_series_to_expression(vP, THERM_NO_COMMIT)
    add_similar_to_expression!(expr[REG, :], vREG[REG, :])
    add_similar_to_expression!(expr[RSV, :], vRSV[RSV, :])
    @constraint(EP,
        [y in THERM_NO_COMMIT, t in 1:T],
        expr[y, t]<=max_power(y, t) * eTotalCap[y])
end
