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
	THERM_ALL = inputs["THERM_ALL"]
	VRE = inputs["VRE"]
	HYDRO_RES = inputs["HYDRO_RES"]
	STOR_ALL = inputs["STOR_ALL"]
	FLEX = inputs["FLEX"]
	MUST_RUN = inputs["MUST_RUN"]
	dfResRevenue = DataFrame(Region = dfGen.region, Resource = inputs["RESOURCES"], Zone = dfGen.Zone, Cluster = dfGen.cluster)
	annual_sum = zeros(G)
	for i in 1:inputs["NCapacityReserveMargin"]
		sym = Symbol("CapRes_$i")
		tempresrev = zeros(G)
		tempresrev[THERM_ALL] = dfGen[THERM_ALL, sym] .* (value.(EP[:eTotalCap][THERM_ALL])) * sum(dual.(EP[:cCapacityResMargin][i, :]))
		tempresrev[VRE] = dfGen[VRE, sym] .* (value.(EP[:eTotalCap][VRE])) .* (inputs["pP_Max"][VRE, :] * (dual.(EP[:cCapacityResMargin][i, :])))
		tempresrev[MUST_RUN] = dfGen[MUST_RUN, sym] .* (value.(EP[:eTotalCap][MUST_RUN])) .* (inputs["pP_Max"][MUST_RUN, :] * (dual.(EP[:cCapacityResMargin][i, :])))
		tempresrev[HYDRO_RES] = dfGen[HYDRO_RES, sym] .* (value.(EP[:vP][HYDRO_RES, :]) * (dual.(EP[:cCapacityResMargin][i, :])))
		if !isempty(STOR_ALL)
			tempresrev[STOR_ALL] = dfGen[STOR_ALL, sym] .* ((value.(EP[:vP][STOR_ALL, :]) - value.(EP[:vCHARGE][STOR_ALL, :]).data + value.(EP[:vCAPCONTRSTOR_VP][STOR_ALL, :]).data - value.(EP[:vCAPCONTRSTOR_VCHARGE][STOR_ALL, :]).data) * (dual.(EP[:cCapacityResMargin][i, :])))
		end
		if !isempty(FLEX)
			tempresrev[FLEX] = dfGen[FLEX, sym] .* ((value.(EP[:vCHARGE_FLEX][FLEX, :]).data - value.(EP[:vP][FLEX, :])) * (dual.(EP[:cCapacityResMargin][i, :])))
		end
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
