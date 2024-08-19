# Running GenX

This section describes how to run GenX with the examples provided in the repository and with user-defined cases. To have a deeper understanding of how to structure the input files and the settings, please refer to the [User Guide](@ref).

## Example cases
GenX repository contains several examples to get you started with GenX. These examples are located in the [example_systems](https://github.com/GenXProject/GenX/tree/main/example_systems) folder of the repository and are designed to be easy to run and to demonstrate the main features of GenX. 

The available examples are:

- [1\_three\_zones](https://github.com/GenXProject/GenX/tree/main/example_systems/1_three_zones)
- [2\_three\_zones\_w\_electrolyzer](https://github.com/GenXProject/GenX/tree/main/example_systems/2_three_zones_w_electrolyzer)
- [3\_three\_zone\_w\_co2\_capture](https://github.com/GenXProject/GenX/tree/main/example_systems/3_three_zone_w_co2_capture)
- [4\_three\_zones\_w\_policies\_slack](https://github.com/GenXProject/GenX/tree/main/example_systems/4_three_zones_w_policies_slack)
- [5\_three\_zones\_w\_piecewise\_fuel](https://github.com/GenXProject/GenX/tree/main/example_systems/5_three_zones_w_piecewise_fuel)
- [6\_three\_zones\_w\_multistage](https://github.com/GenXProject/GenX/tree/main/example_systems/6_three_zones_w_multistage)
- [7\_three\_zones\_w\_colocated\_VRE\_storage](https://github.com/GenXProject/GenX/tree/main/example_systems/7_three_zones_w_colocated_VRE_storage)
- [IEEE\_9\_bus\_DC\_OPF](https://github.com/GenXProject/GenX/tree/main/example_systems/IEEE_9_bus_DC_OPF)

!!! note "Note"
    The following instructions assume that you have already installed GenX and its dependencies. If you haven't, please follow the instructions in the [Installation Guide](@ref).

To run an example, follow these steps:
1. Open a terminal and run Julia with an environment containing GenX;
2. Run the `Run.jl` file located in the example folder.

For example, to run the `1_three_zones` example, you can use the following commands:
```
$ julia
julia> <press close-bracket ] to access the package manager>
(@v1.9) pkg> activate /path/to/env
julia> using GenX
julia> include("/path/to/GenX/example_systems/1_three_zones/Run.jl")
``` 
where `/path/to/env` is the path to the environment containing GenX and `/path/to/GenX` is the path to the `GenX` repository containing the examples.

The `Run.jl` file will read the `.csv` input files which define the system, the resources, and the policies, will solve the model, and finally will write the results in a `results` folder located in the same directory as `Run.jl`.

!!! tip "Tip"
    You could also run the example from the terminal using the following command:
    ```
    $ julia --project=/path/to/env /path/to/GenX/example_systems/1_three_zones/Run.jl`
    ```
    This is equivalent to open a Julia REPL and call the `Run.jl` file using the `include` function.
    The first option is recommended if you want to run GenX multiple times with different settings because it avoids the overhead of recompiling the code every time you run it.

!!! note "Note"
    The default solver for GenX is [HiGHS](https://github.com/jump-dev/HiGHS.jl).

For more information on what happens when you run a GenX case, see the [Running GenX](@ref) section.

!!! note "Note"
    The first seven examples are based on a one-year example with hourly resolution, containing zones representing Massachusetts, Connecticut, and Maine. The ten represented resources include natural gas, solar PV, wind, and lithium-ion battery storage.


## Running GenX with user-defined cases
To run GenX with a user-defined case, you need to create a folder `MyCase` with the following structure:

```
MyCase
├── settings/
├── system/
├── policies/
├── resources/
├── README.md
└── Run.jl
```

where the `settings` folder contains the configuration files for the model and the solver, the `system` folder contains the `.csv` input files related to the system under study, the `resource` folder contains the `.csv` input files with the list of generators to include in the model, and the `policies` folder contains the `.csv` input files which define the policies to be included in the model. 
For instance, one case could have the following structure:

```
MyCase
│ 
├── settings
│   ├── genx_settings.yml           # GenX settings
│   ├── [solver_name]_settings.yml  # Solver settings
│   ├── multi_stage_settings.yml    # Multi-stage settings
│   └── time_domain_reduction.yml   # Time-domain clustering settings
│ 
├── system
│   ├── Demand_data.csv
│   ├── Fuel_data.csv
│   ├── Generators_variability.csv
│   └── Network.csv
│ 
├── policies
│   ├── CO2_cap.csv
│   ├── Minimum_capacity_requirement.csv
│   └── Energy_share_requirement.csv
│ 
├── resources
│   ├── Thermal.csv
│   ├── Storage.csv
│   ├── Vre.csv
│   ├── Hydro.csv
│   └── policy_assignments
|       ├── Resource_minimum_capacity_requirement.csv
│       └── Resource_energy_share_requirement.csv
│
└── Run.jl
```

In this example, `MyCase` will define a case with `Themal`, `Storage`, `Vre`, and `Hydro` resources, the `system` folder will provide the data for the demand, fuel, generators' variability, and network, the `policies` folder will include a CO2 cap, a minimum capacity requirement, and an energy share requirement, and the `settings` folder will contain the configuration files for the model. 

The `Run.jl` file should contain the following code:
```julia
using GenX

run_genx_case!(dirname(@__FILE__))
```
which will run the case using the default solver. To use a different solver, you can pass the Optimizer object as an argument to `run_genx_case!` function. For example, to use Gurobi as the solver, you can use the following code:

```julia
using GenX
using Gurobi

run_genx_case!(dirname(@__FILE__), Gurobi.Optimizer)
```

To run the case, open a terminal and run the following command:
```
$ julia --project="/path/to/env"
julia> include("/path/to/MyCase/Run.jl")
```
where `/path/to/env` is the path to the environment with `GenX` installed, and `/path/to/MyCase` is the path to the folder of the `MyCase` case.
Alternatively, you can run the case directly from the terminal using the following command:
```
$ julia --project="/path/to/env" /path/to/MyCase/Run.jl
```

## What happens when you run a case
*Added in 0.3.4*

The entry point for running a GenX case is the `run_genx_case!("path/to/case")` function, where `path/to/case` is the path to the case directory that contains the `.csv` files with the inputs for GenX and the `settings` folder with the configuration files.

The following are the main steps performed in this function:

1. Establish path to environment setup files and GenX source files.
2. Read in model settings `genx_settings.yml` from the example directory.
3. Configure solver settings.
4. Load the model inputs from the example directory and perform time-domain clustering if required.
5. Generate a GenX model instance.
6. Solve the model.
7. Write the output files to a specified directory.

After the script runs to completion, results will be written to a folder called `results`, located in the current working directory.

## Precompile GenX
*Added in 0.4.1*

!!! note "Note"
    By default, GenX is precompiled when the package is installed to reduce the latency of the first execution of a case. This process may take a couple of minutes, but it will reduce the time needed to run subsequent cases.

However, if you want to disable precompilation, you can set the environment variable `GENX_PRECOMPILE` to `"false"` before loading GenX:

```
$ julia --project="/path/to/env"
julia> ENV["GENX_PRECOMPILE"] = "false"
julia> using GenX
```

Here, `/path/to/env` is the path to the environment where GenX is installed.

!!! note "Note"
    The environment variable `GENX_PRECOMPILE` must be set before loading GenX for the first time. However, to force recompilation of GenX, you can delete the `~/.julia/compiled/vZ.Y/GenX/*.ji` binaries (where vZ.Y is the version of Julia being used, e.g., v1.9), set the environment variable `GENX_PRECOMPILE` to the desired value, and then reload the package. If GenX was imported via `Pkg.develop` or `] dev`, modifying any of the package files will also force recompilation.
