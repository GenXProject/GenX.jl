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
	co2_cap(EP::Model, inputs::Dict, setup::Dict)

This policy constraints mimics the CO$_2$ emissions cap and permit trading systems, allowing for emissions trading across each zone for which the cap applies. The constraint $p \in \mathcal{P}^{CO_2}$ can be flexibly defined for mass-based or rate-based emission limits for one or more model zones, where zones can trade CO$_2$ emissions permits and earn revenue based on their CO$_2$ allowance. Note that if the model is fully linear (e.g. no unit commitment or linearized unit commitment), the dual variable of the emissions constraints can be interpreted as the marginal CO$_2$ price per tonne associated with the emissions target. Alternatively, for integer model formulations, the marginal CO$_2$ price can be obtained after solving the model with fixed integer/binary variables.

The CO$_2$ emissions limit can be defined in one of the following ways: a) a mass-based limit defined in terms of annual CO$_2$ emissions budget (in million tonnes of CO2), b) a load-side rate-based limit defined in terms of tonnes CO$_2$ per MWh of demand and c) a generation-side rate-based limit defined in terms of tonnes CO$_2$ per MWh of generation.

**Load-side rate-based emissions constraint**

We modify the right hand side of the above mass-based constraint, $p \in \mathcal{P}^{CO_2}_{load}$, to set emissions target based on a CO$_2$ emission rate limit in tCO$_2$/MWh $\times$ the total demand served in each zone. In the following constraint, total demand served takes into account non-served energy and storage related losses. Here, $\epsilon_{z,p,load}^{maxCO_2}$ denotes the emission limit in terms on tCO$_2$/MWh.

```math
\begin{aligned}
    \sum_{z \in \mathcal{Z}^{CO_2}_{p,load}} \sum_{y \in \mathcal{G}} \sum_{t \in \mathcal{T}} \left(\epsilon_{y,z}^{CO_2} \times \omega_{t} \times \Theta_{y,t,z} \right)
    \leq & \sum_{z \in \mathcal{Z}^{CO_2}_{p,load}} \sum_{t \in \mathcal{T}}  \left(\epsilon_{z,p,load}^{CO_2} \times  \omega_{t} \times D_{z,t} \right) \\  + & \sum_{z \in \mathcal{Z}^{CO_2}_{p,load}} \sum_{y \in \mathcal{O}}  \sum_{t \in \mathcal{T}} \left(\epsilon_{z,p,load}^{CO_2} \times \omega_{t} \times \left(\Pi_{y,t,z} - \Theta_{y,t,z} \right) \right) \\  - & \sum_{z \in \mathcal{Z}^{CO_2}_{p,load}} \sum_{s \in \mathcal{S} } \sum_{t \in \mathcal{T}}  \left(\epsilon_{z,p,load}^{CO_2} \times \omega_{t} \times \Lambda_{s,z,t}\right) \hspace{1 cm}  \forall p \in \mathcal{P}^{CO_2}_{load}
\end{aligned}
```


Note that the generator-side rate-based constraint can be used to represent a fee-rebate (``feebate'') system: the dirty generators that emit above the bar ($\epsilon_{z,p,gen}^{maxCO_2}$) have to buy emission allowances from the emission regulator in the region $z$ where they are located; in the same vein, the clean generators get rebates from the emission regulator at an emission allowance price being the dual variable of the emissions rate constraint.
"""
function co2_load_side_emission_rate_cap!(EP::Model, inputs::Dict, setup::Dict)

    println("C02 Policies Module - Load-side Emission rate cap")

    dfGen = inputs["dfGen"]
    SEG = inputs["SEG"]  # Number of lines
    G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones
    STOR_ALL = inputs["STOR_ALL"]
    ### Variable ###
    @variable(EP, vCO2Emissions_loadrate_slack[cap=1:inputs["NCO2LoadRateCap"]] >=0)

    ### Expressions ###
    @expression(EP, cCCO2Emissions_loadrate_slack[cap=1:inputs["NCO2LoadRateCap"]], inputs["dfCO2Cap_LoadRate_slack"][cap, :PriceCap] * EP[:vCO2Emissions_loadrate_slack][cap])
    @expression(EP, cCTotalCO2Emissions_loadrate_slack, sum(cCCO2Emissions_loadrate_slack[cap] for cap = 1:inputs["NCO2LoadRateCap"]))
    add_to_expression!(EP[:eObj], EP[:cCTotalCO2Emissions_loadrate_slack])

    @expression(EP, eCO2Emissions_loadrate_LHS[cap=1:inputs["NCO2LoadRateCap"]], 
                sum(EP[:eEmissionsByZoneYear][z] for z in findall(x -> x == 1, inputs["dfCO2Cap_LoadRate"][:, Symbol("CO_2_Cap_Zone_$cap")])))
    @expression(EP, eCO2Emissions_loadrate_RHS[cap=1:inputs["NCO2LoadRateCap"]], 
                sum(inputs["dfCO2Cap_LoadRate"][z, Symbol("CO_2_Max_LoadRate_$cap")] * sum(inputs["omega"][t] * (inputs["pD"][t, z] - EP[:eZonalNSE][t, z]) for t = 1:T) for z in findall(x -> x == 1, inputs["dfCO2Cap_LoadRate"][:, Symbol("CO_2_Cap_Zone_$cap")])))
    
    if !isempty(STOR_ALL)
        # The default without the key is "StorageLosses" not to include storage loss in the policy
        if (setup["StorageLosses"] == 1)
            @expression(EP, eCO2Emissions_loadrate_RHS_STORLOSS[cap=1:inputs["NCO2LoadRateCap"]], sum(inputs["dfCO2Cap_LoadRate"][z, Symbol("CO_2_Max_LoadRate_$cap")] * EP[:eStorageLossByZone][z] for z in findall(x -> x == 1, inputs["dfCO2Cap_LoadRate"][:, Symbol("CO_2_Cap_Zone_$cap")])))
            add_to_expression!.(EP[:eCO2Emissions_loadrate_RHS], EP[:eCO2Emissions_loadrate_RHS_STORLOSS])
        end
    end
      
    if Z > 1
        # The default without the key "PolicyTransmissionLossCoverage" is not to include transmission loss in the policy
        if (setup["PolicyTransmissionLossCoverage"] == 1)
            @expression(EP, eCO2Emissions_loadrate_RHS_TLOSS[cap=1:inputs["NCO2LoadRateCap"]], sum(inputs["dfCO2Cap_LoadRate"][z, Symbol("CO_2_Max_LoadRate_$cap")] * (1/2) * EP[:eTransLossByZoneYear][z] for z in findall(x -> x == 1, inputs["dfCO2Cap_LoadRate"][:, Symbol("CO_2_Cap_Zone_$cap")])))
            add_to_expression!.(EP[:eCO2Emissions_loadrate_RHS], EP[:eCO2Emissions_loadrate_RHS_TLOSS])
        end
    end

    ### Constraints ###
    @constraint(EP, cCO2Emissions_loadrate[cap=1:inputs["NCO2LoadRateCap"]], EP[:eCO2Emissions_loadrate_LHS][cap] <= EP[:eCO2Emissions_loadrate_RHS][cap] + EP[:vCO2Emissions_loadrate_slack][cap])

end
