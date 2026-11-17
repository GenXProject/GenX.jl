@doc raw"""
    ro!(EP::AbstractModel, inputs::Dict, setup::Dict)

Robust optimization (Bertsimas–Sim budget of uncertainty) dual reformulation.

Each uncertain cost coefficient ``c_i`` can deviate from its nominal value by up to
``\hat{c}_i`` (the "delta" read from the `tools` folder). At most ``\Gamma`` of them
(an integer **number of uncertain parameters**) are allowed to take their worst-case
value simultaneously. The worst-case added cost

```math
\max_{S, |S| \le \Gamma} \sum_{i \in S} \hat{c}_i x_i
```

is replaced by its LP dual:

```math
\min \; \Gamma q + \sum_i p_i \quad \text{s.t.} \quad q + p_i \ge \hat{c}_i x_i, \; q \ge 0, \; p_i \ge 0
```

and ``\Gamma q + \sum_i p_i`` is added to the objective (`eRODualObj`).

Two modes are available (see `ro_settings.yml`):

  * `BudgetOfUncertainty >= 0`: a single shared budget ``\Gamma`` (and a single `q`) over
    the union of all parameters of all active categories.
  * `BudgetOfUncertainty = -1`: each active category has its own budget
    `BudgetOfUncertainty_<Category>` and its own `q_<suffix>` variable.

All exposures are expressed in annual objective units (hourly terms are weighted by
`omega`), so they are comparable across categories when the budget is shared.
"""
function ro!(EP::AbstractModel, inputs::Dict, setup::Dict)
    println("Robust Optimization Module")
    ro_settings = inputs["ro_settings"]

    @expression(EP, eRODualObj, AffExpr(0.0))

    if ro_shared_budget(ro_settings)
        @variable(EP, q>=0)
        add_to_expression!(EP[:eRODualObj], ro_settings["BudgetOfUncertainty"], EP[:q])
    end

    ro_settings["MarketBuyPrices"] == 1 && ro_markets_buy!(EP, inputs, setup)
    ro_settings["MarketSellPrices"] == 1 && ro_markets_sell!(EP, inputs, setup)
    ro_settings["FuelsCost"] == 1 && ro_fuels_cost!(EP, inputs, setup)
    ro_settings["InvestmentCost"] == 1 && ro_investment_cost!(EP, inputs, setup)
    ro_settings["FixedOMCost"] == 1 && ro_fixed_om_cost!(EP, inputs, setup)

    add_to_expression!(EP[:eObj], EP[:eRODualObj])

    return nothing
end

ro_shared_budget(ro_settings::Dict) = ro_settings["BudgetOfUncertainty"] >= 0

@doc raw"""
    ro_configure_multi_stage!(inputs::Dict, settings_d::Dict)

Multi-stage (non-myopic) only, called from `configure_multi_stage_inputs`: convert the
annualized investment-cost deltas into truncated overnight capital costs, using the same
factor (`overnight_capital_cost_factor`) and capital recovery period as the nominal
`Inv_Cost_per_MWyr` / `Inv_Cost_per_MWhyr`.

Fixed O&M, fuel and market deltas need no conversion. They are added to the stage
objective as annual costs, and DDP multiplies the whole stage objective by `OPEXMULT`, which
is how the nominal fixed O&M and operating costs are treated as well.
"""
function ro_configure_multi_stage!(inputs::Dict, settings_d::Dict)
    haskey(inputs, "delta_investment_costs") || return nothing
    gen = inputs["RESOURCES"]
    for key in ("delta_investment_costs", "delta_investment_costs_energy")
        d = inputs[key]
        for y in keys(d)
            d[y] *= only(overnight_capital_cost_factor(settings_d,
                [capital_recovery_period(gen[y])]))
        end
    end
    return nothing
end

"""
    ro_effective_gamma(ro_settings, gamma_key)

Budget that applies to a category: the shared budget if one is set, otherwise the
category's own budget.
"""
function ro_effective_gamma(ro_settings::Dict, gamma_key::AbstractString)
    ro_shared_budget(ro_settings) ? ro_settings["BudgetOfUncertainty"] :
    ro_settings[gamma_key]
