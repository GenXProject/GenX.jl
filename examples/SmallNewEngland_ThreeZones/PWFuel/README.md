# ThreeZones_PWFuel

**ThreeZones_PWFuel** a one-year example with hourly resolution, contains zones representing Massachusetts, Connecticut, and Maine. The ten represented resources include only natural gas, solar PV, wind, and lithium-ion battery storage and biomass with ccs. For natural gas ccs generator, we provide picewise fuel usage (PWFU) parameters to represent the fuel consumption at differernt load point. When settings["UCommit"] >= 1 and PWFU parameters are provided in "Thermal.csv", the standard heat rate (i.e., Heat_Rate_MMBTU_per_MWh). 

To run the model, first navigate to the example directory at `GenX/Example_Systems/PiecewiseFuel_CO2`:

`cd("Example_Systems/PiecewiseFuel_CO2")`
   
Next, ensure that your settings in `GenX_settings.yml` are correct.  The linear clustering unit commitment method (settings["UCommit"] = 2) is used. The default settings use the solver HiGHS (`Solver: HiGHS`) and time domain reduced input data (`TimeDomainReduction: 1`). A mass-based carbon cap of 0 t CO<sub>2</sub> (net-zero) is specified in the `CO2_cap.csv` input file. 

Once the settings are confirmed, run the model with the `Run.jl` script in the example directory:

`cd("examples/SmallNewEngland/ThreeZones_PWFuel")`
`include("Run.jl")`

Once the model has completed, results will write to the `Results` directory.