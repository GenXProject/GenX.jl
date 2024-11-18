@doc raw"""
	thermal_commit!(EP::Model, inputs::Dict, setup::Dict)

This function defines the operating constraints for thermal power plants subject to unit commitment constraints on power plant start-ups and shut-down decision ($y \in UC$).

We model capacity investment decisions and commitment and cycling (start-up, shut-down) of thermal generators using the integer clustering technique developed in [Palmintier, 2011](https://pennstate.pure.elsevier.com/en/publications/impact-of-unit-commitment-constraints-on-generation-expansion-pla), [Palmintier, 2013](https://dspace.mit.edu/handle/1721.1/79147), and [Palmintier, 2014](https://ieeexplore.ieee.org/document/6684593). In a typical binary unit commitment formulation, each unit is either on or off. With the clustered unit commitment formulation, one or more cluster(s) of similar generators are clustered by type and zone (typically using heat rate and fixed O\&M cost to create clusters), and the integer commitment state variable for each cluster varies from zero to the number of units in the cluster, $\frac{\Delta^{total}_{y,z}}{\Omega^{size}_{y,z}}$. As discussed in \cite{Palmintier2014}, this approach replaces the large set of binary commitment decisions and associated constraints, which scale directly with the number of individual units, with a smaller set of integer commitment states and  constraints, one for each cluster $y$. The dimensionality of the problem thus scales with the number of units of a given type in each zone, rather than by the number of discrete units, significantly improving computational efficiency. However, this method entails the simplifying assumption that all clustered units have identical parameters (e.g., capacity size, ramp rates, heat rate) and that all committed units in a given time step $t$ are operating at the same power output per unit.

**Power balance expression**

This function adds the sum of power generation from thermal units subject to unit commitment ($\Theta_{y \in UC,t \in T,z \in Z}$) to the power balance expression.

**Startup and shutdown events (thermal plant cycling)**

*Capacitated limits on unit commitment decision variables*

Thermal resources subject to unit commitment ($y \in \mathcal{UC}$) adhere to the following constraints on commitment states, startup events, and shutdown events, which limit each decision to be no greater than the maximum number of discrete units installed (as per the following three constraints):

```math
\begin{aligned}
\nu_{y,z,t} \leq \frac{\Delta^{\text{total}}_{y,z}}{\Omega^{size}_{y,z}}
	\hspace{1.5cm} \forall y \in \mathcal{UC}, \forall z \in \mathcal{Z}, \forall t \in \mathcal{T}
\end{aligned}
```

```math
\begin{aligned}
\chi_{y,z,t} \leq \frac{\Delta^{\text{total}}_{y,z}}{\Omega^{size}_{y,z}}
	\hspace{1.5cm} \forall y \in \mathcal{UC}, \forall z \in \mathcal{Z}, \forall t \in \mathcal{T}
\end{aligned}
```

```math
\begin{aligned}
\zeta_{y,z,t} \leq \frac{\Delta^{\text{total}}_{y,z}}{\Omega^{size}_{y,z}}
	\hspace{1.5cm} \forall y \in \mathcal{UC}, \forall z \in \mathcal{Z}, \forall t \in \mathcal{T}
\end{aligned}
```
(See Constraints 1-3 in the code)

where decision $\nu_{y,z,t}$ designates the commitment state of generator cluster $y$ in zone $z$ at time $t$, decision $\chi_{y,z,t}$ represents number of startup decisions, decision $\zeta_{y,z,t}$ represents number of shutdown decisions, $\Delta^{\text{total}}_{y,z}$ is the total installed capacity, and parameter $\Omega^{size}_{y,z}$ is the unit size.

*Commitment state constraint linking start-up and shut-down decisions*

Additionally, the following constarint maintains the commitment state variable across time, $\nu_{y,z,t}$, as the sum of the commitment state in the prior, $\nu_{y,z,t-1}$, period plus the number of units started in the current period, $\chi_{y,z,t}$, less the number of units shut down in the current period, $\zeta_{y,z,t}$:

```math
\begin{aligned}
&\nu_{y,z,t} =\nu_{y,z,t-1} + \chi_{y,z,t} - \zeta_{y,z,t}
	\hspace{1.5cm} \forall y \in \mathcal{UC}, \forall z \in \mathcal{Z}, \forall t \in \mathcal{T}^{interior} \\
&\nu_{y,z,t} =\nu_{y,z,t +\tau^{period}-1} + \chi_{y,z,t} - \zeta_{y,z,t}
	\hspace{1.5cm} \forall y \in \mathcal{UC}, \forall z \in \mathcal{Z}, \forall t \in \mathcal{T}^{start}
\end{aligned}
```
(See Constraint 4 in the code)

Like other time-coupling constraints, this constraint wraps around to link the commitment state in the first time step of the year (or each representative period), $t \in \mathcal{T}^{start}$, to the last time step of the year (or each representative period), $t+\tau^{period}-1$.

**Ramping constraints**

Thermal resources subject to unit commitment ($y \in UC$) adhere to the following ramping constraints on hourly changes in power output:

```math
\begin{aligned}
	\Theta_{y,z,t-1} + f_{y, z, t-1}+r_{y, z, t-1} - \Theta_{y,z,t}-f_{y, z, t}&\leq  \kappa^{down}_{y,z} \cdot \Omega^{size}_{y,z} \cdot (\nu_{y,z,t} - \chi_{y,z,t}) & \\[6pt]
	\qquad & - \: \rho^{min}_{y,z} \cdot \Omega^{size}_{y,z} \cdot \chi_{y,z,t} & \hspace{0.5cm} \forall y \in \mathcal{UC}, \forall z \in \mathcal{Z}, \forall t \in \mathcal{T}  \\[6pt]
	\qquad & + \: \text{min}( \rho^{max}_{y,z,t}, \text{max}( \rho^{min}_{y,z}, \kappa^{down}_{y,z} ) ) \cdot \Omega^{size}_{y,z} \cdot \zeta_{y,z,t} &
\end{aligned}
```

```math
\begin{aligned}
	\Theta_{y,z,t}+f_{y, z, t}+r_{y, z, t} - \Theta_{y,z,t-1}- f_{y, z, t-1} &\leq  \kappa^{up}_{y,z} \cdot \Omega^{size}_{y,z} \cdot (\nu_{y,z,t} - \chi_{y,z,t}) & \\[6pt]
	\qquad & + \: \text{min}( \rho^{max}_{y,z,t}, \text{max}( \rho^{min}_{y,z}, \kappa^{up}_{y,z} ) ) \cdot \Omega^{size}_{y,z} \cdot \chi_{y,z,t} & \hspace{0.5cm} \forall y \in \mathcal{UC}, \forall z \in \mathcal{Z}, \forall t \in \mathcal{T} \\[6pt]
	\qquad & - \: \rho^{min}_{y,z} \cdot \Omega^{size}_{y,z} \cdot \zeta_{y,z,t} &
\end{aligned}
```
(See Constraints 5-6 in the code)

where decision $\Theta_{y,z,t}$, $f_{y, z, t}$, and $r_{y, z, t}$ are respectively, the energy injected into the grid, regulation, and reserve by technology $y$ in zone $z$ at time $t$, parameter $\kappa_{y,z,t}^{up|down}$ is the maximum ramp-up or ramp-down rate as a percentage of installed capacity, parameter $\rho_{y,z}^{min}$ is the minimum stable power output per unit of installed capacity, and parameter $\rho_{y,z,t}^{max}$ is the maximum available generation per unit of installed capacity. These constraints account for the ramping limits for committed (online) units as well as faster changes in power enabled by units starting or shutting down in the current time step.

**Minimum and maximum power output**

If not modeling regulation and spinning reserves, thermal resources subject to unit commitment adhere to the following constraints that ensure power output does not exceed minimum and maximum feasible levels:

```math
\begin{aligned}
	\Theta_{y,z,t} \geq \rho^{min}_{y,z} \times \Omega^{size}_{y,z} \times \nu_{y,z,t}
	\hspace{1.5cm} \forall y \in \mathcal{UC}, \forall z \in \mathcal{Z}, \forall t \in \mathcal{T}
\end{aligned}
```

```math
\begin{aligned}
	\Theta_{y,z,t} \leq \rho^{max}_{y,z} \times \Omega^{size}_{y,z} \times \nu_{y,z,t}
	\hspace{1.5cm} \forall y \in \mathcal{UC}, \forall z \in \mathcal{Z}, \forall t \in \mathcal{T}
\end{aligned}
```

(See Constraints 7-8 the code)

If modeling reserves and regulation, these constraints are replaced by those established in this ```thermal_commit_operational_reserves()```.

**Minimum and maximum up and down time**

Thermal resources subject to unit commitment adhere to the following constraints on the minimum time steps after start-up before a unit can shutdown again (minimum up time) and the minimum time steps after shut-down before a unit can start-up again (minimum down time):

```math
\begin{aligned}
	\nu_{y,z,t} \geq \displaystyle \sum_{\hat{t} = t-(\tau^{up}_{y,z}-1)}^t \chi_{y,z,\hat{t}}
	\hspace{1.5cm} \forall y \in \mathcal{UC}, \forall z \in \mathcal{Z}, \forall t \in \mathcal{T}
\end{aligned}
```

```math
\begin{aligned}
	\frac{\overline{\Delta_{y,z}} + \Omega_{y,z} - \Delta_{y,z}}{\Omega^{size}_{y,z}} -  \nu_{y,z,t} \geq \displaystyle \sum_{\hat{t} = t-(\tau^{down}_{y,z}-1)}^t \zeta_{y,z,\hat{t}}
	\hspace{1.5cm} \forall y \in \mathcal{UC}, \forall z \in \mathcal{Z}, \forall t \in \mathcal{T}
\end{aligned}
```
(See Constraints 9-10 in the code)

where $\tau_{y,z}^{up|down}$ is the minimum up or down time for units in generating cluster $y$ in zone $z$.

Like with the ramping constraints, the minimum up and down constraint time also wrap around from the start of each time period to the end of each period.
It is recommended that users of GenX must use longer subperiods than the longest min up/down time if modeling UC. Otherwise, the model will report error.
"""
function thermal_commit!(EP::Model, inputs::Dict, setup::Dict)
    println("Thermal (Unit Commitment) Resources Module")

    gen = inputs["RESOURCES"]

    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones
    G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)

    p = inputs["hours_per_subperiod"] #total number of hours per subperiod

    THERM_COMMIT = inputs["THERM_COMMIT"]

    ### Expressions ###

    # These variables are used in the ramp-up and ramp-down expressions
    reserves_term = @expression(EP, [y in THERM_COMMIT, t in 1:T], 0)
    regulation_term = @expression(EP, [y in THERM_COMMIT, t in 1:T], 0)

    if setup["OperationalReserves"] > 0
        THERM_COMMIT_REG = intersect(THERM_COMMIT, inputs["REG"]) # Set of thermal resources with regulation reserves
        THERM_COMMIT_RSV = intersect(THERM_COMMIT, inputs["RSV"]) # Set of thermal resources with spinning reserves
        regulation_term = @expression(EP, [y in THERM_COMMIT, t in 1:T],
            y ∈ THERM_COMMIT_REG ? EP[:vREG][y, t] - EP[:vREG][y, hoursbefore(p, t, 1)] : 0)
        reserves_term = @expression(EP, [y in THERM_COMMIT, t in 1:T],
            y ∈ THERM_COMMIT_RSV ? EP[:vRSV][y, t] : 0)
    end

    ## Power Balance Expressions ##
    @expression(EP, ePowerBalanceThermCommit[t = 1:T, z = 1:Z],
        sum(EP[:vP][y, t]
        for y in intersect(THERM_COMMIT, resources_in_zone_by_rid(gen, z))))
    add_similar_to_expression!(EP[:ePowerBalance], ePowerBalanceThermCommit)

    ### Constraints ###

    ### Capacitated limits on unit commitment decision variables (Constraints #1-3)
    @constraints(EP,
        begin
            [y in THERM_COMMIT, t = 1:T],
            EP[:vCOMMIT][y, t] <= EP[:eTotalCap][y] / cap_size(gen[y])
            [y in THERM_COMMIT, t = 1:T],
            EP[:vSTART][y, t] <= EP[:eTotalCap][y] / cap_size(gen[y])
            [y in THERM_COMMIT, t = 1:T],
            EP[:vSHUT][y, t] <= EP[:eTotalCap][y] / cap_size(gen[y])
        end)

    # Commitment state constraint linking startup and shutdown decisions (Constraint #4)
    @constraints(EP,
        begin
            [y in THERM_COMMIT, t in 1:T],
            EP[:vCOMMIT][y, t] ==
            EP[:vCOMMIT][y, hoursbefore(p, t, 1)] + EP[:vSTART][y, t] - EP[:vSHUT][y, t]
        end)

    ### Maximum ramp up and down between consecutive hours (Constraints #5-6)

    ## For Start Hours
    # Links last time step with first time step, ensuring position in hour 1 is within eligible ramp of final hour position
    # rampup constraints
    @constraint(EP, [y in THERM_COMMIT, t in 1:T],
        EP[:vP][y, t] - EP[:vP][y, hoursbefore(p, t, 1)] + regulation_term[y, t] +
        reserves_term[y, t]<=ramp_up_fraction(gen[y]) * cap_size(gen[y]) *
                             (EP[:vCOMMIT][y, t] - EP[:vSTART][y, t])
                             +
                             min(inputs["pP_Max"][y, t],
                                 max(min_power(gen[y]), ramp_up_fraction(gen[y]))) *
                             cap_size(gen[y]) * EP[:vSTART][y, t]
                             -
                             min_power(gen[y]) * cap_size(gen[y]) * EP[:vSHUT][y, t])

    # rampdown constraints
    @constraint(EP, [y in THERM_COMMIT, t in 1:T],
        EP[:vP][y, hoursbefore(p, t, 1)] - EP[:vP][y, t] - regulation_term[y, t] +
        reserves_term[y,
            hoursbefore(p, t, 1)]<=ramp_down_fraction(gen[y]) * cap_size(gen[y]) *
                                   (EP[:vCOMMIT][y, t] - EP[:vSTART][y, t])
                                   -
                                   min_power(gen[y]) * cap_size(gen[y]) * EP[:vSTART][y, t]
                                   +
                                   min(inputs["pP_Max"][y, t],
                                       max(min_power(gen[y]), ramp_down_fraction(gen[y]))) *
                                   cap_size(gen[y]) * EP[:vSHUT][y, t])

    ### Minimum and maximum power output constraints (Constraints #7-8)
    if setup["OperationalReserves"] == 1
        # If modeling with regulation and reserves, constraints are established by thermal_commit_operational_reserves() function below
        thermal_commit_operational_reserves!(EP, inputs)
    else
        @constraints(EP,
            begin
                # Minimum stable power generated per technology "y" at hour "t" > Min power
                [y in THERM_COMMIT, t = 1:T],
                EP[:vP][y, t] >= min_power(gen[y]) * cap_size(gen[y]) * EP[:vCOMMIT][y, t]

                # Maximum power generated per technology "y" at hour "t" < Max power
                [y in THERM_COMMIT, t = 1:T],
                EP[:vP][y, t] <=
                inputs["pP_Max"][y, t] * cap_size(gen[y]) * EP[:vCOMMIT][y, t]
            end)
    end

    ### Minimum up and down times (Constraints #9-10)
    Up_Time = zeros(Int, G)
    Up_Time[THERM_COMMIT] .= Int.(floor.(up_time.(gen[THERM_COMMIT])))
    @constraint(EP, [y in THERM_COMMIT, t in 1:T],
        EP[:vCOMMIT][y,
            t]>=sum(EP[:vSTART][y, u] for u in hoursbefore(p, t, 0:(Up_Time[y] - 1))))

    Down_Time = zeros(Int, G)
    Down_Time[THERM_COMMIT] .= Int.(floor.(down_time.(gen[THERM_COMMIT])))
    @constraint(EP, [y in THERM_COMMIT, t in 1:T],
        EP[:eTotalCap][y] / cap_size(gen[y]) -
        EP[:vCOMMIT][y,
            t]>=sum(EP[:vSHUT][y, u] for u in hoursbefore(p, t, 0:(Down_Time[y] - 1))))
    ## END Constraints for thermal units subject to integer (discrete) unit commitment decisions

    # Additional constraints on fusion; create total recirculating power expressions
    FUSION = ids_with(gen, fusion)
    if !isempty(FUSION)
        fusion_formulation_thermal_commit!(EP, inputs, setup)
    end

    MAINT = ids_with_maintenance(gen)
    if !isempty(MAINT)
        maintenance_formulation_thermal_commit!(EP, inputs, setup)
    end

    if !isempty(intersect(FUSION, MAINT))
        # modify parasitic power expressions
        fusion_maintenance_adjust_parasitic_power!(EP, gen)
    end

    if !isempty(FUSION)
        # subtract parasitic power from power balance
        fusion_adjust_power_balance!(EP, inputs, gen)
    end
