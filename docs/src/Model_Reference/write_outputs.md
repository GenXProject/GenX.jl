# Functions for Writing the Different Results/Outputs to Separate Files
```@autodocs
Modules = [GenX]
Pages = ["write_outputs.jl", "choose_output_dir.jl", "dftranspose.jl"]
```

## Write Status
```@autodocs
Modules = [GenX]
Pages = ["write_status.jl"]
```

## Write CO_2 Cap
```@docs
GenX.write_co2_cap
```

## Write Costs
```@autodocs
Modules = [GenX]
Pages = ["write_costs.jl"]
```

## Write Fuel Consumption
```@docs
GenX.write_fuel_consumption
```

## Write Emissions
```@autodocs
Modules = [GenX]
Pages = ["write_emissions.jl"]
```

## Write Capacities
```@autodocs
Modules = [GenX]
Pages = ["write_capacity.jl"]
```

## Write Capacity Value
```@autodocs
Modules = [GenX]
Pages = ["write_capacity_value.jl"]
```

## Write Capacity Factors
```@autodocs
Modules = [GenX]
Pages = ["write_capacityfactor.jl"]
```

## Write Charge Values
```@autodocs
Modules = [GenX]
Pages = ["write_charge.jl"]
```

## Write Non-served-energy
```@autodocs
Modules = [GenX]
Pages = ["write_nse.jl"]
```

## Write Storage State of Charge
```@autodocs
Modules = [GenX]
Pages = ["write_storage.jl"]
```

## Write Storage Dual
```@autodocs
Modules = [GenX]
Pages = ["write_storagedual.jl"]
```

## Write Power
```@autodocs
Modules = [GenX]
Pages = ["write_power.jl"]
```

## Write Curtailment
```@autodocs
Modules = [GenX]
Pages = ["write_curtailment.jl"]
```

## Write Prices
```@autodocs
Modules = [GenX]
Pages = ["write_price.jl"]
```

## Write Reliability
```@autodocs
Modules = [GenX]
Pages = ["write_reliability.jl"]
```
## Write Energy Revenue
```@autodocs
Modules = [GenX]
Pages = ["write_energy_revenue.jl"]
```

## Write Subsidy Revenue
```@autodocs
Modules = [GenX]
Pages = ["write_subsidy_revenue.jl"]
```

## Write Operating Reserve and Regulation Revenue
```@autodocs
Modules = [GenX]
Pages = ["write_operating_reserve_price_revenue.jl"]
```

## Write Capacity Revenue
```@autodocs
Modules = [GenX]
Pages = ["write_reserve_margin_revenue.jl"]
```

## Write Hourly Matching Revenue
```@docs
GenX.write_hourly_matching_prices
GenX.write_hourly_matching_revenue
GenX.write_hourly_matching_slack
```

## Write Energy Share Requirement Revenue
```@autodocs
Modules = [GenX]
Pages = ["write_esr_revenue.jl"]
```

## Write Net Revenue
```@autodocs
Modules = [GenX]
Pages = ["write_net_revenue.jl"]
```

## Write Co-Located VRE and Storage files
```@docs
GenX.write_vre_stor
GenX.write_vre_stor_capacity
GenX.write_vre_stor_charge
GenX.write_vre_stor_discharge
```

## Write Multi-stage files
```@autodocs
Modules = [GenX]
Pages = ["write_multi_stage_outputs.jl"]
```
```@docs
GenX.write_multi_stage_costs
GenX.write_multi_stage_stats
GenX.write_multi_stage_settings
GenX.write_multi_stage_network_expansion
GenX.write_multi_stage_capacities_discharge
GenX.write_multi_stage_capacities_charge
GenX.write_multi_stage_capacities_energy
GenX.create_multi_stage_stats_file
GenX.update_multi_stage_stats_file
```

## Write maintenance files
```@autodocs
Modules = [GenX]
Pages = ["write_maintenance.jl"]
```

## Write DCOPF files
```@docs
GenX.write_angles
```

## Write Settings Files
```@docs
GenX.write_settings_file
```

## Write Allam Cycle LOX
```@docs
GenX.write_allam_capacity
GenX.write_allam_output
```

## Write Transmission Outputs
When discrete new lines are present (`DiscreteInvestments = 1`), `load_network_data!` gives each
candidate line its own row, so the solved model has more lines than the user's `Network.csv`. These
writers fold the expanded lines back onto the original corridors using
`inputs["LINE_MAP_ORIGINAL"]`, so the outputs are indexed by the corridors the user supplied. See
[DC-OPF and Transmission Expansion](@ref).
```@autodocs
Modules = [GenX]
Pages = ["write_transmission_flows.jl", "write_transmission_losses.jl", "write_nw_expansion.jl"]
```

## Write Benders Decomposition Outputs
```@autodocs
Modules = [GenX]
Pages = ["write_benders_output.jl", "write_planning_problem_costs.jl"]
```
