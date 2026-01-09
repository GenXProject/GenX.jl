# Three Zones with electrolyzer

This is a one-year example with hourly resolution which contains three zones representing Massachusetts, Connecticut, and Maine. It is designed to show the electrolyzer feature in GenX. The sixteen represented resources include natural gas, solar PV, wind, electrolyzer and lithium-ion battery storage.

To run the model, first navigate to the example directory:

- Using a Julia REPL:

```bash
$ julia
julia> cd("example_systems/2_three_zones_w_electrolyzer/")
```

- Using a terminal or command prompt:
```bash
$ cd example_systems/2_three_zones_w_electrolyzer/
``` 
   
Next, ensure that your settings in `settings/GenX_settings.yml` are correct. The default settings use the solver `HiGHS`, time domain reduced input data (`TimeDomainReduction: 1`), regional requirements for hydrogen production (`HydrogenMinimumProduction: 1`), and minimum capacity requirement policy (`MinCapReq: 1`) as specified in the `policies/Minimum_capacity_requirement.csv` file. Other optional policies include a capacity reserve margin, an energy share requirement (such as renewable portfolio standard (RPS) or clean electricity standard (CES) policies), a CO2 emissions cap, and a maximum capacity requirement policy (see the documentation for more details). 

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

