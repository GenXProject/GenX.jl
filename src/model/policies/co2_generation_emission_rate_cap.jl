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

**Generator-side emissions rate-based constraint**

Similarly, a generation based emission constraint is defined by setting the emission limit based on the total generation times the carbon emission rate limit in tCO$_2$/MWh of the region. The resulting constraint is given as:

```math
\begin{aligned}
\sum_{z \in \mathcal{Z}^{CO_2}_{p,gen}} \sum_{y \in \mathcal{G}} \sum_{t \in \mathcal{T}} & \left(\epsilon_{y,z}^{CO_2} \times \omega_{t} \times \Theta_{y,t,z} \right) \\
    \leq \sum_{z \in \mathcal{Z}^{CO_2}_{p,gen}} \sum_{y \in \mathcal{G}} \sum_{t \in \mathcal{T}} & \left(\epsilon_{z,p,gen}^{CO_2} \times  \omega_{t} \times \Theta_{y,t,z} \right)  \hspace{1 cm}  \forall p \in \mathcal{P}^{CO_2}_{gen}
\end{aligned}
```

Note that the generator-side rate-based constraint can be used to represent a fee-rebate (``feebate'') system: the dirty generators that emit above the bar ($\epsilon_{z,p,gen}^{maxCO_2}$) have to buy emission allowances from the emission regulator in the region $z$ where they are located; in the same vein, the clean generators get rebates from the emission regulator at an emission allowance price being the dual variable of the emissions rate constraint.
"""
function co2_generation_side_emission_rate_cap!(EP::Model, inputs::Dict, setup::Dict)

    println("C02 Policies Module - Generation-side Emission rate cap")

    dfGen = inputs["dfGen"]
    SEG = inputs["SEG"]  # Number of lines
    G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones
    VRE = inputs["VRE"]
    HYDRO_RES = inputs["HYDRO_RES"]
    MUST_RUN = inputs["MUST_RUN"]
    THERM_ALL = inputs["THERM_ALL"]
    ### Expressions ###
    @expression(EP, eGenerationByZone[z=1:Z, t=1:T], 0)

	##CO2 Polcy Module Thermal Generation by zone
    if !isempty(THERM_ALL)
        @expression(EP, eGenerationByThermAll[z=1:Z, t=1:T], # the unit is GW
            sum(EP[:vP][y,t] for y in intersect(THERM_ALL, dfGen[dfGen[!,:Zone].==z,:R_ID]))
        )
        EP[:eGenerationByZone] += eGenerationByThermAll
    end
	##CO2 Polcy Module Hydro Res Generation by zone
    if !isempty(HYDRO_RES)
        @expression(EP, eGenerationByHydroRes[z=1:Z, t=1:T], # the unit is GW
            sum(EP[:vP][y,t] for y in intersect(HYDRO_RES, dfGen[dfGen[!,:Zone].==z,:R_ID]))
        )
        EP[:eGenerationByZone] += eGenerationByHydroRes
    end
    ##CO2 Polcy Module VRE Generation by zone
    if !isempty(VRE)
        @expression(EP, eGenerationByVRE[z=1:Z, t=1:T], # the unit is GW
            sum(EP[:vP][y,t] for y in intersect(VRE, dfGen[dfGen[!,:Zone].==z,:R_ID]))
        )
        EP[:eGenerationByZone] += eGenerationByVRE
    end
	##CO2 Polcy Module Must Run Generation by zone
    if !isempty(MUST_RUN)
        @expression(EP, eGenerationByMustRun[z=1:Z, t=1:T], # the unit is GW
            sum(EP[:vP][y,t] for y in intersect(MUST_RUN, dfGen[dfGen[!,:Zone].==z, :R_ID]))
        )
        EP[:eGenerationByZone] += eGenerationByMustRun
    end
    ### Constraints ###

    ## Generation + Rate-based: Emissions constraint in terms of rate (tons/MWh)
    @constraint(EP, cCO2Emissions_genrate[cap = 1:inputs["NCO2GenRateCap"]],
        sum(EP[:eEmissionsByZoneYear][z] for z in findall(x -> x == 1, inputs["dfCO2GenRateCapZones"][:, cap])) <=
        sum(inputs["dfMaxCO2GenRate"][z, cap] * inputs["omega"][t] * EP[:eGenerationByZone][z, t] for t = 1:T, z in findall(x -> x == 1, inputs["dfCO2GenRateCapZones"][:, cap]))
    )

end
