# Small New England: One Zone Mulit Period

**SmallNewEngland** is set of a simplified versions of the more detailed example system RealSystemExample. It is condensed for easy comprehension and quick testing of different components of the GenX. **SmallNewEngland/OneZone_MultiStage** is a toy multi-stage model, with three model periods and only one zone representing New England. The model includes only natural gas, solar PV, wind, and lithium-ion battery storage. Existing capacities are included to demonstrate the endogenous retirement capabilities of mutli-period modeling in GenX, although these capacities do not reflect actual brownfield capacity in the New England region.

To run the model, first navigate to the example directory at `GenX/Example_Systems/SmallNewEngland/OneZone_MultiStage`:

`cd("Example_Systems/SmallNewEngland/OneZone_MultiStage")`
   
Next, ensure that your settings in `GenX_settings.yml` are correct. The default settings use the solver Gurobi (`Solver: Gurobi`), and time domain reduced input data (`TimeDomainReduction: 1`).

The `multi_stage_settings.yml` file contains settings parameters specific to multi-stage modeling. This example is configured for three model periods (`NumPeriods: 3`) of 10 years in length each (`PeriodLength: 10`).

Multi-period modeling in GenX requires a separate set of model inputs for each period to be modeled, which are located in the directories `Inputs/Inputs_p$`, where `$` is the number of the model period. Although separate model periods can have different costs and policy parameters, the resources names and types, specified in each resource `.csv` files (included in the `Resources` folder) must be identical across model periods. In addition, multi-stage modeling with a single zone requires an additional input file, `Generators_data_multi_stage.csv`, also located in the `Inputs/` directory, which contains fields related to resource lifetimes, capital recovery periods, and endogenous retirements.

A rate-based carbon cap becomes more stringent across the three model periods, declining from of 1,000 gCO<sub>2</sub> per kWh in the first period, 500  gCO<sub>2</sub> per kWh in the second period, and  50 gCO<sub>2</sub> per kWh in the third period, as specified in the `CO2_cap.csv` input files in `Inputs/Inputs_p1`, `Inputs/Inputs_p2`, and `Inputs/Inputs_p3` respectively.

Once the settings are confirmed, run the model with the `Run_multi_stage.jl` script in the example directory:

`include("Run.jl")`

Once the model has completed, results will write to the `Results/` directory.