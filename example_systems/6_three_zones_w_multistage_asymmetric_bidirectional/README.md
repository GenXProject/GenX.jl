# Three Zones Multi-Stage

This is a toy multi-stage example with hourly resolution which contains zones representing Massachusetts, Connecticut, and Maine. It is designed to show how to run multi-stage investment planning models. The ten represented resources include natural gas, solar PV, wind, and lithium-ion battery storage.

To run the model, first navigate to the example directory:

- Using a Julia REPL:

```bash
$ julia
julia> cd("example_systems/6_three_zones_w_multistage/")
```

- Using a terminal or command prompt:
```bash
$ cd example_systems/6_three_zones_w_multistage/
``` 
   
Next, ensure that your settings in `settings/genx_settings.yml` are correct. The default settings use the solver HiGHS and time domain reduced input data (`TimeDomainReduction: 1`). 

The `settings/multi_stage_settings.yml` file contains settings parameters specific to multi-stage modeling. This example is configured for three model periods (`NumPeriods: 3`) of 10 years in length each (`PeriodLength: 10`).

Multi-period modeling in GenX requires a separate set of model inputs for each period to be modeled, which are located in the directories `inputs/inputs_p$`, where `$` is the number of the model period. Although separate model periods can have different costs and policy parameters, the resources names and types, specified in each resource `.csv` files (included in the `resources` folder) must be identical across model periods. In addition, multi-stage modeling with a single zone requires an additional input file, `Resource_multistage_data.csv`, also located in the `resources` directory, which contains fields related to resource lifetimes, capital recovery periods, and endogenous retirements.

A rate-based carbon cap becomes more stringent across the three model periods and for each zone, declining from of 1,000 gCO<sub>2</sub> per kWh in the first period, 500  gCO<sub>2</sub> per kWh in the second period, and  50 gCO<sub>2</sub> per kWh in the third period, as specified in the `policies/CO2_cap.csv` input files in `inputs/inputs_p1`, `inputs/inputs_p2`, and `inputs/inputs_p3` respectively.

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