# Three Zones with Retrofit

This is a one-year example with hourly resolution which contains zones representing Massachusetts, Connecticut, and Maine. The twenty-two represented resources include natural gas, solar PV, wind, lithium-ion battery, and coal power plants. 
This examples shows the usage of the retrofit module of GenX, and the model will be allowed to retire as well as retrofit the existing coal power plants and replacing the coal with blue ammonia with 85% efficiency. 
To run the model, first navigate to the example directory:

- Using a Julia REPL:

```bash
$ julia
julia> cd("example_systems/8_three_zone_w_retrofit/")
```

- Using a terminal or command prompt:
```bash
$ cd example_systems/8_three_zone_w_retrofit/
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