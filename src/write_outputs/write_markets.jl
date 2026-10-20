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

Only zones listed in `MZ` (market-active zones) will report non-zero values.
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
    dfmarkets.AnnualSum .= scale_factor .* (markets * w)

    # --- 5. Write outputs ---
    filepath = joinpath(path, "market.csv")
    if setup["WriteOutputs"] == "annual"
        write_annual(filepath, dfmarkets)
    else
        dfmarkets = write_fulltimeseries(filepath, markets .* scale_factor, dfmarkets)
        if setup["OutputFullTimeSeries"] == 1 && setup["TimeDomainReduction"] == 1
            write_full_time_series_reconstruction(path, setup, dfmarkets, "market")
            @info("Writing Full Time Series for markets")
        end
    end

    return nothing
end
