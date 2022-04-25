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

@doc raw"""
	load_data(setup::Dict, path::AbstractString, inputs_load::Dict)

Function for reading input parameters related to electricity load (demand)
"""
function load_load_data(setup::Dict, path::AbstractString, inputs_load::Dict)

	# Load related inputs
	#data_directory = chop(replace(path, pwd() => ""), head = 1, tail = 0)
	data_directory = joinpath(path, setup["TimeDomainReductionFolder"])
	if setup["TimeDomainReduction"] == 1  && isfile(joinpath(data_directory,"Load_data.csv")) && isfile(joinpath(data_directory,"Generators_variability.csv")) && isfile(joinpath(data_directory,"Fuels_data.csv")) # Use Time Domain Reduced data for GenX
		load_in = DataFrame(CSV.File(joinpath(data_directory,"Load_data.csv"), header=true), copycols=true)
	else # Run without Time Domain Reduction OR Getting original input data for Time Domain Reduction
		load_in = DataFrame(CSV.File(joinpath(path,"Load_data.csv"), header=true), copycols=true)
	end


	# Number of time steps (periods)
	inputs_load["T"] = size(collect(skipmissing(load_in[!,:Time_Index])),1)
	# Number of demand curtailment/lost load segments
	inputs_load["SEG"]=size(collect(skipmissing(load_in[!,:Demand_Segment])),1)

	## Set indices for internal use
	T = inputs_load["T"]   # Total number of time steps (hours)
	Z = inputs_load["Z"]   # Number of zones
	L = inputs_load["L"]   # Number of lines

	inputs_load["omega"] = zeros(Float64, T) # weights associated with operational sub-period in the model - sum of weight = 8760
	inputs_load["REP_PERIOD"] = 1   # Number of periods initialized
	inputs_load["H"] = 1   # Number of sub-periods within each period

	if setup["OperationWrapping"]==0 # Modeling full year chronologically at hourly resolution
		# Total number of subtime periods
		inputs_load["REP_PERIOD"] = 1
		# Simple scaling factor for number of subperiods
		inputs_load["omega"][:] .= 1 #changes all rows of inputs["omega"] from 0.0 to 1.0
	elseif setup["OperationWrapping"]==1
		# Weights for each period - assumed same weights for each sub-period within a period
		inputs_load["Weights"] = collect(skipmissing(load_in[!,:Sub_Weights])) # Weights each period

		# Total number of periods and subperiods
		inputs_load["REP_PERIOD"] = convert(Int16, collect(skipmissing(load_in[!,:Rep_Periods]))[1])
		inputs_load["H"] = convert(Int64, collect(skipmissing(load_in[!,:Timesteps_per_Rep_Period]))[1])

		# Creating sub-period weights from weekly weights
		for w in 1:inputs_load["REP_PERIOD"]
			for h in 1:inputs_load["H"]
				t = inputs_load["H"]*(w-1)+h
				inputs_load["omega"][t] = inputs_load["Weights"][w]/inputs_load["H"]
			end
		end
	end

	# Create time set steps indicies
	inputs_load["hours_per_subperiod"] = div.(T,inputs_load["REP_PERIOD"]) # total number of hours per subperiod
	hours_per_subperiod = inputs_load["hours_per_subperiod"] # set value for internal use

	inputs_load["START_SUBPERIODS"] = 1:hours_per_subperiod:T 	# set of indexes for all time periods that start a subperiod (e.g. sample day/week)
	inputs_load["INTERIOR_SUBPERIODS"] = setdiff(1:T,inputs_load["START_SUBPERIODS"]) # set of indexes for all time periods that do not start a subperiod

	# Demand in MW for each zone
	#println(names(load_in))
	start = findall(s -> s == "Load_MW_z1", names(load_in))[1] #gets the starting column number of all the columns, with header "Load_MW_z1"
	if setup["ParameterScale"] ==1  # Parameter scaling turned on
		# Max value of non-served energy
		inputs_load["Voll"] = collect(skipmissing(load_in[!,:Voll])) /ModelScalingFactor # convert from $/MWh $ million/GWh (assuming objective is divided by 1000)
		# Demand in MW
		inputs_load["pD"] =Matrix(load_in[1:inputs_load["T"],start:start-1+inputs_load["Z"]])/ModelScalingFactor  # convert to GW

	else # No scaling
		# Max value of non-served energy
		inputs_load["Voll"] = collect(skipmissing(load_in[!,:Voll]))
		# Demand in MW
		inputs_load["pD"] =Matrix(load_in[1:inputs_load["T"],start:start-1+inputs_load["Z"]]) #form a matrix with columns as the different zonal load MW values and rows as the hours
	end

	#if setup["TimeDomainReduction"] ==1 # Used in time_domain_reduction
	#	inputs_load["TimestepsPerPeriod"] = collect(skipmissing(load_in[!,:Timesteps_per_Rep_Period]))[1]
	#	inputs_load["UseExtremePeriods"] = collect(skipmissing(load_in[!,:UseExtremePeriods]))[1]
	#	inputs_load["MinPeriods"] = collect(skipmissing(load_in[!,:MinPeriods]))[1]
	#	inputs_load["MaxPeriods"] = collect(skipmissing(load_in[!,:MaxPeriods]))[1]
	#	inputs_load["IterativelyAddPeriods"] = collect(skipmissing(load_in[!,:IterativelyAddPeriods]))[1]
	#	inputs_load["IterateMethod"] = collect(skipmissing(load_in[!,:IterateMethod]))[1]
	#	inputs_load["ClusterMethod"] = collect(skipmissing(load_in[!,:ClusterMethod]))[1]
	#	inputs_load["Threshold"] = collect(skipmissing(load_in[!,:Threshold]))[1]
	#	inputs_load["nReps"] = collect(skipmissing(load_in[!,:nReps]))[1]
	#	inputs_load["ScalingMethod"] = collect(skipmissing(load_in[!,:ScalingMethod]))[1]
	#	inputs_load["LoadWeight"] = collect(skipmissing(load_in[!,:LoadWeight]))[1]
	#	inputs_load["ClusterFuelPrices"] = collect(skipmissing(load_in[!,:ClusterFuelPrices]))[1]
	#	inputs_load["WeightTotal"] = collect(skipmissing(load_in[!,:WeightTotal]))[1]
	#end

	# Cost of non-served energy/demand curtailment (for each segment)
	SEG = inputs_load["SEG"]  # Number of demand segments
	inputs_load["pC_D_Curtail"] = zeros(SEG)
	inputs_load["pMax_D_Curtail"] = zeros(SEG)
	for s in 1:SEG
		# Cost of each segment reported as a fraction of value of non-served energy - scaled implicitly
		inputs_load["pC_D_Curtail"][s] = collect(skipmissing(load_in[!,:Cost_of_Demand_Curtailment_per_MW]))[s]*inputs_load["Voll"][1]
		# Maximum hourly demand curtailable as % of the max demand (for each segment)
		inputs_load["pMax_D_Curtail"][s] = collect(skipmissing(load_in[!,:Max_Demand_Curtailment]))[s]
	end

	println("Load_data.csv Successfully Read!")

	return inputs_load
end