end

@doc raw"""
	thermal_commit_operational_reserves!(EP::Model, inputs::Dict)

This function is called by the ```thermal_commit()``` function when regulation and reserves constraints are active and defines reserve related constraints for thermal power plants subject to unit commitment constraints on power plant start-ups and shut-down decisions.

**Maximum contributions to frequency regulation and reserves**

When modeling frequency regulation and reserves contributions, thermal units subject to unit commitment adhere to the following constraints which limit the maximum contribution to regulation and reserves in each time step to a specified maximum fraction ($,\upsilon^{rsv}_{y,z}$) of the commitment capacity in that time step ($(\Omega^{size}_{y,z} \cdot \nu_{y,z,t})$):

```math
\begin{aligned}
	f_{y,z,t} \leq \upsilon^{reg}_{y,z} \times \rho^{max}_{y,z,t} (\Omega^{size}_{y,z} \times \nu_{y,z,t}) \hspace{1.5cm} \forall y \in \mathcal{UC}, \forall z \in \mathcal{Z}, \forall t \in \mathcal{T}
\end{aligned}
```

```math
\begin{aligned}
	r_{y,z,t} \leq \upsilon^{rsv}_{y,z} \times \rho^{max}_{y,z,t} (\Omega^{size}_{y,z} \times \nu_{y,z,t}) \hspace{1.5cm} \forall y \in \mathcal{UC}, \forall z \in \mathcal{Z}, \forall t \in \mathcal{T}
\end{aligned}
```

where $f_{y,z,t}$ is the frequency regulation contribution limited by the maximum regulation contribution $\upsilon^{reg}_{y,z}$, and $r_{y,z,t}$ is the reserves contribution limited by the maximum reserves contribution $\upsilon^{rsv}_{y,z}$. Limits on reserve contributions reflect the maximum ramp rate for the thermal resource in whatever time interval defines the requisite response time for the regulation or reserve products (e.g., 5 mins or 15 mins or 30 mins). These response times differ by system operator and reserve product, and so the user should define these parameters in a self-consistent way for whatever system context they are modeling.

**Minimum and maximum power output**

When modeling frequency regulation and spinning reserves contributions, thermal resources subject to unit commitment adhere to the following constraints that ensure the sum of power output and reserve and/or regulation contributions do not exceed minimum and maximum feasible power output:

```math
\begin{aligned}
	\Theta_{y,z,t} - f_{y,z,t} \geq \rho^{min}_{y,z} \times \Omega^{size}_{y,z} \times \nu_{y,z,t}
	\hspace{1.5cm} \forall y \in \mathcal{UC}, \forall z \in \mathcal{Z}, \forall t \in \mathcal{T}
\end{aligned}
```

```math
\begin{aligned}
	\Theta_{y,z,t} + f_{y,z,t} + r_{y,z,t} \leq \rho^{max}_{y,z,t} \times \Omega^{size}_{y,z} \times \nu_{y,z,t}
	\hspace{1.5cm} \forall y \in \mathcal{UC}, \forall z \in \mathcal{Z}, \forall t \in \mathcal{T}
\end{aligned}
```

"""
function thermal_commit_operational_reserves!(EP::Model, inputs::Dict)
    println("Thermal Commit Operational Reserves Module")

    gen = inputs["RESOURCES"]

    T = inputs["T"]     # Number of time steps (hours)

    THERM_COMMIT = inputs["THERM_COMMIT"]

    REG = intersect(THERM_COMMIT, inputs["REG"]) # Set of thermal resources with regulation reserves
    RSV = intersect(THERM_COMMIT, inputs["RSV"]) # Set of thermal resources with spinning reserves

    vP = EP[:vP]
    vREG = EP[:vREG]
    vRSV = EP[:vRSV]

    commit(y, t) = cap_size(gen[y]) * EP[:vCOMMIT][y, t]
    max_power(y, t) = inputs["pP_Max"][y, t]

    # Maximum regulation and reserve contributions
    @constraint(EP,
        [y in REG, t in 1:T],
        vREG[y, t]<=max_power(y, t) * reg_max(gen[y]) * commit(y, t))
    @constraint(EP,
        [y in RSV, t in 1:T],
        vRSV[y, t]<=max_power(y, t) * rsv_max(gen[y]) * commit(y, t))

    # Minimum stable power generated per technology "y" at hour "t" and contribution to regulation must be > min power
    expr = extract_time_series_to_expression(vP, THERM_COMMIT)
    add_similar_to_expression!(expr[REG, :], -vREG[REG, :])
    @constraint(EP,
        [y in THERM_COMMIT, t in 1:T],
        expr[y, t]>=min_power(gen[y]) * commit(y, t))

    # Maximum power generated per technology "y" at hour "t"  and contribution to regulation and reserves up must be < max power
    expr = extract_time_series_to_expression(vP, THERM_COMMIT)
    add_similar_to_expression!(expr[REG, :], vREG[REG, :])
    add_similar_to_expression!(expr[RSV, :], vRSV[RSV, :])
    @constraint(EP,
        [y in THERM_COMMIT, t in 1:T],
        expr[y, t]<=max_power(y, t) * commit(y, t))
