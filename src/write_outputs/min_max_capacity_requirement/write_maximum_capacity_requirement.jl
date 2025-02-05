function write_maximum_capacity_requirement(path::AbstractString,
        inputs::Dict,
        setup::Dict,
        EP::Model)
    NumberOfMaxCapReqs = inputs["NumberOfMaxCapReqs"]
    # Maya: Changed Symbol to string for CO2 Cap labels
    dfMaxCapPrice = DataFrame(
        Constraint = [String("MaxCapReq_$maxcap")
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
    
    write_output_file(joinpath(path, setup["WriteResultsNamesDict"]["maxcap"]),
        dfMaxCapPrice,
        filetype = setup["ResultsFileType"],
        compression = setup["ResultsCompressionType"])
end
