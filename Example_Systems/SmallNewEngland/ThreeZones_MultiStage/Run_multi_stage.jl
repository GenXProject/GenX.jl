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

environment_path = "../../../package_activate.jl"
#include(environment_path) #Run this line to activate the Julia virtual environment for GenX; skip it, if the appropriate package versions are installed

### Set relevant directory paths
src_path = "../../../src/"

inpath = pwd()

### Load GenX
println("Loading packages")
push!(LOAD_PATH, src_path)

#using Pkg
#Pkg.activate("GenXJulEnv")

using GenX
using YAML
using BenchmarkTools

genx_settings = joinpath(settings_path, "genx_settings.yml") #Settings YAML file path
mysetup = configure_settings(genx_settings) # mysetup dictionary stores settings and GenX-specific parameters

multistage_settings = joinpath(settings_path, "multi_stage_settings.yml") # Multi stage settings YAML file path
mysetup["MultiStageSettingsDict"] = YAML.load(open(multistage_settings))

### Cluster time series inputs if necessary and if specified by the user
TDRpath = joinpath(inpath, "Inputs", "Inputs_p1", mysetup["TimeDomainReductionFolder"])
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

### Load Inputs
model_dict=Dict()
inputs_dict=Dict()

for t in 1:mysetup["MultiStageSettingsDict"]["NumStages"]

	# Step 0) Set Model Year
	mysetup["MultiStageSettingsDict"]["CurStage"] = t

	# Step 1) Load Inputs
	global inpath_sub = string("$inpath/Inputs/Inputs_p",t)

	inputs_dict[t] = load_inputs(mysetup, inpath_sub)
	inputs_dict[t] = configure_multi_stage_inputs(inputs_dict[t],mysetup["MultiStageSettingsDict"],mysetup["NetworkExpansion"])

	# Step 2) Generate model
	model_dict[t] = generate_model(mysetup, inputs_dict[t], OPTIMIZER)
end

### Solve model
println("Solving Model")

# Step 3) Run DDP Algorithm
model_dict, mystats_d, inputs_dict = run_ddp(model_dict, mysetup, inputs_dict)

# Step 4) Write final outputs from each stage
outpath = string("$inpath/Results")
if !haskey(mysetup, "OverwriteResults") || mysetup["OverwriteResults"] == 1
	# Overwrite existing results if dir exists
	# This is the default behaviour when there is no flag, to avoid breaking existing code
	if !(isdir(outpath))
		mkdir(outpath)
	end
else
	# Find closest unused ouput directory name and create it
	outpath = choose_output_dir(outpath)
	mkdir(outpath)
end

for p in 1:mysetup["MultiStageSettingsDict"]["NumStages"]
	outpath_cur = string("$outpath/Results_p$p")
	write_outputs(model_dict[p], outpath_cur, mysetup, inputs_dict[p])
end

# Step 5) Write DDP summary outputs
write_multi_stage_outputs(mystats_d, outpath, mysetup, inputs_dict)