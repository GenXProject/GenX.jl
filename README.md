# GenX
# GenX [![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://sambuddhac.github.io/GenX.jl/stable) [![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://sambuddhac.github.io/GenX.jl/dev) [![Build Status](https://github.com/sambuddhac/GenX.jl/badges/master/pipeline.svg)](https://github.com/sambuddhac/GenX.jl/pipelines) [![Coverage](https://github.com/sambuddhac/GenX.jl/badges/master/coverage.svg)](https://github.com/sambuddhac/GenX.jl/commits/master) [![Build Status](https://travis-ci.com/sambuddhac/GenX.jl.svg?branch=master)](https://travis-ci.com/sambuddhac/GenX.jl) [![Build Status](https://ci.appveyor.com/api/projects/status/github/sambuddhac/GenX.jl?svg=true)](https://ci.appveyor.com/project/sambuddhac/GenX-jl) [![Build Status](https://cloud.drone.io/api/badges/sambuddhac/GenX.jl/status.svg)](https://cloud.drone.io/sambuddhac/GenX.jl) [![Build Status](https://api.cirrus-ci.com/github/sambuddhac/GenX.jl.svg)](https://cirrus-ci.com/github/sambuddhac/GenX.jl) [![Coverage](https://codecov.io/gh/sambuddhac/GenX.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/sambuddhac/GenX.jl) [![Coverage](https://coveralls.io/repos/github/sambuddhac/GenX.jl/badge.svg?branch=master)](https://coveralls.io/github/sambuddhac/GenX.jl?branch=master) [![ColPrac: Contributor's Guide on Collaborative Practices for Community Packages](https://img.shields.io/badge/ColPrac-Contributor's%20Guide-blueviolet)](https://github.com/SciML/ColPrac)

# GenX

## Requirements

GenX.jl runs on Julia v1.3.1 and JuMP v0.21.4, and requires a valid Gurobi license on the host machine. Note that this is an older JuMP distribution. If you have a different version of JuMP installed in your Julia environment, you can install JuMP v0.21.4 by running the command `pkg> add JuMP@0.21.4` in the Julia package manager (you can access the Julia package manager by running the command `julia> ]` in the Julia command prompt). GenX.jl requires the following Julia packages:
* CSV (v0.6.0)
* DataFrames (v0.20.2)
* JuMP (v0.21.3)
* LinearAlgebra
* MathProgBase (v0.7.8)
* StatsBase (v0.33.0)
* YAML (v0.4.3)
* Clustering (v0.14.2)
* Combinatorics (v1.0.2)
* Distance (v0.10.2)
* Documenter (v0.24.7)
* DocumenterTools (v0.1.9)

You can see all of the packages installed in your Julia environment and their version numbers by running pkg> status on the package manager command line.

## Documentation

Detailed documentation for GenX can be found [here](https://docs.google.com/document/d/1G_1gdnSj92jF8nda2Zl8O4M5B98t19gOYnbbMFhohb4/edit?usp=sharing). It includes details of each of GenX's methods, required and optional input files, and outputs.

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

Note that if you have not already installed the required Julia packages, you are using a version of JuMP other than v0.21.4, or you do not have a valid Gurobi license on your host machine, you will receive an error message and Run_test.jl will not run to completion.
Documentation for [GenX](https://github.com/GenXProject/GenX).

## Contents
```@contents
```
## Index

```@index
```

```@autodocs
Modules = [GenX]
```