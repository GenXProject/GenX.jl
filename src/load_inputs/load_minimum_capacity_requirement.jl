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
    load_minimum_capacity_requirement!(path::AbstractString, inputs::Dict, setup::Dict)

Read input parameters related to mimimum capacity requirement constraints (e.g. technology specific deployment mandates)
"""
function load_minimum_capacity_requirement!(path::AbstractString, inputs::Dict, setup::Dict)
    filename = "Minimum_capacity_requirement.csv"
    df = load_dataframe(joinpath(path, filename))
    NumberOfMinCapReqs = length(df[!,:MinCapReqConstraint])
    inputs["NumberOfMinCapReqs"] = NumberOfMinCapReqs
    inputs["MinCapReq"] = df[!,:Min_MW]
    if setup["ParameterScale"] == 1
        inputs["MinCapReq"] /= ModelScalingFactor # Convert to GW
    end
    println(filename * " Successfully Read!")
end
