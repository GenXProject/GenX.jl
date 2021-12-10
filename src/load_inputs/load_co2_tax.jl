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
	load_co2_tax(setup::Dict, path::AbstractString, sep::AbstractString, inputs_co2_tax::Dict)

Function for reading input parameters related to CO$_2$ emissions cap constraints
"""
function load_co2_tax(setup::Dict, path::AbstractString, sep::AbstractString, inputs_co2_tax::Dict)
	# Definition of CO2 Tax requirements by zone (as Max Mtons)
	#inputs_co2_tax["dfCO2Cap"] = CSV.read(string(path,sep,"CO2_cap.csv"), header=true)
	inputs_co2_tax["dfCO2Tax"] = DataFrame(CSV.File(string(path, sep,"CO2_tax.csv"), header=true), copycols=true)


	inputs_co2_tax["dfCO2Tax"][!,:CO2Tax] = convert(Array{Float64}, inputs_co2_tax["dfCO2Tax"][!,:CO2Tax])


	# scale parameters if ModelScalingFactor is applied 
	# convert the unit from $/ton to $/kton
	if setup["ParameterScale"] == 1
		inputs_co2_tax["dfCO2Tax"][!,:CO2Tax] = inputs_co2_tax["dfCO2Tax"][!,:CO2Tax]/ModelScalingFactor

	else
		inputs_co2_tax["dfCO2Tax"][!,:CO2Tax] = inputs_co2_tax["dfCO2Tax"][!,:CO2Tax]

	end



	println("CO2_tax.csv Successfully Read!")
	return inputs_co2_tax
end
