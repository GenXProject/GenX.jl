"""
GenX: An Configurable Capacity Expansion Model
Copyright (C) 2021,  Massachusetts Institute of Technology
This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
A complete copy of the GNU General Public License v2 (GPLv2) is available
in LICENSE.txt.  Users uncompressing this from an archive may not have
received this license file.  If not, see <http://www.gnu.org/licenses/>.
"""

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
	\Theta_{y,z,t-1} - \Theta_{y,z,t} &\leq  \kappa^{down}_{y,z} \cdot \Omega^{size}_{y,z} \cdot (\nu_{y,z,t} - \chi_{y,z,t}) & \\[6pt]
	\qquad & - \: \rho^{min}_{y,z} \cdot \Omega^{size}_{y,z} \cdot \chi_{y,z,t} & \hspace{0.5cm} \forall y \in \mathcal{UC}, \forall z \in \mathcal{Z}, \forall t \in \mathcal{T}  \\[6pt]
	\qquad & + \: \text{min}( \rho^{max}_{y,z,t}, \text{max}( \rho^{min}_{y,z}, \kappa^{down}_{y,z} ) ) \cdot \Omega^{size}_{y,z} \cdot \zeta_{y,z,t} &
\end{aligned}
```
```math
\begin{aligned}
	\Theta_{y,z,t} - \Theta_{y,z,t-1} &\leq  \kappa^{up}_{y,z} \cdot \Omega^{size}_{y,z} \cdot (\nu_{y,z,t} - \chi_{y,z,t}) & \\[6pt]
	\qquad & + \: \text{min}( \rho^{max}_{y,z,t}, \text{max}( \rho^{min}_{y,z}, \kappa^{up}_{y,z} ) ) \cdot \Omega^{size}_{y,z} \cdot \chi_{y,z,t} & \hspace{0.5cm} \forall y \in \mathcal{UC}, \forall z \in \mathcal{Z}, \forall t \in \mathcal{T} \\[6pt]
	\qquad & - \: \rho^{min}_{y,z} \cdot \Omega^{size}_{y,z} \cdot \zeta_{y,z,t} &
\end{aligned}
```
(See Constraints 5-6 in the code)
where decision $\Theta_{y,z,t}$ is the energy injected into the grid by technology $y$ in zone $z$ at time $t$, parameter $\kappa_{y,z,t}^{up|down}$ is the maximum ramp-up or ramp-down rate as a percentage of installed capacity, parameter $\rho_{y,z}^{min}$ is the minimum stable power output per unit of installed capacity, and parameter $\rho_{y,z,t}^{max}$ is the maximum available generation per unit of installed capacity. These constraints account for the ramping limits for committed (online) units as well as faster changes in power enabled by units starting or shutting down in the current time step.
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
If modeling reserves and regulation, these constraints are replaced by those established in this ```thermal_commit_reserves()```.
**Minimum and maximum up and down time**
Thermal resources subject to unit commitment adhere to the following constraints on the minimum time steps after start-up before a unit can shutdown again (minimum up time) and the minimum time steps after shut-down before a unit can start-up again (minimum down time):
```math
\begin{aligned}
	\nu_{y,z,t} \geq \displaystyle \sum_{\hat{t} = t-\tau^{up}_{y,z}}^t \chi_{y,z,\hat{t}}
	\hspace{1.5cm} \forall y \in \mathcal{UC}, \forall z \in \mathcal{Z}, \forall t \in \mathcal{T}
