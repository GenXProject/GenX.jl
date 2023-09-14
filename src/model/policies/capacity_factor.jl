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

    # Define resources that have capacity factor constraints
    CF_UPPER = dfGen[dfGen.Capacity_Factor_ub.<1,:R_ID]
    CF_LOWER = dfGen[dfGen.Capacity_Factor_ub.>0,:R_ID]
    
    ### Constraints ###
	@constraint(EP, cCapacityFactor_upper[y in CF_UPPER, t = 1:T], 
        sum(EP[:vP][y, t]*inputs["omega"][t] for t=1:T) <= sum(dfGen[y, :Capacity_Factor_ub]*EP[:eTotalCap][y]*inputs["omega"][t] for t = 1:T)
	)

    @constraint(EP, cCapacityFactor_lower[y in CF_UPPER, t = 1:T], 
        sum(EP[:vP][y, t]*inputs["omega"][t] for t=1:T) >= sum(dfGen[y, :Capacity_Factor_lb]*EP[:eTotalCap][y]*inputs["omega"][t] for t = 1:T)
    )
end