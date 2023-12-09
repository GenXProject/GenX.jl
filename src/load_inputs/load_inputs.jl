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
	load_inputs(setup::Dict,path::AbstractString)

Loads various data inputs from multiple input .csv files in path directory and stores variables in a Dict (dictionary) object for use in model() function

inputs:
setup - dict object containing setup parameters
path - string path to working directory

returns: Dict (dictionary) object containing all data inputs
"""
function load_inputs(setup::Dict,path::AbstractString)

	## Read input files
	println("Reading Input CSV Files")
	## Declare Dict (dictionary) object used to store parameters
	inputs = Dict()
	# Read input data about power network topology, operating and expansion attributes
	if isfile(joinpath(path,"Network.csv"))
		network_var = load_network_data!(setup, path, inputs)
	else
		inputs["Z"] = 1
		inputs["L"] = 0
	end

	# Read temporal-resolved load data, and clustering information if relevant
	load_demand_data!(setup, path, inputs)
	# Read clustering information if relevant
	load_cluster!(setup, path, inputs)
	# Read fuel cost data, including time-varying fuel costs
	cost_fuel, CO2_fuel = load_fuels_data!(setup, path, inputs)
	# Read in generator/resource related inputs
	load_generators_data!(setup, path, inputs, cost_fuel, CO2_fuel)
	# Read in generator/resource availability profiles
	load_generators_variability!(setup, path, inputs)

	if setup["CapacityReserveMargin"] == 1
		load_cap_reserve_margin!(setup, path, inputs)
		if inputs["Z"] > 1
			load_cap_reserve_margin_trans!(setup, inputs, network_var)
		end
	end

	# Read in general configuration parameters for reserves (resource-specific reserve parameters are read in generators_data())
	if setup["Reserves"] == 1
		load_reserves!(setup, path, inputs)
	end

	if setup["MinCapReq"] == 1
		load_minimum_capacity_requirement!(path, inputs, setup)
	end

	if setup["MaxCapReq"] == 1
		load_maximum_capacity_requirement!(path, inputs, setup)
	end

	if setup["EnergyShareRequirement"] == 1
		load_energy_share_requirement!(setup, path, inputs)
	end

	if setup["CO2Cap"] >= 1
		load_co2_cap!(setup, path, inputs)
	end

	if !isempty(inputs["VRE_STOR"])
		load_vre_stor_variability!(setup, path, inputs)
	end

	# Read in mapping of modeled periods to representative periods
	if is_period_map_necessary(setup, path, inputs) && is_period_map_exist(setup, path, inputs)
		load_period_map!(setup, path, inputs)
	end

	# Virtual charge discharge cost
	scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
	inputs["VirtualChargeDischargeCost"] = setup["VirtualChargeDischargeCost"] / scale_factor

	println("CSV Files Successfully Read In From $path")

	return inputs
end

function is_period_map_necessary(setup::Dict, path::AbstractString, inputs::Dict)
	ow = setup["OperationWrapping"]==1
	has_stor_lds = !isempty(inputs["STOR_LONG_DURATION"])
	has_hydro_lds = !isempty(inputs["STOR_HYDRO_LONG_DURATION"])
	has_vre_stor_lds = !isempty(inputs["VRE_STOR"]) && !isempty(inputs["VS_LDS"])
    multiple_rep_periods && (has_stor_lds || has_hydro_lds || has_vre_stor_lds)
end

function is_period_map_exist(setup::Dict, path::AbstractString, inputs::Dict)
	data_directory = chop(replace(path, pwd() => ""), head = 1, tail = 0)
	is_here = isfile(joinpath(data_directory,"Period_map.csv"))
	is_in_folder = isfile(joinpath(data_directory, setup["TimeDomainReductionFolder"], "Period_map.csv"))
	is_here || is_in_folder
end
