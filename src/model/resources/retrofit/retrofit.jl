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

For retrofit resources ($y\in \mathcal{RF}$), the capacity $\Omega_{y,z}$ that may be installed
is constrained by the amount of capacity $\Delta_{y',z}$ retired by the source technology $y'$ as well
as the retrofit efficiency [SYM? $ef_y$].

```math
\begin{aligned}
\Omega_{y,z} \leq ef_{y} \times \Delta_{y',z}
\hspace{4 cm}  \forall y \in \mathcal{RF}, z \in \mathcal{Z}
\end{aligned}
```
"""
function retrofit(EP::Model, inputs::Dict)

	println("Retrofit Resources Module")

	RETRO = inputs["RETRO"] # Set of all retrofit resources
	NEW_CAP = inputs["NEW_CAP"] # Set of all resources eligible for new capacity
	RETRO_SOURCE = inputs["RETROFIT_SOURCES"] # Source technology for the retrofit
	RETRO_EFFICIENCY = inputs["RETROFIT_EFFICIENCIES"] # Maximum ratio of retrofitted capacity to source capacity

	### Constraints ###

	@constraint(EP, cRetroMaxCap[y in intersect(RETRO,NEW_CAP)], EP[:vCAP][y] <= RETRO_EFFICIENCY[y]*EP[:vRETCAP][findall(x->x==RETRO_SOURCE[y], inputs["RESOURCES"])[1]])

	return EP
end
