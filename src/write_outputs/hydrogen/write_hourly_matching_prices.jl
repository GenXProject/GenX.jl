function write_hourly_matching_prices(path::AbstractString,
        inputs::Dict,
        setup::Dict,
        EP::Model)
    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones
    

    ## Extract dual variables of constraints
    dfHourlyMatchPrices = DataFrame(Zone = 1:Z) # The unit is $/MWh
    # Dividing dual variable for each hour with corresponding hourly weight to retrieve marginal cost of the constraint
    price = dual.(EP[:cHourlyMatching]) ./ inputs["omega"] 
    dfHourlyMatchPrices = hcat(dfHourlyMatchPrices,
        DataFrame(transpose(price), :auto))

    auxNew_Names = [Symbol("Zone"); [Symbol("t$t") for t in 1:T]]
    rename!(dfHourlyMatchPrices, auxNew_Names)

    CSV.write(joinpath(path, "hourly_matching_prices.csv"),
        dftranspose(dfHourlyMatchPrices, false), writeheader = false)

    return nothing
end
