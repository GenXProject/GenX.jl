function write_minimum_capacity_requirement(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    NumberOfMinCapReqs = inputs["NumberOfMinCapReqs"]
    dfMinCapPrice = DataFrame(Constraint = [Symbol("MinCapReq_$mincap") for mincap = 1:NumberOfMinCapReqs],
                                Price= dual.(EP[:cZoneMinCapReq]))
    if setup["ParameterScale"] == 1
        dfMinCapPrice.Price *= ModelScalingFactor # Convert Million $/GW to $/MW
    end
    if haskey(inputs, "MinCapPriceCap")
		dfMinCapPrice[!,:Slack] = convert(Array{Float64}, value.(EP[:vMinCap_slack]))
		dfMinCapPrice[!,:Penalty] = convert(Array{Float64}, value.(EP[:eCMinCap_slack]))
		if setup["ParameterScale"] == 1
            dfMinCapPrice.Slack *= ModelScalingFactor # Convert GW to MW
            dfMinCapPrice.Penalty *= ModelScalingFactor^2 # Convert Million $ to $
		end
	end
    CSV.write(joinpath(path, "MinCapReq_prices_and_penalties.csv"), dfMinCapPrice)
end
