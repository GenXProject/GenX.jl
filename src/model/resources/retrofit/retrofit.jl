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
	retrofit(EP::Model, inputs::Dict)

This function defines the constraints for operation of retrofit technologies, including
	but not limited to carbon capture, natural gas-hydrogen blending, and thermal energy storage.

For retrofittable resources $y$, the sum of retrofit capacity $\Omega_{y_r,z}$ that may be installed
is constrained by the amount of capacity $\Delta_{y,z}$ retired as well as the retrofit efficiency
$ef_{y_r}$ where $y_r$ is any technology in the set of retrofits of $y$ ($RF(y)$).

```math
\begin{aligned}
\sum_{y_r} \frac{\Omega_{y_r,z}}{ef(y_r)} \leq \Delta_{y,z}
\hspace{4 cm}  \forall y \in Y, y_r \in \mathcal{RF(y)}, z \in \mathcal{Z}
\end{aligned}
```
"""
function retrofit(EP::Model, inputs::Dict)

	println("Retrofit Resources Module")

	G = inputs["G"]   # Number of resources (generators, storage, DR, and DERs)
	RETRO = inputs["RETRO"] # Set of all retrofit resources
	RET_CAP = inputs["RET_CAP"] # Set of all resources eligible for capacity retirements
	RETRO_SOURCE = inputs["RETROFIT_SOURCES"] # Source technology for the retrofit [1:G]
	RETRO_EFFICIENCY = inputs["RETROFIT_EFFICIENCIES"] # Maximum ratio of retrofitted capacity to source capacity [1:G]

	### Constraints ###

	@constraint(EP, cRetroMaxCap[y in RET_CAP], sum(EP[:vCAP][yr]/RETRO_EFFICIENCY[yr] for yr in findall(x->inputs["RESOURCES"][y]==RETRO_SOURCE[x], 1:G)) <= EP[:vRETCAP][y])

	return EP
end
