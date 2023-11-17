@doc raw"""
	write_reserve_margin_revenue(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for reporting the capacity revenue earned by each generator listed in the input file.
    GenX will print this file only when capacity reserve margin is modeled and the shadow price can be obtained form the solver.
    Each row corresponds to a generator, and each column starting from the 6th to the second last is the total revenue from each capacity reserve margin constraint.
    The revenue is calculated as the capacity contribution of each time steps multiplied by the shadow price, and then the sum is taken over all modeled time steps.
    The last column is the total revenue received from all capacity reserve margin constraints.
    As a reminder, GenX models the capacity reserve margin (aka capacity market) at the time-dependent level, and each constraint either stands for an overall market or a locality constraint.
"""
function write_reserve_margin_revenue(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]
	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
	dfResRevenue = DataFrame(Region = dfGen.region, Resource = inputs["RESOURCES"], Zone = dfGen.Zone, Cluster = dfGen.cluster)
	annual_sum = zeros(G)
	for i in 1:inputs["NCapacityReserveMargin"]
		sym = Symbol("CapRes_$i")
		tempresrev = zeros(G)
		tempresrev = dfGen[:, sym] .* (value.(EP[:vCapContribution]) * dual.(EP[:cCapacityResMargin][i, :]))
		if setup["ParameterScale"] == 1
			tempresrev *= ModelScalingFactor^2
		end
		annual_sum .+= tempresrev
		dfResRevenue = hcat(dfResRevenue, DataFrame([tempresrev], [sym]))
	end
	dfResRevenue.AnnualSum = annual_sum
	CSV.write(joinpath(path, "ReserveMarginRevenue.csv"), dfResRevenue)
	return dfResRevenue
end
