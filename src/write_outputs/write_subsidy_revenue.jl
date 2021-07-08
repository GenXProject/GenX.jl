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
	write_subsidy_revenue(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, dfCap::DataFrame, EP::Model)

Function for reporting subsidy revenue earned if a generator specified `Min_Cap` is provided in the input file. GenX will print this file only the shadow price can be obtained form the solver. Do not confuse this with the Minimum Capacity Carveout constraint, which is for a subset of generators, and a separate revenue term will be calculated in other files. The unit is \$.
"""
function write_subsidy_revenue(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, dfCap::DataFrame, EP::Model)
	dfGen = inputs["dfGen"]
	#NumberOfMinCapReqs = inputs["NumberOfMinCapReqs"]

	dfSubRevenue = DataFrame(region = dfGen[!,:region], Resource = inputs["RESOURCES"], zone = dfGen[!,:Zone], Cluster = dfGen[!,:cluster], R_ID = dfGen[!,:R_ID])
	#dfSubRevenue.SubsidyRevenue .= 0.0
	
	if v"1.3" <= VERSION < v"1.4"
		dfSubRevenue[!,:SubsidyRevenue] .= 0.0
	elseif v"1.5" <= VERSION < v"1.6"
		dfSubRevenue.SubsidyRevenue = zeros(size(dfSubRevenue, 1))
		#dfSubRevenue[:,:SubsidyRevenue] = zeros(size(dfSubRevenue, 1))
	end
	
	#dfSubRevenue[!,:SubsidyRevenue] .= 0.0
	for y in (dfGen[(dfGen[!,:Min_Cap_MW].>0) ,:][!,:R_ID])
		dfSubRevenue[y,:SubsidyRevenue] = (value.(EP[:eTotalCap])[y]) * (dual.(EP[:cMinCap])[y])
	end

	if setup["ParameterScale"] == 1
		dfSubRevenue.SubsidyRevenue = dfSubRevenue.SubsidyRevenue*(ModelScalingFactor^2) #convert from Million US$ to US$
	end
	### calculating tech specific subsidy revenue

	dfRegSubRevenue = DataFrame(region = dfGen[!,:region], Resource = inputs["RESOURCES"], zone = dfGen[!,:Zone], Cluster = dfGen[!,:cluster], R_ID = dfGen[!,:R_ID])
	#dfRegSubRevenue.SubsidyRevenue .= 0.0
	if v"1.3" <= VERSION < v"1.4"
		dfRegSubRevenue[!,:SubsidyRevenue] .= 0.0
	elseif v"1.5" <= VERSION < v"1.6"
		dfRegSubRevenue.SubsidyRevenue = zeros(size(dfRegSubRevenue, 1))
	end
	if (setup["MinCapReq"] >= 1)
		for mincap in 1:inputs["NumberOfMinCapReqs"] # This key only exists if MinCapReq >= 1, so we can't get it at the top outside of this condition.
			for y in dfGen[(dfGen[!,Symbol("MinCapTag_$mincap")].== 1) ,:][!,:R_ID]
			   dfRegSubRevenue[y,:SubsidyRevenue] = (value.(EP[:eTotalCap])[y]) * (dual.(EP[:cZoneMinCapReq])[mincap])
			end
		end
	end

	if setup["ParameterScale"] == 1
		dfRegSubRevenue.SubsidyRevenue = dfRegSubRevenue.SubsidyRevenue*(ModelScalingFactor^2) #convert from Million US$ to US$
	end

	CSV.write(string(path,sep,"SubsidyRevenue.csv"), dfSubRevenue)
	CSV.write(string(path,sep,"RegSubsidyRevenue.csv"), dfRegSubRevenue)
	return dfSubRevenue, dfRegSubRevenue
end
