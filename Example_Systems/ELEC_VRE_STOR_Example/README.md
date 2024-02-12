# VREStor_Example: Colocated VRE+Storage Example System

**ELEC_VRE_Stor_Example** is an example system that uses the colocated electrolyzer + VRE + storage module. It runs a very simple 1 zone, 24-hour continental US model. To meet the regional H2 production requirement, the model can choose either a grid-connected electrolyzer or an electrolyzer co-located with VRE_STOR.
To run the model, first navigate to the example directory at `GenX/Example_Systems/VREStor_Example`:

`cd("Example_Systems/VREStor_Example")`
   
Next, ensure that your settings in `GenX_settings.yml` are correct. The default settings use the solver HiGHS (`Solver: HiGHS`). Other optional policies include minimum and maximum capacity requirements, a capacity reserve margin, and more.

Once the settings are confirmed, run the model with the `Run.jl` script in the example directory:

`include("Run.jl")`

Once the model has completed, results will write to the `Results` directory.
