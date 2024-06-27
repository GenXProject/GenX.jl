# Three Zones with co-located VRE+Storage+Electrolyzers

This example system shows the functionalities of the colocated VRE+storage+Electrolyzer module of GenX. It runs a three-zone, 1,680-hour continental US model, with a carbon constraint and with a long duration energy storage resource that the model can choose to co-locate with either solar or wind. In this case, the storage resource is forced in via minimum and maximum capacity requirement constraints, but these constraints could be easily removed (although the storage resource has a cost of zero in this case so a cost would have to be added). 

To run the model, first navigate to the example directory:

- Using a Julia REPL:

```bash
$ julia
julia> cd("example_systems/7_three_zones_w_colocated_VRE_storage/")
```

- Using a terminal or command prompt:
```bash
$ cd example_systems/8_three_zones_w_colocated_VRE_storage_electrolyzers/
``` 
   
Next, ensure that your settings in `settings/genx_settings.yml` are correct. The linear clustering unit commitment method (settings["UCommit"] = 2) is used. The default settings use the solver `HiGHS`, time domain reduced input data (`TimeDomainReduction: 0`) minimum and maximum capacity requirement policies (`MinCapReq: 1`, `MaxCapReq: 1`), a capacity reserve margin, an energy share requirement (such as renewable portfolio standard (RPS) or clean electricity standard (CES) policies), and a CO2 emissions cap (see the documentation for more details). Each policy is specified in the corresponding file inside the `policies` folder. A mass-based carbon cap of 50 gCO<sub>2</sub> per kWh is specified in the `policies/CO2_cap.csv` input file.

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
