function write_maximum_capacity_requirement(path::AbstractString,
    inputs::Dict,
    setup::Dict,
    EP::Model)
    NumberOfMaxCapReqs = inputs["NumberOfMaxCapReqs"]
    dfMaxCapPrice = DataFrame(Constraint = [Symbol("MaxCapReq_$maxcap")
                                            for maxcap in 1:NumberOfMaxCapReqs],
        Price = -dual.(EP[:cZoneMaxCapReq]))

    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    dfMaxCapPrice.Price *= scale_factor

    if haskey(inputs, "MaxCapPriceCap")
        dfMaxCapPrice[!, :Slack] = convert(Array{Float64}, value.(EP[:vMaxCap_slack]))
        dfMaxCapPrice[!, :Penalty] = convert(Array{Float64}, value.(EP[:eCMaxCap_slack]))
        dfMaxCapPrice.Slack *= scale_factor # Convert GW to MW
        dfMaxCapPrice.Penalty *= scale_factor^2 # Convert Million $ to $
    end
    CSV.write(joinpath(path, "MaxCapReq_prices_and_penalties.csv"), dfMaxCapPrice)
end
