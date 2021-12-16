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
	write_co2_cap_price_revenue(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for reporting carbon price of mass-based carbon cap.

"""
function write_co2_cap_price_revenue(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    dfGen = inputs["dfGen"]
    G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones
    # L = inputs["L"]     # Number of transmission lines
    # W = inputs["REP_PERIOD"]     # Number of subperiods
    # SEG = inputs["SEG"] # Number of load curtailment segments

    tempCO2Price = zeros(Z, inputs["NCO2Cap"])
    for cap = 1:inputs["NCO2Cap"]
        for z in findall(x -> x == 1, inputs["dfCO2CapZones"][:, cap])
            tempCO2Price[z, cap] = dual.(EP[:cCO2Emissions_mass])[cap]
            if setup["ParameterScale"] == 1
                # when scaled, The dual variable is in unit of Million US$/kton, thus k$/ton, to get $/ton, multiply 1000
                tempCO2Price[z, cap] = (-1) * tempCO2Price[z, cap] * ModelScalingFactor
            end
        end
    end
    dfCO2Price = hcat(DataFrame(Zone = 1:Z), DataFrame(tempCO2Price))
    auxNew_Names = [Symbol("Zone"); [Symbol("CO2_Price_$cap") for cap = 1:inputs["NCO2Cap"]]]
    names!(dfCO2Price, auxNew_Names)

    CSV.write(string(path, sep, "CO2Price_mass.csv"), dfCO2Price, writeheader = false)

    dfCO2MassCapRev = DataFrame(Zone = 1:Z, AnnualSum = zeros(Z))
    for cap = 1:inputs["NCO2Cap"]
        if setup["ParameterScale"] == 1
            # when scaled, The dual variable function is in unit of Million US$/kton; 
            # The budget is in unit of kton, and thus the product is in Million US$. 
            # Multiply scaling factor twice to get back US$.
            temp_CO2MassCapRev = DataFrame(A = (-1) * (dual.(EP[:cCO2Emissions_mass])[cap]) * (inputs["dfCO2CapZones"][:, cap]) .* (inputs["dfMaxCO2"][:, cap] * ModelScalingFactor * ModelScalingFactor))
        else
            temp_CO2MassCapRev = DataFrame(A = (-1) * (dual.(EP[:cCO2Emissions_mass])[cap]) * (inputs["dfCO2CapZones"][:, cap]) .* (inputs["dfMaxCO2"][:, cap]))
        end
        dfCO2MassCapRev = hcat(dfCO2MassCapRev, temp_CO2MassCapRev)
        rename!(dfCO2MassCapRev, Dict(:A => Symbol("CO2_MassCap_Revenue_$cap")))
    end
    dfCO2MassCapRev.AnnualSum = sum(eachcol(dfCO2MassCapRev[:, 3:inputs["NCO2Cap"]+2]))
    CSV.write(string(path, sep, "CO2Revenue_mass.csv"), dfCO2MassCapRev, writeheader = false)

    dfCO2MassCapCost = DataFrame(Resource = inputs["RESOURCES"], AnnualSum = Array{Union{Missing,Float32}}(undef, G))
    for cap = 1:inputs["NCO2Cap"]
        temp_CO2MassCapCost = DataFrame(A = zeros(G))
        for g = 1:G
            temp_z = dfGen[g, :Zone]
            # when scaled, The dual variable function is in unit of Million US$/kton; 
            # The emission is in unit of kton, and thus the product is in Million US$. 
            # Multiply scaling factor twice to get back US$.
            if setup["ParameterScale"] == 1
                temp_CO2MassCapCost[g, :A] = (-1) * (dual.(EP[:cCO2Emissions_mass])[cap]) * sum(inputs["omega"] .* (value.(EP[:eEmissionsByPlant])[g, :])) * inputs["dfCO2CapZones"][temp_z, cap] * ModelScalingFactor * ModelScalingFactor
            else
                temp_CO2MassCapCost[g, :A] = (-1) * (dual.(EP[:cCO2Emissions_mass])[cap]) * sum(inputs["omega"] .* (value.(EP[:eEmissionsByPlant])[g, :])) * inputs["dfCO2CapZones"][temp_z, cap]
            end

        end
        dfCO2MassCapCost = hcat(dfCO2MassCapCost, temp_CO2MassCapCost)
        rename!(dfCO2MassCapCost, Dict(:A => Symbol("CO2_MassCap_Cost_$cap")))
    end
    dfCO2MassCapCost.AnnualSum = sum(eachcol(dfCO2MassCapCost[:, 3:inputs["NCO2Cap"]+2]))
    CSV.write(string(path, sep, "CO2Cost_mass.csv"), dfCO2MassCapCost, writeheader = false)

    return dfCO2Price, dfCO2MassCapRev, dfCO2MassCapCost
end