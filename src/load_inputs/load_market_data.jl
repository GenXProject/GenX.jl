@doc raw"""
	load_market_data!(setup::Dict, path::AbstractString, inputs::Dict)

Parse the import_limit_MW_x and price_per_MWh_x for each of the tiers in the Market_data.csv into
the 
- inputs["market_import_limits_MW"]::Vector{Float64} and
- inputs["market_prices_per_MWh"]::Vector{Vector{Float64}}
"""
function load_market_data!(setup::Dict, path::AbstractString, inputs::Dict)
    system_dir = joinpath(path, setup["SystemFolder"])

    filename = "Market_data.csv"
    df = load_dataframe(joinpath(system_dir, filename))
    limit_columns = names(df, r"^import_limit_MW_")
    price_columns = names(df, r"^price_per_MWh_")

    inputs["market_import_limits_MW"] = Vector{Float64}()
    for col in limit_columns
        push!(inputs["market_import_limits_MW"], convert(Float64, df[1, col]))
    end

    inputs["market_prices_per_MWh"] = Vector{Vector{Float64}}()
    for col in price_columns
        push!(inputs["market_prices_per_MWh"], convert(Vector{Float64}, df[:, col]))
    end

    println(filename * " Successfully Read!")
end