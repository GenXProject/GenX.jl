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
	investment_energy(EP::Model, inputs::Dict)

This function defines the expressions and constraints keeping track of total available storage charge capacity across all resources as well as constraints on capacity retirements. The function also adds investment and fixed O\&M related costs related to charge capacity to the objective function.

The total capacity of each resource is defined as the sum of the existing capacity plus the newly invested capacity minus any retired capacity.

```math
\begin{aligned}
& \Delta^{total,energy}_{y,z} =(\overline{\Delta^{energy}_{y,z}}+\Omega^{energy}_{y,z}-\Delta^{energy}_{y,z}) \forall y \in \mathcal{O}, z \in \mathcal{Z}
\end{aligned}
```

One cannot retire more capacity than existing capacity.

```math
\begin{aligned}
&\Delta^{energy}_{y,z} \leq \overline{\Delta^{energy}_{y,z}}
		\hspace{4 cm}  \forall y \in \mathcal{O}, z \in \mathcal{Z}
\end{aligned}
```

For resources where $\overline{\Omega_{y,z}^{energy}}$ and $\underline{\Omega_{y,z}^{energy}}$ is defined, then we impose constraints on minimum and maximum power capacity.

```math
\begin{aligned}
& \Delta^{total,energy}_{y,z} \leq \overline{\Omega}^{energy}_{y,z}
	\hspace{4 cm}  \forall y \in \mathcal{O}, z \in \mathcal{Z} \\
& \Delta^{total,energy}_{y,z}  \geq \underline{\Omega}^{energy}_{y,z}
	\hspace{4 cm}  \forall y \in \mathcal{O}, z \in \mathcal{Z}
\end{aligned}
```

In addition, this function adds investment and fixed O\&M related costs related to charge capacity to the objective function:

```math
\begin{aligned}
& 	\sum_{y \in \mathcal{O} } \sum_{z \in \mathcal{Z}}
	\left( (\pi^{INVEST,energy}_{y,z} \times    \Omega^{energy}_{y,z})
	+ (\pi^{FOM,energy}_{y,z} \times  \Delta^{total,energy}_{y,z})\right)
\end{aligned}
```
"""
function investment_energy(EP::Model, inputs::Dict, MultiStage::Int)

	println("Storage Investment Module")

	dfGen = inputs["dfGen"]

	STOR_ALL = inputs["STOR_ALL"] # Set of all storage resources
	NEW_CAP_ENERGY = inputs["NEW_CAP_ENERGY"] # Set of all storage resources eligible for new energy capacity
	RET_CAP_ENERGY = inputs["RET_CAP_ENERGY"] # Set of all storage resources eligible for energy capacity retirements

	### Variables ###

	## Energy storage reservoir capacity (MWh capacity) built/retired for storage with variable power to energy ratio (STOR=1 or STOR=2)

	# New installed energy capacity of resource "y"
	@variable(EP, vCAPENERGY[y in NEW_CAP_ENERGY] >= 0)

	# Retired energy capacity of resource "y" from existing capacity
	@variable(EP, vRETCAPENERGY[y in RET_CAP_ENERGY] >= 0)

	if MultiStage == 1
		@variable(EP, vEXISTINGCAPENERGY[y in STOR_ALL] >= 0);
	end

	### Expressions ###

	if MultiStage == 1
		@expression(EP, eExistingCapEnergy[y in STOR_ALL], vEXISTINGCAPENERGY[y])
	else
		@expression(EP, eExistingCapEnergy[y in STOR_ALL], dfGen[!,:Existing_Cap_MWh][y])
	end

	@expression(EP, eTotalCapEnergy[y in STOR_ALL],
		if (y in intersect(NEW_CAP_ENERGY, RET_CAP_ENERGY))
			eExistingCapEnergy[y] + EP[:vCAPENERGY][y] - EP[:vRETCAPENERGY][y]
		elseif (y in setdiff(NEW_CAP_ENERGY, RET_CAP_ENERGY))
			eExistingCapEnergy[y] + EP[:vCAPENERGY][y]
		elseif (y in setdiff(RET_CAP_ENERGY, NEW_CAP_ENERGY))
			eExistingCapEnergy[y] - EP[:vRETCAPENERGY][y]
		else
			eExistingCapEnergy[y] + EP[:vZERO]
		end
	)

	## Objective Function Expressions ##

	# Fixed costs for resource "y" = annuitized investment cost plus fixed O&M costs
	# If resource is not eligible for new energy capacity, fixed costs are only O&M costs
	@expression(EP, eCFixEnergy[y in STOR_ALL],
		if y in NEW_CAP_ENERGY # Resources eligible for new capacity
			dfGen[!,:Inv_Cost_per_MWhyr][y]*vCAPENERGY[y] + dfGen[!,:Fixed_OM_Cost_per_MWhyr][y]*eTotalCapEnergy[y]
		else
			dfGen[!,:Fixed_OM_Cost_per_MWhyr][y]*eTotalCapEnergy[y]
		end
	)

	# Sum individual resource contributions to fixed costs to get total fixed costs
	@expression(EP, eTotalCFixEnergy, sum(EP[:eCFixEnergy][y] for y in STOR_ALL))

	# Add term to objective function expression
	if MultiStage == 1
		# OPEX multiplier scales fixed costs to account for multiple years between two model stages
		# We divide by OPEXMULT since we are going to multiply the entire objective function by this term later,
		# and we have already accounted for multiple years between stages for fixed costs.
		EP[:eObj] += (1/inputs["OPEXMULT"])*eTotalCFixEnergy
	else
		EP[:eObj] += eTotalCFixEnergy
	end

	### Constratints ###

	if MultiStage == 1
		@constraint(EP, cExistingCapEnergy[y in STOR_ALL], EP[:vEXISTINGCAPENERGY][y] == dfGen[!,:Existing_Cap_MWh][y])
	end
	
	## Constraints on retirements and capacity additions
	# Cannot retire more energy capacity than existing energy capacity
	@constraint(EP, cMaxRetEnergy[y in RET_CAP_ENERGY], vRETCAPENERGY[y] <= eExistingCapEnergy[y])

	## Constraints on new built energy capacity
	# Constraint on maximum energy capacity (if applicable) [set input to -1 if no constraint on maximum energy capacity]
	# DEV NOTE: This constraint may be violated in some cases where Existing_Cap_MWh is >= Max_Cap_MWh and lead to infeasabilty
	@constraint(EP, cMaxCapEnergy[y in intersect(dfGen[dfGen.Max_Cap_MWh.>0,:R_ID], STOR_ALL)], eTotalCapEnergy[y] <= dfGen[!,:Max_Cap_MWh][y])

	# Constraint on minimum energy capacity (if applicable) [set input to -1 if no constraint on minimum energy apacity]
	# DEV NOTE: This constraint may be violated in some cases where Existing_Cap_MWh is <= Min_Cap_MWh and lead to infeasabilty
	@constraint(EP, cMinCapEnergy[y in intersect(dfGen[dfGen.Min_Cap_MWh.>0,:R_ID], STOR_ALL)], eTotalCapEnergy[y] >= dfGen[!,:Min_Cap_MWh][y])

	return EP
end
