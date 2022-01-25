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
	thermal_commit(EP::Model, inputs::Dict, Reserves::Int)

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
	\Theta_{y,z,t} \geq \rho^{max}_{y,z} \times \Omega^{size}_{y,z} \times \nu_{y,z,t}
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
"""
function fleccs_commit(EP::Model, inputs::Dict,FLECCS::Int,UCommit::Int,  Reserves::Int)

	println("FLECCS (Unit Commitment) Resources Module")

	dfGen_ccs = inputs["dfGen_ccs"]

	T = inputs["T"]     # Number of time steps (hours)
	Z = inputs["Z"]     # Number of zones
	G = inputs["G"]     # Number of resources


	FLECCS_ALL = inputs["FLECCS_ALL"] # set of FLECCS generator
	N_F = inputs["N_F"] 	# get number of flexible subcompoents
	n_F = length(N_F)
	COMMIT_ccs = inputs["COMMIT_CCS"] # CCS compoents subjected to UC
 

	hours_per_subperiod = inputs["hours_per_subperiod"] #total number of hours per subperiod
	START_SUBPERIODS = inputs["START_SUBPERIODS"]
	INTERIOR_SUBPERIODS = inputs["INTERIOR_SUBPERIODS"]



	### Variables ###

	## Decision variables for unit commitment
	# gas turbine and steam turbine are grouped into vCOMMIT_NGCC, for Allam cycle, we also use vCOMMIT_NGCC to represent the commitment status
	# commitment state variable
	@variable(EP, vCOMMIT_FLECCS[y in FLECCS_ALL, i in COMMIT_ccs, t=1:T] >= 0)
	# startup event variable
	@variable(EP, vSTART_FLECCS[y in FLECCS_ALL, i in COMMIT_ccs, t=1:T] >= 0)
	# shutdown event variable
	@variable(EP, vSHUT_FLECCS[y in FLECCS_ALL, i in COMMIT_ccs, t=1:T] >= 0)

	### Expressions ###
	## Objective Function Expressions ##
	# Startup costs of "generation" for resource "y" during hour "t"
	@expression(EP, eCStart_FLECCS[y in FLECCS_ALL, i in COMMIT_ccs, t=1:T],(inputs["omega"][t]*inputs["C_Start_FLECCS"][y,i,t]*vSTART_FLECCS[y,i,t]))
	# Julia is fastest when summing over one row one column at a time
	@expression(EP, eTotalCStartT_FLECCS[t=1:T], sum(eCStart_FLECCS[y,i,t] for y in FLECCS_ALL, i in COMMIT_ccs))
	@expression(EP, eTotalCStart_FLECCS, sum(eTotalCStartT_FLECCS[t] for t=1:T))

	EP[:eObj] += eTotalCStart_FLECCS

	### Constratints ###
	## Declaration of integer/binary variables
	if UCommit == 1 # Integer UC constraints
		for y in FLECCS_ALL
		    for i in COMMIT_ccs
			    set_integer.(vCOMMIT_FLECCS[y,i,:])
	    		set_integer.(vSTART_FLECCS[y,i,:])
		    	set_integer.(vSHUT_FLECCS[y,i,:])
			    if y in inputs["RET_CAP_FLECCS"]
    				set_integer(EP[:vRETCAP_FLECCS][y,i])
	    		end
		    	if y in inputs["NEW_CAP_FLECCS"]
			     	set_integer(EP[:vRETCAP_FLECCS][y,i])
				end
			end
		end
	end 




	### Expressions ###

	### Constraints ###

	### Capacitated limits on unit commitment decision variables (Constraints #1-3)
	@constraints(EP, begin
		[y in FLECCS_ALL, i in COMMIT_ccs, t=1:T], vCOMMIT_FLECCS[y,i,t] <= EP[:eTotalCapFLECCS][y,i]/dfGen_ccs[(dfGen_ccs[!,:R_ID].==y),:Cap_Size][i]
		[y in FLECCS_ALL, i in COMMIT_ccs, t=1:T], vSTART_FLECCS[y,i,t] <= EP[:eTotalCapFLECCS][y,i]/dfGen_ccs[(dfGen_ccs[!,:R_ID].==y),:Cap_Size][i]
		[y in FLECCS_ALL, i in COMMIT_ccs, t=1:T], vSHUT_FLECCS[y,i,t] <= EP[:eTotalCapFLECCS][y,i]/dfGen_ccs[(dfGen_ccs[!,:R_ID].==y),:Cap_Size][i]
	end)

	# Commitment state constraint linking startup and shutdown decisions (Constraint #4)
	@constraints(EP, begin
		# For Start Hours, links first time step with last time step in subperiod
		[y in FLECCS_ALL, i in COMMIT_ccs, t in START_SUBPERIODS], vCOMMIT_FLECCS[y,i,t] == vCOMMIT_FLECCS[y,i,(t+hours_per_subperiod-1)] + vSTART_FLECCS[y,i,t] - vSHUT_FLECCS[y,i,t]
		# For all other hours, links commitment state in hour t with commitment state in prior hour + sum of start up and shut down in current hour
		[y in FLECCS_ALL, i in COMMIT_ccs, t in INTERIOR_SUBPERIODS], vCOMMIT_FLECCS[y,i,t] == vCOMMIT_FLECCS[y,i,t-1] + vSTART_FLECCS[y,i,t] - vSHUT_FLECCS[y,i,t]
	end)

	### Maximum ramp up and down between consecutive hours (Constraints #5-6)
    ## 
	## For Start Hours
	# Links last time step with first time step, ensuring position in hour 1 is within eligible ramp of final hour position
		# rampup constraints
	@constraint(EP,[y in FLECCS_ALL, i in COMMIT_ccs, t in START_SUBPERIODS],
		EP[:vFLECCS_output][y,i,t]-EP[:vFLECCS_output][y,i,(t+hours_per_subperiod-1)] <= dfGen_ccs[(dfGen_ccs[!,:R_ID].==y),:Ramp_Up_Percentage][i]*dfGen_ccs[(dfGen_ccs[!,:R_ID].==y),:Cap_Size][i]*(vCOMMIT_FLECCS[y,i,t]-vSTART_FLECCS[y,i,t])
			+ min(1,max(dfGen_ccs[(dfGen_ccs[!,:R_ID].==y),:Min_Power][i],dfGen_ccs[!,:Ramp_Up_Percentage][y]))*dfGen_ccs[(dfGen_ccs[!,:R_ID].==y),:Cap_Size][i]*vSTART_FLECCS[y,i,t]
			-dfGen_ccs[(dfGen_ccs[!,:R_ID].==y),:Min_Power][i]*dfGen_ccs[(dfGen_ccs[!,:R_ID].==y),:Cap_Size][i]*vSHUT_FLECCS[y,i,t])

		# rampdown constraints
	@constraint(EP,[y in FLECCS_ALL, i in COMMIT_ccs, t in START_SUBPERIODS],
		EP[:vFLECCS_output][y,i,(t+hours_per_subperiod-1)]-EP[:vFLECCS_output][y,i,t] <=dfGen_ccs[(dfGen_ccs[!,:R_ID].==y),:Ramp_Dn_Percentage][i]*dfGen_ccs[(dfGen_ccs[!,:R_ID].==y),:Cap_Size][i]*(vCOMMIT_FLECCS[y,i,t]-vSTART_FLECCS[y,i,t])
			-dfGen_ccs[(dfGen_ccs[!,:R_ID].==y),:Min_Power][i]*dfGen_ccs[(dfGen_ccs[!,:R_ID].==y),:Cap_Size][i]*vSTART_FLECCS[y,i,t]
			+ min(1,max(dfGen_ccs[(dfGen_ccs[!,:R_ID].==y),:Min_Power][i],dfGen_ccs[!,:Ramp_Dn_Percentage][y]))*dfGen_ccs[(dfGen_ccs[!,:R_ID].==y),:Cap_Size][i]*vSHUT_FLECCS[y,i,t])

	## For Interior Hours
		# rampup constraints
	@constraint(EP,[y in FLECCS_ALL, i in COMMIT_ccs, t in INTERIOR_SUBPERIODS],
		EP[:vFLECCS_output][y,i,t]-EP[:vFLECCS_output][y,i,t-1] <=dfGen_ccs[(dfGen_ccs[!,:R_ID].==y),:Ramp_Up_Percentage][i]*dfGen_ccs[(dfGen_ccs[!,:R_ID].==y),:Cap_Size][i]*(vCOMMIT_FLECCS[y,i,t]-vSTART_FLECCS[y,i,t])
			+ min(1,max(dfGen_ccs[(dfGen_ccs[!,:R_ID].==y),:Min_Power][i],dfGen_ccs[!,:Ramp_Up_Percentage][y]))*dfGen_ccs[(dfGen_ccs[!,:R_ID].==y),:Cap_Size][i]*vSTART_FLECCS[y,i,t]
			-dfGen_ccs[(dfGen_ccs[!,:R_ID].==y),:Min_Power][i]*dfGen_ccs[(dfGen_ccs[!,:R_ID].==y),:Cap_Size][i]*vSHUT_FLECCS[y,i,t])

		# rampdown constraints
	@constraint(EP,[y in FLECCS_ALL, i in COMMIT_ccs, t in INTERIOR_SUBPERIODS],
		EP[:vFLECCS_output][y,i,t-1]-EP[:vFLECCS_output][y,i,t] <=dfGen_ccs[(dfGen_ccs[!,:R_ID].==y),:Ramp_Dn_Percentage][i]*dfGen_ccs[(dfGen_ccs[!,:R_ID].==y),:Cap_Size][i]*(vCOMMIT_FLECCS[y,i,t]-vSTART_FLECCS[y,i,t])
			-dfGen_ccs[(dfGen_ccs[!,:R_ID].==y),:Min_Power][i]*dfGen_ccs[(dfGen_ccs[!,:R_ID].==y),:Cap_Size][i]*vSTART_FLECCS[y,i,t]
			+min(1,max(dfGen_ccs[(dfGen_ccs[!,:R_ID].==y),:Min_Power][i],dfGen_ccs[!,:Ramp_Dn_Percentage][y]))*dfGen_ccs[(dfGen_ccs[!,:R_ID].==y),:Cap_Size][i]*vSHUT_FLECCS[y,i,t])

	### Minimum and maximum power output constraints (Constraints #7-8)
	@constraints(EP, begin
		# Minimum stable power generated per technology "y" at hour "t" > Min power
		[y in FLECCS_ALL, i in COMMIT_ccs, t=1:T], EP[:vFLECCS_output][y,i,t] >= dfGen_ccs[(dfGen_ccs[!,:R_ID].==y),:Min_Power][i]*dfGen_ccs[(dfGen_ccs[!,:R_ID].==y),:Cap_Size][i]*vCOMMIT_FLECCS[y,i,t]

		# Maximum power generated per technology "y" at hour "t" < Max power
		[y in FLECCS_ALL, i in COMMIT_ccs, t=1:T], EP[:vFLECCS_output][y,i,t] <= dfGen_ccs[(dfGen_ccs[!,:R_ID].==y),:Cap_Size][i]*vCOMMIT_FLECCS[y,i,t]
	end)


    ####Fangwei
	### Minimum up and down times (Constraints #9-10)
	for y in FLECCS_ALL
		for i in COMMIT_ccs
		    ## up time
		    Up_Time = Int(floor(dfGen_ccs[(dfGen_ccs[!,:R_ID].==y),:Up_Time][i]))
		    Up_Time_HOURS = [] # Set of hours in the summation term of the maximum up time constraint for the first subperiod of each representative period
		    for s in START_SUBPERIODS
			    Up_Time_HOURS = union(Up_Time_HOURS, (s+1):(s+Up_Time-1))
		    end

		    @constraints(EP, begin
			    # cUpTimeInterior: Constraint looks back over last n hours, where n = dfGen_ccs[(dfGen_ccs[!,:R_ID].==y),:Up_Time][i])
			    [t in setdiff(INTERIOR_SUBPERIODS,Up_Time_HOURS)], vCOMMIT_FLECCS[y,i,t] >= sum(vSTART_FLECCS[y,i,e] for e=(t-dfGen_ccs[(dfGen_ccs[!,:R_ID].==y),:Up_Time][i]):t)

			    # cUpTimeWrap: If n is greater than the number of subperiods left in the period, constraint wraps around to first hour of time series
			    # cUpTimeWrap constraint equivalant to: sum(vSTART_FLECCS[y,e] for e=(t-((t%hours_per_subperiod)-1):t))+sum(vSTART_FLECCS[y,e] for e=(hours_per_subperiod_max-(dfGen_ccs[(dfGen_ccs[!,:R_ID].==y),:Up_Time][i])-(t%hours_per_subperiod))):hours_per_subperiod_max)
			    [t in Up_Time_HOURS], vCOMMIT_FLECCS[y,i,t] >= sum(vSTART_FLECCS[y,i,e] for e=(t-((t%hours_per_subperiod)-1):t))+sum(vSTART_FLECCS[y,i,e] for e=((t+hours_per_subperiod-(t%hours_per_subperiod))-(dfGen_ccs[(dfGen_ccs[!,:R_ID].==y),:Up_Time][i]-(t%hours_per_subperiod))):(t+hours_per_subperiod-(t%hours_per_subperiod)))

			    # cUpTimeStart:
			    # NOTE: Expression t+hours_per_subperiod-(t%hours_per_subperiod) is equivalant to "hours_per_subperiod_max"
			    [t in START_SUBPERIODS], vCOMMIT_FLECCS[y,i,t] >= vSTART_FLECCS[y,i,t]+sum(vSTART_FLECCS[y,i,e] for e=((t+hours_per_subperiod-1)-(dfGen_ccs[(dfGen_ccs[!,:R_ID].==y),:Up_Time][i]-1)):(t+hours_per_subperiod-1))
		    end)

		    ## down time
		    Down_Time = Int(floor(dfGen_ccs[(dfGen_ccs[!,:R_ID].==y),:Down_Time][i]))
		    Down_Time_HOURS = [] # Set of hours in the summation term of the maximum down time constraint for the first subperiod of each representative period
		    for s in START_SUBPERIODS
		    	Down_Time_HOURS = union(Down_Time_HOURS, (s+1):(s+Down_Time-1))
		    end

		    # Constraint looks back over last n hours, where n = dfGen_ccs[(dfGen_ccs[!,:R_ID].==y),:Down_Time][i]
		    # TODO: Replace LHS of constraints in this block with eNumPlantsOffline[y,t]
		    @constraints(EP, begin
		    	# cDownTimeInterior: Constraint looks back over last n hours, where n = inputs["pDMS_Time"][y]
		    	[t in setdiff(INTERIOR_SUBPERIODS,Down_Time_HOURS)], EP[:eTotalCapFLECCS][y,i]/dfGen_ccs[(dfGen_ccs[!,:R_ID].==y),:Cap_Size][i]-vCOMMIT_FLECCS[y,i,t] >= sum(vSHUT_FLECCS[y,i,e] for e=(t-dfGen_ccs[(dfGen_ccs[!,:R_ID].==y),:Down_Time][i]):t)

		    	# cDownTimeWrap: If n is greater than the number of subperiods left in the period, constraint wraps around to first hour of time series
		    	# cDownTimeWrap constraint equivalant to: EP[:eTotalCapFLECCS][y,i]/dfGen_ccs[(dfGen_ccs[!,:R_ID].==y),:Cap_Size][i]-vCOMMIT_FLECCS[y,t] >= sum(vSHUT_FLECCS[y,e] for e=(t-((t%hours_per_subperiod)-1):t))+sum(vSHUT_FLECCS[y,e] for e=(hours_per_subperiod_max-(dfGen_ccs[(dfGen_ccs[!,:R_ID].==y),:Down_Time][i]-(t%hours_per_subperiod))):hours_per_subperiod_max)
		    	[t in Down_Time_HOURS], EP[:eTotalCapFLECCS][y,i]/dfGen_ccs[(dfGen_ccs[!,:R_ID].==y),:Cap_Size][i]-vCOMMIT_FLECCS[y,i,t] >= sum(vSHUT_FLECCS[y,i,e] for e=(t-((t%hours_per_subperiod)-1):t))+sum(vSHUT_FLECCS[y,i,e] for e=((t+hours_per_subperiod-(t%hours_per_subperiod))-(dfGen_ccs[(dfGen_ccs[!,:R_ID].==y),:Down_Time][i]-(t%hours_per_subperiod))):(t+hours_per_subperiod-(t%hours_per_subperiod)))
    
		    	# cDownTimeStart:
		    	# NOTE: Expression t+hours_per_subperiod-(t%hours_per_subperiod) is equivalant to "hours_per_subperiod_max"
		    	[t in START_SUBPERIODS], EP[:eTotalCapFLECCS][y,i]/dfGen_ccs[(dfGen_ccs[!,:R_ID].==y),:Cap_Size][i]-vCOMMIT_FLECCS[y,i,t]  >= vSHUT_FLECCS[y,i,t]+sum(vSHUT_FLECCS[y,i,e] for e=((t+hours_per_subperiod-1)-(dfGen_ccs[(dfGen_ccs[!,:R_ID].==y),:Down_Time][i]-1)):(t+hours_per_subperiod-1))
		    end)
	    end
	end

	## END Constraints for thermal units subject to integer (discrete) unit commitment decisions



	return EP
end

