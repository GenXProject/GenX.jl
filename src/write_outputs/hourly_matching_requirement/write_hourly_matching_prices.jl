@doc raw"""
	write_hourly_matching_prices(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for reporting the shadow price of each hourly matching constraint in each timestep.
GenX will print this file only when an hourly matching requirement is modeled and the shadow price can be obtained form the solver.
Each column corresponds to an hourly matching constraint, and each row corresponds to a timestep.
"""
function write_hourly_matching_prices(path::AbstractString,
        inputs::Dict,
        setup::Dict,
        EP::Model)
    T = inputs["T"]     # Number of time steps (hours)
    nHM = inputs["nHM"]     # Number of zones
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    ## Extract dual variables of constraints
    dfHourlyMatchPrices = DataFrame(hm = 1:nHM) # The unit is $/MWh
    # Dividing dual variable for each hour with corresponding hourly weight to retrieve marginal cost of the constraint
    price = dual.(EP[:cHourlyMatching]) ./ inputs["omega"] * scale_factor
    dfHourlyMatchPrices = hcat(dfHourlyMatchPrices,
        DataFrame(transpose(price), :auto))

    auxNew_Names = [Symbol("Zone"); [Symbol("t$t") for t in 1:T]]
    rename!(dfHourlyMatchPrices, auxNew_Names)

    write_transposed_csv(joinpath(path, "hourly_matching_prices.csv"),
        dfHourlyMatchPrices,
        writeheader = false)
    return nothing
end
