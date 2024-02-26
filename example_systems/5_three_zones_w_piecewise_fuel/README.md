# Small New England: Three Zones with piecewise fuel consumption

**PWFuel** a one-year example with hourly resolution, contains zones representing Massachusetts, Connecticut, and Maine. The ten represented resources include only natural gas, solar PV, wind, and lithium-ion battery storage and biomass with ccs. For natural gas ccs generator, we provide picewise fuel usage (PWFU) parameters to represent the fuel consumption at differernt load point. When settings["UCommit"] >= 1 and PWFU parameters are provided in "Thermal.csv", the standard heat rate (i.e., Heat_Rate_MMBTU_per_MWh). 

To run the model, first navigate to the example directory at `GenX/examples/SmallNewEngland_ThreeZones/PWFuel`:

`cd("examples/SmallNewEngland_ThreeZones/PWFuel")`
   
Next, ensure that your settings in `Settings/GenX_settings.yml` are correct. The linear clustering unit commitment method (settings["UCommit"] = 2) is used. The default settings use the solver HiGHS (`Solver: HiGHS`) and time domain reduced input data (`TimeDomainReduction: 1`). A mass-based carbon cap of 0 t CO<sub>2</sub> (net-zero) is specified in the `CO2_cap.csv` input file. 

Once the settings are confirmed, run the model with the `Run.jl` script in the example directory:

`include("Run.jl")`

Once the model has completed, results will write to the `Results` directory.