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
	write_co2_generation_emission_rate_cap_price_revenue(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for reporting carbon price of generation emission rate carbon cap.

"""
function write_co2_generation_emission_rate_cap_price_revenue(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    dfGen = inputs["dfGen"]
    G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones
    THERM_ALL = inputs["THERM_ALL"]
    VRE = inputs["VRE"]
    HYDRO_RES = inputs["HYDRO_RES"]
    STOR_ALL = inputs["STOR_ALL"]
    FLEX = inputs["FLEX"]
    MUST_RUN = inputs["MUST_RUN"]
    POWERGEN = union(THERM_ALL, HYDRO_RES, VRE, MUST_RUN)

    dfCO2GenRatePrice = DataFrame(CO2_GenRate_Constraint = [Symbol("CO2_GenRate_Cap_$cap") for cap = 1:inputs["NCO2GenRateCap"]],
                        CO2_GenRate_Price = (-1) * (dual.(EP[:cCO2Emissions_genrate])),
                        CO2_GenRate_Slack = value.(EP[:vCO2Emissions_genrate_slack]),
                        CO2_GenRate_Penalty = value.(EP[:eCCO2Emissions_genrate_slack]))
    if setup["ParameterScale"] == 1
        dfCO2GenRatePrice.CO2_GenRate_Price .*= ModelScalingFactor
        dfCO2GenRatePrice.CO2_GenRate_Slack .*= ModelScalingFactor
        dfCO2GenRatePrice.CO2_GenRate_Penalty .*= ModelScalingFactor^2
    end
    CSV.write(joinpath(path, "CO2Price_n_penalty_genrate.csv"), dfCO2GenRatePrice)

    temp_totalpowerMWh = zeros(G)
    # in GenRate Cap constraint, generation is defined as the generation from the four types of resources
    temp_totalpowerMWh[POWERGEN] .= value.(EP[:vP][POWERGEN, :]) * inputs["omega"] 
    dfCO2GenRateCapCost = DataFrame(Resource = inputs["RESOURCES"], AnnualSum = zeros(G))
    for cap = 1:inputs["NCO2GenRateCap"]
        temp_CO2GenRateCapCost = zeros(G)
        GEN_UNDERCAP = intersect(findall(x -> x == 1, (inputs["dfCO2Cap_GenRate"][dfGen[:, :Zone], Symbol("CO_2_Cap_Zone_$cap")])), POWERGEN)
        temp_CO2GenRateCapCost[GEN_UNDERCAP] = (-1) * (dual.(EP[:cCO2Emissions_genrate])[cap]) * (value.(EP[:eEmissionsByPlantYear][GEN_UNDERCAP]) - temp_totalpowerMWh[GEN_UNDERCAP] .* inputs["dfCO2Cap_GenRate"][dfGen[GEN_UNDERCAP, :Zone], Symbol("CO_2_Max_GenRate_$cap")])
        if setup["ParameterScale"] == 1
            temp_CO2GenRateCapCost *= (ModelScalingFactor^2)
        end
        dfCO2GenRateCapCost.AnnualSum .+= temp_CO2GenRateCapCost
        dfCO2GenRateCapCost = hcat(dfCO2GenRateCapCost, DataFrame([temp_CO2GenRateCapCost], [Symbol("CO2_GenRateCap_Cost_$cap")]))
    end
    CSV.write(joinpath(path, "CO2Cost_genrate.csv"), dfCO2GenRateCapCost)

    return dfCO2GenRatePrice, dfCO2GenRateCapCost
end