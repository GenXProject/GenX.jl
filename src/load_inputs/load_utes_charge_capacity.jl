@doc raw"""
    load_utes_charge_capacity!(setup::Dict, resources_path::AbstractString, inputs::Dict)

Load the optional `UTES_charge_capacity.csv` file that specifies the temperature-dependent spare
thermal capacity available to charge the underground reservoir (MWth) above the data-center cooling
load.

## File format

| Column | Description |
|--------|-------------|
| `Resource` | UTES resource name (must match a resource in the UTES set) |
| `Deg_Celsius` | Ambient temperature (°C) |
| `MWth` | Spare thermal charging capacity (MW_th) available at that temperature |

All `MWth` values must be non-negative. Rows are sorted by `Deg_Celsius` per resource; linear
interpolation is used for ambient temperatures that fall between table rows.  Temperatures outside
the table range are clamped to the nearest boundary value (with a one-time warning).

## Effect on the model

When this file is present for a resource `y`:
- `inputs["MaxChargePower"][y][t]` is populated with the interpolated spare capacity at each hour.
- `chiller.jl` uses `Q[t] + MaxChargePower[y][t]` as the effective chiller capacity when building
  the temperature-drop upper bound (`cChillerTempDrop_ub`), allowing `vTemp_Chiller` to drop below
  `T_HX12` and charge the reservoir.
- `reservior_thermal_energy_storage.jl` adds `cRTES_MaxChargePower` to bound
  `eThermalPower_UTES_Reservoir` from above by `MaxChargePower[y][t]`.

When the file is absent, `inputs["MaxChargePower"]` is set to `nothing` and the existing
`Cap_chiller` from `UTES.csv` governs the temperature-drop constraint (legacy behaviour).
"""
function load_utes_charge_capacity!(setup::Dict,
                                     resources_path::AbstractString,
                                     inputs::Dict)
    # Only relevant when CoolingDemand is active and UTES resources exist
    if setup["CoolingDemand"] != 1 || !haskey(inputs, "UTES") || isempty(inputs["UTES"])
        inputs["MaxChargePower"] = nothing
        return nothing
    end

    file_path = joinpath(resources_path, "UTES_charge_capacity.csv")
    if !isfile(file_path)
        inputs["MaxChargePower"] = nothing
        return nothing
    end

    df = load_dataframe(file_path)

    # ------------------------------------------------------------------
    # Validate columns
    # ------------------------------------------------------------------
    required_cols = ["Resource", "Deg_Celsius", "MWth"]
    for col in required_cols
        if col ∉ names(df)
            error("UTES_charge_capacity.csv is missing required column: $col")
        end
    end

    dropmissing!(df, required_cols)

    if any(df.MWth .< 0)
        error("UTES_charge_capacity.csv contains negative MWth values. " *
              "All spare capacity values must be non-negative.")
    end

    gen   = inputs["RESOURCES"]
    UTES  = inputs["UTES"]
    T     = inputs["T"]
    pAmbientTemp = inputs["pAmbientTemp"]

    # Map resource names to UTES indices
    utes_name_to_idx = Dict(resource_name(gen[y]) => y for y in UTES)

    # Build per-resource lookup tables: resource_idx => (temps, caps)
    resource_lookup = Dict{Int, Tuple{Vector{Float64}, Vector{Float64}}}()
    for rname in unique(df.Resource)
        y = get(utes_name_to_idx, rname, nothing)
        if y === nothing
            @warn "UTES_charge_capacity.csv contains resource '$rname' that is not in the " *
                  "UTES resource set. Ignoring."
            continue
        end
        res_df = filter(row -> row.Resource == rname, df)
        sort!(res_df, :Deg_Celsius)
        resource_lookup[y] = (collect(Float64, res_df.Deg_Celsius),
                              collect(Float64, res_df.MWth))
    end

    # ------------------------------------------------------------------
    # Pre-compute MaxChargePower[y][t] by interpolating at each timestep
    # ------------------------------------------------------------------
    max_charge_power = Dict{Int, Vector{Float64}}()
    warned = Ref(false)   # shared across all resources / timesteps

    for y in UTES
        lut = get(resource_lookup, y, nothing)
        lut === nothing && continue   # no data for this resource

        temps, caps = lut
        zone = gen[y].zone
        max_charge_power[y] = [
            interpolate_cop(pAmbientTemp[zone, t], temps, caps, warned,
                            "UTES_charge_capacity")
            for t in 1:T
        ]
    end

    inputs["MaxChargePower"] = max_charge_power
    println("UTES_charge_capacity.csv Successfully Read!")
    return nothing
end
