# Small New England: One Zone + VRE Bins

**SmallNewEngland** is set of a simplified versions of the more detailed example system RealSystemExample. It is condensed for easy comprehension and quick testing of different components of the GenX. **SmallNewEngland/OneZone_3VREBin** is an iteration on our most basic model. Like the basic model, this is a one-year example with hourly resolution containing only one zone representing New England. In addition, it divides its wind resource into three separate bins with different parameters as defined in `Vre.csv` and `Generators_variability.csv`. This division into bins of different costs, capacities, and capacity factors allows the user to model more realistic supply curves of each resource. 

To run the model, first navigate to the example directory at `GenX/Example_Systems/SmallNewEngland/OneZone_3VREBin`:

`cd("Example_Systems/SmallNewEngland/OneZone_3VREBin")`
   
Next, ensure that your settings in `GenX_settings.yml` are correct. The default settings use the solver Gurobi (`Solver: Gurobi`), time domain reduced input data (`TimeDomainReduction: 1`), and linearized unit commitment of thermal resources (`UCommit: 2`). Other optional policies include minimum capacity requirements, a capacity reserve margin, and more. A rate-based carbon cap of 20 gCO<sub>2</sub> per kWh is specified in the `CO2_cap.csv` input file.

Once the settings are confirmed, run the model with the `Run.jl` script in the example directory:

`include("Run.jl")`

Once the model has completed, results will write to the `Results` directory.