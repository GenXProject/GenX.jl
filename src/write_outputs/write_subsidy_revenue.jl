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
	write_subsidy_revenue(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for reporting subsidy revenue earned if a generator specified `Min_Cap` is provided in the input file, or if a generator is subject to a Minimum Capacity Requirement constraint. The unit is \$.
"""
function write_subsidy_revenue(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]
	G = inputs["G"]

	dfSubRevenue = DataFrame(Region = dfGen[!, :region], Resource = inputs["RESOURCES"], Zone = dfGen[!, :Zone], Cluster = dfGen[!, :cluster], R_ID=dfGen[!, :R_ID], SubsidyRevenue = zeros(G))
	MIN_CAP = dfGen[(dfGen[!, :Min_Cap_MW].>0), :R_ID]
	dfSubRevenue.SubsidyRevenue[MIN_CAP] .= (value.(EP[:eTotalCap])[MIN_CAP]) .* (dual.(EP[:cMinCap][MIN_CAP])).data

	### calculating tech specific subsidy revenue
	dfRegSubRevenue = DataFrame(Region = dfGen[!, :region], Resource = inputs["RESOURCES"], Zone = dfGen[!, :Zone], Cluster = dfGen[!, :cluster], R_ID=dfGen[!, :R_ID], SubsidyRevenue = zeros(G))
	if (setup["MinCapReq"] >= 1)
		if !isempty(inputs["VRE_STOR"])
			dfVRE_STOR = inputs["dfVRE_STOR"]
		end
		for mincap in 1:inputs["NumberOfMinCapReqs"] # This key only exists if MinCapReq >= 1, so we can't get it at the top outside of this condition.
			if !isempty(inputs["VRE_STOR"])
				MIN_CAP_GEN = union(dfGen[(dfGen[!, Symbol("MinCapTag_$mincap")].==1), :R_ID], dfVRE_STOR[(dfVRE_STOR[!, Symbol("MinCapTag_$mincap")].==1), :R_ID])
			else
				MIN_CAP_GEN = dfGen[(dfGen[!, Symbol("MinCapTag_$mincap")].==1), :R_ID]
			end
			dfRegSubRevenue.SubsidyRevenue[MIN_CAP_GEN] .= dfRegSubRevenue.SubsidyRevenue[MIN_CAP_GEN] + (value.(EP[:eTotalCap][MIN_CAP_GEN])) * (dual.(EP[:cZoneMinCapReq][mincap]))
		end
	end

	if setup["ParameterScale"] == 1
		dfSubRevenue.SubsidyRevenue *= ModelScalingFactor^2 #convert from Million US$ to US$
		dfRegSubRevenue.SubsidyRevenue *= ModelScalingFactor^2 #convert from Million US$ to US$
	end

	CSV.write(joinpath(path, "SubsidyRevenue.csv"), dfSubRevenue)
	CSV.write(joinpath(path, "RegSubsidyRevenue.csv"), dfRegSubRevenue)
	return dfSubRevenue, dfRegSubRevenue
end