\end{aligned}
```
```math
\begin{aligned}
	\frac{\overline{\Delta_{y,z}} + \Omega_{y,z} - \Delta_{y,z}}{\Omega^{size}_{y,z}} -  \nu_{y,z,t} \geq \displaystyle \sum_{\hat{t} = t-\tau^{down}_{y,z}}^t \zeta_{y,z,\hat{t}}
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

	dfGen = inputs["dfGen"]

	T = inputs["T"]     # Number of time steps (hours)
	Z = inputs["Z"]     # Number of zones
	G = inputs["G"]     # Number of resources

	hours_per_subperiod = inputs["hours_per_subperiod"] #total number of hours per subperiod

	THERM_COMMIT = inputs["THERM_COMMIT"]
	START_SUBPERIODS = inputs["START_SUBPERIODS"]
	INTERIOR_SUBPERIODS = inputs["INTERIOR_SUBPERIODS"]

	### Expressions ###

	## Power Balance Expressions ##
	@expression(EP, ePowerBalanceThermCommit[t=1:T, z=1:Z],
		sum(EP[:vP][y,t] for y in intersect(THERM_COMMIT, dfGen[dfGen[!,:Zone].==z,:R_ID])))

	add_to_expression!.(EP[:ePowerBalance], EP[:ePowerBalanceThermCommit])

	### Constraints ###

	### Capacitated limits on unit commitment decision variables (Constraints #1-3)
	@constraints(EP, begin
		[y in THERM_COMMIT, t=1:T], EP[:vCOMMIT][y,t] <= EP[:eTotalCap][y]/dfGen[y,:Cap_Size]
		[y in THERM_COMMIT, t=1:T], EP[:vSTART][y,t] <= EP[:eTotalCap][y]/dfGen[y,:Cap_Size]
		[y in THERM_COMMIT, t=1:T], EP[:vSHUT][y,t] <= EP[:eTotalCap][y]/dfGen[y,:Cap_Size]
	end)

	# Commitment state constraint linking startup and shutdown decisions (Constraint #4)
	@constraints(EP, begin
		# For Start Hours, links first time step with last time step in subperiod
		[y in THERM_COMMIT, t in START_SUBPERIODS], EP[:vCOMMIT][y,t] == EP[:vCOMMIT][y,(t+hours_per_subperiod-1)] + EP[:vSTART][y,t] - EP[:vSHUT][y,t]
		# For all other hours, links commitment state in hour t with commitment state in prior hour + sum of start up and shut down in current hour
		[y in THERM_COMMIT, t in INTERIOR_SUBPERIODS], EP[:vCOMMIT][y,t] == EP[:vCOMMIT][y,t-1] + EP[:vSTART][y,t] - EP[:vSHUT][y,t]
	end)

	### Maximum ramp up and down between consecutive hours (Constraints #5-6)

	## For Start Hours
	# Links last time step with first time step, ensuring position in hour 1 is within eligible ramp of final hour position
		# rampup constraints
	@constraint(EP,[y in THERM_COMMIT, t in START_SUBPERIODS],
		EP[:vP][y,t]-EP[:vP][y,(t+hours_per_subperiod-1)] <= dfGen[y,:Ramp_Up_Percentage]*dfGen[y,:Cap_Size]*(EP[:vCOMMIT][y,t]-EP[:vSTART][y,t])
			+ min(inputs["pP_Max"][y,t],max(dfGen[y,:Min_Power],dfGen[y,:Ramp_Up_Percentage]))*dfGen[y,:Cap_Size]*EP[:vSTART][y,t]
			- dfGen[y,:Min_Power]*dfGen[y,:Cap_Size]*EP[:vSHUT][y,t])

		# rampdown constraints
	@constraint(EP,[y in THERM_COMMIT, t in START_SUBPERIODS],
		EP[:vP][y,(t+hours_per_subperiod-1)]-EP[:vP][y,t] <= dfGen[y,:Ramp_Dn_Percentage]*dfGen[y,:Cap_Size]*(EP[:vCOMMIT][y,t]-EP[:vSTART][y,t])
			- dfGen[y,:Min_Power]*dfGen[y,:Cap_Size]*EP[:vSTART][y,t]
			+ min(inputs["pP_Max"][y,t],max(dfGen[y,:Min_Power],dfGen[y,:Ramp_Dn_Percentage]))*dfGen[y,:Cap_Size]*EP[:vSHUT][y,t])

	## For Interior Hours
		# rampup constraints
	@constraint(EP,[y in THERM_COMMIT, t in INTERIOR_SUBPERIODS],
		EP[:vP][y,t]-EP[:vP][y,t-1] <= dfGen[y,:Ramp_Up_Percentage]*dfGen[y,:Cap_Size]*(EP[:vCOMMIT][y,t]-EP[:vSTART][y,t])
			+ min(inputs["pP_Max"][y,t],max(dfGen[y,:Min_Power],dfGen[y,:Ramp_Up_Percentage]))*dfGen[y,:Cap_Size]*EP[:vSTART][y,t]
			-dfGen[y,:Min_Power]*dfGen[y,:Cap_Size]*EP[:vSHUT][y,t])

		# rampdown constraints
	@constraint(EP,[y in THERM_COMMIT, t in INTERIOR_SUBPERIODS],
		EP[:vP][y,t-1]-EP[:vP][y,t] <= dfGen[y,:Ramp_Dn_Percentage]*dfGen[y,:Cap_Size]*(EP[:vCOMMIT][y,t]-EP[:vSTART][y,t])
			-dfGen[y,:Min_Power]*dfGen[y,:Cap_Size]*EP[:vSTART][y,t]
			+min(inputs["pP_Max"][y,t],max(dfGen[y,:Min_Power],dfGen[y,:Ramp_Dn_Percentage]))*dfGen[y,:Cap_Size]*EP[:vSHUT][y,t])

	### Minimum and maximum power output constraints (Constraints #7-8)
	if setup["Reserves"] == 1
		# If modeling with regulation and reserves, constraints are established by thermal_commit_reserves() function below
		thermal_commit_reserves!(EP, inputs)
	else
		@constraints(EP, begin
			# Minimum stable power generated per technology "y" at hour "t" > Min power
			[y in THERM_COMMIT, t=1:T], EP[:vP][y,t] >= dfGen[y,:Min_Power]*dfGen[y,:Cap_Size]*EP[:vCOMMIT][y,t]

			# Maximum power generated per technology "y" at hour "t" < Max power
			[y in THERM_COMMIT, t=1:T], EP[:vP][y,t] <= inputs["pP_Max"][y,t]*dfGen[y,:Cap_Size]*EP[:vCOMMIT][y,t]
		end)
	end

	### Minimum up and down times (Constraints #9-10)
	p = hours_per_subperiod
	Up_Time = zeros(Int, nrow(dfGen))
	Up_Time[THERM_COMMIT] .= Int.(floor.(dfGen[THERM_COMMIT,:Up_Time]))
	@constraint(EP, [y in THERM_COMMIT, t in 1:T],
		EP[:vCOMMIT][y,t] >= sum(EP[:vSTART][y, hoursbefore(p, t, 0:(Up_Time[y] - 1))])
	)

	Down_Time = zeros(Int, nrow(dfGen))
	Down_Time[THERM_COMMIT] .= Int.(floor.(dfGen[THERM_COMMIT,:Down_Time]))
	@constraint(EP, [y in THERM_COMMIT, t in 1:T],
		EP[:eTotalCap][y]/dfGen[y,:Cap_Size]-EP[:vCOMMIT][y,t] >= sum(EP[:vSHUT][y, hoursbefore(p, t, 0:(Down_Time[y] - 1))])
	)

	## END Constraints for thermal units subject to integer (discrete) unit commitment decisions

