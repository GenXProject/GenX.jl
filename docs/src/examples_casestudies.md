# Running GenX

This section describes how to run GenX with the examples provided in the repository and with user-defined cases. To have a deeper understanding of how to structure the input files and the settings, please refer to the [GenX Inputs](@ref) and [Model settings parameters](@ref) sections of the [User Guide](@ref).

## GenX examples and case studies
GenX repository contains several examples to get you started with GenX. These examples are located in the [Example_Systems](https://github.com/GenXProject/GenX/tree/main/Example_Systems) folder of the repository and are designed to be easy to run and to demonstrate the main features of GenX. 

The available examples are:

- SmallNewEngland
- RealSystemExample
- RetrofitExample
- MethodofMorrisExample
- Input_data_explained

### Running an example

!!! note "Note"
    The following instructions assume that you have already installed GenX and its dependencies. If you haven't, please follow the instructions in the [Installation Guide](@ref).

Each example folder contains a set of `.csv` files for the inputs of GenX, a `Settings` folder for the configuration of the model and the solver, and a `Run.jl` file that can be used to run each example. For instance, to run the `SmallNewEngland` example with a single zone, follow these steps:
1. Open a terminal and navigate to the `GenX` repository.
2. Run the following command:
```
$ julia --project Example_Systems/SmallNewEngland/OneZone/Run.jl`
```
This command will run the `Run.jl` file located in the `Example_Systems/SmallNewEngland/OneZone` folder. The `--project` flag tells Julia to activate the environment defined in the `Project.toml` file located in the `GenX` folder. This file contains the correct list dependencies to run GenX. The `Run.jl` file will read the inputs of GenX from the `.csv` files located in the `Example_Systems/SmallNewEngland/OneZone` folder and will write the results in a `Results` folder located in the same directory as `Run.jl`.

!!! tip "Tip"
    Running the command 
    ```
    $ julia --project Example_Systems/SmallNewEngland/OneZone/Run.jl`
    ```
    from the `GenX` folder is equivalent to open a Julia REPL and call the `Run.jl` file using the `include` function:
    ```
    $ julia --project
    julia> include("Example_Systems/SmallNewEngland/OneZone/Run.jl")
    ```
    The second option is recommended if you want to run GenX multiple times with different settings because it avoids the overhead of recompiling the code every time you run it.

To run an example from a different directory, you can use the following command:

```
$ julia --project="/path/to/GenX" /path/to/GenX/Example_Systems/SmallNewEngland/OneZone/Run.jl`
```
where `/path/to/GenX` is the path to the `GenX` repository.

!!! note "Note"
    The default solver for GenX is [HiGHS](https://github.com/jump-dev/HiGHS.jl).

For more information on what happens when you run a GenX case, see the [Running GenX](@ref) section.

## Running GenX with user-defined cases
To run GenX with a user-defined case, you need to create a folder `MyCase` with the following structure:
```
MyCase
├── Demand_data.csv
├── Energy_share_requirements.csv
├── Fuel_data.csv
├── Generators_data.csv
├── Generators_variability.csv
[...] # Other input files
├── Settings
│   ├── genx_settings.yml           # GenX settings           
│   ├── [solver_name]_settings.yml  # Solver settings
|   [optional]
│   ├── multi_stage_settings.yml    # Multi-stage settings
│   └── time_domain_reduction.yml   # Time-domain clustering settings
└── Run.jl
```
where `MyCase` is the name of the folder of the case. The `Run.jl` file is the entry point for running GenX and it should contain the following code:
```julia
using GenX
run_genx_case!(dirname(@__FILE__))
```
To run the case, open a terminal and run the following command:
```
$ julia --project="/path/to/GenX" /path/to/MyCase/Run.jl
```
where `/path/to/GenX` is the path to the `GenX` repository, and `/path/to/MyCase` is the path to the folder of the `MyCase` case.
Alternatively, you can run the case from a Julia REPL:
```
$ julia --project="/path/to/GenX"
julia> include("/path/to/MyCase/Run.jl")
```

## What happens when you run a case
*Added in 0.3.4*

The entry point for running a GenX case is the `run_genx_case!("path/to/case")` function, where `path/to/case` is the path to the case directory that contains the `.csv` files with the inputs for GenX and the `Settings` folder with the configuration files.

The following are the main steps performed in that function:

1. Establish path to environment setup files and GenX source files.
2. Read in model settings `genx_settings.yml` from the example directory.
3. Configure solver settings.
4. Load the model inputs from the example directory and perform time-domain clustering if required.
5. Generate a GenX model instance.
6. Solve the model.
7. Write the output files to a specified directory.

After the script runs to completion, results will be written to a folder called `Results`, located in the current working directory.

## Additional method for running GenX cases
Added in 0.3.4

An alternative method for running GenX cases is to use the `run_genx_case!` function directly from a Julia REPL. This is particularly useful if one wants to run multiple GenX cases in sequence, as GenX needs only to be compiled by Julia once, and can be somewhat faster.

Start Julia pointed at the GenX environment, and then proceed as follows:

```
$ julia --project=/path/to/GenX

julia> using GenX

julia> run_genx_case!("/path/to/case")
```
where `/path/to/case` is the path to the case directory that contains the `.csv` files with the inputs for GenX and the `Settings` folder with the configuration files. All output will be written in that case's folder, as usual. Examples can be run in this way as well by using the path to the example directory in place of `/path/to/case`.
