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
	load_co2_cap(setup::Dict, path::AbstractString, inputs_co2::Dict)

Function for reading input parameters related to CO$_2$ emissions cap constraints
"""
function load_co2_cap(setup::Dict, path::AbstractString, inputs_co2::Dict)
    inputs_co2["dfCO2Cap_slack"] = DataFrame(CSV.File(joinpath(path,"CO2_cap_slack.csv"), header=true), copycols=true)
    if setup["ParameterScale"] == 1
		inputs_co2["dfCO2Cap_slack"][!,:PriceCap] ./= ModelScalingFactor #from $/ton to million$/kton.
	end
	# Determine the number of ESR constraints
	inputs_co2["NCO2Cap"] = size(collect(skipmissing(inputs_co2["dfCO2Cap_slack"][!,:CO2_Mass_Constraint])),1)
	# Definition of Cap requirements by zone (as Max Mtons)
	inputs_co2["dfCO2Cap"] = DataFrame(CSV.File(joinpath(path,"CO2_cap.csv"), header=true), copycols=true)
    
    if setup["ParameterScale"] == 1
        inputs_co2["dfCO2Cap"][:, [Symbol("CO_2_Max_Mtons_$cap") for cap = 1:inputs_co2["NCO2Cap"]]] .*= ((1e6) / ModelScalingFactor)
    else
        inputs_co2["dfCO2Cap"][:, [Symbol("CO_2_Max_Mtons_$cap") for cap = 1:inputs_co2["NCO2Cap"]]] .*= (1e6)
    end
    println("CO2_cap.csv Successfully Read!")
    return inputs_co2
end
