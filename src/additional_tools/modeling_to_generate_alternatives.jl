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
	mga(EP::Model, path::AbstractString, setup::Dict, inputs::Dict, outpath::AbstractString)

We have implemented an updated Modeling to Generate Alternatives (MGA) Algorithm proposed by [Evelina et al., (2017)](https://www.sciencedirect.com/science/article/pii/S0360544217304097) to generate a set of feasible, near cost-optimal technology portfolios. This algorithm was developed by [Brill Jr, E. D., 1979](https://pubsonline.informs.org/doi/abs/10.1287/mnsc.25.5.413) and introduced to energy system planning by [DeCarolia, J. F., 2011](https://www.sciencedirect.com/science/article/pii/S0140988310000721).

To create the MGA formulation, we replace the cost-minimizing objective function of GenX with a new objective function that creates multiple generation portfolios by zone. We further add a new budget constraint based on the optimal objective function value $f^*$ of the least-cost model and the user-specified value of slack $\delta$. After adding the slack constraint, the resulting MGA formulation is given as:

```math
\begin{aligned}
	\text{max/min} \quad
	&\sum_{z \in \mathcal{Z}}\sum_{r \in \mathcal{R}} \beta_{z,r}^{k}P_{z,r}\\
	\text{s.t.} \quad
	&P_{zr} = \sum_{y \in \mathcal{G}}\sum_{t \in \mathcal{T}} \omega_{t} \Theta_{y,t,z,r}  \\
	& f \leq f^* + \delta \\
	&Ax = b
\end{aligned}
```

where, $\beta_{zr}$ is a random objective fucntion coefficient betwen $[0,100]$ for MGA iteration $k$. $\Theta_{y,t,z,r}$ is a generation of technology $y$ in zone $z$ in time period $t$ that belongs to a resource type $r$. We aggregate $\Theta_{y,t,z,r}$ into a new variable $P_{z,r}$ that represents total generation from technology type $r$ in a zone $z$. In the second constraint above, $\delta$ denote the increase in budget from the least-cost solution and $f$ represents the expression for the total system cost. The constraint $Ax = b$ represents all other constraints in the power system model. We then solve the formulation with minimization and maximization objective function to explore near optimal solution space.
"""
function mga(EP::Model, path::AbstractString, setup::Dict, inputs::Dict, outpath::AbstractString)

    if setup["ModelingToGenerateAlternatives"]==1
        # Start MGA Algorithm
	    println("MGA Module")

	    # Objective function value of the least cost problem
	    Least_System_Cost = objective_value(EP)

	    # Read sets
	    dfGen = inputs["dfGen"]
	    T = inputs["T"]     # Number of time steps (hours)
	    Z = inputs["Z"]     # Number of zonests
	    G = inputs["G"]

	    # Create a set of unique technology types
	    TechTypes = unique(dfGen[dfGen[!, :MGA] .== 1, :Resource_Type])

	    # Read slack parameter representing desired increase in budget from the least cost solution
	    slack = setup["ModelingtoGenerateAlternativeSlack"]

	    ### Variables ###

	    @variable(EP, vSumvP[TechTypes = 1:length(TechTypes), z = 1:Z] >= 0) # Variable denoting total generation from eligible technology of a given type

	    ### End Variables ###

	    ### Constraints ###

	    # Constraint to set budget for MGA iterations
	    @constraint(EP, budget, EP[:eObj] <= Least_System_Cost * (1 + slack) )

        # Constraint to compute total generation in each zone from a given Technology Type
	    @constraint(EP,cGeneration[tt = 1:length(TechTypes), z = 1:Z], vSumvP[tt,z] == sum(EP[:vP][y,t] * inputs["omega"][t]
	    for y in dfGen[(dfGen[!,:Resource_Type] .== TechTypes[tt]) .& (dfGen[!,:Zone] .== z), :R_ID], t in 1:T))

	    ### End Constraints ###

	    ### Create Results Directory for MGA iterations
        outpath_max = joinpath(path, "MGAResults_max")
	    if !(isdir(outpath_max))
	    	mkdir(outpath_max)
	    end
        outpath_min = joinpath(path, "MGAResults_min")
	    if !(isdir(outpath_min))
	    	mkdir(outpath_min)
	    end

	    ### Begin MGA iterations for maximization and minimization objective ###
	    mga_start_time = time()

	    print("Starting the first MGA iteration")

	    for i in 1:setup["ModelingToGenerateAlternativeIterations"]

	    	# Create random coefficients for the generators that we want to include in the MGA run for the given budget
	    	pRand = rand(length(unique(dfGen[dfGen[!, :MGA] .== 1, :Resource_Type])),length(unique(dfGen[!,:Zone])))

	    	### Maximization objective
	    	@objective(EP, Max, sum(pRand[tt,z] * vSumvP[tt,z] for tt in 1:length(TechTypes), z in 1:Z ))

	    	# Solve Model Iteration
	    	status = optimize!(EP)

            # Create path for saving MGA iterations
	    	mgaoutpath_max = joinpath(outpath_max, string("MGA", "_", slack,"_", i))

	    	# Write results
	    	write_outputs(EP, mgaoutpath_max, setup, inputs)

	    	### Minimization objective
	    	@objective(EP, Min, sum(pRand[tt,z] * vSumvP[tt,z] for tt in 1:length(TechTypes), z in 1:Z ))

	    	# Solve Model Iteration
	    	status = optimize!(EP)

            # Create path for saving MGA iterations
	    	mgaoutpath_min = joinpath(outpath_min, string("MGA", "_", slack,"_", i))

	    	# Write results
	    	write_outputs(EP, mgaoutpath_min, setup, inputs)

	    end

	    total_time = time() - mga_start_time
	    ### End MGA Iterations ###
	end

end
