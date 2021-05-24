@doc raw"""
	minimum_capacity_requirement(EP::Model, inputs::Dict)

The minimum capacity requirement constraint allows for modeling minimum deployment of a certain technology or set of eligible technologies across the eligible model zones and can be used to mimic policies supporting specific technology build out (i.e. capacity deployment targets/mandates for storage, offshore wind, solar etc.). The default unit of the constraint is in MW. For each requirement $p \in \mathcal{P}^{MinCapReq}$, we model the policy with the following constraint.
```math
\begin{aligned}
\sum_{y \in \mathcal{G} } \sum_{z \in \mathcal{Z} } \left( \epsilon_{y,z,p}^{MinCapReq} \times \Delta^{\text{total}}_{y,z} \right) \geq REQ_{p}^{MinCapReq} \hspace{1 cm}  \forall p \in \mathcal{P}^{MinCapReq}
\end{aligned}
 ```
Note that $\epsilon_{y,z,p}^{MinCapReq}$ is the eligiblity of a generator of technology $y$ in zone $z$ of requirement $p$ and will be equal to $1$ for eligible generators and will be zero for ineligible resources. The dual value of each minimum capacity constraint can be interpreted as the required payment (e.g. subsidy) per MW per year required to ensure adequate revenue for the qualifying resources.
"""
function minimum_capacity_requirement(EP::Model, inputs::Dict)

	println("Minimum Capacity Requirement Module")

	dfGen = inputs["dfGen"]
	NumberOfMinCapReqs = inputs["NumberOfMinCapReqs"]
	@constraint(EP, cZoneMinCapReq[mincap = 1:NumberOfMinCapReqs],
	sum(EP[:eTotalCap][y]
	for y in dfGen[(dfGen[!,Symbol("MinCapTag_$mincap")].== 1) ,:][!,:R_ID])
	>= inputs["MinCapReq"][mincap])

	return EP
end
