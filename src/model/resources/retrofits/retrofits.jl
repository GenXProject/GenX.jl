@doc raw"""
	retrofit(EP::Model, inputs::Dict)

This function defines the constraints for operation of retrofit technologies, including
	but not limited to carbon capture and thermal energy storage.

For retrofittable source technologies $y$ and retrofit technologies $r$, the sum of retrofit capacity $\Omega_{r,z}$ that may be installed
is constrained by the amount of capacity $\Delta_{y,z}$ retired as well as the retrofit efficiency
$ef_{y,r}$ where $r$ is any technology in the set of retrofit options of $y$ ($RF(y)$).

```math
\begin{aligned}
\sum_{r \in RF(y)} R_{y,r} \leq \Delta_y \quad \quad \quad \quad \forall y \in Y
\end{aligned}
```

```math
\begin{aligned}
\sum_{y : r \in RF(y)} R_{y,r}\cdot ef_{y,r} = \Omega_r \quad \quad \quad \quad \forall r \in RF(Y)
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

	### Variables ###
	# Retrofit capacity transition variables included in investment_discharge.jl.

	### Expressions ###

	# Retired capacity of all retirement-eligible resources (adjusted for unit commitment such that all are in capacity units MW|GW)
	@expression(EP, eRetroRetireCap[y in RET_CAP],
		if y in COMMIT
			EP[:vRETCAP][y]*CAP_SIZE[y]
		else
			EP[:vRETCAP][y]
		end
	)

	# One-to-Many Retrofit Mapping: Sum of capacity being retrofitted from a resource to all of its possible destination retrofit technologies (adjusted for unit commitment such that all are in capacity units MW|GW)
	@expression(EP, eRetroRetireCapMap[y in RET_CAP],
		if y in COMMIT
			sum( EP[:vRETROFIT][y,r]*CAP_SIZE[y] for r in intersect( findall(x->in(RESOURCES[y],RETRO_SOURCES[x]),1:G), NEW_CAP ); init=0 )
		else
			sum( EP[:vRETROFIT][y,r] for r in intersect( findall(x->in(RESOURCES[y],RETRO_SOURCES[x]),1:G), NEW_CAP ); init=0 )
		end
	)

	# Many-to-One Retrofit Mapping: For a given retrofit technology, sum of retrofit capacity from all of its possible sources (adjusted for unit commitment such that all are in capacity units MW|GW)
	@expression(EP, eRetroInstallCapMap[r in intersect(RETRO, NEW_CAP)],
		if r in COMMIT
			sum( RETRO_SOURCE_IDS[r][i] in RET_CAP ? EP[:vRETROFIT][RETRO_SOURCE_IDS[r][i], r]*CAP_SIZE[RETRO_SOURCE_IDS[r][i]]*RETRO_EFFICIENCY[r][i] : 0 for i in 1:NUM_RETRO_SOURCES[r]; init=0 )
		else
			sum( RETRO_SOURCE_IDS[r][i] in RET_CAP ? EP[:vRETROFIT][RETRO_SOURCE_IDS[r][i], r]*RETRO_EFFICIENCY[r][i] : 0 for i in 1:NUM_RETRO_SOURCES[r]; init=0 )
		end
	)

	# Installed capacity of all retrofit resources (adjusted for unit commitment such that all are in capacity units MW|GW)
	@expression(EP, eRetroInstallCap[r in intersect(RETRO, NEW_CAP)],
		if r in COMMIT
			EP[:vCAP][r]*CAP_SIZE[r]
		else
			EP[:vCAP][r]
		end
	)

	### Constraints ###

	# (One-to-Many) Sum of retrofitted capacity from a given source technology must not exceed the retired capacity of that technology. (Retrofitting is included within retirement, not a distinct category)
	# TO DO: Add term for decommissioned capacity on RHS and make it an equality constraint
	@constraint(EP, cRetroSource[y in RET_CAP], eRetroRetireCap[y] >= eRetroRetireCapMap[y])

	# (Many-to-One) New installed capacity of retrofit technology r must be equal to the (efficiency-downscaled) sum of capacity retrofitted to technology r from source technologies yr
	@constraint(EP, cRetroDest[r in intersect(RETRO, NEW_CAP)], eRetroInstallCapMap[r] == eRetroInstallCap[r])

	return EP
end
