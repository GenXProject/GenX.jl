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
	load_energy_share_requirement(setup::Dict, path::AbstractString, inputs_ESR::Dict)

Function for reading input parameters related to mimimum energy share requirement constraints (e.g. renewable portfolio standard or clean electricity standard policies)
"""
function load_energy_share_requirement(setup::Dict, path::AbstractString, inputs_ESR::Dict)
	# Define the alternative compliance penalty of energy share requirement, aka the price cap.
	inputs_ESR["dfESR_slack"] = DataFrame(CSV.File(joinpath(path,"Energy_share_requirement_slack.csv"), header=true), copycols=true)
	if setup["ParameterScale"] == 1
		inputs_ESR["dfESR_slack"][!,:PriceCap] ./= ModelScalingFactor
	end
	# Determine the number of ESR constraints
	inputs_ESR["nESR"] = size(collect(skipmissing(inputs_ESR["dfESR_slack"][!,:ESR_Constraint])),1)
	# Definition of ESR requirements by zone (as % of load)
	# e.g. any policy requiring a min share of qualifying resources (Renewable Portfolio Standards / Renewable Energy Obligations / Clean Energy Standards etc.)
	inputs_ESR["dfESR"] = DataFrame(CSV.File(joinpath(path,"Energy_share_requirement.csv"), header=true), copycols=true)
	println("Energy_share_requirement.csv Successfully Read!")
	return inputs_ESR
end
