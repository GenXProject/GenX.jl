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
	load_load_data!(setup::Dict, path::AbstractString, inputs::Dict)

Read input parameters related to electricity load (demand)
"""
function load_load_data!(setup::Dict, path::AbstractString, inputs::Dict)

	# Load related inputs
	data_directory = joinpath(path, setup["TimeDomainReductionFolder"])
    if setup["TimeDomainReduction"] == 1  && time_domain_reduced_files_exist(data_directory)
        my_dir = data_directory
	else
        my_dir = path
	end
    filename = "Load_data.csv"
    file_path = joinpath(my_dir, filename)
    load_in = DataFrame(CSV.File(file_path, header=true), copycols=true)

    as_vector(col::Symbol) = collect(skipmissing(load_in[!, col]))

	# Number of time steps (periods)
    T = length(as_vector(:Time_Index))
	# Number of demand curtailment/lost load segments
    SEG = length(as_vector(:Demand_Segment))

	## Set indices for internal use
    inputs["T"] = T
    inputs["SEG"] = SEG
	Z = inputs["Z"]   # Number of zones

	inputs["omega"] = zeros(Float64, T) # weights associated with operational sub-period in the model - sum of weight = 8760
	inputs["REP_PERIOD"] = 1   # Number of periods initialized
	inputs["H"] = 1   # Number of sub-periods within each period

	if setup["OperationWrapping"]==0 # Modeling full year chronologically at hourly resolution
		# Simple scaling factor for number of subperiods
		inputs["omega"] .= 1 #changes all rows of inputs["omega"] from 0.0 to 1.0
	elseif setup["OperationWrapping"]==1
		# Weights for each period - assumed same weights for each sub-period within a period
		inputs["Weights"] = as_vector(:Sub_Weights) # Weights each period

		# Total number of periods and subperiods
		inputs["REP_PERIOD"] = convert(Int16, as_vector(:Rep_Periods)[1])
		inputs["H"] = convert(Int64, as_vector(:Timesteps_per_Rep_Period)[1])

		# Creating sub-period weights from weekly weights
		for w in 1:inputs["REP_PERIOD"]
			for h in 1:inputs["H"]
				t = inputs["H"]*(w-1)+h
				inputs["omega"][t] = inputs["Weights"][w]/inputs["H"]
			end
		end
	end

	# Create time set steps indicies
	inputs["hours_per_subperiod"] = div.(T,inputs["REP_PERIOD"]) # total number of hours per subperiod
	hours_per_subperiod = inputs["hours_per_subperiod"] # set value for internal use

	inputs["START_SUBPERIODS"] = 1:hours_per_subperiod:T 	# set of indexes for all time periods that start a subperiod (e.g. sample day/week)
	inputs["INTERIOR_SUBPERIODS"] = setdiff(1:T, inputs["START_SUBPERIODS"]) # set of indexes for all time periods that do not start a subperiod

	# Demand in MW for each zone
	start = findall(s -> s == "Load_MW_z1", names(load_in))[1] #gets the starting column number of all the columns, with header "Load_MW_z1"
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
    # Max value of non-served energy
    inputs["Voll"] = as_vector(:Voll) / scale_factor # convert from $/MWh $ million/GWh (assuming objective is divided by 1000)
    # Demand in MW
    inputs["pD"] =Matrix(load_in[1:T, start:start+Z-1]) / scale_factor  # convert to GW

	# Cost of non-served energy/demand curtailment
    # Cost of each segment reported as a fraction of value of non-served energy - scaled implicitly
    inputs["pC_D_Curtail"] = as_vector(:Cost_of_Demand_Curtailment_per_MW) * inputs["Voll"][1]
    # Maximum hourly demand curtailable as % of the max demand (for each segment)
    inputs["pMax_D_Curtail"] = as_vector(:Max_Demand_Curtailment)

	println(filename * " Successfully Read!")
end
