# Three Zones with Robust Investment Costs

**Three Zones with Robust Investment Costs** is the three-zone system (Massachusetts, Connecticut and Maine) with the ten resources: natural gas, solar PV, wind and lithium-ion battery storage. It adds robust optimization (RO) on **investment costs**. The model chooses capacity that stays cost-effective when up to Γ resources have investment costs above their nominal values.

## How the robust optimization works

Each uncertain cost can rise above its nominal value by up to a given deviation (its *delta*). The **budget of uncertainty** Γ is an integer: the **number of uncertain parameters** allowed to be at their worst case at the same time. The model adds the worst-case extra cost for that budget to the objective:

- `Γ = 0`: no cost deviates, so the result is the deterministic GenX solution.
- `Γ = N` (all uncertain parameters): every cost is at its worst case.
- Values in between give intermediate levels of protection.

For investment costs, each resource is **one** uncertain parameter. A storage resource's MW and MWh investment costs deviate together.

## RO inputs

RO is switched on in `settings/genx_settings.yml` with `RO: 1`. Its inputs are in the `tools/` folder:

- `tools/ro_settings.yml` selects which costs are uncertain and sets the budget:

  ```yaml
  BudgetOfUncertainty: 4    # shared Γ over all active categories (-1 = use per-category budgets)
  InvestmentCost: 1         # 1 = investment costs are uncertain
  FixedOMCost: 0
  FuelsCost: 0
  MarketBuyPrices: 0
  MarketSellPrices: 0
  ```

  With `BudgetOfUncertainty: -1`, each active category uses its own budget: `BudgetOfUncertainty_InvestmentCost`, `BudgetOfUncertainty_FixedOMCost`, `BudgetOfUncertainty_FuelPrices`, `BudgetOfUncertainty_MarketBuyPrices` and `BudgetOfUncertainty_MarketSellPrices`.

- `tools/Investment_cost_bounds.csv` gives the deviation of each resource's investment cost, in the same units as the resource files:

  | Column | Meaning |
  |---|---|
  | `Resource` | Resource name, as in the `resources/` files |
  | `Inv_Cost_per_MWyr_bounds` | Deviation of `Inv_Cost_per_MWyr` ($/MW-yr) |
  | `Inv_Cost_per_MWhyr_bounds` | Deviation of `Inv_Cost_per_MWhyr` ($/MWh-yr, storage only) |

  Resources not listed, or listed with zero deviations, are treated as certain.

Other categories use `Fixed_OM_cost_bounds.csv` and `Fuels_cost_bounds.csv`. Fuel bounds are hourly: give the full time series, and with `TimeDomainReduction: 1` GenX writes the representative-period rows to `TDR_results/tools/`. If you change a bounds file after `TDR_results` has been created, delete `TDR_results` so it is regenerated.

## Running the example

Navigate to the example directory:

- Using a Julia REPL:

```bash
$ julia
julia> cd("example_systems/14_three_zones_ro_investment_cost/")
```

- Using a terminal or command prompt:

```bash
$ cd example_systems/14_three_zones_ro_investment_cost/
```

The default settings use the solver `HiGHS`, time domain reduced input data (`TimeDomainReduction: 1`) and a minimum capacity requirement policy (`MinCapReq: 1`) from `policies/Minimum_capacity_requirement.csv`. Run the model with `Run.jl`:

- Using a Julia REPL (recommended):

```julia
julia> include("Run.jl")
```

- Using a terminal or command prompt:

```bash
$ julia Run.jl
```

## RO outputs

Besides the standard GenX outputs, the `results` directory contains:

- `ro_investment_cost.csv`: for each uncertain resource, its capacities, nominal cost, deviation, cost exposure (`ResExposure`) and `DualRes_SIC`. A dual of 1 means the resource's cost is at its worst case.
- `ro_summary.csv`: Γ, the number of uncertain parameters and the worst-case added cost (`WorstCaseCost`, in $) for each category, plus the total.

To see the effect of the budget, rerun with different values of `BudgetOfUncertainty` (for example 0, 2, 4 and 10) and compare total costs and capacity mixes.
