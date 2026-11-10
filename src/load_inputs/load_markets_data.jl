
@doc raw"""
    get_market_timeseries_dir(setup::Dict, path::AbstractString, filename::AbstractString)

Return the directory from which the time series market file `filename` is read. When time domain
reduction is active and the reduced files exist, this is the `TimeDomainReductionFolder` of the
case at `path`; otherwise it is the `SystemFolder`.
"""
function get_market_timeseries_dir(setup::Dict, path::AbstractString, filename::AbstractString)
    TDR_directory = joinpath(path, setup["TimeDomainReductionFolder"])
    my_dir = get_systemfiles_path(setup, TDR_directory, path)
    if my_dir == TDR_directory && !isfile(joinpath(my_dir, filename))
        error("""$filename was not found in $TDR_directory. The time domain reduced inputs were
              probably created before Markets was enabled. Delete $TDR_directory and run the case
              again so that time domain reduction also writes the market files.""")
    end
    return my_dir
end

@doc raw"""
    extract_zonal_market_matrix(df::DataFrame, columnprefix::AbstractString, Z::Int,
        filename::AbstractString)

Build a ``T \times Z`` matrix from the columns `columnprefix_z` of `df`. Columns may be given for
any subset of zones ``z \in 1, \dots, Z``; zones without a column are set to `0`. Returns the matrix
and the list of zones that had a column.
"""
function extract_zonal_market_matrix(df::DataFrame, columnprefix::AbstractString, Z::Int,
        filename::AbstractString)
    zones = find_matrix_columns_in_dataframe(df, columnprefix)
    if !allunique(zones)
        error("$filename: duplicate $(columnprefix) columns for zones $(zones).")
    end
    if !all(z -> z in 1:Z, zones)
        error("$filename: $(columnprefix) columns must refer to zones 1 to $Z, but found zones $(zones).")
    end
    mat = zeros(Float64, nrow(df), Z)
    for z in zones
        col = df[!, "$(columnprefix)_$(z)"]
        if any(ismissing, col)
            error("$filename: column $(columnprefix)_$(z) has missing values.")
        end
        mat[:, z] = Float64.(col)
    end
    return mat, zones
end

@doc raw"""
    load_zones_markets!(setup::Dict, path::AbstractString, inputs::Dict)

Read `Zones_markets.csv`, which lists the modeled zones and flags which of them are connected to
an external wholesale market.

**Input file columns**

| Column | Description |
| :----- | :---------- |
| `Zone` | Zone index, an integer in ``1, \dots, Z``. Each zone may appear at most once. |
| `Market` | `1` if the zone is connected to the market, `0` otherwise. |
| `Market_Max_Buy` | Maximum electricity the zone can buy from the market in each time step [MW]. |
| `Market_Max_Sell` | Maximum electricity the zone can sell to the market in each time step [MW]. |

Only zones with `Market = 1` take part in market transactions. Their transaction limits are read
and the limits of zones with `Market = 0` are ignored. If `ParameterScale = 1`, the limits are
converted from MW to GW.

**Entries added to `inputs`**

- `inputs["MZ"]`: vector of market zone indices
- `inputs["Mrkt_Max_Buy"]`: `Dict` mapping each market zone to its maximum purchase
- `inputs["Mrkt_Max_Sell"]`: `Dict` mapping each market zone to its maximum sale
"""
function load_zones_markets!(setup::Dict, path::AbstractString, inputs::Dict)
    filename = "Zones_markets.csv"
    Z = inputs["Z"]

    # Load dataframe
    zones_markets_df = load_dataframe(joinpath(path, filename))

    # Validate zone indices and market flags
    zones = zones_markets_df.Zone
    if !all(z -> z in 1:Z, zones)
        error("$filename: Zone values must be integers between 1 and $Z, but found $(zones).")
    end
    if !allunique(zones)
        error("$filename: each zone may appear only once, but found duplicates in $(zones).")
    end
    if !all(f -> f in (0, 1), zones_markets_df.Market)
        error("$filename: Market column must contain only 0 or 1.")
    end

    # Filter only zones that are actually markets
    market_zones_df = filter(row -> row.Market == 1, zones_markets_df)

    if any(<(0), market_zones_df.Market_Max_Buy) || any(<(0), market_zones_df.Market_Max_Sell)
        error("$filename: Market_Max_Buy and Market_Max_Sell must be non-negative.")
    end

    # Extract list of market zones
    inputs["MZ"] = Vector{Int}(market_zones_df.Zone)

    # Transaction limits for market zones (MW -> GW if scaled)
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
    inputs["Mrkt_Max_Buy"]  = Dict(row.Zone => row.Market_Max_Buy  / scale_factor for row in eachrow(market_zones_df))
    inputs["Mrkt_Max_Sell"] = Dict(row.Zone => row.Market_Max_Sell / scale_factor for row in eachrow(market_zones_df))

    println(filename * " Successfully Read!")
end

