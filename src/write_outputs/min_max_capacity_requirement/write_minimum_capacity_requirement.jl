function write_minimum_capacity_requirement(path::AbstractString,
    inputs::Dict,
    setup::Dict,
    EP::Model)
    NumberOfMinCapReqs = inputs["NumberOfMinCapReqs"]
    dfMinCapPrice = DataFrame(Constraint = [Symbol("MinCapReq_$mincap")
                                            for mincap in 1:NumberOfMinCapReqs],
        Price = dual.(EP[:cZoneMinCapReq]))

    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    dfMinCapPrice.Price *= scale_factor # Convert Million $/GW to $/MW

    if haskey(inputs, "MinCapPriceCap")
        dfMinCapPrice[!, :Slack] = convert(Array{Float64}, value.(EP[:vMinCap_slack]))
        dfMinCapPrice[!, :Penalty] = convert(Array{Float64}, value.(EP[:eCMinCap_slack]))
        dfMinCapPrice.Slack *= scale_factor # Convert GW to MW
        dfMinCapPrice.Penalty *= scale_factor^2 # Convert Million $ to $
    end
    CSV.write(joinpath(path, "MinCapReq_prices_and_penalties.csv"), dfMinCapPrice)
end
