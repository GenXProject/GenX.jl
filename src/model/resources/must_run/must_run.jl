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
	must_run(EP::Model, inputs::Dict, CapacityReserveMargin::Int)

This function defines the constraints for operation of `must-run' or non-dispatchable resources, such as rooftop solar systems that do not receive dispatch signals, run-of-river hydroelectric facilities without the ability to spill water, or cogeneration systems that must produce a fixed quantity of heat in each time step. This resource type can also be used to model baseloaded or self-committed thermal generators that do not respond to economic dispatch.

For must-run resources ($y\in \mathcal{MR}$) output in each time period $t$ must exactly equal the available capacity factor times the installed capacity, not allowing for curtailment. These resources are also not eligible for contributing to frequency regulation or operating reserve requirements.

```math
\begin{aligned}
\Theta_{y,z,t} = \rho^{max}_{y,z,t}\times \Delta^{total}_{y,z}
\hspace{4 cm}  \forall y \in \mathcal{MR}, z \in \mathcal{Z},t \in \mathcal{T}
\end{aligned}
```
"""
function must_run(EP::Model, inputs::Dict, CapacityReserveMargin::Int)

	println("Must-Run Resources Module")

	dfGen = inputs["dfGen"]

	T = inputs["T"]     # Number of time steps (hours)
	Z = inputs["Z"]     # Number of zones
	G = inputs["G"] 	# Number of generators

	MUST_RUN = inputs["MUST_RUN"]

	### Expressions ###

	## Power Balance Expressions ##

	@expression(EP, ePowerBalanceNdisp[t=1:T, z=1:Z],
		sum(EP[:vP][y,t] for y in intersect(MUST_RUN, dfGen[dfGen[!,:Zone].==z,:][!,:R_ID])))

	EP[:ePowerBalance] += ePowerBalanceNdisp

	# Capacity Reserves Margin policy
	if CapacityReserveMargin > 0
		@expression(EP, eCapResMarBalanceMustRun[res=1:inputs["NCapacityReserveMargin"], t=1:T], sum(dfGen[y,Symbol("CapRes_$res")] * EP[:eTotalCap][y] * inputs["pP_Max"][y,t]  for y in MUST_RUN))
		EP[:eCapResMarBalance] += eCapResMarBalanceMustRun
	end

	### Constratints ###

	@constraint(EP, [y in MUST_RUN, t=1:T], EP[:vP][y,t] == inputs["pP_Max"][y,t]*EP[:eTotalCap][y])

	return EP
end