end

@doc raw"""
    maintenance_formulation_thermal_commit!(EP::Model, inputs::Dict, setup::Dict)

Creates maintenance variables and constraints for thermal-commit plants.
"""
function maintenance_formulation_thermal_commit!(EP::Model, inputs::Dict, setup::Dict)
    @info "Maintenance Module for Thermal plants"

    ensure_maintenance_variable_records!(inputs)
    gen = inputs["RESOURCES"]

    by_rid(rid, sym) = by_rid_res(rid, sym, gen)

    MAINT = ids_with_maintenance(gen)
    resource_component(y) = by_rid(y, :resource_name)
    cap(y) = by_rid(y, :cap_size)
    maint_dur(y) = Int(floor(by_rid(y, :maintenance_duration)))
    maint_freq(y) = Int(floor(by_rid(y, :maintenance_cycle_length_years)))
    maint_begin_cadence(y) = Int(floor(by_rid(y, :maintenance_begin_cadence)))

    integer_operational_unit_commitment = setup["UCommit"] == 1

    vcommit = :vCOMMIT
    ecap = :eTotalCap

    sanity_check_maintenance(MAINT, inputs)

    for y in MAINT
        maintenance_formulation!(EP,
            inputs,
            resource_component(y),
            y,
            maint_begin_cadence(y),
            maint_dur(y),
            maint_freq(y),
            cap(y),
            vcommit,
            ecap,
            integer_operational_unit_commitment)
    end
