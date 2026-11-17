function default_ro_settings()
    Dict{Any, Any}(
        # Budgets are integers = NUMBER of uncertain parameters allowed to take their
        # worst-case value simultaneously (not a fraction / percentage).
        #   BudgetOfUncertainty >= 0 : one shared budget over all active categories
        #   BudgetOfUncertainty = -1 : use the per-category budgets below
        "BudgetOfUncertainty" => -1,
        "BudgetOfUncertainty_MarketBuyPrices" => -1,
        "BudgetOfUncertainty_MarketSellPrices" => -1,
        "BudgetOfUncertainty_FuelPrices" => -1,
        "BudgetOfUncertainty_InvestmentCost" => -1,
        "BudgetOfUncertainty_FixedOMCost" => -1,
        "MarketBuyPrices" => 0,
        "MarketSellPrices" => 0,
        "FuelsCost" => 0,
        "InvestmentCost" => 0,
        "FixedOMCost" => 0
    )
end

# (gamma key, count key, active flag key, label)
const RO_CATEGORIES = [
    ("BudgetOfUncertainty_MarketBuyPrices", "count_uncertain_mbuy_param", "MarketBuyPrices", "Market Buy Prices"),
    ("BudgetOfUncertainty_MarketSellPrices", "count_uncertain_msell_param", "MarketSellPrices", "Market Sell Prices"),
    ("BudgetOfUncertainty_FuelPrices", "count_uncertain_fuel_param", "FuelsCost", "Fuel Costs"),
    ("BudgetOfUncertainty_InvestmentCost", "count_uncertain_invest_param", "InvestmentCost", "Investment Cost"),
    ("BudgetOfUncertainty_FixedOMCost", "count_uncertain_fixedom_param", "FixedOMCost", "Fixed OM Cost"),
]

# Hourly bounds files; with TimeDomainReduction they are reduced by write_ro_tdr_bounds
const RO_HOURLY_BOUNDS_FILES = ["Fuels_cost_bounds.csv",
    "Market_buy_price_bounds.csv", "Market_sell_price_bounds.csv"]

function load_ro_settings(setup::Dict, path::AbstractString, inputs::Dict)
    println("Configuring Robust Optimization (RO) Settings...")

    ro_settings = default_ro_settings()
    ro_file = joinpath(path, "ro_settings.yml")
    if isfile(ro_file)
        merge!(ro_settings, YAML.load_file(ro_file))
    else
        @warn "RO = 1 but no ro_settings.yml found in $path; using default RO settings (no uncertainty active)."
    end
    inputs["ro_settings"] = ro_settings
end


"""
    ro_load_hourly_bounds(filename, setup, inputs)

Load an hourly bounds file with one row per model time step:
`<ToolsFolder>/<filename>` on the full time series, or
`<TimeDomainReductionFolder>/<ToolsFolder>/<filename>` (written by time domain
reduction) when `TimeDomainReduction = 1`.
"""
function ro_load_hourly_bounds(filename::AbstractString, setup::Dict, inputs::Dict)
    case = inputs["ro_case_path"]
    tdr = setup["TimeDomainReduction"] == 1
    dir = tdr ?
          joinpath(case, setup["TimeDomainReductionFolder"], setup["ToolsFolder"]) :
          joinpath(case, setup["ToolsFolder"])
    file = joinpath(dir, filename)

    if !isfile(file)
        tdr && error("$file not found. It is written by time domain reduction when RO = 1; " *
                     "delete the $(setup["TimeDomainReductionFolder"]) folder so it is regenerated.")
        error("$file not found.")
    end

    df = load_dataframe(file)
    T = inputs["T"]
    nrow(df) == T ||
        error("$file has $(nrow(df)) rows but the model has T = $T time steps.")
    return df
end

function load_market_buy_price_bound_data!(setup::Dict, path::AbstractString, inputs::Dict)
    filename = "Market_buy_price_bounds.csv"
    haskey(inputs, "MZ") ||
        error("RO on market buy prices requires market inputs (inputs[\"MZ\"]), which are not loaded in this GenX version.")

    df = ro_load_hourly_bounds(filename, setup, inputs)
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    delta = transpose(extract_matrix_from_dataframe(df, "BuyPriceDelta")) ./ scale_factor
    size(delta, 1) == inputs["Z"] ||
        @warn "$filename: expected columns for all $(inputs["Z"]) zones, got $(size(delta, 1))"

    inputs["Market_BuyPrices_Delta"] = delta
    inputs["count_uncertain_mbuy_param"] = count(!iszero, delta[inputs["MZ"], :])
    println("$filename successfully read.")
