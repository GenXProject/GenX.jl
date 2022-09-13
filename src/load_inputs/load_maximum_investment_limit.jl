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
load_maximum_investment_limit(setup::Dict, path::AbstractString, inputs::Dict)

Function for reading input parameters related to max investment limit constraints
"""
function load_maximum_investment_limit(setup::Dict, path::AbstractString, inputs::Dict)
    MaxInvReq = DataFrame(CSV.File(joinpath(path, "Maximum_investment_limit.csv"), header = true), copycols = true)
    NumberOfMaxInvReq = size(collect(skipmissing(MaxInvReq[!, :MaxInvReqConstraint])), 1)
    inputs["NumberOfMaxInvReq"] = NumberOfMaxInvReq
    inputs["MaxInvReq"] = MaxInvReq[!, :Max_MW]
    inputs["MaxInvPriceCap"] = MaxInvReq[!, :PriceCap]
    if setup["ParameterScale"] == 1
        inputs["MaxInvReq"] /= ModelScalingFactor # Convert to GW
        inputs["MaxInvPriceCap"] /= ModelScalingFactor # Convert to $/MW-year to MillionUSD/GW-year
    end
    println("Maximum_investment_limit.csv Successfully Read!")
    return inputs
end
