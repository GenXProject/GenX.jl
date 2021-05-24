# Real System Example: Three Zones

**RealSystemExample/ISONE_Trizone** is  more detailed example system approximating the ISO New England region with three zones representing  Connecticut, and Maine and rest of ISO New England (MA, VT, NH, RI). They are total of 58 different resources modeled in the system. The temporal resolution of the model inputs is specified to be 480 hours or 20 days and the model requires GenX_settings parameter `OperationWrapping=1` to run without errors.

To run the model, first navigate to the example directory at `GenX/Example_Systems/RealSystemExample/ISONE_Trizone`:

`cd("Example_Systems/RealSystemExample/ISONE_Trizone")`
   
Next, ensure that your settings in `GenX_settings.yml` are correct. The default settings use the solver Gurobi (`Solver: Gurobi`), time domain reduced input data (`TimeDomainReduction: 0`).  Other optional policies include minimum capacity requirements, a capacity reserve margin, and more. 

Once the settings are confirmed, run the model with the `Run_test.jl` script in the example directory:

`include("Run_test.jl")`

Once the model has completed, results will write to the `Results` directory.