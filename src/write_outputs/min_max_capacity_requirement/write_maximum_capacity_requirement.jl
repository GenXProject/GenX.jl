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

function write_maximum_capacity_requirement(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    NumberOfMaxCapReqs = inputs["NumberOfMaxCapReqs"]
    dfMaxCapPrice = DataFrame(Constraint = [Symbol("MaxCapReq_$maxcap") for maxcap = 1:NumberOfMaxCapReqs],
                                Price= dual.(EP[:cZoneMaxCapReq]))
    if setup["ParameterScale"] == 1
        dfMaxCapPrice.Price *= ModelScalingFactor # Convert Million $/GW to $/MW
    end
    if haskey(inputs, "MaxCapPriceCap")
		dfMaxCapPrice[!,:Slack] = convert(Array{Float64}, value.(EP[:vMaxCap_slack]))
		dfMaxCapPrice[!,:Penalty] = convert(Array{Float64}, value.(EP[:eCMaxCap_slack]))
		if setup["ParameterScale"] == 1
            dfMaxCapPrice.Slack *= ModelScalingFactor # Convert GW to MW
            dfMaxCapPrice.Penalty *= ModelScalingFactor^2 # Convert Million $ to $
		end
	end
    CSV.write(joinpath(path, "MaxCapReq_prices_and_penalties.csv"), dfMaxCapPrice)
end