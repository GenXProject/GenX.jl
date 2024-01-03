function write_charging_cost(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]
	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
	STOR_ALL = inputs["STOR_ALL"]
	FLEX = inputs["FLEX"]
	ELECTROLYZER = inputs["ELECTROLYZER"]
	VRE_STOR = inputs["VRE_STOR"]
	VS_STOR = !isempty(VRE_STOR) ? inputs["VS_STOR"] : []

    price = locational_marginal_price(EP, inputs, setup)

	dfChargingcost = DataFrame(Region = dfGen[!, :region], Resource = inputs["RESOURCES"], Zone = dfGen[!, :Zone], Cluster = dfGen[!, :cluster], AnnualSum = Array{Float64}(undef, G),)
	chargecost = zeros(G, T)
	if !isempty(STOR_ALL)
	    chargecost[STOR_ALL, :] .= (value.(EP[:vCHARGE][STOR_ALL, :]).data) .* transpose(price)[dfGen[STOR_ALL, :Zone], :]
	end
	if !isempty(FLEX)
	    chargecost[FLEX, :] .= value.(EP[:vP][FLEX, :]) .* transpose(price)[dfGen[FLEX, :Zone], :]
	end
	if !isempty(ELECTROLYZER)
		chargecost[ELECTROLYZER, :] .= (value.(EP[:vUSE][ELECTROLYZER, :]).data) .* transpose(price)[dfGen[ELECTROLYZER, :Zone], :]
	end
	if !isempty(VS_STOR)
		chargecost[VS_STOR, :] .= value.(EP[:vCHARGE_VRE_STOR][VS_STOR, :].data) .* transpose(price)[dfGen[VS_STOR, :Zone], :]
	end
	if setup["ParameterScale"] == 1
	    chargecost *= ModelScalingFactor
	end
	dfChargingcost.AnnualSum .= chargecost * inputs["omega"]
	write_simple_csv(joinpath(path, "ChargingCost.csv"), dfChargingcost)
	return dfChargingcost
end
