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

	dfGen = inputs["dfGen"]

	T = inputs["T"]     # Number of time steps (hours)
	Z = inputs["Z"]     # Number of zones

	p = inputs["hours_per_subperiod"] #total number of hours per subperiod

	THERM_NO_COMMIT = inputs["THERM_NO_COMMIT"]

	### Expressions ###

	## Power Balance Expressions ##
	@expression(EP, ePowerBalanceThermNoCommit[t=1:T, z=1:Z],
		sum(EP[:vP][y,t] for y in intersect(THERM_NO_COMMIT, dfGen[dfGen[!,:Zone].==z,:R_ID]))
	)
	add_similar_to_expression!(EP[:ePowerBalance], ePowerBalanceThermNoCommit)

	### Constraints ###

	### Maximum ramp up and down between consecutive hours (Constraints #1-2)
	@constraints(EP, begin

		## Maximum ramp up between consecutive hours
        [y in THERM_NO_COMMIT, t in 1:T], EP[:vP][y,t] - EP[:vP][y, hoursbefore(p,t,1)] <= dfGen[y,:Ramp_Up_Percentage]*EP[:eTotalCap][y]

		## Maximum ramp down between consecutive hours
		[y in THERM_NO_COMMIT, t in 1:T], EP[:vP][y, hoursbefore(p,t,1)] - EP[:vP][y,t] <= dfGen[y,:Ramp_Dn_Percentage]*EP[:eTotalCap][y]
	end)

	### Minimum and maximum power output constraints (Constraints #3-4)
	if setup["Reserves"] == 1
		# If modeling with regulation and reserves, constraints are established by thermal_no_commit_reserves() function below
		thermal_no_commit_reserves!(EP, inputs)
	else
		@constraints(EP, begin
			# Minimum stable power generated per technology "y" at hour "t" Min_Power
			[y in THERM_NO_COMMIT, t=1:T], EP[:vP][y,t] >= dfGen[y,:Min_Power]*EP[:eTotalCap][y]

			# Maximum power generated per technology "y" at hour "t"
			[y in THERM_NO_COMMIT, t=1:T], EP[:vP][y,t] <= inputs["pP_Max"][y,t]*EP[:eTotalCap][y]
		end)

	end
	# END Constraints for thermal resources not subject to unit commitment
end

@doc raw"""
	thermal_no_commit_reserves!(EP::Model, inputs::Dict)

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
function thermal_no_commit_reserves!(EP::Model, inputs::Dict)

	println("Thermal No Commit Reserves Module")

	dfGen = inputs["dfGen"]

	T = inputs["T"]     # Number of time steps (hours)

	THERM_NO_COMMIT = setdiff(inputs["THERM_ALL"], inputs["COMMIT"])

	# Constraints on contribution to regulation and reserves
	# Thermal units without commitment constraints assumed to be quick-start units, so can contribute a specified fraction of their
	# total installed capacity to reserves

	THERM_NO_COMMIT_REG_RSV = intersect(THERM_NO_COMMIT, inputs["REG"], inputs["RSV"]) # Set of thermal resources with both regulation and spinning reserves

	THERM_NO_COMMIT_REG = intersect(THERM_NO_COMMIT, inputs["REG"]) # Set of thermal resources with regulation reserves
	THERM_NO_COMMIT_RSV = intersect(THERM_NO_COMMIT, inputs["RSV"]) # Set of thermal resources with spinning reserves

	THERM_NO_COMMIT_NO_RES = setdiff(THERM_NO_COMMIT, THERM_NO_COMMIT_REG, THERM_NO_COMMIT_RSV) # Set of thermal resources with no reserves

	THERM_NO_COMMIT_REG_ONLY = setdiff(THERM_NO_COMMIT_REG, THERM_NO_COMMIT_RSV) # Set of thermal resources only with regulation reserves
	THERM_NO_COMMIT_RSV_ONLY = setdiff(THERM_NO_COMMIT_RSV, THERM_NO_COMMIT_REG) # Set of thermal resources only with spinning reserves

	if !isempty(THERM_NO_COMMIT_REG_RSV)
		@constraints(EP, begin

			[y in THERM_NO_COMMIT_REG_RSV, t=1:T], EP[:vREG][y,t] <= inputs["pP_Max"][y,t]*dfGen[y,:Reg_Max]*EP[:eTotalCap][y]
			[y in THERM_NO_COMMIT_REG_RSV, t=1:T], EP[:vRSV][y,t] <= inputs["pP_Max"][y,t]*dfGen[y,:Rsv_Max]*EP[:eTotalCap][y]

			# Minimum stable power generated per technology "y" at hour "t" and contribution to regulation down must be > min power
			[y in THERM_NO_COMMIT_REG_RSV, t=1:T], EP[:vP][y,t]-EP[:vREG][y,t] >= dfGen[y,:Min_Power]*EP[:eTotalCap][y]

			# Maximum power generated per technology "y" at hour "t" and contribution to regulation and reserves must be < max power
			[y in THERM_NO_COMMIT_REG_RSV, t=1:T], EP[:vP][y,t]+EP[:vREG][y,t]+EP[:vRSV][y,t] <= inputs["pP_Max"][y,t]*EP[:eTotalCap][y]
		end)
	end

	if !isempty(THERM_NO_COMMIT_REG)
		@constraints(EP, begin

			[y in THERM_NO_COMMIT_REG, t=1:T], EP[:vREG][y,t] <= inputs["pP_Max"][y,t]*dfGen[y,:Reg_Max]*EP[:eTotalCap][y]

			# Minimum stable power generated per technology "y" at hour "t" and contribution to regulation down must be > min power
			[y in THERM_NO_COMMIT_REG, t=1:T], EP[:vP][y,t]-EP[:vREG][y,t] >= dfGen[y,:Min_Power]*EP[:eTotalCap][y]

			# Maximum power generated per technology "y" at hour "t" and contribution to regulation and reserves must be < max power
			[y in THERM_NO_COMMIT_REG, t=1:T], EP[:vP][y,t]+EP[:vREG][y,t] <= inputs["pP_Max"][y,t]*EP[:eTotalCap][y]
		end)
	end

	if !isempty(THERM_NO_COMMIT_RSV)
		@constraints(EP, begin

			[y in THERM_NO_COMMIT_RSV, t=1:T], EP[:vRSV][y,t] <= inputs["pP_Max"][y,t]*dfGen[y,:Rsv_Max]*EP[:eTotalCap][y]

			# Minimum stable power generated per technology "y" at hour "t" and contribution to regulation down must be > min power
			[y in THERM_NO_COMMIT_RSV, t=1:T], EP[:vP][y,t] >= dfGen[y,:Min_Power]*EP[:eTotalCap][y]

			# Maximum power generated per technology "y" at hour "t" and contribution to regulation and reserves must be < max power
			[y in THERM_NO_COMMIT_RSV, t=1:T], EP[:vP][y,t]+EP[:vRSV][y,t] <= inputs["pP_Max"][y,t]*EP[:eTotalCap][y]
		end)
	end

	if !isempty(THERM_NO_COMMIT_NO_RES)
		@constraints(EP, begin
			# Minimum stable power generated per technology "y" at hour "t" Min_Power
			[y in THERM_NO_COMMIT_NO_RES, t=1:T], EP[:vP][y,t] >= dfGen[y,:Min_Power]*EP[:eTotalCap][y]

			# Maximum power generated per technology "y" at hour "t"
			[y in THERM_NO_COMMIT_NO_RES, t=1:T], EP[:vP][y,t] <= inputs["pP_Max"][y,t]*EP[:eTotalCap][y]
		end)
	end

end
