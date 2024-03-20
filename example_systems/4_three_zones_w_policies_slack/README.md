# Three Zones, Slack Variables Example

This is a one-year example with hourly resolution which contains zones representing Massachusetts, Connecticut, and Maine. It is designed to show how to use slack variables to meet a policy constraint if it cannot be met cost-effectively by normal means. The ten represented resources include natural gas, solar PV, wind, and lithium-ion battery storage. It additionally contains example input files (inside the `policies` folder) establishing slack variables for policy constraints (e.g. the Capacity Reserve Margin, CO2 Cap, etc.). These slack variables allow the relevant constraints to be violated at the cost of a specified objective function penalty, which can be used to either identify problematic constraints without causing infeasibilities in GenX, or to set price caps beyond which policies are no longer enforced. These slack variables will only be created if the relevant input data (`Capacity_reserve_margin_slack.csv`, `CO2_cap_slack.csv`, `Energy_share_requirement_slack.csv`, or the `PriceCap` column in `Minimum_capacity_requirement.csv` and `Maximum_capacity_requirement.csv`) are present. If any of these inputs are not present, GenX will instantiate the relevant policy as a hard constraint, which will throw an infeasibility error if violated.

To run the model, first navigate to the example directory:

- Using a Julia REPL:

```bash
$ julia
julia> cd("example_systems/4_three_zones_w_policies_slack/")
```

- Using a terminal or command prompt:
```bash
$ cd example_systems/4_three_zones_w_policies_slack/
``` 
   
Next, ensure that your settings in `settings/GenX_settings.yml` are correct. The default settings use the solver `HiGHS`, time domain reduced input data (`TimeDomainReduction: 1`), minimum and maximum capacity requirement policies (`MinCapReq: 1`, `MaxCapReq: 1`), a capacity reserve margin, an energy share requirement (such as renewable portfolio standard (RPS) or clean electricity standard (CES) policies), and a CO2 emissions cap. Each policy is specified in the corresponding file inside the `policies` folder.  

Once the settings are confirmed, run the model with the `Run.jl` script in the example directory:

- Using a Julia REPL (recommended)
```julia
julia> include("Run.jl")
```
- Using a terminal or command prompt:
```bash
$ julia Run.jl
```

Once the model has completed, results will write to the `results` directory.