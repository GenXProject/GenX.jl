@doc raw"""
	hourly_matching!(EP::Model, inputs::Dict)

This module defines the hourly matching policy constraint. #TODO: Add more details.

# Arguments
- EP::Model: The optimization model object.
- inputs::Dict: A dictionary containing input data.

"""
function hourly_matching!(EP::Model, inputs::Dict)
    println("Hourly Matching Policies Module")
    T = inputs["T"]
    Z = inputs["Z"]

    ## Energy Share Requirements (minimum energy share from qualifying renewable resources) constraint
    @constraint(EP, cHourlyMatching[t = 1:T, z = 1:Z], EP[:eHM][t, z]>=0)
end