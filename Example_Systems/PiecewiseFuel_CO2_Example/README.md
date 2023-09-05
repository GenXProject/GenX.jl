# PiecewiseFuel_CO2: One Zone

**PiecewiseFuel_CO2** is set of a simplified versions of the more detailed example system RealSystemExample. It is condensed for easy comprehension and quick testing of different components of the GenX. **PiecewiseFuel_CO2** is our most basic model, a one-year example with hourly resolution containing only one zone representing New England. The model includes only natural gas, solar PV, wind, and lithium-ion battery storage with no initial capacity. 

To run the model, first navigate to the example directory at `GenX/Example_Systems/PiecewiseFuel_CO2`:

`cd("Example_Systems/PiecewiseFuel_CO2")`
   
Next, ensure that your settings in `GenX_settings.yml` are correct. The default settings use the solver HiGHS (`Solver: HiGHS`), time domain reduced input data (`TimeDomainReduction: 1`). Other optional policies include minimum capacity requirements, a capacity reserve margin, and more. A rate-based carbon cap of 0 gCO<sub>2</sub> per kWh (net-zero) is specified in the `CO2_cap.csv` input file.

Once the settings are confirmed, run the model with the `Run.jl` script in the example directory:

`include("Run.jl")`

Once the model has completed, results will write to the `Results` directory.