end

"""
    ro_budget_q!(EP, ro_settings, gamma_key, suffix)

Return the budget dual variable `q` a category should use. In shared mode this is
`EP[:q]`. In per-category mode a new `q_<suffix>` is created and `Γ_c q_c` is added
to `eRODualObj`. Returns `nothing` when the category budget is 0 (no deviation allowed,
i.e. deterministic), in which case the category adds nothing to the model.
"""
function ro_budget_q!(EP::AbstractModel, ro_settings::Dict, gamma_key::AbstractString,
        suffix::AbstractString)
    ro_shared_budget(ro_settings) && return EP[:q]

    Gamma = ro_settings[gamma_key]
    Gamma > 0 || return nothing

    qsym = Symbol("q_", suffix)
    EP[qsym] = @variable(EP, lower_bound=0, base_name=string(qsym))
    add_to_expression!(EP[:eRODualObj], Gamma, EP[qsym])
    return EP[qsym]
end

function ro_markets_buy!(EP::AbstractModel, inputs::Dict, setup::Dict)
    println("Applying robust optimization to market buy prices")
    q = ro_budget_q!(EP, inputs["ro_settings"], "BudgetOfUncertainty_MarketBuyPrices", "mb")
    isnothing(q) && return nothing

    haskey(EP, :vMBUY) ||
        error("RO on market buy prices requires the market module (variable vMBUY), which is not part of this model.")

    T = inputs["T"]
    MZ = inputs["MZ"]
    omega = inputs["omega"]
    Delta = inputs["Market_BuyPrices_Delta"]

    @variable(EP, p_mb[m in MZ, t = 1:T]>=0)
    @constraint(EP, cDualSmb[m in MZ, t = 1:T],
        q + p_mb[m, t]>=omega[t] * Delta[m, t] * EP[:vMBUY][m, t])
    add_to_expression!(EP[:eRODualObj], sum(p_mb))
    return nothing
end

function ro_markets_sell!(EP::AbstractModel, inputs::Dict, setup::Dict)
    println("Applying robust optimization to market sell prices")
    q = ro_budget_q!(EP, inputs["ro_settings"], "BudgetOfUncertainty_MarketSellPrices", "ms")
    isnothing(q) && return nothing

    haskey(EP, :vMSELL) ||
        error("RO on market sell prices requires the market module (variable vMSELL), which is not part of this model.")

    T = inputs["T"]
    MZ = inputs["MZ"]
    omega = inputs["omega"]
    Delta = inputs["Market_SellPrices_Delta"]

    # Worst case for sales is a price *drop*: lost revenue = Delta * vMSELL.
    @variable(EP, p_ms[m in MZ, t = 1:T]>=0)
    @constraint(EP, cDualSms[m in MZ, t = 1:T],
        q + p_ms[m, t]>=omega[t] * Delta[m, t] * EP[:vMSELL][m, t])
    add_to_expression!(EP[:eRODualObj], sum(p_ms))
    return nothing
end

function ro_fuels_cost!(EP::AbstractModel, inputs::Dict, setup::Dict)
    println("Applying robust optimization to fuel costs")
    q = ro_budget_q!(EP, inputs["ro_settings"], "BudgetOfUncertainty_FuelPrices", "fc")
    isnothing(q) && return nothing

    T = inputs["T"]
    gen = inputs["RESOURCES"]
    omega = inputs["omega"]
    fuels = inputs["fuels"]
    Delta = inputs["delta_fuel_costs"]

    # vFuel / vStartFuel only exist for single-fuel resources
    resources_by_fuel = Dict(f => Int[] for f in fuels)
    for y in inputs["SINGLE_FUEL"]
        push!(get!(resources_by_fuel, fuel(gen[y]), Int[]), y)
    end

    @expression(EP, eFuelExposure[f in fuels, t = 1:T],
        omega[t] * Delta[f, t] *
        sum(EP[:vFuel][y, t] + EP[:vStartFuel][y, t] for y in resources_by_fuel[f];
            init = AffExpr(0.0)))

    @variable(EP, p_fc[f in fuels, t = 1:T]>=0)
    @constraint(EP, cDualSfc[f in fuels, t = 1:T], q + p_fc[f, t]>=eFuelExposure[f, t])
    add_to_expression!(EP[:eRODualObj], sum(p_fc))
    return nothing