@doc raw"""
    load_market_price_data!(setup::Dict, path::AbstractString, inputs::Dict)

Read `Market_price.csv`, which gives the hourly prices at which each zone buys electricity from and
sells electricity to the external market.

**Input file columns**

| Column | Description |
| :----- | :---------- |
| `Time_Index` | Time step index. |
| `BuyPrice_z` | Price paid for electricity bought from the market in zone `z` [\$/MWh]. |
| `SellPrice_z` | Price received for electricity sold to the market in zone `z` [\$/MWh]. |

Columns are matched to zones by their suffix `z`, so they may be given in any order. Every market
zone (`Market = 1` in `Zones_markets.csv`) must have both a `BuyPrice_z` and a `SellPrice_z`
column. Columns for other zones are optional; zones without a column default to a price of `0`.
Prices in zones with `Market = 0` are not used. The file must have one row per time step. If `ParameterScale = 1`, prices are converted from \$/MWh to M\$/GWh.

`path` is the case folder. The file is read from the `SystemFolder`, or from the
`TimeDomainReductionFolder` when time domain reduction is active (see
[`cluster_inputs`](@ref) and the `ClusterMarketPrices` setting).

**Entries added to `inputs`**

- `inputs["Market_BuyPrices"]`: ``Z \times T`` matrix of buy prices
- `inputs["Market_SellPrices"]`: ``Z \times T`` matrix of sell prices
"""
function load_market_price_data!(setup::Dict, path::AbstractString, inputs::Dict)
    filename = "Market_price.csv"
    T = inputs["T"]
    Z = inputs["Z"]

    # Load the market price dataframe (from the TDR folder if time domain reduction is used)
    my_dir = get_market_timeseries_dir(setup, path, filename)
    price_df = load_dataframe(joinpath(my_dir, filename))

    # Validate time dimension: one row per time step
    if nrow(price_df) != T
        error("$filename: expected $T time steps, but found $(nrow(price_df)) rows.")
    end

    # Extract price matrices (time x zone); zones without a column default to 0
    sell_price_mat, sell_zones = extract_zonal_market_matrix(price_df, "SellPrice", Z, filename)
    buy_price_mat, buy_zones = extract_zonal_market_matrix(price_df, "BuyPrice", Z, filename)

    # Market zones must have both prices, otherwise purchases would be free
    for (name, zones) in (("BuyPrice", buy_zones), ("SellPrice", sell_zones))
        missing_zones = setdiff(inputs["MZ"], zones)
        if !isempty(missing_zones)
            error("$filename: market zones $(missing_zones) have no $name column. " *
                  "Prices are required for every zone with Market = 1 in Zones_markets.csv.")
        end
    end

    # Scale market prices from $/MWh to M$/GWh
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
    sell_price_mat /= scale_factor
    buy_price_mat /= scale_factor

    # Transpose to align as (zone, time)
    inputs["Market_SellPrices"] = permutedims(sell_price_mat)
    inputs["Market_BuyPrices"]  = permutedims(buy_price_mat)

    println(filename * " Successfully Read!")
end

@doc raw"""
    load_market_purchase_emissions_data!(setup::Dict, path::AbstractString, inputs::Dict)

Read `Market_emissions.csv`, which gives the hourly CO``_2`` emission rate assigned to electricity
bought from the external market.

**Input file columns**

| Column | Description |
| :----- | :---------- |
| `Time_Index` | Time step index. |
| `CO2_tons_MWh_z` | Emission rate of electricity bought from the market in zone `z` [tCO``_2``/MWh]. |

Columns are matched to zones by their suffix `z`, so they may be given in any order. Zones without
a `CO2_tons_MWh_z` column default to an emission rate of `0`; a warning is printed if this applies
to a market zone (`Market = 1` in `Zones_markets.csv`). Rates in zones with `Market = 0` are not
used. The file must have one row per time step. No scaling is
applied: with `ParameterScale = 1`, tCO``_2``/MWh is equal to ktCO``_2``/GWh.

`path` is the case folder. The file is read from the `SystemFolder`, or from the
`TimeDomainReductionFolder` when time domain reduction is active.

**Entries added to `inputs`**

- `inputs["Market_CO2_tons_MWh"]`: ``Z \times T`` matrix of emission rates
"""
function load_market_purchase_emissions_data!(setup::Dict, path::AbstractString, inputs::Dict)
    filename = "Market_emissions.csv"
    T = inputs["T"]
    Z = inputs["Z"]

    # Load emissions dataframe (from the TDR folder if time domain reduction is used)
    my_dir = get_market_timeseries_dir(setup, path, filename)
    emissions_df = load_dataframe(joinpath(my_dir, filename))

    # Validate time dimension: one row per time step
    if nrow(emissions_df) != T
        error("$filename: expected $T time steps, but found $(nrow(emissions_df)) rows.")
    end

    # Extract emissions matrix (time x zone); zones without a column default to 0
    co2_emissions_mat, co2_zones = extract_zonal_market_matrix(emissions_df, "CO2_tons_MWh",
        Z, filename)

    missing_zones = setdiff(inputs["MZ"], co2_zones)
    if !isempty(missing_zones)
        @warn("$filename: market zones $(missing_zones) have no CO2_tons_MWh column. " *
              "Market purchases in these zones are assumed to have zero emissions.")
    end

    # Transpose to align as (zone, time)
    inputs["Market_CO2_tons_MWh"] = permutedims(co2_emissions_mat)

    println(filename * " Successfully Read!")
end
