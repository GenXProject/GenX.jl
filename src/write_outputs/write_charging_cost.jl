function write_charging_cost(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	res =  inputs["RESOURCES"]

	regions = region.(res)
	clusters = cluster.(res)
	zones = zone_id.(res)

	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
	STOR_ALL = inputs["STOR_ALL"]
	FLEX = inputs["FLEX"]
	ELECTROLYZER = inputs["ELECTROLYZER"]
	VRE_STOR = inputs["VRE_STOR"]
	VS_STOR = !isempty(VRE_STOR) ? inputs["VS_STOR"] : []

    price = locational_marginal_price(EP, inputs, setup)

	dfChargingcost = DataFrame(Region = regions, Resource = inputs["RESOURCE_NAMES"], Zone = zones, Cluster = clusters, AnnualSum = Array{Float64}(undef, G),)
	chargecost = zeros(G, T)
	if !isempty(STOR_ALL)
	    chargecost[STOR_ALL, :] .= (value.(EP[:vCHARGE][STOR_ALL, :]).data) .* transpose(price)[zone_id.(res.STOR), :]
	end
	if !isempty(FLEX)
	    chargecost[FLEX, :] .= value.(EP[:vP][FLEX, :]) .* transpose(price)[zone_id.(res.FLEX), :]
	end
	if !isempty(ELECTROLYZER)
		chargecost[ELECTROLYZER, :] .= (value.(EP[:vUSE][ELECTROLYZER, :]).data) .* transpose(price)[zone_id.(res.ELECTROLYZER), :]
	end
	if !isempty(VS_STOR)
		chargecost[VS_STOR, :] .= value.(EP[:vCHARGE_VRE_STOR][VS_STOR, :].data) .* transpose(price)[zone_id.(res[VS_STOR]), :]
	end
	if setup["ParameterScale"] == 1
	    chargecost *= ModelScalingFactor
	end
	dfChargingcost.AnnualSum .= chargecost * inputs["omega"]
	write_simple_csv(joinpath(path, "ChargingCost.csv"), dfChargingcost)
	return dfChargingcost
end