end

function load_market_sell_price_bound_data!(setup::Dict, path::AbstractString, inputs::Dict)
    filename = "Market_sell_price_bounds.csv"
    haskey(inputs, "MZ") ||
        error("RO on market sell prices requires market inputs (inputs[\"MZ\"]), which are not loaded in this GenX version.")

    df = ro_load_hourly_bounds(filename, setup, inputs)
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    delta = transpose(extract_matrix_from_dataframe(df, "SellPriceDelta")) ./ scale_factor
    size(delta, 1) == inputs["Z"] ||
        @warn "$filename: expected columns for all $(inputs["Z"]) zones, got $(size(delta, 1))"

    inputs["Market_SellPrices_Delta"] = delta
    inputs["count_uncertain_msell_param"] = count(!iszero, delta[inputs["MZ"], :])
    println("$filename successfully read.")
end

function load_fuel_bound_data!(setup::Dict, path::AbstractString, inputs::Dict)
    filename = "Fuels_cost_bounds.csv"
    df = ro_load_hourly_bounds(filename, setup, inputs)
    T = inputs["T"]
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    all_fuels = inputs["fuels"]
    uncertain_fuels = setdiff(names(df), ["Time_Index"])
    unknown = setdiff(uncertain_fuels, all_fuels)
    isempty(unknown) || @warn "$filename: columns $unknown are not fuels in Fuels_data.csv and are ignored."

    delta = zeros(length(all_fuels), T)
    for (i, f) in enumerate(all_fuels)
        f in uncertain_fuels && (delta[i, :] = df[!, f] ./ scale_factor)
    end

    multi = inputs["MULTI_FUELS"]
    if !isempty(multi)
        @warn "Fuel-cost RO only covers single-fuel resources; multi-fuel resources $(resource_name.(inputs["RESOURCES"][multi])) are treated deterministically."
    end

    inputs["delta_fuel_costs"] = Containers.DenseAxisArray(delta, all_fuels, 1:T)
    inputs["count_uncertain_fuel_param"] = count(!iszero, delta)
    println(filename * " Successfully Read!")
end

# Read a Resource => value map from an optional column; missing column -> empty map
function ro_column_map(df::DataFrame, col::Symbol, scale_factor)
    hasproperty(df, col) || return Dict{String, Float64}()
    Dict(String(r.Resource) => Float64(r[col]) / scale_factor for r in eachrow(df))
end

function ro_warn_unknown_resources(df::DataFrame, filename, gen)
    unknown = setdiff(String.(df.Resource), resource_name.(gen))
    isempty(unknown) || @warn "$filename: resources $unknown are not in the model and are ignored."
end

function load_investment_cost_bound_data!(setup::Dict, path::AbstractString, inputs::Dict)
    filename = "Investment_cost_bounds.csv"
    df = load_dataframe(joinpath(path, filename))
    gen = inputs["RESOURCES"]
    ro_warn_unknown_resources(df, filename, gen)

    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
    mw = ro_column_map(df, :Inv_Cost_per_MWyr_bounds, scale_factor)
    mwh = ro_column_map(df, :Inv_Cost_per_MWhyr_bounds, scale_factor)

    NEW_CAP = Set(inputs["NEW_CAP"])
    NEW_CAP_ENERGY = Set(inputs["NEW_CAP_ENERGY"])

    delta_mw = Dict{Int, Float64}()
    delta_mwh = Dict{Int, Float64}()
    for y in 1:inputs["G"]
        name = resource_name(gen[y])
        d_mw = get(mw, name, 0.0)
        d_mwh = get(mwh, name, 0.0)
        if d_mw != 0
            y in NEW_CAP ? (delta_mw[y] = d_mw) :
            @warn "$filename: $name has a nonzero MW investment-cost delta but cannot build new MW capacity; ignored."
        end
        if d_mwh != 0
            y in NEW_CAP_ENERGY ? (delta_mwh[y] = d_mwh) :
            @warn "$filename: $name has a nonzero MWh investment-cost delta but cannot build new MWh capacity; ignored."
        end
    end

    inputs["delta_investment_costs"] = delta_mw
    inputs["delta_investment_costs_energy"] = delta_mwh
    # One uncertain parameter per resource (its MW and MWh deltas deviate together)
    inputs["RO_INV"] = sort!(collect(union(keys(delta_mw), keys(delta_mwh))))
    inputs["count_uncertain_invest_param"] = length(inputs["RO_INV"])

    println(filename * " Successfully Read!")
    return nothing
