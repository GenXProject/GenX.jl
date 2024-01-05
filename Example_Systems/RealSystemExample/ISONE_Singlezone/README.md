# Real System Example: Single Zones

**RealSystemExample/ISONE_Singlezone** is detailed example system approximating the ISO New England region with one zone that represents the whole ISO-NE.
They are total of 58 different resources modeled in the system.

To run the model, first navigate to the example directory at `GenX/Example_Systems/RealSystemExample/ISONE_Singlezone`:

`cd("Example_Systems/RealSystemExample/ISONE_Singlezone")`

Next, ensure that your settings in `GenX_settings.yml` are correct.
The default settings use the solver Gurobi (`Solver: Gurobi`).
`TimeDomainReduction` is turned on (`1`), which reduces the full-year input data to 11 one-weeks periods of 168 hours.
Other optional policies include minimum capacity requirements, a capacity reserve margin, and more. 

Once the settings are confirmed, run the model with the `Run.jl` script in the example directory:

`julia --project=/path/to/GenX Run.jl`

Once the model has completed, results will write to the `Results` directory.