end

function ro_investment_cost!(EP::AbstractModel, inputs::Dict, setup::Dict)
    println("Applying robust optimization to investment cost (MW + MWh of a resource form one uncertain parameter)")
    q = ro_budget_q!(EP, inputs["ro_settings"], "BudgetOfUncertainty_InvestmentCost", "ic")
    isnothing(q) && return nothing

    gen = inputs["RESOURCES"]
    COMMIT = inputs["COMMIT"]
    RO_INV = inputs["RO_INV"]                       # resources with nonzero delta
    delta_mw = inputs["delta_investment_costs"]          # keyed by y in NEW_CAP
    delta_mwh = inputs["delta_investment_costs_energy"]  # keyed by y in NEW_CAP_ENERGY

    # Multi-stage: the deltas are overnight costs (ro_configure_multi_stage!). Like the nominal
    # investment cost they are divided by OPEXMULT, because DDP multiplies the whole stage
    # objective by OPEXMULT. OPEXMULT = 1 for myopic runs.
    inv_mult = setup["MultiStage"] == 1 ? 1 / inputs["OPEXMULT"] : 1.0

    # Same structure as eCInvCap / eCInvEnergyCap in GenX
    function exposure(y)
        ex = AffExpr(0.0)
        if haskey(delta_mw, y)
            unit_size = y in COMMIT ? cap_size(gen[y]) : 1.0
            add_to_expression!(ex, delta_mw[y] * unit_size * inv_mult, EP[:vCAP][y])
        end
        if haskey(delta_mwh, y)
            add_to_expression!(ex, delta_mwh[y] * inv_mult, EP[:vCAPENERGY][y])
        end
        return ex
    end

    @expression(EP, eResExposure[y in RO_INV], exposure(y))
    @variable(EP, p_ic[y in RO_INV]>=0)
    @constraint(EP, cDualResSic[y in RO_INV], q + p_ic[y]>=eResExposure[y])
    add_to_expression!(EP[:eRODualObj], sum(p_ic; init = AffExpr(0.0)))
    return nothing
end

function ro_fixed_om_cost!(EP::AbstractModel, inputs::Dict, setup::Dict)
    println("Applying robust optimization to fixed O&M cost (MW + MWh of a resource form one uncertain parameter)")
    q = ro_budget_q!(EP, inputs["ro_settings"], "BudgetOfUncertainty_FixedOMCost", "fxc")
    isnothing(q) && return nothing

    RO_FOM = inputs["RO_FOM"]                       # resources with nonzero delta
    delta_mw = inputs["delta_fixed_om_costs"]            # keyed by resource id
    delta_mwh = inputs["delta_fixed_om_costs_energy"]    # keyed by storage resource id

    # Same structure as eCFix / eCFixEnergy in GenX (applied to total capacity)
    function exposure(y)
        ex = AffExpr(0.0)
        if haskey(delta_mw, y)
            add_to_expression!(ex, delta_mw[y], EP[:eTotalCap][y])
        end
        if haskey(delta_mwh, y)
            add_to_expression!(ex, delta_mwh[y], EP[:eTotalCapEnergy][y])
        end
        return ex
    end

    @expression(EP, eFOMExposure[y in RO_FOM], exposure(y))
    @variable(EP, p_fxc[y in RO_FOM]>=0)
    @constraint(EP, cDualResFxc[y in RO_FOM], q + p_fxc[y]>=eFOMExposure[y])
    add_to_expression!(EP[:eRODualObj], sum(p_fxc; init = AffExpr(0.0)))
    return nothing
end
