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
	write_co2_generation_emission_rate_cap_price_revenue(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for reporting carbon price of generation emission rate carbon cap.

"""
function write_co2_generation_emission_rate_cap_price_revenue(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    dfGen = inputs["dfGen"]
    G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones
    # L = inputs["L"]     # Number of transmission lines
    # W = inputs["REP_PERIOD"]     # Number of subperiods
    # SEG = inputs["SEG"] # Number of load curtailment segments


    tempCO2Price = zeros(Z, inputs["NCO2GenRateCap"])
    for cap = 1:inputs["NCO2GenRateCap"]
        for z in findall(x -> x == 1, inputs["dfCO2GenRateCapZones"][:, cap])
            if setup["ParameterScale"] == 1
                tempCO2Price[z, cap] = (-1) * dual.(EP[:cCO2Emissions_genrate])[cap] * ModelScalingFactor
            else
                tempCO2Price[z, cap] = (-1) * dual.(EP[:cCO2Emissions_genrate])[cap]
            end
        end
    end
    dfCO2GenRatePrice = hcat(DataFrame(Zone = 1:Z), DataFrame(tempCO2Price))
    auxNew_Names = [Symbol("Zone"); [Symbol("CO2_GenRate_Price_$cap") for cap = 1:inputs["NCO2GenRateCap"]]]
    names!(dfCO2GenRatePrice, auxNew_Names)
    CSV.write(string(path, sep, "CO2Price_genrate.csv"), dfCO2GenRatePrice, writeheader = false)

    temp_totalpowerMWh = zeros(G) # in GenRate Cap constraint, generation is defined as the generation from the four types of resources
    for g = 1:G
        if g in (dfGen[(dfGen[!, :THERM].>=1).|(dfGen[!, :MUST_RUN].>=1).|(dfGen[!, :VRE].>=1).|(dfGen[!, :HYDRO].>=1), :R_ID])
            temp_totalpowerMWh[g] = sum(((transpose(value.(EP[:vP]))[:, g])) .* inputs["omega"])
        end
    end

    dfCO2GenRateCapCost = DataFrame(Resource = inputs["RESOURCES"], AnnualSum = zeros(G))
    for cap = 1:inputs["NCO2GenRateCap"]
        temp_CO2GenRateCapCost = DataFrame(A = zeros(G))
        for g = 1:G
            temp_z = dfGen[g, :Zone]
            if setup["ParameterScale"] == 1
                temp_CO2GenRateCapCost[g, :A] = (-1) * (dual.(EP[:cCO2Emissions_genrate])[cap]) * (inputs["dfCO2GenRateCapZones"][temp_z, cap]) * (sum(inputs["omega"] .* (value.(EP[:eEmissionsByPlant])[g, :])) - temp_totalpowerMWh[g] * inputs["dfMaxCO2GenRate"][temp_z, cap]) * ModelScalingFactor * ModelScalingFactor
            else
                temp_CO2GenRateCapCost[g, :A] = (-1) * (dual.(EP[:cCO2Emissions_genrate])[cap]) * (inputs["dfCO2GenRateCapZones"][temp_z, cap]) * (sum(inputs["omega"] .* (value.(EP[:eEmissionsByPlant])[g, :])) - temp_totalpowerMWh[g] * inputs["dfMaxCO2GenRate"][temp_z, cap])
            end
        end
        dfCO2GenRateCapCost = hcat(dfCO2GenRateCapCost, temp_CO2GenRateCapCost)
        rename!(dfCO2GenRateCapCost, Dict(:A => Symbol("CO2_GenRateCap_Cost_$cap")))
    end
    dfCO2GenRateCapCost.AnnualSum = sum(eachcol(dfCO2GenRateCapCost[:, 3:inputs["NCO2GenRateCap"]+2]))
    CSV.write(string(path, sep, "CO2Cost_genrate.csv"), dfCO2GenRateCapCost, writeheader = false)

    return dfCO2GenRatePrice, dfCO2GenRateCapCost
end