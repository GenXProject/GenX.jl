
const MARKET_LIMITS = "market_import_limits_MW"
const MARKET_PRICES = "market_prices_per_MWh"
const SELL_TIER = 1  # can only sell in tier 1

@doc raw"""
	load_market_data!(setup::Dict, path::AbstractString, inputs::Dict)

Parse the import_limit_MW_x and price_per_MWh_x for each of the tiers in the Market_data.csv into
the 
- inputs[MARKET_LIMITS]::Vector{Float64} and
- inputs[MARKET_PRICES]::Vector{Vector{Float64}}
"""
function load_market_data!(setup::Dict, path::AbstractString, inputs::Dict)
    system_dir = joinpath(path, setup["SystemFolder"])

    filename = "Market_data.csv"
    df = load_dataframe(joinpath(system_dir, filename))
    limit_columns = names(df, r"^import_limit_MW_")
    price_columns = names(df, r"^price_per_MWh_")

    inputs[MARKET_LIMITS] = Vector{Float64}()
    for col in limit_columns
        push!(inputs[MARKET_LIMITS], convert(Float64, df[1, col]))
    end

    inputs[MARKET_PRICES] = Vector{Vector{Float64}}()
    for col in price_columns
        push!(inputs[MARKET_PRICES], convert(Vector{Float64}, df[:, col]))
    end

    println(filename * " Successfully Read!")
end