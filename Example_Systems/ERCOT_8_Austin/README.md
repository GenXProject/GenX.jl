# Real System Example: Three Zones

**RealSystemExample/ISONE_Trizone_FullTimeseries** is  more detailed example system approximating the ISO New England region with three zones representing  Connecticut, and Maine and rest of ISO New England (MA, VT, NH, RI).
They are total of 58 different resources modeled in the system.
This is full-day (24 hour) case.

To run the model, first navigate to the example directory at `GenX/Example_Systems/RealSystemExample/ISONE_Trizone_FullTimeseries`:

`cd("Example_Systems/RealSystemExample/ISONE_Trizone_FullTimeseries")`

Next, ensure that your settings in `GenX_settings.yml` are correct.
The default settings use the solver HiGHS (`Solver: highs`).
Other optional policies include minimum capacity requirements, a capacity reserve margin, and more. 

Once the settings are confirmed, run the model with the `Run.jl` script in the example directory:

`include("Run.jl")`

Once the model has completed, results will write to the `Results` directory.
