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

    dfGen = inputs["dfGen"]
	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
	Z = inputs["Z"]     # Number of zones
	THERM_ALL = inputs["THERM_ALL"]
    println(T)

    ### Constraints ###

	@constraint(EP, cCapacityFactor_upper[y in THERM_ALL, t = 1:T], 
        sum(EP[:vP][y, t]*inputs["omega"][t] for t=1:T)<=dfGen[y, :Capacity_Factor_ub]*EP[:eTotalCap][y]*T
	)

    @constraint(EP, cCapacityFactor_lower[y in THERM_ALL, t = 1:T], 
        sum(EP[:vP][y, t]*inputs["omega"][t] for t=1:T)>=dfGen[y, :Capacity_Factor_lb]*EP[:eTotalCap][y]*T
    )
end