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
	energy_share_requirement(EP::Model, inputs::Dict, setup::Dict)

This function establishes constraints that can be flexibily applied to define alternative forms of policies that require generation of a minimum quantity of megawatt-hours from a set of qualifying resources, such as renewable portfolio standard (RPS) or clean electricity standard (CES) policies prevalent in different jurisdictions. These policies usually require that the annual MWh generation from a subset of qualifying generators has to be higher than a pre-specified percentage of load from qualifying zones.

The implementation allows for user to define one or multiple RPS/CES style minimum energy share constraints, where each constraint can cover different combination of model zones to mimic real-world policy implementation (e.g. multiple state policies, multiple RPS tiers or overlapping RPS and CES policies). The number of energy share requirement constraints is specified by the user by the value of the GenX settings parameter ```EnergyShareRequirement``` (this value should be an integer >=0). For each constraint $p \in \mathcal{P}^{ESR}$, we define a subset of zones $z \in \mathcal{Z}^{ESR}_{p} \subset \mathcal{Z}$ that are eligible for trading renewable/clean energy credits to meet the corresponding renewable/clean energy requirement.

For each energy share requirement constraint $p \in \mathcal{P}^{ESR}$, we specify the share of total demand in each eligible model zone, $z \in \mathcal{Z}^{ESR}_{p}$, that must be served by qualifying resources, $\mathcal{G}_{p}^{ESR} \subset \mathcal{G}$:

```math
\begin{aligned}
&\sum_{z \in \mathcal{Z}_{p}^{ESR}} \sum_{y \in \mathcal{G}_{p}^{ESR}} \sum_{t \in \mathcal{T}} (\omega_{t} \times  \Theta_{y,z,t}) \geq  \sum_{z \in \mathcal{Z}^{ESR}_{p}} \sum_{t \in \mathcal{T}} (\mu_{p,z}^{ESR} \times \omega_{t} \times D_{z,t}) + \\
&\sum_{y \in \mathcal{O}} \sum_{z \in \mathcal{Z}^{ESR}_{p}} \sum_{t \in \mathcal{T}} \left(\mu_{p,z}^{ESR} \times \omega_{t} \times (\Pi_{y,z,t} - \Theta_{y,z,t}) \right) \hspace{1 cm}  \forall p \in \mathcal{P}^{ESR} \\
\end{aligned}
```

The final term in the summation above adds roundtrip storage losses to the total load to which the energy share obligation applies. This term is included in the constraint if the GenX setup parameter ```StorageLosses=1```. If ```StorageLosses=0```, this term is removed from the constraint. In practice, most existing renewable portfolio standard policies do not account for storage losses when determining energy share requirements. However, with 100% RPS or CES policies enacted in several jurisdictions, policy makers may wish to include storage losses in the minimum energy share, as otherwise there will be a difference between total generation and total load that will permit continued use of non-qualifying resources (e.g. emitting generators).
"""
function energy_share_requirement(EP::Model, inputs::Dict, setup::Dict)

	println("Energy Share Requirement Policies Module")

	## Energy Share Requirements (minimum energy share from qualifying renewable resources) constraint
	@constraint(EP, cESRShare[ESR=1:inputs["nESR"]], EP[:eESR][ESR] >= 0)
	return EP
end