end

@doc raw"""
    thermal_maintenance_capacity_reserve_margin_adjustment!(EP::Model, inputs::Dict)

Eliminates the contribution of a plant to the capacity reserve margin while it is down for maintenance.
"""
function thermal_maintenance_capacity_reserve_margin_adjustment!(EP::Model,
        inputs::Dict)
    gen = inputs["RESOURCES"]

    T = inputs["T"]     # Number of time steps (hours)
    ncapres = inputs["NCapacityReserveMargin"]
    THERM_COMMIT = inputs["THERM_COMMIT"]
    MAINT = ids_with_maintenance(gen)
    applicable_resources = intersect(MAINT, THERM_COMMIT)

    maint_adj = @expression(EP, [capres in 1:ncapres, t in 1:T],
        sum(thermal_maintenance_capacity_reserve_margin_adjustment(EP,
                inputs,
                y,
                capres,
                t) for y in applicable_resources))
    add_similar_to_expression!(EP[:eCapResMarBalance], maint_adj)
end

function thermal_maintenance_capacity_reserve_margin_adjustment(EP::Model,
        inputs::Dict,
        y::Int,
        capres::Int,
        t)
    gen = inputs["RESOURCES"]
    resource_component = resource_name(gen[y])
    capresfactor = derating_factor(gen[y], tag = capres)
    cap = cap_size(gen[y])
    down_var = EP[Symbol(maintenance_down_name(resource_component))]
    return -capresfactor * down_var[t] * cap
