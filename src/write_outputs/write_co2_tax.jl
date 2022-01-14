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
	write_co2_tax(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for reporting carbon tax.

"""
function write_co2_tax(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    dfGen = inputs["dfGen"]
    G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones
    L = inputs["L"]     # Number of transmission lines
    W = inputs["REP_PERIOD"]     # Number of subperiods
    SEG = inputs["SEG"] # Number of load curtailment segments

    dfCO2TaxCost = DataFrame(Resource = inputs["RESOURCES"], AnnualSum = zeros(G))
    for g = 1:G
        temp_z = dfGen[g, :Zone]
        if setup["ParameterScale"] == 1
            dfCO2TaxCost[g, :AnnualSum] = sum(inputs["omega"] .* (value.(EP[:eEmissionsByPlant])[g, :])) * inputs["dfCO2Tax"][temp_z] * ModelScalingFactor * ModelScalingFactor
        else
            dfCO2TaxCost[g, :AnnualSum] = sum(inputs["omega"] .* (value.(EP[:eEmissionsByPlant])[g, :])) * inputs["dfCO2Tax"][temp_z]
        end
    end
    CSV.write(string(path, sep, "CO2Cost_tax.csv"), dfCO2TaxCost, writeheader = false)
    return dfCO2TaxCost
end