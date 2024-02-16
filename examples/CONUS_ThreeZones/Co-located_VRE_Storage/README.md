# VREStor_Example: Colocated VRE+Storage Example System

**VREStor_Example** is an example system that uses the colocated VRE+storage module. It runs a very simple 3 zone, 24-hour continental US model, with a carbon constraint and with a long duration energy storage resource that the model can choose to co-locate with either solar or wind. In this case, the storage resource is forced in via minimum and maximum capacity requirement constraints but these constraints could be easily removed (although the storage resource has a cost of zero in this case so a cost would have to be added). This case is designed to show what the inputs look like for a colocated VRE+storaeg case.

To run the model, first navigate to the example directory at `GenX/Example_Systems/VREStor_Example`:

`cd("Example_Systems/VREStor_Example")`
   
Next, ensure that your settings in `GenX_settings.yml` are correct. The default settings use the solver HiGHS (`Solver: HiGHS`). Other optional policies include minimum and maximum capacity requirements, a capacity reserve margin, and more. A zero carbon constraint is included in this case but this could be modified.

Once the settings are confirmed, run the model with the `Run.jl` script in the example directory:

`include("Run.jl")`

Once the model has completed, results will write to the `Results` directory.
