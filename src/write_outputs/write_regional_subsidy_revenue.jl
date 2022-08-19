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
	write_regional_subsidy_revenue(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
Function for reporting subsidy revenue earned if the Minimum Capacity Carveout constraint is in place, 
    which is for a subset of generators. The unit is \$.
"""


function write_regional_subsidy_revenue(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    dfGen = inputs["dfGen"]
    G = inputs["G"]

    ### calculating tech specific subsidy revenue

    dfRegSubRevenue = DataFrame(Region = dfGen[!, :region], Resource = inputs["RESOURCES"], Zone = dfGen[!, :Zone], Cluster = dfGen[!, :cluster], SubsidyRevenue = zeros(G))
    for mincap in 1:inputs["NumberOfMinCapReqs"] # This key only exists if MinCapReq >= 1, so we can't get it at the top outside of this condition.
        MIN_CAP_GEN = dfGen[(dfGen[!, Symbol("MinCapTag_$mincap")].>0), :R_ID]
        # check for VRE-Storage module
        dfRegSubRevenue.SubsidyRevenue[MIN_CAP_GEN] .+= (dual.(EP[:cZoneMinCapReq])[mincap]) * (value.(EP[:eTotalCap])[MIN_CAP_GEN]) .* dfGen[MIN_CAP_GEN, Symbol("MinCapTag_$mincap")]

    end

    if setup["ParameterScale"] == 1
        dfRegSubRevenue.SubsidyRevenue *= ModelScalingFactor^2 #convert from Million US$ to US$
    end

    CSV.write(joinpath(path, "RegSubsidyRevenue.csv"), dfRegSubRevenue)
    return dfRegSubRevenue
end