end

@doc raw"""
	thermal_commit_reserves!(EP::Model, inputs::Dict)

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
	\Theta_{y,z,t} - f_{y,z,t} \geq \rho^{min}_{y,z} \times Omega^{size}_{y,z} \times \nu_{y,z,t}
	\hspace{1.5cm} \forall y \in \mathcal{UC}, \forall z \in \mathcal{Z}, \forall t \in \mathcal{T}
\end{aligned}
```
```math
\begin{aligned}
	\Theta_{y,z,t} + f_{y,z,t} + r_{y,z,t} \leq \rho^{max}_{y,z,t} \times \Omega^{size}_{y,z} \times \nu_{y,z,t}
	\hspace{1.5cm} \forall y \in \mathcal{UC}, \forall z \in \mathcal{Z}, \forall t \in \mathcal{T}
\end{aligned}
```
Note there are multiple versions of these constraints in the code in order to avoid creation of unecessary constraints and decision variables for thermal units unable to provide regulation and/or reserves contributions due to input parameters (e.g. ```Reg_Max=0``` and/or ```RSV_Max=0```).
"""
function thermal_commit_reserves!(EP::Model, inputs::Dict)

	println("Thermal Commit Reserves Module")

	dfGen = inputs["dfGen"]

	T = inputs["T"]     # Number of time steps (hours)

	THERM_COMMIT = inputs["THERM_COMMIT"]

	THERM_COMMIT_REG_RSV = intersect(THERM_COMMIT, inputs["REG"], inputs["RSV"]) # Set of thermal resources with both regulation and spinning reserves

	THERM_COMMIT_REG = intersect(THERM_COMMIT, inputs["REG"]) # Set of thermal resources with regulation reserves
	THERM_COMMIT_RSV = intersect(THERM_COMMIT, inputs["RSV"]) # Set of thermal resources with spinning reserves

	THERM_COMMIT_NO_RES = setdiff(THERM_COMMIT, THERM_COMMIT_REG, THERM_COMMIT_RSV) # Set of thermal resources with no reserves

	THERM_COMMIT_REG_ONLY = setdiff(THERM_COMMIT_REG, THERM_COMMIT_RSV) # Set of thermal resources only with regulation reserves
	THERM_COMMIT_RSV_ONLY = setdiff(THERM_COMMIT_RSV, THERM_COMMIT_REG) # Set of thermal resources only with spinning reserves

	if !isempty(THERM_COMMIT_REG_RSV)
		@constraints(EP, begin
			# Maximum regulation and reserve contributions
			[y in THERM_COMMIT_REG_RSV, t=1:T], EP[:vREG][y,t] <= inputs["pP_Max"][y,t]*dfGen[y,:Reg_Max]*dfGen[y,:Cap_Size]*EP[:vCOMMIT][y,t]
			[y in THERM_COMMIT_REG_RSV, t=1:T], EP[:vRSV][y,t] <= inputs["pP_Max"][y,t]*dfGen[y,:Rsv_Max]*dfGen[y,:Cap_Size]*EP[:vCOMMIT][y,t]

			# Minimum stable power generated per technology "y" at hour "t" and contribution to regulation must be > min power
			[y in THERM_COMMIT_REG_RSV, t=1:T], EP[:vP][y,t]-EP[:vREG][y,t] >= dfGen[y,:Min_Power]*dfGen[y,:Cap_Size]*EP[:vCOMMIT][y,t]

			# Maximum power generated per technology "y" at hour "t"  and contribution to regulation and reserves up must be < max power
			[y in THERM_COMMIT_REG_RSV, t=1:T], EP[:vP][y,t]+EP[:vREG][y,t]+EP[:vRSV][y,t] <= inputs["pP_Max"][y,t]*dfGen[y,:Cap_Size]*EP[:vCOMMIT][y,t]
		end)
	end

	if !isempty(THERM_COMMIT_REG)
		@constraints(EP, begin
			# Maximum regulation and reserve contributions
			[y in THERM_COMMIT_REG, t=1:T], EP[:vREG][y,t] <= inputs["pP_Max"][y,t]*dfGen[y,:Reg_Max]*dfGen[y,:Cap_Size]*EP[:vCOMMIT][y,t]

			# Minimum stable power generated per technology "y" at hour "t" and contribution to regulation must be > min power
			[y in THERM_COMMIT_REG, t=1:T], EP[:vP][y,t]-EP[:vREG][y,t] >= dfGen[y,:Min_Power]*dfGen[y,:Cap_Size]*EP[:vCOMMIT][y,t]

			# Maximum power generated per technology "y" at hour "t"  and contribution to regulation must be < max power
			[y in THERM_COMMIT_REG, t=1:T], EP[:vP][y,t]+EP[:vREG][y,t] <= inputs["pP_Max"][y,t]*dfGen[y,:Cap_Size]*EP[:vCOMMIT][y,t]
		end)
	end

	if !isempty(THERM_COMMIT_RSV)
		@constraints(EP, begin
			# Maximum regulation and reserve contributions
			[y in THERM_COMMIT_RSV, t=1:T], EP[:vRSV][y,t] <= inputs["pP_Max"][y,t]*dfGen[y,:Rsv_Max]*dfGen[y,:Cap_Size]*EP[:vCOMMIT][y,t]

			# Minimum stable power generated per technology "y" at hour "t" must be > min power
			[y in THERM_COMMIT_RSV, t=1:T], EP[:vP][y,t] >= dfGen[y,:Min_Power]*dfGen[y,:Cap_Size]*EP[:vCOMMIT][y,t]

			# Maximum power generated per technology "y" at hour "t"  and contribution to reserves up must be < max power
			[y in THERM_COMMIT_RSV, t=1:T], EP[:vP][y,t]+EP[:vRSV][y,t] <= inputs["pP_Max"][y,t]*dfGen[y,:Cap_Size]*EP[:vCOMMIT][y,t]
		end)
	end

	if !isempty(THERM_COMMIT_NO_RES)
		@constraints(EP, begin
			# Minimum stable power generated per technology "y" at hour "t" > Min power
			[y in THERM_COMMIT_NO_RES, t=1:T], EP[:vP][y,t] >= dfGen[y,:Min_Power]*dfGen[y,:Cap_Size]*EP[:vCOMMIT][y,t]

			# Maximum power generated per technology "y" at hour "t" < Max power
			[y in THERM_COMMIT_NO_RES, t=1:T], EP[:vP][y,t] <= inputs["pP_Max"][y,t]*dfGen[y,:Cap_Size]*EP[:vCOMMIT][y,t]
		end)
	end

