
@doc raw"""
    load_zones_markets!(setup::Dict, path::AbstractString, inputs::Dict)

Function for reading flags that indicate whether a load zone is a market or not
"""
function load_zones_markets!(setup::Dict, path::AbstractString, inputs::Dict)
    filename = "Zones_markets.csv"

    # Load dataframe
    zones_markets_df = load_dataframe(joinpath(path, filename))

    # Filter only zones that are actually markets
    market_zones_df = filter(row -> row.Market == 1, zones_markets_df)

    # Extract list of market zones
    inputs["MZ"] = market_zones_df.Zone

    # Build dictionaries in a single pass
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
    inputs["Mrkt_Max_Buy"]  = Dict(row.Zone => row.Market_Max_Buy  / scale_factor for row in eachrow(market_zones_df))
    inputs["Mrkt_Max_Sell"] = Dict(row.Zone => row.Market_Max_Sell / scale_factor for row in eachrow(market_zones_df))

    println(filename * " Successfully Read!")
end

function load_market_price_data!(setup::Dict, path::AbstractString, inputs::Dict)
    filename = "Market_price.csv"
   
    # Load the market price dataframe
    price_df = load_dataframe(joinpath(path, filename))

    # Validate number of rows vs time steps
    if nrow(price_df) != inputs["T"]
        @warn """Number of rows in $filename ($nrow(price_df)) does NOT match expected time steps ($inputs["T"]).""" maxlog=1
    end

    # Extract price matrices (each col corresponds to a market zone)
    sell_price_mat = extract_matrix_from_dataframe(price_df, "SellPrice")
    buy_price_mat  = extract_matrix_from_dataframe(price_df, "BuyPrice")

    
    # Scale market prices from $/MWh to M$/GWh
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
    sell_price_mat /= scale_factor
    buy_price_mat /= scale_factor

    # Expected number of active markets
    num_zones = inputs["Z"]  # Use for all zones
    sell_cols = size(sell_price_mat, 2)
    buy_cols  = size(buy_price_mat, 2)

    # Validate columns for sell & buy prices
    if sell_cols != num_zones
        @warn """Expected sell price columns for $num_zones zones, but found $sell_cols columns.""" maxlog=1
    end
    if buy_cols != num_zones
        @warn """Expected buy price columns for $num_zones zones, but found $buy_cols columns.""" maxlog=1
    end

    # Transpose to align as (market, time)
    inputs["Market_SellPrices"] = transpose(sell_price_mat)
    inputs["Market_BuyPrices"]  = transpose(buy_price_mat)

    println(filename * " Successfully Read!")
end

function load_market_purchase_emissions_data!(setup::Dict, path::AbstractString, inputs::Dict)
    filename = "Market_emissions.csv"
    # Load emissions dataframe
    emissions_df = load_dataframe(joinpath(path, filename))

    # Expected number of time steps
    num_rows = nrow(emissions_df)

    # Validate time dimension
    if nrow(emissions_df) != inputs["T"]
        @warn """Number of rows in $filename ($num_rows) does NOT match expected time steps ($inputs["T"]).""" maxlog=1
    end

    # Extract emissions matrix (time x markets)
    co2_emissions_mat = extract_matrix_from_dataframe(emissions_df, "CO2_tons_MWh")

    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
    co2_emissions_mat /= scale_factor

    # Expected number of markets
    num_zones = inputs["Z"]
    emissions_cols = size(co2_emissions_mat, 2)

    # Validate number of markets
    if emissions_cols != num_zones
        @warn """Expected CO₂ emissions columns for $num_zones markets, but found $emissions_cols columns.""" maxlog=1
    end

    # Transpose to align as (market, time)
    inputs["Market_CO2_tons_MWh"] = transpose(co2_emissions_mat)

    println(filename * " Successfully Read!")
end