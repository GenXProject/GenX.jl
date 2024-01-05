# Electrolyzer Example

**Electrolyzer Example** is a simple, one zone test case designed to show the Electrolyzer feature in use, adapted from **SmallNewEngland/OneZone**.

To run the model, first navigate to the example directory at `GenX/Example_Systems/Electrolyzer_Example`:

`cd("Example_Systems/Electrolyzer_Example")`
   
Next, ensure that your settings in `GenX_settings.yml` are correct. The default settings use time domain reduced input data (`TimeDomainReduction: 1`), and an energy square requirement as specified in the `Energy_share_requirement.csv` file. Other optional policies include minimum capacity requirements, a capacity reserve margin, and more.

Once the settings are confirmed, run the model with the `Run.jl` script in the example directory:

`include("Run.jl")`

Once the model has completed, results will write to the `Results` directory.
