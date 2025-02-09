# Three Zones with Allam Cycle Lox

**Three Zones with Allam Cycle Lox**, a one-year example with hourly resolution, contains zones representing Massachusetts, Connecticut, and Maine. The thirteen represented resources include natural gas, solar PV, wind, lithium-ion battery storage, and Allam Cycle Lox.

To run the model, first navigate to the example directory:

- Using a Julia REPL:

```bash
$ julia
julia> cd("example_systems/11_three_zones_w_allam_cycle_lox")
```

- Using a terminal or command prompt:
```bash
$ cd example_systems/11_three_zones_w_allam_cycle_lox
``` 
   
Next, ensure that your settings in `settings/genx_settings.yml` are correct. The default settings use the solver `HiGHS`, and time domain reduced input data (`TimeDomainReduction: 1`). Optional policies include a capacity reserve margin, an energy share requirement (such as renewable portfolio standard (RPS) or clean electricity standard (CES) policies), a maximum and minimum capacity requirement policy (see the documentation for more details). Each policy is specified in the corresponding file inside the `policies` folder. For this example, a mass-based carbon cap of 50 gCO<sub>2</sub> per kWh is specified in the `policies/CO2_cap.csv` input file.

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
