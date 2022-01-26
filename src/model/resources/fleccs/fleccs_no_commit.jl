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
	thermal_no_commit(EP::Model, inputs::Dict, Reserves::Int)

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
function fleccs_no_commit(EP::Model, inputs::Dict, FLECCS::Int, Reserves::Int)

	println("FLECCS (No Unit Commitment) Resources Module")

	dfGen_ccs = inputs["dfGen_ccs"]

	T = inputs["T"]     # Number of time steps (hours)
	Z = inputs["Z"]     # Number of zones
	G = inputs["G"]     # Number of resources

    G_F = inputs["G_F"] # Number of FLECCS generator
	FLECCS_ALL = inputs["FLECCS_ALL"] # set of FLECCS generator
	NO_COMMIT_ccs =  inputs["NO_COMMIT_CCS"]

	FLECCS_parameters = inputs["FLECCS_parameters"] # FLECCS specific parameters
	# get number of flexible subcompoents
	N_F = inputs["N_F"]

	hours_per_subperiod = inputs["hours_per_subperiod"] #total number of hours per subperiod
	START_SUBPERIODS = inputs["START_SUBPERIODS"]
	INTERIOR_SUBPERIODS = inputs["INTERIOR_SUBPERIODS"]


	### Constraints ###
	### Maximum ramp up and down between consecutive hours (Constraints #1-2)
	@constraints(EP, begin
		## Maximum ramp up between consecutive hours
		## Gas turbine
		# Start Hours: Links last time step with first time step, ensuring position in hour 1 is within eligible ramp of final hour position
		# NOTE: We should make wrap-around a configurable option
		[y in FLECCS_ALL, i in NO_COMMIT_ccs, t in START_SUBPERIODS], EP[:vFLECCS_output][y,i,t]-EP[:vFLECCS_output][y,i,(t+hours_per_subperiod-1)] <=  dfGen_ccs[(dfGen_ccs[!,:R_ID].==y),:Ramp_Up_Percentage][i]*EP[:eTotalCapFLECCS][y,i]
		# Interior Hours
		[y in FLECCS_ALL,i in NO_COMMIT_ccs, t in INTERIOR_SUBPERIODS], EP[:vFLECCS_output][y,i,t]-EP[:vFLECCS_output][y,i,t-1] <=   dfGen_ccs[(dfGen_ccs[!,:R_ID].==y),:Ramp_Up_Percentage][i] * EP[:eTotalCapFLECCS][y,i]
		## Maximum ramp down between consecutive hours
		# Start Hours: Links last time step with first time step, ensuring position in hour 1 is within eligible ramp of final hour position
		[y in FLECCS_ALL,i in NO_COMMIT_ccs, t in START_SUBPERIODS], EP[:vFLECCS_output][y,i,(t+hours_per_subperiod-1)] -EP[:vFLECCS_output][y,i,t] <=  dfGen_ccs[(dfGen_ccs[!,:R_ID].==y),:Ramp_Dn_Percentage][i]*EP[:eTotalCapFLECCS][y,i]
		# Interior Hours
		[y in FLECCS_ALL,i in NO_COMMIT_ccs, t in INTERIOR_SUBPERIODS], EP[:vFLECCS_output][y,i,t-1] - EP[:vFLECCS_output][y,i,t] <=dfGen_ccs[(dfGen_ccs[!,:R_ID].==y),:Ramp_Dn_Percentage][i] * EP[:eTotalCapFLECCS][y,i]

	end)



	### Minimum and maximum power output constraints (Constraints #3-4)
	@constraints(EP, begin
	    # gas turbine
		# Minimum stable power generated per technology "y" at hour "t" Min_Power
		[y in FLECCS_ALL,i in NO_COMMIT_ccs, t=1:T], EP[:vFLECCS_output][y,i,t] >= dfGen_ccs[(dfGen_ccs[!,:R_ID].==y),:Min_Power][i]*EP[:eTotalCapFLECCS][y,i]
		# Maximum power generated per technology "y" at hour "t"
		[y in FLECCS_ALL,i in NO_COMMIT_ccs, t=1:T], EP[:vFLECCS_output][y,i,t] <= EP[:eTotalCapFLECCS][y,i]

    end)


	# END Constraints for FLECCS resources not subject to unit commitment

	##### CO2 emissioms

	# Add CO2 from start up fuel and vented CO2
	#@expression(EP, eEmissionsByPlantFLECCS[y in FLECCS_ALL, t=1:T], EP[:eCO2_vent][y,t])


	return EP
end
