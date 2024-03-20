# Running the model

When running a new case, it is recommended to create a new folder for the case outside of the `GenX` repository. This folder should contain all the `.csv` input files described in the [GenX Inputs](@ref) section, as well as the `settings` folder containing at least the `genx_settings.yml` and `[solver_name].yml` files.  

!!! tip "Tip"
    Check out the [Running GenX](@ref) for additional information on how to run GenX and what happens when you run a case.

Once the model and the solver are set up, and once all the `.csv` input files are ready, GenX can be run using the following command:

```
$ julia --project=/path/to/GenX

julia> using GenX
julia> run_genx_case!("/path/to/case")
```

where `/path/to/GenX` is the path to the `GenX` repository, and `/path/to/case` is the path to the folder of the case. 

Alternatively, you can create a `Run.jl` file with the following code:

```julia
using GenX
run_genx_case!(dirname(@__FILE__))
```
and and place it in the case folder. Then, you can run the case by opening a terminal and running the following command:

```bash
$ julia --project="/path/to/GenX" /path/to/case/Run.jl
```
where `/path/to/GenX` is the path to the `GenX` repository, and `/path/to/case` is the path to the folder of the case.

The output files will be saved in the `Results` folder inside the case folder. Check out the [GenX Outputs](@ref) section for more information on the output files.

!!! note "Slack Variables"
    To run a case with **slack variables**, check out the [Policy Slack Variables](@ref) section.