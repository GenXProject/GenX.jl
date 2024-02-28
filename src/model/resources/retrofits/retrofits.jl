@doc raw"""
	retrofit(EP::Model, inputs::Dict)

This function defines the constraints for operation of retrofit technologies, including
	but not limited to carbon capture and thermal energy storage.

For retrofittable source technologies $y$ and retrofit technologies $r$, the sum of retrofit capacity $\Omega_{r,z}$ that may be installed
is constrained by the retrofittable capacity $P_{y,z}$ as well as the retrofit efficiency
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

	gen = inputs["RESOURCES"]

	COMMIT 	  = inputs["COMMIT"]   # Set of all resources subject to unit commitment
	RETROFIT_CAP   = inputs["RETROFIT_CAP"]  # Set of all resources being retrofitted
	RETROFIT_OPTIONS = inputs["RETROFIT_OPTIONS"] # Set of all resources being created
	RETROFIT_IDS = inputs["RETROFIT_IDS"] # Set of unique IDs for retrofit resources

	@constraint(EP, cRetrofitZone[c in RETROFIT_IDS],
	sum(cap_size(gen[y]) * EP[:vRETROCAP][y] * retrofit_efficiency(gen[y]) for y in intersect(RETROFIT_CAP, COMMIT, resources_in_retrofit_pool_by_rid(gen,c)); init=0) 
	+ sum(EP[:vRETROCAP][y] * retrofit_efficiency(gen[y]) for y in setdiff(intersect(RETROFIT_CAP, resources_in_retrofit_pool_by_rid(gen,c)), COMMIT); init=0)
	== sum(cap_size(gen[y]) * EP[:vCAP][y] * retrofit_efficiency(gen[y]) for y in intersect(RETROFIT_OPTIONS, COMMIT, resources_in_retrofit_pool_by_rid(gen,c)); init=0)
	+ sum(EP[:vCAP][y] * retrofit_efficiency(gen[y]) for y in setdiff(intersect(RETROFIT_OPTIONS, resources_in_retrofit_pool_by_rid(gen,c)), COMMIT); init=0)) 

	return EP
end
