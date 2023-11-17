function write_capacity_value(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]
	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
	if setup["ParameterScale"] == 1
		existingplant_position = findall(x -> x >= 1, (value.(EP[:eTotalCap])) * ModelScalingFactor)
	else
		existingplant_position = findall(x -> x >= 1, (value.(EP[:eTotalCap])))
	end
	totalcap = repeat((value.(EP[:eTotalCap])), 1, T)
	dfCapValue = DataFrame()
	for i in 1:inputs["NCapacityReserveMargin"]
		temp_dfCapValue = DataFrame(Resource = inputs["RESOURCES"], Zone = dfGen[!, :Zone], Reserve = fill(Symbol("CapRes_$i"), G))
		temp_capvalue = zeros(G, T)
		temp_riskyhour = zeros(G, T)
		temp_cap_derate = zeros(G, T)
		temp_cap_derate[existingplant_position, :] = repeat(dfGen[existingplant_position, Symbol("CapRes_$i")], 1, T)
		if setup["ParameterScale"] == 1
			riskyhour_position = findall(x -> x >= 1, ((dual.(EP[:cCapacityResMargin][i, :])) ./ inputs["omega"] * ModelScalingFactor))
		else
			riskyhour_position = findall(x -> x >= 1, ((dual.(EP[:cCapacityResMargin][i, :])) ./ inputs["omega"]))
		end
		temp_riskyhour[:, riskyhour_position] = ones(Int, G, length(riskyhour_position))
		temp_capvalue[existingplant_position, :] = 
			(temp_cap_derate[existingplant_position, :] .* 
				temp_riskyhour[existingplant_position, :] .* 
				value.(EP[:vCapContribution][existingplant_position, :]) ./ 
				totalcap[existingplant_position, :])
		temp_dfCapValue = hcat(temp_dfCapValue, DataFrame(temp_capvalue, :auto))
		auxNew_Names = [Symbol("Resource"); Symbol("Zone"); Symbol("Reserve"); [Symbol("t$t") for t in 1:T]]
		rename!(temp_dfCapValue, auxNew_Names)
		append!(dfCapValue, temp_dfCapValue)
	end
	CSV.write(joinpath(path, "CapacityValue.csv"), dfCapValue)
end
