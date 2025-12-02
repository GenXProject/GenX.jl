@doc raw"""
    capacity_factor_requirement!(EP::Model, inputs::Dict, setup::Dict)
This function establishes constraints that can be flexibily applied to define generators' type based on load level (peaker, intermediate, and base).
Load level is reflected by capacity factors and a upper and lower bound of capacity is applied to each thermal resource.
```math
\begin{aligned}
\end{aligned}
```
"""
function capacity_factor_requirement!(EP::Model, inputs::Dict, setup::Dict)

	println("Capacity Factor Requirement Policies Module")

    gen = inputs["RESOURCES"]
	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
	Z = inputs["Z"]     # Number of zones

    # Define resources that have capacity factor constraints
    CF_UPPER = is_cf_ub(gen)
    CF_LOWER = is_cf_lb(gen)
    
    ### Constraints ###
	@constraint(EP, cCapacityFactor_upper[y in CF_UPPER], 
        sum(EP[:vP][y, t]*inputs["omega"][t] for t=1:T) <= sum(gen[y].capacity_factor_ub*EP[:eTotalCap][y]*inputs["omega"][t] for t = 1:T)
	)

    @constraint(EP, cCapacityFactor_lower[y in CF_LOWER], 
        sum(EP[:vP][y, t]*inputs["omega"][t] for t=1:T) >= sum(gen[y]. capacity_factor_lb*EP[:eTotalCap][y]*inputs["omega"][t] for t = 1:T)
    )
end