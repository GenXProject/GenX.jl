# write_ro.jl — Output writers for the Robust Optimization module.
# Worst-case added cost:  v* = Σ_c Γ_c q_c + Σ_i p_i   (= value of eRODualObj)
# where q is the budget dual variable (shared, or one per category) and p_i the
# parameter-specific dual variable. The dual of each `q + p_i >= exposure_i` constraint is
# in [0, 1]: 1 means parameter i is at its worst-case value, fractional values occur at ties.
# Money outputs are in $ (scaled back when ParameterScale = 1); hourly exposures and p are
# weighted by omega (annual $).

# Duals of the solver objective (ObjScale * eObj) are divided by ObjScale so they refer to
# eObj: in [0, 1], with 1 meaning the parameter is at its worst-case value.
ro_dual(EP::AbstractModel, setup::Dict, c) = has_duals(EP) ? dual(c) / setup["ObjScale"] : NaN

# ---------------------------------------------------------------------------
# Market buy / sell (shared implementation)
# ---------------------------------------------------------------------------
function write_ro_market(path::AbstractString, inputs::Dict, setup::Dict,
        EP::AbstractModel, side::Symbol)
    buy = side == :buy
    MZ = inputs["MZ"]
    T = inputs["T"]
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    price_key = buy ? "Market_BuyPrices" : "Market_SellPrices"
    vsym = buy ? :vMBUY : :vMSELL
    psym = buy ? :p_mb : :p_ms
    csym = buy ? :cDualSmb : :cDualSms
    names_ = buy ?
             ["BuyPrice", "DeltaBuyPrice", "BuyExposure", "p_mb", "Dual_Smb",
        "ActualBuyPrice", "MPurchases", "BasicPurchasesCost", "TotalPurchasesCost"] :
             ["SellPrice", "DeltaSellPrice", "SellExposure", "p_ms", "Dual_Sms",
        "ActualSellPrice", "MSales", "BasicSalesRevenue", "TotalSalesRevenue"]
    L = length(names_)

    df = DataFrame(Component = repeat(names_, outer = length(MZ)),
        Zone = repeat(collect(MZ), inner = L),
        AnnualSum = zeros(L * length(MZ)))
    mtx = zeros(L * length(MZ), T)

    has_block = haskey(EP, psym)
    for (k, z) in enumerate(MZ)
        price = inputs[price_key][z, :] .* scale_factor
        delta = inputs[price_key * "_Delta"][z, :] .* scale_factor
        qty = vec(value.(EP[vsym][z, :]).data) .* scale_factor
        p = has_block ? vec(value.(EP[psym][z, :]).data) .* scale_factor^2 : zeros(T)
        d = has_block ? [ro_dual(EP, setup, EP[csym][z, t]) for t in 1:T] : zeros(T)

        # worst case: buy price goes up, sell price goes down
        actual = buy ? price .+ delta .* d : price .- delta .* d
        rows = (k - 1) * L .+ (1:L)
        mtx[rows, :] = vcat(price', delta', (delta .* qty)', p', d', actual', qty',
            (qty .* price)', (qty .* actual)')
    end

    df.AnnualSum .= mtx * inputs["omega"]
    # p is already omega-weighted (annual $), so its annual sum is a plain sum
    for (k, _) in enumerate(MZ)
        r = (k - 1) * L + 4
        df.AnnualSum[r] = sum(mtx[r, :])
    end
    df = hcat(df, DataFrame(mtx, [Symbol("t$t") for t in 1:T]))
    CSV.write(joinpath(path, buy ? "ro_market_buy.csv" : "ro_market_sell.csv"),
        dftranspose(df, false), writeheader = false)
end

# ---------------------------------------------------------------------------
# Fuel cost
# ---------------------------------------------------------------------------
function write_ro_fuel_cost(path::AbstractString, inputs::Dict, setup::Dict,
        EP::AbstractModel)
    haskey(EP, :p_fc) || return nothing
    T = inputs["T"]
    fuels = inputs["fuels"]
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    df = DataFrame(Time_Index = repeat(1:T, outer = length(fuels)),
        Fuel = repeat(fuels, inner = T),
        Original_Price = reduce(vcat, [inputs["fuel_costs"][f] for f in fuels]) .*
                         scale_factor,
        Delta_Price = reduce(vcat, [vec(inputs["delta_fuel_costs"][f, :].data)
                                    for f in fuels]) .* scale_factor,
        FuelExposure = [value(EP[:eFuelExposure][f, t]) for f in fuels for t in 1:T] .*
                       scale_factor^2,
        p_fc = [value(EP[:p_fc][f, t]) for f in fuels for t in 1:T] .* scale_factor^2,
        Dual_Sfc = [ro_dual(EP, setup, EP[:cDualSfc][f, t]) for f in fuels for t in 1:T])
    CSV.write(joinpath(path, "ro_fuel_cost.csv"), df)
