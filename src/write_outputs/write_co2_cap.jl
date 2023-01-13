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
	write_co2_cap_price_revenue(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for reporting carbon price of mass-based carbon cap.

"""
function write_co2_cap_price_revenue(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    dfGen = inputs["dfGen"]
    G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones


    dfCO2Price = DataFrame(CO2_Mass_Constraint = [Symbol("CO2_Mass_Cap_$cap") for cap = 1:inputs["NCO2Cap"]],
                            CO2_Mass_Price = (-1) * (dual.(EP[:cCO2Emissions_mass])),
                            CO2_Mass_Slack = value.(EP[:vCO2Emissions_mass_slack]),
                            CO2_Mass_Penalty = value.(EP[:eCCO2Emissions_mass_slack]))
    if setup["ParameterScale"] == 1
        dfCO2Price.CO2_Mass_Price .*= ModelScalingFactor
        dfCO2Price.CO2_Mass_Slack .*= ModelScalingFactor
        dfCO2Price.CO2_Mass_Penalty .*= ModelScalingFactor^2
    end
    CSV.write(joinpath(path, "CO2Price_n_penalty_mass.csv"), dfCO2Price)

    dfCO2MassCapRev = DataFrame(Zone = 1:Z, AnnualSum = zeros(Z))
    temp_CO2MassCapRev = zeros(Z)
    for cap = 1:inputs["NCO2Cap"]
        temp_CO2MassCapRev = (-1) * (dual.(EP[:cCO2Emissions_mass])[cap]) * (inputs["dfCO2Cap"][:, Symbol("CO_2_Cap_Zone_$cap")]) .* (inputs["dfCO2Cap"][:, Symbol("CO_2_Max_Mtons_$cap")])
        if setup["ParameterScale"] == 1
            # when scaled, The dual variable function is in unit of Million US$/kton; 
            # The budget is in unit of kton, and thus the product is in Million US$. 
            # Multiply scaling factor twice to get back US$.
            temp_CO2MassCapRev *= (ModelScalingFactor^2)
        end
        dfCO2MassCapRev.AnnualSum .+= temp_CO2MassCapRev
        dfCO2MassCapRev = hcat(dfCO2MassCapRev, DataFrame([temp_CO2MassCapRev], [Symbol("CO2_MassCap_Revenue_$cap")]))
    end
    CSV.write(joinpath(path, "CO2Revenue_mass.csv"), dfCO2MassCapRev)

    dfCO2MassCapCost = DataFrame(Resource = inputs["RESOURCES"], AnnualSum = zeros(G))
    for cap = 1:inputs["NCO2Cap"]
        temp_CO2MassCapCost = zeros(G)
        GEN_UNDERCAP = findall(x -> x == 1, (inputs["dfCO2Cap"][dfGen[:, :Zone], Symbol("CO_2_Cap_Zone_$cap")]))
        temp_CO2MassCapCost[GEN_UNDERCAP] = (-1) * (dual.(EP[:cCO2Emissions_mass])[cap]) * (value.(EP[:eEmissionsByPlantYear][GEN_UNDERCAP]))
        if setup["ParameterScale"] == 1
            # when scaled, The dual variable function is in unit of Million US$/kton; 
            # The budget is in unit of kton, and thus the product is in Million US$. 
            # Multiply scaling factor twice to get back US$.
            temp_CO2MassCapCost *= (ModelScalingFactor^2)
        end
        dfCO2MassCapCost.AnnualSum .+= temp_CO2MassCapCost
        dfCO2MassCapCost = hcat(dfCO2MassCapCost, DataFrame([temp_CO2MassCapCost], [Symbol("CO2_MassCap_Cost_$cap")]))
    end
    CSV.write(joinpath(path, "CO2Cost_mass.csv"), dfCO2MassCapCost)

    return dfCO2Price, dfCO2MassCapRev, dfCO2MassCapCost
end