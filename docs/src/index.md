# GenX Documentation

```@meta
CurrentModule = GenX
```
## Overview

GenX is a highly-configurable electricity resource capacity expansion model that incorporates several state-of-the-art practices in electricity system planning to offer improved decision support for a changing electricity landscape. GenX is a constrained optimization model that determines the mix of electricity generation, storage, transmission, and demand-side resource investments and operational decisions to meet electricity demand in one or more future planning years at lowest cost subject to a variety of power system operational constraints and specified policy constraints, such as CO$_2$ emissions limits. Importantly, GenX can be configured with varying level of model resolution and scope, with regards to chronological variability of electricity demand and renewable energy availability, power system operational detail and unit commitment constraints, and transmission and distribution network representation, depending on the planning problem or policy question to be studied. As such, the GenX model is designed to be highly configurable, with several different degrees of resolution possible on each of these key dimensions. The model is capable of representing a full range of conventional and novel electricity resources, including thermal generators, variable renewable resources (wind and solar), run-of-river, reservoir and pumped-storage hydroelectric generators, energy storage devices, demand-side flexibility, and several advanced technologies such as long-duration energy storage and thermal plants with flexible carbon capture and storage.

## Requirements

GenX runs on Julia v1.3.1 and JuMP v0.21.4, and requires a valid Gurobi license on the host machine. Note that this is an older JuMP distribution. If you have a different version of JuMP installed in your Julia environment, you can install JuMP v0.21.4 by running the command `pkg> add JuMP@0.21.4` in the Julia package manager (you can access the Julia package manager by running the command `julia> ]` in the Julia command prompt). GenX.jl requires the following Julia packages:
* CSV (v0.5.23)
* DataFrames (v0.20.2)
* Gurobi (v0.7.6)
* JuMP (v0.21.4)
* LinearAlgebra
* MathProgBase (v0.7.8)
* StatsBase (v0.33.0)
* YAML (v0.4.3)
* Documenter (v0.24.7)
* DocumenterTools (v0.1.9)

You can see all of the packages installed in your Julia environment and their version numbers by running pkg> status on the package manager command line.

## Documentation

Detailed documentation for GenX can be found [here](https://docs.google.com/document/d/1G_1gdnSj92jF8nda2Zl8O4M5B98t19gOYnbbMFhohb4/edit?usp=sharing). It includes details of each of GenX's methods, required and optional input files, and outputs. 
Documentation for [GenX](https://github.com/GenXProject/GenX.jl).

## Running an Instance of GenX

The Run_test.jl file provides an example of how to use GenX.jl for capacity expansion modeling. The following are the main steps performed in the Run_test.jl script:
1.	Specify input parameters
2.	Instantiate a Gurobi Solver instance
3.	Load the model inputs from a specified directory
4.	Generate a GenX model
5.	Solve the model
6.	Write the output files to a specified directory

Here are step by step instructions for running Run_test.jl:
1.	Start an instance of the Julia kernel.
2.	Make your present working directory the directory which contains Run_test.jl. To do this, you can use the Julia command `julia> cd(“/path/to/directory/containing/GenX”)`, using the pathname of the directory containing Run_test.jl. Note that GenX.jl, as well as a folder containing your inputs files, should be in this directory in addition to Run_test.jl. Details about the required input files can be found below. You can check your present working directory by running the command `julia> pwd()`.
3.	Run the script by executing the command `julia> include(“Run_test.jl”)`.
4.	After the script runs to completion, results will be written to a folder called “Results”

Note that if you have not already installed the required Julia packages, you are using a version of JuMP other than v0.18.6, or you do not have a valid Gurobi license on your host machine, you will receive an error message and Run_test.jl will not run to completion.

## Contents
```@contents
```
## Index

```@index
```

```@autodocs
Modules = [GenX]
```