end

# ---------------------------------------------------------------------------
# Investment cost (one row per uncertain resource)
# ---------------------------------------------------------------------------
function write_ro_investment_cost(path::AbstractString, inputs::Dict, setup::Dict,
        EP::AbstractModel)
    haskey(EP, :p_ic) || return nothing
    gen = inputs["RESOURCES"]
    R = inputs["RO_INV"]
    STOR_ALL = Set(inputs["STOR_ALL"])
    NEW_CAP_ENERGY = Set(inputs["NEW_CAP_ENERGY"])
    NEW_CAP = Set(inputs["NEW_CAP"])
    COMMIT = Set(inputs["COMMIT"])
    sf = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
    dmw = inputs["delta_investment_costs"]
    dmwh = inputs["delta_investment_costs_energy"]

    df = DataFrame(Resource = [resource_name(gen[r]) for r in R],
        StartCapacity = [existing_cap_mw(gen[r]) for r in R] .* sf,
        NewCapacity = [r in NEW_CAP ?
                       value(EP[:vCAP][r]) * (r in COMMIT ? cap_size(gen[r]) : 1.0) :
                       0.0 for r in R] .* sf,
        EndCapacity = [value(EP[:eTotalCap][r]) for r in R] .* sf,
        StartEnergyCap = [r in STOR_ALL ? existing_cap_mwh(gen[r]) : 0.0 for r in R] .* sf,
        NewEnergyCap = [r in NEW_CAP_ENERGY ? value(EP[:vCAPENERGY][r]) : 0.0 for r in R] .* sf,
        EndEnergyCap = [r in STOR_ALL ? value(EP[:eTotalCapEnergy][r]) : 0.0 for r in R] .* sf,
        InvestmentCost_MW = [inv_cost_per_mwyr(gen[r]) for r in R] .* sf,
        InvestmentCost_MWh = [r in STOR_ALL ? inv_cost_per_mwhyr(gen[r]) : 0.0 for r in R] .* sf,
        DeltaInvestmentCost_MW = [get(dmw, r, 0.0) for r in R] .* sf,
        DeltaInvestmentCost_MWh = [get(dmwh, r, 0.0) for r in R] .* sf,
        ResExposure = [value(EP[:eResExposure][r]) for r in R] .* sf^2,
        p_ic = [value(EP[:p_ic][r]) for r in R] .* sf^2,
        DualRes_SIC = [ro_dual(EP, setup, EP[:cDualResSic][r]) for r in R])
    df[!, :Gamma] .= ro_effective_gamma(inputs["ro_settings"],
        "BudgetOfUncertainty_InvestmentCost")
    CSV.write(joinpath(path, "ro_investment_cost.csv"), df)
end

# ---------------------------------------------------------------------------
# Fixed O&M cost (one row per uncertain resource)
# ---------------------------------------------------------------------------
function write_ro_fixed_om_cost(path::AbstractString, inputs::Dict, setup::Dict,
        EP::AbstractModel)
    haskey(EP, :p_fxc) || return nothing
    gen = inputs["RESOURCES"]
    R = inputs["RO_FOM"]
    STOR_ALL = Set(inputs["STOR_ALL"])
    sf = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
    dmw = inputs["delta_fixed_om_costs"]
    dmwh = inputs["delta_fixed_om_costs_energy"]

    df = DataFrame(Resource = [resource_name(gen[r]) for r in R],
        StartCapacity = [existing_cap_mw(gen[r]) for r in R] .* sf,
        EndCapacity = [value(EP[:eTotalCap][r]) for r in R] .* sf,
        StartEnergyCap = [r in STOR_ALL ? existing_cap_mwh(gen[r]) : 0.0 for r in R] .* sf,
        EndEnergyCap = [r in STOR_ALL ? value(EP[:eTotalCapEnergy][r]) : 0.0 for r in R] .* sf,
        FixedOMCost_MW = [fixed_om_cost_per_mwyr(gen[r]) for r in R] .* sf,
        FixedOMCost_MWh = [r in STOR_ALL ? fixed_om_cost_per_mwhyr(gen[r]) : 0.0 for r in R] .* sf,
        DeltaFixedOMCost_MW = [get(dmw, r, 0.0) for r in R] .* sf,
        DeltaFixedOMCost_MWh = [get(dmwh, r, 0.0) for r in R] .* sf,
        FOMExposure = [value(EP[:eFOMExposure][r]) for r in R] .* sf^2,
        p_fxc = [value(EP[:p_fxc][r]) for r in R] .* sf^2,
        DualRes_FXC = [ro_dual(EP, setup, EP[:cDualResFxc][r]) for r in R])
    df[!, :Gamma] .= ro_effective_gamma(inputs["ro_settings"],
        "BudgetOfUncertainty_FixedOMCost")
    CSV.write(joinpath(path, "ro_fixed_om_cost.csv"), df)
