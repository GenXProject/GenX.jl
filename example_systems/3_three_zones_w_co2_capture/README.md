# Three Zones with CO2 capture

This is a one-year example with hourly resolution which contains zones representing Massachusetts, Connecticut, and Maine. The ten represented resources include natural gas, solar PV, wind, and lithium-ion battery storage and biomass with carbon capture and storage. 
This examples shows the usage of CO2, biomass, and piecewise fuel usage related functions of GenX. 

To run the model, first navigate to the example directory:

- Using a Julia REPL:

```bash
$ julia
julia> cd("example_systems/3_three_zone_w_co2_capture//")
```

- Using a terminal or command prompt:
```bash
$ cd example_systems/3_three_zone_w_co2_capture/
``` 
   
Next, ensure that your settings in `settings/genx_settings.yml` are correct. The linear clustering unit commitment method (settings["UCommit"] = 2) is used. The default settings use the solver `HiGHS`, time domain reduced input data (`TimeDomainReduction: 1`) and minimum capacity requirement policy (`MinCapReq: 1`) as specified in the `policies/Minimum_capacity_requirement.csv` file. Other optional policies include a capacity reserve margin, an energy share requirement (such as renewable portfolio standard (RPS) or clean electricity standard (CES) policies), a CO2 emissions cap, and a maximum capacity requirement policy (see the documentation for more details). A mass-based carbon cap of 50 gCO<sub>2</sub> per kWh is specified in the `policies/CO2_cap.csv` input file.

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