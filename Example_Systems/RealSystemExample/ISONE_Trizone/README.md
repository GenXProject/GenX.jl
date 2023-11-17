# Real System Example: Three Zones

**RealSystemExample/ISONE_Trizone** is  more detailed example system approximating the ISO New England region with three zones representing  Connecticut, and Maine and rest of ISO New England (MA, VT, NH, RI).
There are a total of 58 different resources modeled in the system.
The temporal resolution of the model inputs is specified to be 480 hours or 20 days.

To run the model, first navigate to the example directory at `GenX/Example_Systems/RealSystemExample/ISONE_Trizone`:

`cd("Example_Systems/RealSystemExample/ISONE_Trizone")`

Next, ensure that your settings in `GenX_settings.yml` are correct.
The default settings use the solver HiGHS (`Solver: highs`).
Other optional policies include minimum capacity requirements, a capacity reserve margin, and more. 

Since these input data are already clustered, time domain reduction must be turned off (`TimeDomainReduction: 0`).

Once the settings are confirmed, run the model with the `Run.jl` script in the example directory:

`include("Run.jl")`

Once the model has completed, results will write to the `Results` directory.
