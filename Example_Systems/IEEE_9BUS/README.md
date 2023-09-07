# IEEE 9-BUS Test case 

They are total of 3 generators and three loads

To run the model, first navigate to the example directory at `GenX/Example_Systems/RealSystemExample/IEEE_9BUS`:

`cd("Example_Systems/RealSystemExample/IEEE_9BUS")`

Next, ensure that your settings in `GenX_settings.yml` are correct.
The default settings use the solver Gurobi (`Solver: Gurobi`).
Other optional policies include minimum capacity requirements, a capacity reserve margin, and more. 

Once the settings are confirmed, run the model with the `Run.jl` script in the example directory:

`include("Run.jl")`

Once the model has completed, results will write to the `Results` directory.
