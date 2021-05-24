# GenX

## Overview
GenX is a highly-configurable electricity resource capacity expansion model that incorporates several state-of-the-art practices in electricity system planning to offer improved decision support for a changing electricity landscape. 

GenX is a constrained linear or mixed integer linear optimization model that determines the portfolio of electricity generation, storage, transmission, and demand-side resource investments and operational decisions to meet electricity demand in one or more future planning years at lowest cost subject to a variety of power system operational constraints and specified policy constraints, such as CO2 emissions limits.

Importantly, GenX can be configured with varying level of model resolution and scope, with regards to chronological variability of electricity demand and renewable energy availability, power system operational detail and unit commitment constraints, and transmission network representation, depending on the planning problem or policy question to be studied. As such, the GenX model is designed to be highly flexible and configurable, with several different degrees of resolution possible on each of these key dimensions. The model is capable of representing a full range of conventional and novel electricity resources, including thermal generators, variable renewable resources (wind and solar), run-of-river, reservoir and pumped-storage hydroelectric generators, energy storage devices, demand-side flexibility, and several advanced technologies such as long-duration energy storage.

The 'main' branch is the current master branch of GenX. The various subdirectories are described below:

1. `src/` Contains the core GenX model code for reading inputs, model generation, solving and writing model outputs.

2. `Example_Systems/` Contains fully specified examples that users can use to test GenX and get familiar with its various features. Within this folder, we have two sets of examples: 
-   `RealSystemExample/`, a detailed system representation based on ISO New England and including many different resources (upto 58)
-   `SmallNewEngland/` , a simplified system consisting of 4 different resources per zone.

3.  `docs/` Contains all the documentation pertaining to the model.

4. `GenXJulEnv` Contains the .toml files related to setting up the Julia environment with all the specified package versions in `julenv.jl`.

## Requirements

GenX.jl runs on Julia v1.3.0 and JuMP v0.21.3, and is currently setup to use one of the following solvers: A) Gurobi, and B) CPLEX. Note that using Gurobi and CPLEX requires a valid license on the host machine. Compatibility with open source solvers Clp and GLPK will be added shortly. The file `juliaenv.jl` in the parent directory lists all of the packages and their versions needed to run GenX. You can see all of the packages installed in your Julia environment and their version numbers by running `pkg> status` on the package manager command line in the Jula REPL.

## Documentation

Detailed documentation for GenX can be found [here](https://genxproject.github.io/GenX/). It includes details of each of GenX's methods, required and optional input files, and outputs. Interested users may also want to browse through prior publications that have used GenX to understand the various features of the tool. Full publication list is available [here](https://energy.mit.edu/genx/#publications).

## Running an Instance of GenX
Download or clone the GenX repository on your machine in a directory named 'GenX'. Create this new directory in a location where you wish to store the GenXJulEnv environment.

The Run_test.jl file in each of the example sub-folders within `Example_Systems/` provides an example of how to use GenX.jl for capacity expansion modeling. The following are the main steps performed in the Run_test.jl script:
1.	Establish path to environment setup files and GenX source files.
2.	Read in model settings `GenX_Settings.yml` from the example directory.
3.  	Configure solver settings.
4.	Load the model inputs from the example directory and perform time-domain clustering if required.
5.	Generate a GenX model instance.
6.	Solve the model.
7.	Write the output files to a specified directory.

Here are step-by-step instructions for running Run_test.jl:
1.	Start an instance of the Julia kernel.
2.	Make your present working directory to be where the Run_test.jl is located. To do this, you can use the Julia command `julia> cd(“/path/to/directory/containing/file)`, using the actual pathname of the directory containing Run_test.jl. Note that all your inputs files should be in this directory in addition to Run_test.jl. Details about the required input files can be found in the documentation linked above or in the examples provided in the folder `Example_Systems/`. You can check your present working directory by running the command `julia> pwd()`.
3.	Run the script by executing the command `julia> include(“Run_test.jl”)`.
4.	After the script runs to completion, results will be written to a folder called “Results”, also located in the same directory as `Run_test.jl`.

Note that if you have not already installed the required Julia packages, you are using a version of JuMP other than v0.21.4, or you do not have a valid Gurobi license on your host machine, you will receive an error message and Run_test.jl will not run to completion.
Documentation for [GenX](https://genxproject.github.io/GenX/). 

## Contents
```@contents
```
## Index

```@index
```

```@autodocs
Modules = [GenX]
```
## Bug and feature requests and contact info
If you would like to report a bug in the code or request a feature, please use our [Issue Tracker](https://github.com/GenXProject/GenX/issues). If you're unsure or have questions on how to use GenX that are not addressed by the above documentation, please reach out to Sambuddha Chakrabarti (sc87@princeton.edu), Jesse Jenkins (jdj2@princeton.edu) or Dharik Mallapragada (dharik@mit.edu).
