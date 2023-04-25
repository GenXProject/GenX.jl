@doc raw"""
	minimum_capacity_requirement!(EP::Model, inputs::Dict, setup::Dict)
The minimum capacity requirement constraint allows for modeling minimum deployment of a certain technology or set of eligible technologies across the eligible model zones and can be used to mimic policies supporting specific technology build out (i.e. capacity deployment targets/mandates for storage, offshore wind, solar etc.). The default unit of the constraint is in MW. For each requirement $p \in \mathcal{P}^{MinCapReq}$, we model the policy with the following constraint.
```math
\begin{aligned}
\sum_{y \in \mathcal{G} } \sum_{z \in \mathcal{Z} } \left( \epsilon_{y,z,p}^{MinCapReq} \times \Delta^{\text{total}}_{y,z} \right) \geq REQ_{p}^{MinCapReq} \hspace{1 cm}  \forall p \in \mathcal{P}^{MinCapReq}
\end{aligned}
```
Note that $\epsilon_{y,z,p}^{MinCapReq}$ is the eligiblity of a generator of technology $y$ in zone $z$ of requirement $p$ and will be equal to $1$ for eligible generators and will be zero for ineligible resources. The dual value of each minimum capacity constraint can be interpreted as the required payment (e.g. subsidy) per MW per year required to ensure adequate revenue for the qualifying resources.
"""
function minimum_capacity_requirement!(EP::Model, inputs::Dict, setup::Dict)

	println("Minimum Capacity Requirement Module")
	NumberOfMinCapReqs = inputs["NumberOfMinCapReqs"]

	@constraint(EP, cZoneMinCapReq[mincap = 1:NumberOfMinCapReqs], EP[:eMinCapRes][mincap] >= inputs["MinCapReq"][mincap])

	# if input files are present, add minimum capacity requirement slack variables
	if haskey(inputs, "MinCapPriceCap")
		@variable(EP, vMinCap_slack[mincap = 1:NumberOfMinCapReqs]>=0)
		EP[:eMinCapRes] += vMinCap_slack

		@expression(EP, eCMinCap_slack[mincap = 1:NumberOfMinCapReqs], inputs["MinCapPriceCap"][mincap] * EP[:vMinCap_slack][mincap])
		@expression(EP, eTotalCMinCapSlack, sum(EP[:eCMinCap_slack][mincap] for mincap = 1:NumberOfMinCapReqs))
		
		EP[:eObj] += eTotalCMinCapSlack
	end
end
