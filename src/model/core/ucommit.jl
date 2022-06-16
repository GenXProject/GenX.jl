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
	ucommit(EP::Model, inputs::Dict, setup::Dict)

This function creates decision variables and cost expressions associated with thermal plant unit commitment or start-up and shut-down decisions (cycling on/off)

**Unit commitment decision variables:**

This function defines the following decision variables:

$\nu_{y,t,z}$ designates the commitment state of generator cluster $y$ in zone $z$ at time $t$;
$\chi_{y,t,z}$ represents number of startup decisions in cluster $y$ in zone $z$ at time $t$;
$\zeta_{y,t,z}$ represents number of shutdown decisions in cluster $y$ in zone $z$ at time $t$.

**Cost expressions:**

The total cost of start-ups across all generators subject to unit commitment ($y \in UC$) and all time periods, t is expressed as:
```math
\begin{aligned}
	C^{start} = \sum_{y \in UC, t \in T} \omega_t \times start\_cost_{y} \times \chi_{y,t}
\end{aligned}
```

The sum of start-up costs is added to the objective function.
"""
function ucommit!(EP::Model, inputs::Dict, setup::Dict)

	println("Unit Commitment Module")

	dfGen = inputs["dfGen"]

	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
	Z = inputs["Z"]     # Number of zones
	COMMIT = inputs["COMMIT"] # For not, thermal resources are the only ones eligible for Unit Committment

	### Variables ###

	## Decision variables for unit commitment
	# commitment state variable
	@variable(EP, vCOMMIT[y in COMMIT, t=1:T] >= 0)
	# startup event variable
	@variable(EP, vSTART[y in COMMIT, t=1:T] >= 0)
	# shutdown event variable
	@variable(EP, vSHUT[y in COMMIT, t=1:T] >= 0)

	### Expressions ###

	## Objective Function Expressions ##

    # Startup costs of "generation" for resource "y" during hour "t"
	# Fixed cost per start-up if unit commitment is modelled
    @expression(EP, eCStart[y in COMMIT, t = 1:T], 
		(dfGen[y, :Start_Cost_per_MW] * vSTART[y, t]))

    # Julia is fastest when summing over one row one column at a time
    # Sum to plant level
    @expression(EP, ePlantCStart[y in COMMIT], 
		sum(inputs["omega"][t] * eCStart[y, t] for t in 1:T))
    # Sum to zonal level
    @expression(EP, eZonalCStart[z = 1:Z], 
		(EP[:vZERO] + sum(ePlantCStart[y] 
			for y in intersect(COMMIT, dfGen[(dfGen[!, :Zone].==z), :R_ID]))))
    # Sum to system level
    @expression(EP, eTotalCStart, sum(eZonalCStart[z] for z = 1:Z))

	add_to_expression!(EP[:eObj], EP[:eTotalCStart])

	### Constratints ###
	## Declaration of integer/binary variables
	if setup["UCommit"] == 1 # Integer UC constraints
		for y in COMMIT
			set_integer.(vCOMMIT[y,:])
			set_integer.(vSTART[y,:])
			set_integer.(vSHUT[y,:])
			if y in inputs["RET_CAP"]
				set_integer(EP[:vRETCAP][y])
			end
			if y in inputs["NEW_CAP"]
				set_integer(EP[:vCAP][y])
			end
		end
	end #END unit commitment configuration
	return EP
end
