# Small New England: Three Zones, Slack Variables Example

**Policies**, a one-year example with hourly resolution, contains zones representing Massachusetts, Connecticut, and Maine and is designed to show how to use slack variables to meet a policy constraint if it cannot be met cost-effectively by normal means. The ten represented resources include only natural gas, solar PV, wind, and lithium-ion battery storage. It additionally contains example input files establishing slack variables for policy constraints (e.g. the Capacity Reserve Margin, CO2 Cap, etc.). These slack variables allow the relevant constraints to be violated at the cost of a specified objective function penalty, which can be used to either identify problematic constraints without causing infeasibilities in GenX, or to set price caps beyond which policies are no longer enforced. These slack variables will only be created if the relevant input data (Capacity_reserve_margin_slack.csv, CO2_cap_slack.csv, Energy_share_requirement_slack.csv, or the 'PriceCap' column in 'Minimum_capacity_requirement.csv') are present. If any of these inputs are not present, GenX will isntantiate the relevant policy as a hard constraint, which will throw an infeasibility if violated.

To run the model, first navigate to the example directory at `GenX/examples/SmallNewEngland_ThreeZones/Policies`:

`cd("examples/SmallNewEngland_ThreeZones/Policies")`
   
Next, ensure that your settings in `Settings/GenX_settings.yml` are correct. The default settings use the solver HiGHS (`Solver: HiGHS`), time domain reduced input data (`TimeDomainReduction: 1`). Other optional policies include minimum capacity requirements, a capacity reserve margin, and more. A rate-based carbon cap of 50 gCO<sub>2</sub> per kWh is specified in the `CO2_cap.csv` input file.

Once the settings are confirmed, run the model with the `Run.jl` script in the example directory:

`include("Run.jl")`

Once the model has completed, results will write to the `Results` directory.