end

function load_fixed_om_cost_bound_data!(setup::Dict, path::AbstractString, inputs::Dict)
    filename = "Fixed_OM_cost_bounds.csv"
    df = load_dataframe(joinpath(path, filename))
    gen = inputs["RESOURCES"]
    ro_warn_unknown_resources(df, filename, gen)

    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
    mw = ro_column_map(df, :Fixed_OM_Cost_per_Mwyr_bound, scale_factor)
    mwh = ro_column_map(df, :Fixed_OM_Cost_per_Mwhyr_bound, scale_factor)

    STOR_ALL = Set(inputs["STOR_ALL"])

    delta_mw = Dict{Int, Float64}()
    delta_mwh = Dict{Int, Float64}()
    for y in 1:inputs["G"]
        name = resource_name(gen[y])
        d_mw = get(mw, name, 0.0)
        d_mwh = get(mwh, name, 0.0)
        d_mw != 0 && (delta_mw[y] = d_mw)
        if d_mwh != 0
            y in STOR_ALL ? (delta_mwh[y] = d_mwh) :
            @warn "$filename: non-storage resource $name has a nonzero MWh fixed O&M delta; ignored."
        end
    end

    inputs["delta_fixed_om_costs"] = delta_mw
    inputs["delta_fixed_om_costs_energy"] = delta_mwh
    inputs["RO_FOM"] = sort!(collect(union(keys(delta_mw), keys(delta_mwh))))
    inputs["count_uncertain_fixedom_param"] = length(inputs["RO_FOM"])

    println(filename * " Successfully Read!")
end

function validate_gamma!(inputs::Dict)
    ro = inputs["ro_settings"]
    active = [c for c in RO_CATEGORIES if ro[c[3]] == 1]

    if isempty(active)
        @warn "RO = 1 but no uncertainty category is active in ro_settings.yml; the model is deterministic."
        return nothing
    end

    check_int(key) = isa(ro[key], Integer) ||
        error("$key must be an integer number of uncertain parameters (got $(repr(ro[key]))).")

    check_int("BudgetOfUncertainty")

    if ro_shared_budget(ro)
        gamma = ro["BudgetOfUncertainty"]
        n = sum(get(inputs, c[2], 0) for c in active)
        for (gamma_key, count_key, _, label) in active
            ro[gamma_key] == -1 ||
                @warn "$gamma_key is ignored because the shared BudgetOfUncertainty = $gamma is set."
            println("  $label: $(get(inputs, count_key, 0)) uncertain parameters")
        end
        ro_report_gamma("Shared budget", gamma, n)
    else
        for (gamma_key, count_key, _, label) in active
            check_int(gamma_key)
            gamma = ro[gamma_key]
            gamma >= 0 ||
                error("$label is active but neither BudgetOfUncertainty nor $gamma_key is set (>= 0).")
            ro_report_gamma(label, gamma, get(inputs, count_key, 0))
        end
    end
    return nothing
end

function ro_report_gamma(label, gamma, n)
    if gamma > n
        @warn "$label: Γ = $gamma exceeds the number of uncertain parameters ($n); " *
              "this is full worst-case (box) robustness."
    else
        println("  ✓ $label: Γ = $gamma (out of $n uncertain parameters)")
    end
end

function load_ro_data!(setup::Dict, case_path::AbstractString, inputs::Dict)
    # Supported: single-stage and multi-stage runs (full time series or TDR representative
    # periods). With MultiStage, `case_path` is the stage folder (inputs/inputs_p<t>), so each
    # stage reads its own <ToolsFolder> and RO is applied stage by stage (see
    # ro_configure_multi_stage! for the investment-cost discounting).
    setup["Benders"] == 1 &&
        error("Robust optimization (RO = 1) is not supported with Benders decomposition.")

    inputs["ro_case_path"] = case_path
    path = joinpath(case_path, setup["ToolsFolder"])

    load_ro_settings(setup, path, inputs)
    ro = inputs["ro_settings"]

    ro["MarketBuyPrices"] == 1 && load_market_buy_price_bound_data!(setup, path, inputs)
    ro["MarketSellPrices"] == 1 && load_market_sell_price_bound_data!(setup, path, inputs)
    ro["FuelsCost"] == 1 && load_fuel_bound_data!(setup, path, inputs)
    ro["InvestmentCost"] == 1 && load_investment_cost_bound_data!(setup, path, inputs)
    ro["FixedOMCost"] == 1 && load_fixed_om_cost_bound_data!(setup, path, inputs)

    validate_gamma!(inputs)
end
