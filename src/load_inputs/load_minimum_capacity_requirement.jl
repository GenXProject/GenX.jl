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
	load_minimum_capacity_requirement(setup::Dict, path::AbstractString, inputs::Dict)

Function for reading input parameters related to mimimum capacity requirement constraints (e.g. technology specific deployment mandates)
"""
function load_minimum_capacity_requirement(setup::Dict, path::AbstractString, inputs::Dict)
	MinCapReq = DataFrame(CSV.File(joinpath(path, "Minimum_capacity_requirement.csv"), header=true), copycols=true)
	NumberOfMinCapReqs = size(collect(skipmissing(MinCapReq[!,:MinCapReqConstraint])),1)
	inputs["NumberOfMinCapReqs"] = NumberOfMinCapReqs
	inputs["MinCapReq"] = MinCapReq[!,:Min_MW]
	if setup["ParameterScale"] == 1
		inputs["MinCapReq"] = inputs["MinCapReq"]/ModelScalingFactor # Convert to GW
	end
	println("Minimum_capacity_requirement.csv Successfully Read!")
	return inputs
end
