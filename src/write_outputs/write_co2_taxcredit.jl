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
	write_credit_for_captured_emissions(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
"""
function write_credit_for_captured_emissions(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    dfGen = inputs["dfGen"]
    G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)

    dfCO2CaptureCredit = DataFrame(Resource = inputs["RESOURCES"], AnnualSum = zeros(G))
    dfCO2CaptureCredit.AnnualSum = value.(EP[:eEmissionsCaptureByPlantYear]) * (-1) .* inputs["dfCO2Credit"][dfGen[:, :Zone], "CO2Credit"]
    if setup["ParameterScale"] == 1
        dfCO2CaptureCredit.AnnualSum *= ModelScalingFactor^2
    end
    CSV.write(joinpath(path, "CO2Credit.csv"), dfCO2CaptureCredit)
    return dfCO2CaptureCredit
end
