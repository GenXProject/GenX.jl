function write_subsidy_revenue(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, dfCap::DataFrame, EP::Model)
	dfGen = inputs["dfGen"]
	#NumberOfMinCapReqs = inputs["NumberOfMinCapReqs"]

	dfSubRevenue = DataFrame(region = dfGen[!,:region], Resource = inputs["RESOURCES"], zone = dfGen[!,:Zone], Cluster = dfGen[!,:cluster], R_ID = dfGen[!,:R_ID])
	#dfSubRevenue.SubsidyRevenue .= 0.0
	dfSubRevenue[!,:SubsidyRevenue] .= 0.0
	for y in (dfGen[(dfGen[!,:Min_Cap_MW].>0) ,:][!,:R_ID])
		dfSubRevenue[y,:SubsidyRevenue] = (value.(EP[:eTotalCap])[y]) * (dual.(EP[:cMinCap])[y])
	end

	if setup["ParameterScale"] == 1
		dfSubRevenue.SubsidyRevenue = dfSubRevenue.SubsidyRevenue*(ModelScalingFactor^2) #convert from Million US$ to US$
	end
	### calculating tech specific subsidy revenue

	dfRegSubRevenue = DataFrame(region = dfGen[!,:region], Resource = inputs["RESOURCES"], zone = dfGen[!,:Zone], Cluster = dfGen[!,:cluster], R_ID = dfGen[!,:R_ID])
	#dfRegSubRevenue.SubsidyRevenue .= 0.0
	dfRegSubRevenue[!,:SubsidyRevenue] .= 0.0
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
