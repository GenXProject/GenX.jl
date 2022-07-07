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

UPDATE THIS WITH NEW MATH

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
	RESOURCES = inputs["RESOURCES"] # Set of all resources by name
	RETRO = inputs["RETRO"] # Set of all retrofit resources by ID
	NEW_CAP = inputs["NEW_CAP"] # Set of all resources eligible for capacity expansion by ID
	RET_CAP = inputs["RET_CAP"] # Set of all resources eligible for capacity retirements by ID
	COMMIT = inputs["COMMIT"]   # Set of all resources subject to unit commitment
	RETRO_SOURCES = inputs["RETROFIT_SOURCES"] # Source technologies by name for each retrofit [1:G]
	RETRO_SOURCE_IDS = inputs["RETROFIT_SOURCE_IDS"] # Source technologies by ID for each retrofit [1:G]
	RETRO_EFFICIENCY = inputs["RETROFIT_EFFICIENCIES"] # Ratio of installed retrofit capacity to source capacity [0:1] (indexed by retrofit tech r, source # i)
	CAP_SIZE = inputs["dfGen"][!, :Cap_Size] # Capacity sizes for resources subject to unit commitment
	NUM_RETRO_SOURCES = inputs["NUM_RETROFIT_SOURCES"] # Number of possible sources for a given retrofit resource

	println("RETRO SOURCE")
	println(inputs["RETROFIT_SOURCES"])
	println("RETIREMENT-ELIGBLE RESOURCES")
	println(RET_CAP)
	println("EXPANSION-ELIGIBLE RESOURCES")
	println(NEW_CAP)
	println("RETROFIT-ELIGIBLE RESOURCES")
	println(RETRO)
	println("  Intersection: ")
	println([intersect(findall(x->in(inputs["RESOURCES"][y],RETRO_SOURCES[x]),1:G), findall(x->x in NEW_CAP, 1:G)) for y in RET_CAP])

	### Variables ###
	# Retrofit capacity transition variables included in investment_discharge.jl.

	### Expressions ###

	println("Expressions...")

	# Retired capacity of all retirement-eligible resources (adjusted for unit commitment such that all are in capacity units MW|GW)
	println("eRetroRetireCap")
	@expression(EP, eRetroRetireCap[y in RET_CAP],
		if y in COMMIT
			EP[:vRETCAP][y]*CAP_SIZE[y]
		else
			EP[:vRETCAP][y]
		end
	)

	# One-to-Many Retrofit Mapping: Sum of capacity being retrofitted from a resource to all of its possible destination retrofit technologies (adjusted for unit commitment such that all are in capacity units MW|GW)
	println("eRetroRetireCapMap")
	@expression(EP, eRetroRetireCapMap[y in RET_CAP],
		if y in COMMIT
			sum( EP[:vRETROFIT][y,r]*CAP_SIZE[y] for r in intersect( findall(x->in(RESOURCES[y],RETRO_SOURCES[x]),1:G), NEW_CAP ); init=0 )
		else
			sum( EP[:vRETROFIT][y,r] for r in intersect( findall(x->in(RESOURCES[y],RETRO_SOURCES[x]),1:G), NEW_CAP ); init=0 )
		end
	)

	# Many-to-One Retrofit Mapping: For a given retrofit technology, sum of retrofit capacity from all of its possible sources (adjusted for unit commitment such that all are in capacity units MW|GW)
	println("eRetroInstallCapMap")
	@expression(EP, eRetroInstallCapMap[r in intersect(RETRO, NEW_CAP)],
		if r in COMMIT
			sum( RETRO_SOURCE_IDS[r][i] in RET_CAP ? EP[:vRETROFIT][RETRO_SOURCE_IDS[r][i], r]*CAP_SIZE[RETRO_SOURCE_IDS[r][i]]*RETRO_EFFICIENCY[r][i] : 0 for i in 1:NUM_RETRO_SOURCES[r]; init=0 )
		else
			sum( RETRO_SOURCE_IDS[r][i] in RET_CAP ? EP[:vRETROFIT][RETRO_SOURCE_IDS[r][i], r]*RETRO_EFFICIENCY[r][i] : 0 for i in 1:NUM_RETRO_SOURCES[r]; init=0 )
		end
	)

	# Installed capacity of all retrofit resources (adjusted for unit commitment such that all are in capacity units MW|GW)
	println("eRetroInstallCap")
	@expression(EP, eRetroInstallCap[r in intersect(RETRO, NEW_CAP)],
		if r in COMMIT
			EP[:vCAP][r]*CAP_SIZE[r]
		else
			EP[:vCAP][r]
		end
	)

	### Constraints ###

	println("Constraints...")

	println("Retrofit Source (LHS) Constraint...")
	# (One-to-Many) Sum of retrofitted capacity from a given source technology must not exceed the retired capacity of that technology. (Retrofitting is included within retirement, not a distinct category)
	# TO DO: Add term for decommissioned capacity on RHS and make it an equality constraint
	@constraint(EP, cRetroSource[y in RET_CAP], eRetroRetireCap[y] >= eRetroRetireCapMap[y])


	println("Retrofit Desintation (RHS) Constraint...")
	# (Many-to-One) New installed capacity of retrofit technology r must be equal to the (efficiency-downscaled) sum of capacity retrofitted to technology r from source technologies yr
	@constraint(EP, cRetroDest[r in intersect(RETRO, NEW_CAP)], eRetroInstallCapMap[r] == eRetroInstallCap[r])


	return EP
end
