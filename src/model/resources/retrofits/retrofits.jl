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

	T = inputs["T"]     # Number of time steps (hours)
	Z = inputs["Z"]     # Number of zones
	G = inputs["G"] 	# Number of generators
	C = inputs["C"] 	# Number of cluster

	gen = inputs["RESOURCES"]
	dfRetrofit = inputs["dfRetrofit"]

	COMMIT 	  = inputs["COMMIT"]   # Set of all resources subject to unit commitment
	RETRO_CAP   = inputs["RETRO_CAP"]  # Set of all resources being retrofitted
	RETRO_CREAT = inputs["RETRO"] # Set of all resources being created

	# RETRO_CAP_CHARGE = inputs["RETRO_CAP_CHARGE"]  # Set of all charge capacity resources being created
	# RETRO_CAP_ENERGY = inputs["RETRO_CAP_ENERGY"]  # Set of all energy resources being created

	# return retrofit efficiency for retrofit pool id equal to c
	function retrofit_efficiency(c::Int64)
		df_row = findfirst(dfRetrofit.retrofit_pool_id .== c)
		return dfRetrofit[df_row, :retrofit_efficiency]
	end

	@constraint(EP, cRetrofit_zone_commit[c=1:C],
	sum(cap_size(gen[y]) * EP[:vRETROCAP][y] for y in intersect(RETRO_CAP, COMMIT, resources_in_retrofit_pool_by_rid(gen,c)); init=0) * 1.0
	+ sum(EP[:vRETROCAP][y] for y in setdiff(intersect(RETRO_CAP, resources_in_retrofit_pool_by_rid(gen,c)), COMMIT); init=0)
	== sum(cap_size(gen[y]) * EP[:vCAP][y] for y in intersect(RETRO_CREAT, COMMIT, resources_in_retrofit_pool_by_rid(gen,c)); init=0)
	+ sum(EP[:vCAP][y] for y in setdiff(intersect(RETRO_CREAT, resources_in_retrofit_pool_by_rid(gen,c)), COMMIT); init=0)) 

	return EP
end