end

@doc raw"""
    hoursbefore(p::Int, t::Int, b::Int)

Determines the time index b hours before index t in
a landscape starting from t=1 which is separated
into distinct periods of length p.

For example, if p = 10,
1 hour before t=1 is t=10,
1 hour before t=10 is t=9
1 hour before t=11 is t=20
"""
function hoursbefore(p::Int, t::Int, b::Int)::Int
	period = div(t - 1, p)
	return period * p + mod1(t - b, p)
end

@doc raw"""
    hoursbefore(p::Int, t::Int, b::UnitRange)

This is a generalization of hoursbefore(... b::Int)
to allow for example b=1:3 to fetch a Vector{Int} of the three hours before
time index t.
"""
function hoursbefore(p::Int, t::Int, b::UnitRange{Int})::Vector{Int}
	period = div(t - 1, p)
	return period * p .+ mod1.(t .- b, p)
end

@doc raw"""
    hoursbefore(p::Int, t::Int, b::Int)
Determines the time index b hours before index t in
a landscape starting from t=1 which is separated
into distinct periods of length p.
For example, if p = 10,
1 hour before t=1 is t=10,
1 hour before t=10 is t=9
1 hour before t=11 is t=20
"""
function hoursbefore(p::Int, t::Int, b::Int)::Int
	period = div(t - 1, p)
	return period * p + mod1(t - b, p)
end

@doc raw"""
    hoursbefore(p::Int, t::Int, b::UnitRange)
This is a generalization of hoursbefore(... b::Int)
to allow for example b=1:3 to fetch a Vector{Int} of the three hours before
time index t.
"""
function hoursbefore(p::Int, t::Int, b::UnitRange{Int})::Vector{Int}
	period = div(t - 1, p)
	return period * p .+ mod1.(t .- b, p)
end