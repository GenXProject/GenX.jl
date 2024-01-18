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

	dfGen = inputs["dfGen"]

	RESOURCES = inputs["RESOURCES"] # Set of all resources by name
	COMMIT 	  = inputs["COMMIT"]   # Set of all resources subject to unit commitment
	RETRO_CAP   = inputs["RETRO_CAP"]  # Set of all resources being retrofitted
	RETRO_CREAT = inputs["RETRO"] # Set of all resources being created

	RETRO_CAP_CHARGE = inputs["RETRO_CAP_CHARGE"]  # Set of all charge capacity resources being created
	RETRO_CAP_ENERGY = inputs["RETRO_CAP_ENERGY"]  # Set of all energy resources being created

	### Expressions ###

	@constraint(EP, cRetrofit_zone_commit[c=1:C],
	sum(dfGen[y,:Cap_Size]* EP[:vRETROCAP][y] for y in intersect(RETRO_CAP,COMMIT,dfGen[(dfGen[!,:cluster].==c),:R_ID])) * 1
	== sum(dfGen[y1,:Cap_Size]* EP[:vRETROCREATCAP][y1] for y1 in intersect(RETRO_CREAT,COMMIT,dfGen[(dfGen[!,:cluster].==c),:R_ID]))
	+ sum(EP[:vRETROCREATCAP][y2] for y2 in setdiff(intersect(RETRO_CREAT, dfGen[(dfGen[!,:cluster].==c),:R_ID]), COMMIT))) 

	return EP
end
