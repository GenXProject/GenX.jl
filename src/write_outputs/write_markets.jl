@doc raw"""
    write_market(path::AbstractString, inputs::Dict, setup::Dict, EP::AbstractModel)

Generates market activity outputs (buy and sell) for each model zone and time step.

This function writes the time series and annual summary of market purchases and sales
for each zone. Results are saved in `market.csv` under the provided output path.

# Arguments
- `path::AbstractString`: Output directory path.
- `inputs::Dict`: Dictionary containing model inputs including zone info and weights.
- `setup::Dict`: Model settings including scaling and output format options.
- `EP::AbstractModel`: JuMP model containing market variables.

Only zones listed in `MZ` (market-active zones) will report non-zero values. The last entry,
`Net_Purchase`, is the system-wide net market purchase (total purchases minus total sales) in
each time step; a negative value means the system is a net seller to the market.
"""
function write_market(path::AbstractString, inputs::Dict, setup::Dict, EP::AbstractModel)
    Z = inputs["Z"]
    MZ = inputs["MZ"]
    T = inputs["T"]
    w = inputs["omega"]
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    # --- 1. Prepare column names for all zones ---
    buy_cols  = ["Market_Buy_$z"  for z in 1:Z]
    sell_cols = ["Market_Sell_$z" for z in 1:Z]
    col_names = vcat(buy_cols, sell_cols)
    zones     = vcat(1:Z, 1:Z)

    # --- 2. Initialize DataFrame ---
    dfmarkets = DataFrame(
        Market   = col_names,
        Zone     = zones,
        AnnualSum = Vector{Union{Missing, Float64}}(undef, 2Z)
    )

    # --- 3. Initialize markets matrix for all zones (2Z x T) ---
    markets = zeros(Float64, 2 * Z, T)

    # Fill only for active market zones
    for m in MZ
        markets[m, :] = value.(EP[:vMBUY][m, :])
        markets[Z + m, :] = value.(EP[:vMSELL][m, :])
    end
    

    # --- 4. Apply scaling & Compute annual sum (weighted by w) ---
    markets .*= scale_factor
    dfmarkets.AnnualSum .= markets * w

    # --- 5. Net purchases across all zones (buy - sell) ---
    # Written in place of the generic "Total" row, which would add purchases and sales together
    net_name = "Net_Purchase"
    net_ts = vec(sum(markets[1:Z, :], dims = 1) .- sum(markets[(Z + 1):(2Z), :], dims = 1))
    net_annual = sum(net_ts .* w)

    # --- 6. Write outputs ---
    filepath = joinpath(path, "market.csv")
    if setup["WriteOutputs"] == "annual"
        push!(dfmarkets, [net_name 0 net_annual])
        CSV.write(filepath, dfmarkets)
    else
        col_names = [Symbol("Resource"); Symbol("Zone"); Symbol("AnnualSum");
                     [Symbol("t$t") for t in 1:T]]
        dfmarkets = hcat(dfmarkets, DataFrame(markets, :auto))
        rename!(dfmarkets, col_names)
        net_row = DataFrame([net_name 0 net_annual permutedims(net_ts)], col_names)
        dfmarkets = vcat(dfmarkets, net_row)
        CSV.write(filepath, dftranspose(dfmarkets, false), writeheader = false)
        if setup["OutputFullTimeSeries"] == 1 && setup["TimeDomainReduction"] == 1
            write_full_time_series_reconstruction(path, setup, dfmarkets, "market")
            @info("Writing Full Time Series for markets")
        end
    end

    return nothing
end
