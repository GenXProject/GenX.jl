# Small New England: Three Zones

**SimpleCase**, a one-year example with hourly resolution, contains zones representing Massachusetts, Connecticut, and Maine. The ten represented resources include only natural gas, solar PV, wind, and lithium-ion battery storage.

To run the model, first navigate to the example directory at `GenX/examples/SmallNewEngland_ThreeZones/SimpleCase`:

`cd("examples/SmallNewEngland_ThreeZones/SimpleCase")`
   
Next, ensure that your settings in `Settings/GenX_settings.yml` are correct. The default settings use the solver HiGHS (`Solver: HiGHS`), time domain reduced input data (`TimeDomainReduction: 1`). Other optional policies include minimum capacity requirements, a capacity reserve margin, and more. A rate-based carbon cap of 50 gCO<sub>2</sub> per kWh is specified in the `Policies/CO2_cap.csv` input file.

Once the settings are confirmed, run the model with the `Run.jl` script in the example directory:

`include("Run.jl")`

Once the model has completed, results will write to the `Results` directory.
