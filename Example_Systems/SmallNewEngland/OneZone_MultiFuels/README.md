# Small New England: One Zone with resources that can use multiple fuels

**SmallNewEngland** is set of a simplified versions of the more detailed example system RealSystemExample. It is condensed for easy comprehension and quick testing of different components of the GenX. **SmallNewEngland/OneZone_MultiFules** is one of our most basic models, a 24-hour example with hourly resolution containing only one zone representing New England. The model includes only natural gas (cofiring with H2), solar PV, wind, and lithium-ion battery storage with no initial capacity. 

To run the model, first navigate to the example directory at `GenX/Example_Systems/SmallNewEngland/OneZone_MultiFuels`:

`cd("Example_Systems/SmallNewEngland/OneZone_MultiFuels")`
   
Next, ensure that your settings in `GenX_settings.yml` are correct. The default settings use the solver HiGHS (`Solver: HiGHS`). Other optional policies include minimum capacity requirements, a capacity reserve margin, and more. 

Once the settings are confirmed, run the model with the `Run.jl` script in the example directory:

`include("Run.jl")`

Once the model has completed, results will write to the `Results` directory.