end

@doc raw"""
    fusion_formulation_thermal_commit!(EP::Model, inputs::Dict)

Apply fusion-core-specific constraints to the model.

"""
function fusion_formulation_thermal_commit!(EP::Model, inputs::Dict, setup::Dict)
    @info "Fusion Module for Thermal-commit plants"

    integer_operational_unit_commitment = setup["UCommit"] == 1

    ensure_fusion_pulse_variable_records!(inputs)
    ensure_fusion_expression_records!(inputs)
    gen = inputs["RESOURCES"]

    FUSION = ids_with(gen, fusion)

    resource_component(y) = resource_name(gen[y])

    # power_like will be vP + vREG + vRSV for fusion plants with reserves, else just vP.
    # This makes writing all the fusion-specific constraints much simpler since they need not 
    # deal with vREG/vRSV/OperationalReserves.
    power_like = EP[:vP]
    if setup["OperationalReserves"] == 1
        REG = intersect(FUSION, inputs["REG"]) # Set of thermal resources with regulation reserves
        RSV = intersect(FUSION, inputs["RSV"]) # Set of thermal resources with spinning reserves

        vREG = EP[:vREG]
        vRSV = EP[:vRSV]
        power_like = extract_time_series_to_expression(power_like, FUSION)
        add_similar_to_expression!(power_like[REG, :], vREG[REG, :])
        add_similar_to_expression!(power_like[RSV, :], vRSV[RSV, :])
    end

    for y in FUSION
        name = resource_component(y)
        reactor = FusionReactorData(gen, y)
        fusion_pulse_variables!(
            EP, inputs, integer_operational_unit_commitment, name, y, reactor, :eTotalCap)
        fusion_pulse_status_linking_constraints!(EP, inputs, name, y, reactor, :vCOMMIT)
        fusion_pulse_thermal_power_generation_constraint!(
            EP, inputs, name, y, reactor, power_like)
        fusion_parasitic_power!(EP, inputs, name, y, reactor, :eTotalCap)
        fusion_max_fpy_per_year_constraint!(EP, inputs, y, reactor, :eTotalCap, EP[:vP])

        add_fusion_component_to_zone_listing(inputs, y, name)
    end
end

# Cancel out the dependence on down_var, since CRM is related to power, not capacity
function thermal_maintenance_and_fusion_capacity_reserve_margin_adjustment(
        EP, inputs, y, capres, t)
    return -thermal_maintenance_capacity_reserve_margin_adjustment(EP, inputs, y, capres, t)
end
