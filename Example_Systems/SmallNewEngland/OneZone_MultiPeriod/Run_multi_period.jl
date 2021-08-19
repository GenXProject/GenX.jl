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

#environment_path = "../../../package_activate.jl"
#include(environment_path) #Run this line to activate the Julia virtual environment for GenX; skip it, if the appropriate package versions are installed

### Set relevant directory paths
src_path = "../../../src/"

inpath = pwd()

### Load GenX
println("Loading packages")
push!(LOAD_PATH, src_path)

using Pkg
Pkg.activate("GenXJulEnv")

using GenX
using YAML
using BenchmarkTools

genx_settings = joinpath(settings_path, "genx_settings.yml") #Settings YAML file path
mysetup = YAML.load(open(genx_settings)) # mysetup dictionary stores settings and GenX-specific parameters

multiperiod_settings = joinpath(settings_path, "multi_period_settings.yml") # Multi period settings YAML file path 
merge!(mysetup,YAML.load(open(multiperiod_settings)))

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

# DDP Setup Parameters
#co2_array = [0.1, 0.05, 0.01] # CO2 emissions intensity in each model year in tCO2/MWh NOTE: the length of this array has to be align with number of model time periods

myinputs=Dict()
model_dict=Dict()
cur_inv_dict=Dict()
for t in 1:mysetup["NumPeriods"]

	# Step 0) Set Model Year
	mysetup["CurPeriod"] = t

	# Step 1) Load Inputs
	if mysetup["SeparateInputs"] == 1
		global inpath = string("$working_path/Input_Period_",t)
	end
	global myinputs = load_inputs(mysetup, inpath)
	myinputs = configure_multi_period_inputs(myinputs)

	# Step 2) Set the specific CO2 constraints for each model (overwriting the CSV file inputs)
	#Z = myinputs["Z"]
	#for z in 1:Z
	#	myinputs["pMaxCO2Rate"][z] = co2_array[t]
	#end

	# Step 3) Generate model
	EP = generate_model(mysetup, myinputs, OPTIMIZER)

	# Step 4) Add model to dictionary
	model_dict[t] = EP

end

#=
### Solve model
println("Solving Model")
EP, solve_time = solve_model(model_dict[1], mysetup)
myinputs["solve_time"] = solve_time # Store the model solve time in myinputs

### Write output
# Run MGA if the MGA flag is set to 1 else only save the least cost solution
println("Writing Output")
outpath = "$inpath/Results_DDP"
write_outputs(EP, outpath, mysetup, myinputs)
#println(@btime write_outputs(EP, outpath, mysetup, myinputs))
if mysetup["ModelingToGenerateAlternatives"] == 1
    println("Starting Model to Generate Alternatives (MGA) Iterations")
    mga(EP,inpath,mysetup,myinputs,outpath)
end
=#
# Step 5) Run DDP Algorithm
## Solve Model
myresults_d, mystats_d = run_ddp(model_dict, mysetup, myinputs)

#=
# Step 6) Write final outputs from each period
if ! isdir("Results")
	mkdir("Results")
end

for t in 1:mysetup["DDP_Total_Periods"]
	outpath = string("$working_path/Results/Results_Period_",t)
	GenX_Modular.write_outputs(mysetup,outpath,myresults_d[t],myinputs)
end

# Step 7) Write DDP summary outputs
outpath = string("$working_path/Results/")
write_ddp_outputs(myresults_d, mystats_d, outpath, mysetup)
=#