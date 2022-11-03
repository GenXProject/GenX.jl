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
	co2_cap!(EP::Model, inputs::Dict, setup::Dict)

This policy constraints mimic the CO$_2$ emissions cap and permit trading systems, and allow emissions trading across each zone for which the cap applies. 
Note that if the model is solved with dual solution (e.g. a linear programming with no unit commitment or with linearized unit commitment, or a mixed integer programming re-solved with integer variables fixed), the dual variable of the emissions constraints can be interpreted as the marginal CO$_2$ price per tonne associated with the emissions target. 
If carbon prices are available, participanting zones can trade CO$_2$ emissions permits and earn revenue based on their CO$_2$ allowance. 

Each CO$_2$ emissions limit can be defined in the following ways: 
a) a mass-based limit defined in terms of annual CO$_2$ emissions budget (in million tonnes of CO2). This constraint describes this option.
b) a load-side rate-based limit defined in terms of tonnes CO$_2$ per MWh of demand and 
c) a generation-side rate-based limit defined in terms of tonnes CO$_2$ per MWh of generation.

**Mass-based emissions constraint**

Mass-based emission limits are implemented in the following expression. For each constraint, $p \in \mathcal{P}^{CO_2}_{mass}$, we define a set of zones $z \in \mathcal{Z}^{CO_2}_{p,mass}$ that can trade CO$_2$ allowance. Input data for each constraint  $p \in \mathcal{P}^{CO_2}_{mass}$ requires the CO$_2$ allowance/ budget for each model zone, $\epsilon^{CO_{2}}_{z,p, mass}$, to be provided in terms of million metric tonnes. For every generator $y$, the parameter $\epsilon_{y,z}^{CO_2}$ reflects the specific $CO_2$ emission intensity in tCO$_2$/MWh associated with its operation.  The resulting constraint is given as:

```math
\begin{aligned}
    \sum_{z \in \mathcal{Z}^{CO_2}_{p,mass}} \sum_{y \in \mathcal{G}} \sum_{t \in \mathcal{T}} \left(\epsilon_{y,z}^{CO_2} \times \omega_{t} \times \Theta_{y,z,t} \right)
   & \leq \sum_{z \in \mathcal{Z}^{CO_2}_{p,mass}} \epsilon^{CO_{2}}_{z,p, mass} + \epsilon^{CO_{2}}_{p, mass, slack} \hspace{1 cm}  \forall p \in \mathcal{P}^{CO_2}_{mass}
\end{aligned}
```

In the above constraint, we include both power discharge and charge term for each resource to account for the potential for CO$_2$ emissions (or removal when considering negative emissions technologies) associated with each step. Note that if a limit is applied to each zone separately, then the set $\mathcal{Z}^{CO_2}_{p,mass}$ will contain only one zone with no possibility of trading. If a system-wide emission limit constraint is applied, then $\mathcal{Z}^{CO_2}_{p,mass}$ will be equivalent to a set of all zones.

"""
function co2_cap!(EP::Model, inputs::Dict, setup::Dict)

	println("C02 Policies Module")

	### Variable ###
	@variable(EP, vCO2Emissions_mass_slack[cap = 1:inputs["NCO2Cap"]] >=0)

	### Expression ###
	@expression(EP, eCCO2Emissions_mass_slack[cap = 1:inputs["NCO2Cap"]], 
		inputs["dfCO2Cap_slack"][cap,:PriceCap] * EP[:vCO2Emissions_mass_slack][cap])
	@expression(EP, eCTotalCO2Emissions_mass_slack, 
		sum(EP[:eCCO2Emissions_mass_slack][cap] for cap = 1:inputs["NCO2Cap"]))
	add_to_expression!(EP[:eObj], EP[:eCTotalCO2Emissions_mass_slack])

	### Constraints ###

    ## Mass-based: Emissions constraint in absolute emissions limit (tons)
    @constraint(EP, cCO2Emissions_mass[cap = 1:inputs["NCO2Cap"]],
        sum(EP[:eEmissionsByZoneYear][z] for z in findall(x -> x == 1, inputs["dfCO2Cap"][:, Symbol("CO_2_Cap_Zone_$cap")])) <=
        (sum(inputs["dfCO2Cap"][z, Symbol("CO_2_Max_Mtons_$cap")] for z in findall(x -> x == 1, inputs["dfCO2Cap"][:, Symbol("CO_2_Cap_Zone_$cap")])) + 
		EP[:vCO2Emissions_mass_slack][cap])
    )

end
