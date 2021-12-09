"""
GenX: An Configurable Capacity Expansion Model
Copyright (C) 2021,  Massachusetts Institute of Technology
This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
A complete copy of the GNU General Public License v2 (GPLv2) is available
in LICENSE.txt.  Users uncompressing this from an archive may not have
received this license file.  If not, see <http://www.gnu.org/licenses/>.
"""

cd(dirname(@__FILE__))
settings_path = joinpath(pwd(), "Settings")
#=
environment_path = "../../../package_activate.jl"
include(environment_path) #Run this line to activate the Julia virtual environment for GenX; skip it, if the appropriate package versions are installed
=#
### Set relevant directory paths
src_path = "../../../src/"

inpath = pwd()

### Load GenX
println("Loading packages")
push!(LOAD_PATH, src_path)

using GenX
using YAML
using BenchmarkTools

genx_settings = joinpath(settings_path, "genx_settings.yml") #Settings YAML file path
mysetup = YAML.load(open(genx_settings)) # mysetup dictionary stores settings and GenX-specific parameters

### Cluster time series inputs if necessary and if specified by the user
TDRpath = joinpath(inpath, mysetup["TimeDomainReductionFolder"])
if mysetup["TimeDomainReduction"] == 1
    if (!isfile(TDRpath*"/Load_data.csv")) || (!isfile(TDRpath*"/Generators_variability.csv")) || (!isfile(TDRpath*"/Fuels_data.csv"))
        println("Clustering Time Series Data...")
        cluster_inputs(inpath, settings_path, mysetup)
    else
        println("Time Series Data Already Clustered.")
    end
end

### Configure solver
println("Configuring Solver")
OPTIMIZER = configure_solver(mysetup["Solver"], settings_path)

#### Running a case

### Load inputs
println("Loading Inputs")
# myinputs dictionary will store read-in data and computed parameters
myinputs = load_inputs(mysetup, inpath)

### Generate model
println("Generating the Optimization Model")
EP = generate_model(mysetup, myinputs, OPTIMIZER)

### Solve model
println("Solving Model")
EP, solve_time = solve_model(EP, mysetup)
myinputs["solve_time"] = solve_time # Store the model solve time in myinputs

### Write output
# Run MGA if the MGA flag is set to 1 else only save the least cost solution
println("Writing Output")
outpath = "$inpath/Results"
elapsed_time = @elapsed write_outputs(EP, outpath, mysetup, myinputs)
println("Time elapsed for writing is")
println(elapsed_time)
if mysetup["ModelingToGenerateAlternatives"] == 1
    println("Starting Model to Generate Alternatives (MGA) Iterations")
    mga(EP,inpath,mysetup,myinputs,outpath)
end
