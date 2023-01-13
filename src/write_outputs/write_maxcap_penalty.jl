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

function write_maxcap_penalty(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    NumberOfMaxCapReqs = inputs["NumberOfMaxCapReqs"]
    dfMaxCapPenalty = DataFrame(Constraint = [Symbol("MaxCap_$maxcap") for maxcap = 1:NumberOfMaxCapReqs],
                                Price= dual.(EP[:cZoneMaxCapReq]),
                                Slack = value.(EP[:vMaxCap_slack]),
                                Penalty = value.(EP[:eCMaxCap_slack]))
    if setup["ParameterScale"] == 1
        dfMaxCapPenalty.Price *= ModelScalingFactor
        dfMaxCapPenalty.Slack *= ModelScalingFactor
        dfMaxCapPenalty.Penalty *= ModelScalingFactor^2
    end
    CSV.write(joinpath(path, "MaxCap_Price_n_penalty.csv"), dfMaxCapPenalty)
end