end

# ---------------------------------------------------------------------------
# Summary: one row per category plus a total. Total_v_star = value(eRODualObj).
# ---------------------------------------------------------------------------
function write_ro_summary(path::AbstractString, inputs::Dict, setup::Dict,
        EP::AbstractModel)
    ro = inputs["ro_settings"]
    sf2 = (setup["ParameterScale"] == 1 ? ModelScalingFactor : 1)^2
    shared = ro_shared_budget(ro)

    cats = [("MarketBuyPrices", :p_mb, :q_mb), ("MarketSellPrices", :p_ms, :q_ms),
        ("FuelsCost", :p_fc, :q_fc), ("InvestmentCost", :p_ic, :q_ic),
        ("FixedOMCost", :p_fxc, :q_fxc)]
    gamma_keys = Dict(c[3] => c[1] for c in RO_CATEGORIES)
    count_keys = Dict(c[3] => c[2] for c in RO_CATEGORIES)

    df = DataFrame(Category = String[], Gamma = Int[], NumUncertainParams = Int[],
        q = Float64[], Gamma_q = Float64[], Sum_p = Float64[], WorstCaseCost = Float64[])

    for (flag, psym, qsym) in cats
        ro[flag] == 1 || continue
        sum_p = haskey(EP, psym) ? sum(value.(EP[psym])) : 0.0
        gamma = ro_effective_gamma(ro, gamma_keys[flag])
        qv = shared ? NaN : (haskey(EP, qsym) ? value(EP[qsym]) : 0.0)
        gq = shared ? 0.0 : gamma * (isnan(qv) ? 0.0 : qv)
        push!(df, (flag, gamma, get(inputs, count_keys[flag], 0), qv * sf2,
            gq * sf2, sum_p * sf2, (gq + sum_p) * sf2))
    end
    if shared
        gamma = ro["BudgetOfUncertainty"]
        qv = value(EP[:q])
        push!(df, ("SharedBudget", gamma, sum(df.NumUncertainParams; init = 0),
            qv * sf2, gamma * qv * sf2, 0.0, gamma * qv * sf2))
    end
    total = value(EP[:eRODualObj])
    push!(df, ("Total", -1, sum(df.NumUncertainParams[1:end-(shared ? 1 : 0)]; init = 0),
        NaN, sum(df.Gamma_q), sum(df.Sum_p), total * sf2))

    CSV.write(joinpath(path, "ro_summary.csv"), df)
    println("RO worst-case added cost v* = ", round(total * sf2; digits = 2), " \$")
    return nothing
end

# ---------------------------------------------------------------------------
# Master dispatcher
# ---------------------------------------------------------------------------
function write_ro(path::AbstractString, inputs::Dict, setup::Dict, EP::AbstractModel)
    ro = inputs["ro_settings"]
    ro["MarketBuyPrices"] == 1 && haskey(EP, :p_mb) &&
        write_ro_market(path, inputs, setup, EP, :buy)
    ro["MarketSellPrices"] == 1 && haskey(EP, :p_ms) &&
        write_ro_market(path, inputs, setup, EP, :sell)
    ro["FuelsCost"] == 1 && write_ro_fuel_cost(path, inputs, setup, EP)
    ro["InvestmentCost"] == 1 && write_ro_investment_cost(path, inputs, setup, EP)
    ro["FixedOMCost"] == 1 && write_ro_fixed_om_cost(path, inputs, setup, EP)
    write_ro_summary(path, inputs, setup, EP)
    return nothing
end
