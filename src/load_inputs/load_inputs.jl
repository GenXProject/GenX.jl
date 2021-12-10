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

	## Use appropriate directory separator depending on Mac or Windows config
	if Sys.isunix()
		sep = "/"
    elseif Sys.iswindows()
		sep = "\U005c"
    else
        sep = "/"
	end

	data_directory = chop(replace(path, pwd() => ""), head = 1, tail = 0)

	## Read input files
	println("Reading Input CSV Files")
	## Declare Dict (dictionary) object used to store parameters
	inputs = Dict()
	# Read input data about power network topology, operating and expansion attributes
    if isfile(string(path,sep,"Network.csv"))
		inputs, network_var = load_network_data(setup, path, sep, inputs)
	else
		inputs["Z"] = 1
		inputs["L"] = 0
	end

	# Read temporal-resolved load data, and clustering information if relevant
	inputs = load_load_data(setup, path, sep, inputs)
	# Read fuel cost data, including time-varying fuel costs
	inputs, cost_fuel, CO2_fuel = load_fuels_data(setup, path, sep, inputs)
	# Read in generator/resource related inputs
	inputs = load_generators_data(setup, path, sep, inputs, cost_fuel, CO2_fuel)
	# Read in generator/resource availability profiles
	inputs = load_generators_variability(setup, path, sep, inputs)

	if setup["CapacityReserveMargin"]==1
		inputs = load_cap_reserve_margin(setup, path, sep, inputs)
		if inputs["Z"] >1
			inputs = load_cap_reserve_margin_trans(setup, path, sep, inputs,network_var)
		end
	end

	# Read in general configuration parameters for reserves (resource-specific reserve parameters are read in generators_data())
	if setup["Reserves"]==1
		inputs = load_reserves(setup, path, sep, inputs)
	end

	if setup["MinCapReq"] == 1
		inputs = load_minimum_capacity_requirement(path,sep, inputs, setup)
	end

	if setup["EnergyShareRequirement"]==1
		inputs = load_energy_share_requirement(setup, path, sep, inputs)
	end

	if setup["CO2Cap"] >= 1
		inputs = load_co2_cap(setup, path, sep, inputs)
	end

	if setup["CO2Tax"] >= 1
		inputs = load_co2_tax(setup, path, sep, inputs)
	end

	if setup["CO2Credit"] >= 1
		inputs = load_co2_credit(setup, path, sep, inputs)
	end


	# Read in mapping of modeled periods to representative periods
	if setup["OperationWrapping"]==1 && !isempty(inputs["STOR_LONG_DURATION"]) && (isfile(data_directory*"/Period_map.csv") || isfile(joinpath(data_directory,string(joinpath(setup["TimeDomainReductionFolder"],"Period_map.csv"))))) # Use Time Domain Reduced data for GenX)
		inputs = load_period_map(setup, path, sep, inputs)
	end
	
	println("CSV Files Successfully Read In From $path$sep")

	return inputs
end
