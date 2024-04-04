function write_hydrogen_prices(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    scale_factor = setup["ParameterScale"] == 1 ? 10^6 : 1  # If ParameterScale==1, costs are in millions of $
    dfHydrogenPrice = DataFrame(Hydrogen_Price_Per_Tonne = convert(Array{Float64},
        dual.(EP[:cHydrogenMin]) * scale_factor))

    CSV.write(joinpath(path, "hydrogen_prices.csv"), dfHydrogenPrice)
    return nothing
end
