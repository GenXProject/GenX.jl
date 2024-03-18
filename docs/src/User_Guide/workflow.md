# User Guide

## Introduction
GenX is a constrained **linear** or **mixed integer linear optimization model** that determines the portfolio of electricity generation, storage, transmission, and demand-side resource investments and operational decisions to meet electricity demand in one or more future planning years at lowest cost, while subject to a variety of power system operational constraints, resource availability limits, and other imposed environmental, market design, and policy constraints.

Depending on the planning problem or question to be studied, GenX can be configured with varying levels of model resolution and scope, with regards to: 
1. Temporal resolution of time series data such as **electricity demand** and **renewable energy availability**; 
2. Power system **operational detail** and unit **commitment constraints**; 
3. **Geospatial resolution** and **transmission network** representation. 

The model is also capable of representing a full range of conventional and novel electricity resources, including thermal generators, variable renewable resources (wind and solar), run-of-river, reservoir and pumped-storage hydroelectric generators, energy storage devices, demand-side flexibility, demand response, and several advanced technologies such as long-duration energy storage.

## Workflow
The flexibility of GenX is achieved through a modular and transparent code structure developed in [Julia](http://julialang.org/) + [JuMP](http://jump.dev/). The software workflow includes two main steps: 

1. **Model configuration** and **building**: this step involves the specification of the planning problem to be studied, including time dependent data like electricity demand, renewable energy availability and fuel prices, number and type of resources included in the model, graph representation of the transmission network, and the set of constraints and objectives to be imposed.

2. **Model execution**: once the model is configured, a solver is called to find the optimal solution to the planning problem. The solution is then post-processed to generate a set of output files that can be used for further analysis.

The next sections in this guide provide more details on how to perform all the steps in the workflow: 
1. [Model settings parameters](@ref): `genx_settings.yml`
2. [Solver Configuration](@ref): `[solver_name]_settings.yml`
3. [GenX Inputs](@ref)
4. [Time-domain reduction](@ref): `time_domain_reduction.yml` (optional)
5. [Multi-stage setup](@ref): `multi_stage_settings.yml` (optional)
6. [Running the model](@ref)
7. [GenX Outputs](@ref)

## Details of running a GenX case 
This section details as to what happens in the process of running a GenX case. As a first step, the GenX package and the desired solver (is it's anyting other than the default solver, HiGHS; for instance, Gurobi) are loaded 

```julia
using GenX
using Gurobi
optimizer=Gurobi.Optimizer
```
The next command the user needs to run is the following:

```julia
run_genx_case!("<Location_of_the_case_study_data>", optimizer)
```
Contingent upon whether a single stage model or a multi-stage model is intended to be run, the above function, inturn makes calls to either of these two functions:
For single-stage case:
```julia
run_genx_case_simple!(case, mysetup, optimizer)
```
From within this function, if time-domain reduction (TDR) is needed, GenX first checks 	whether there already is time domain clustered data (in order to avoid duplication of efforts) by running 
```julia
prevent_doubled_timedomainreduction(case)
```
and if the function
```julia
!time_domain_reduced_files_exist(TDRpath)
```
returns true value, it then runs
```julia
cluster_inputs(case, settings_path, mysetup)
```
to generate the time-domain clustered data for the time-series.
-OR-
For multi-stage case:

```julia
run_genx_case_multistage!(case, mysetup, optimizer)
```
In this case also, the TDR clustering is done in a similar way, exxcept for the fact that if TDRSettingsDict["MultiStageConcatenate"] is set to 0, the TDR clustering is done individually for each stage. Otherwise, the clustering is done for all the stages together. The next step is configuring the solver, which is done by
```julia
OPTIMIZER = configure_solver(settings_path, optimizer)
```
The call to configure_solver first gets the particular solver that is being used to solve the particular case at hand, which then calls a function specific to that solver in order to use either the default values of the solver settings parameter or, any other set of values, specified in the settings YAML file for that particular solver. 

The configuration of solver is followed by loading the input files by running the following function:
```julia
myinputs = load_inputs(mysetup, case)
```
The above function in its turn calls separate functions to load different resources, demand data, fuels data etc. and returns the dictionary myinputs populated by the input data. The next function call is to generate the model 
```julia
time_elapsed = @elapsed EP = generate_model(mysetup, myinputs, OPTIMIZER)
println("Time elapsed for model building is")
println(time_elapsed)
```
The above function call instantiates the different decision variables, constraints, and objective function expressions from the input data. It can be seen that we also keep track of the time required to build the model. Follwoing this, the solve_model function makes the call to the solver and return the results as well as the solve time. 
```julia
EP, solve_time = solve_model(EP, mysetup)
myinputs["solve_time"] = solve_time # Store the model solve time in myinputs
```
For writing the results, we invoke the following function:
```julia
outputs_path = get_default_output_folder(case)
elapsed_time = @elapsed outputs_path = write_outputs(EP, outputs_path, mysetup, myinputs)
```
The call to the write_outputs() function in turn calls a series of functions (write_capacity, write_power etc.) each of which querries the respective decision variables and creates dataframes, eventually outputting the results to separate CSV files. 

## Single and Multi-stage investment planning

In addition to the standard single-stage planning mode, in which the produces a single snapshot of the minimum-cost generation capacity mix to meet demand at least cost under some pre-specified future conditions, recent improvements in the GenX source code (part of v0.3 release) enable its use for studying **long-term evolution** of the power system across multiple investment stages. GenX can be used to study multi-stage power system planning in the following two ways:

- The user can formulate and solve a deterministic multi-stage planning problem with perfect foresight i.e. demand, cost, and policy assumptions about all stages are known and exploited to determine the least-cost investment trajectory for the entire period. The solution relies on exploiting the decomposable nature of the multi-stage problem via the implementation of the dual dynamic programming algorithm, described in [Lara et al. 2018 here](https://www.sciencedirect.com/science/article/abs/pii/S0377221718304466).

- The user can formulate a sequential, myopic multi-stage planning problem, where the model solves a sequence of single-stage investment planning problems wherein investment decisions in each stage are individually optimized to meet demand given assumptions for the current planning stage and with investment decisions from previous stages treated as inputs for the current stage. We refer to this as "myopic" (or shortsighted) mode since the solution does not account for information about future stages in determining investments for a given stage. This version is generally more computationally efficient than the deterministic multi-stage expansion with perfect foresight mode.

