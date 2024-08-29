function write_hydrogen_prices(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor^2 : 1  # If ParameterScale==1, costs are in millions of $

    NumberOfH2DemandReqs = inputs["NumberOfH2DemandReqs"]
    dfHydrogenPrice = DataFrame(
        H2_Demand = [Symbol("H2_Demand_$h2demand") for h2demand in 1:NumberOfH2DemandReqs],
        Hydrogen_Price_Per_Tonne = convert(
            Array{Float64}, dual.(EP[:cZoneH2DemandReq]) * scale_factor))

    write_output_file(joinpath(path, setup["WriteResultsNamesDict"]["hydrogen_prices"]),
        dfHydrogenPrice,
        filetype = setup["ResultsFileType"],
        compression = setup["ResultsCompressionType"])
    return nothing
end
