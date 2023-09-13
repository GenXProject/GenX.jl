# PiecewiseFuel_CO2

**PiecewiseFuel_CO2** is a 24 hr example and contains only one zone. It is condensed for easy and quick testing of CO2, biomass, and piecewise fuel usage related functions of the GenX. This testing 
system only includes natural gas ccs, wind, and biomass with ccs, all set at a fixed initial 
capacity, and does not allow for building additional capacity. For natural gas ccs generator, we provide picewise fuel usage (PWFU) parameters to represent the fuel consumption at differernt load point. Please refer to "PiecewiseFuelUsage_data_description.pptx" for a sylized visual representation of PWFU segments and corresponding data requirements. When UC >= 1 and PWFU parameters are provided in "Generator_data.csv", the standard heat rate (i.e., Heat_Rate_MMBTU_per_MWh) will not be used unless UC = 0. 

To run the model, first navigate to the example directory at `GenX/Example_Systems/PiecewiseFuel_CO2`:

`cd("Example_Systems/PiecewiseFuel_CO2")`
   
Next, ensure that your settings in `GenX_settings.yml` are correct.  The linear clustering unit commitment method (UC = 2) is used. The default settings use the solver HiGHS (`Solver: HiGHS`). A mass-based carbon cap of 0 t CO<sub>2</sub> (net-zero) is specified in the `CO2_cap.csv` input file. 

Once the settings are confirmed, run the model with the `Run.jl` script in the example directory:

`include("Run.jl")`

Once the model has completed, results will write to the `Results` directory.
