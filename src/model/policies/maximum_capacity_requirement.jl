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
	maximum_capacity_requirement!(EP::Model, inputs::Dict, setup::Dict)
The maximum capacity requirement constraint allows for modeling maximum deployment of a certain technology or set of eligible technologies across the eligible model zones and can be used to mimic policies supporting specific technology build out (i.e. capacity deployment targets/mandates for storage, offshore wind, solar etc.). The default unit of the constraint is in MW. For each requirement $p \in \mathcal{P}^{MaxCapReq}$, we model the policy with the following constraint.
```math
\begin{aligned}
\sum_{y \in \mathcal{G} } \sum_{z \in \mathcal{Z} } \left( \epsilon_{y,z,p}^{MaxCapReq} \times \Delta^{\text{total}}_{y,z} \right) \leq REQ_{p}^{MaxCapReq} \hspace{1 cm}  \forall p \in \mathcal{P}^{MaxCapReq}
\end{aligned}
```
Note that $\epsilon_{y,z,p}^{MaxCapReq}$ is the eligiblity of a generator of technology $y$ in zone $z$ of requirement $p$ and will be equal to $1$ for eligible generators and will be zero for ineligible resources. The dual value of each maximum capacity constraint can be interpreted as the required payment (e.g. subsidy) per MW per year required to ensure adequate revenue for the qualifying resources.
"""
function maximum_capacity_requirement!(EP::Model, inputs::Dict, setup::Dict)

	println("Maximum Capacity Requirement Module")
	NumberOfMaxCapReqs = inputs["NumberOfMaxCapReqs"]

	@constraint(EP, cZoneMaxCapReq[maxcap = 1:NumberOfMaxCapReqs], EP[:eMaxCapRes][maxcap] <= inputs["MaxCapReq"][maxcap])

	# if input files are present, add maximum capacity requirement slack variables
	if haskey(inputs, "MaxCapPriceCap")
		@variable(EP, vMaxCap_slack[maxcap = 1:NumberOfMaxCapReqs]>=0)
		EP[:eMaxCapRes] += vMaxCap_slack

		@expression(EP, eCMaxCap_slack[maxcap = 1:NumberOfMaxCapReqs], inputs["MaxCapPriceCap"][maxcap] * EP[:vMaxCap_slack][maxcap])
		@expression(EP, eTotalCMaxCapSlack, sum(EP[:eCMaxCap_slack][maxcap] for maxcap = 1:NumberOfMaxCapReqs))
		
		EP[:eObj] += eTotalCMaxCapSlack
	end
end
