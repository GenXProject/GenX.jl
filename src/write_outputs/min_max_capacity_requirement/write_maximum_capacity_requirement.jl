function write_maximum_capacity_requirement(path::AbstractString,
        inputs::Dict,
        setup::Dict,
        EP::Model)
    NumberOfMaxCapReqs = inputs["NumberOfMaxCapReqs"]
    dfMaxCapPrice = DataFrame(
        Constraint = [Symbol("MaxCapReq_$maxcap")
                      for maxcap in 1:NumberOfMaxCapReqs],
        Price = -dual.(EP[:cZoneMaxCapReq]))

    



    if haskey(inputs, "MaxCapPriceCap")
        dfMaxCapPrice[!, :Slack] = convert(Array{Float64}, value.(EP[:vMaxCap_slack]))
        dfMaxCapPrice[!, :Penalty] = convert(Array{Float64}, value.(EP[:eCMaxCap_slack]))


    end
    CSV.write(joinpath(path, "MaxCapReq_prices_and_penalties.csv"), dfMaxCapPrice)
end
