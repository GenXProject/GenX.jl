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
	load_fuels_data(setup::Dict, path::AbstractString, sep::AbstractString, inputs_fuel::Dict)

Function for reading input parameters related to fuel costs and CO$_2$ content of fuels
"""
function load_fuels_data(setup::Dict, path::AbstractString, sep::AbstractString, inputs_fuel::Dict)

	# Fuel related inputs - read in different files depending on if time domain reduction is activated or not
	#data_directory = chop(replace(path, pwd() => ""), head = 1, tail = 0)
	data_directory = joinpath(path, setup["TimeDomainReductionFolder"])
	if setup["TimeDomainReduction"] == 1  && isfile(joinpath(data_directory,"Load_data.csv")) && isfile(joinpath(data_directory,"Generators_variability.csv")) && isfile(joinpath(data_directory,"Fuels_data.csv")) # Use Time Domain Reduced data for GenX
		fuels_in = DataFrame(CSV.File(string(joinpath(data_directory,"Fuels_data.csv")), header=true), copycols=true)
	else  # Run without Time Domain Reduction OR Getting original input data for Time Domain Reduction
		fuels_in = DataFrame(CSV.File(string(path,sep,"Fuels_data.csv"), header=true), copycols=true)
	end
    
	use_minmax_supply = false
	start_ind = 2
	if (fuels_in[1, :Time_Index] == -2) && (fuels_in[2, :Time_Index] == -1)
		println("\tMinimum and Maximum supply constraints found")
		start_ind += 2
		use_minmax_supply = true
	end
        
	# Fuel costs .&  CO2 emissions rate for each fuel type (stored in dictionary objects)
	fuels = names(fuels_in)[2:end] # fuel type indexes
	costs = Matrix(fuels_in[start_ind:end,2:end])
	# New addition for variable fuel price
	CO2_content = fuels_in[start_ind-1,2:end] # tons CO2/MMBtu
	fuel_costs = Dict{AbstractString,Array{Float64}}()
	fuel_CO2 = Dict{AbstractString,Float64}()
	Minimum_Supply_MMBTU = Vector{Float64}(undef, length(fuels))
	Maximum_Supply_MMBTU = Vector{Float64}(undef, length(fuels))
	if use_minmax_supply
		Minimum_Supply_MMBTU_content = fuels_in[1,2:end] # New addition for minimum supply constraint
		Maximum_Supply_MMBTU_content = fuels_in[2,2:end] # New addition for maximum supply constraint
	end
	for i = 1:length(fuels)
		if setup["ParameterScale"] ==1
			fuel_costs[string(fuels[i])] = costs[:,i]/ModelScalingFactor
			fuel_CO2[string(fuels[i])] = CO2_content[i]/ModelScalingFactor # kton/MMBTU
			if use_minmax_supply
				Minimum_Supply_MMBTU[i] = Minimum_Supply_MMBTU_content[i]/ModelScalingFactor 
				Maximum_Supply_MMBTU[i] = Maximum_Supply_MMBTU_content[i]/ModelScalingFactor 
			end
		else
			fuel_costs[string(fuels[i])] = costs[:,i]
			fuel_CO2[string(fuels[i])] = CO2_content[i] # ton/MMBTU
			if use_minmax_supply
				Minimum_Supply_MMBTU[i] = Minimum_Supply_MMBTU_content[i]
				Maximum_Supply_MMBTU[i] = Maximum_Supply_MMBTU_content[i]
			end
		end
	end

	inputs_fuel["fuels"] = fuels
	inputs_fuel["fuel_costs"] = fuel_costs
	inputs_fuel["fuel_CO2"] = fuel_CO2
	inputs_fuel["Minimum_Supply_MMBTU"] = Minimum_Supply_MMBTU
	inputs_fuel["Maximum_Supply_MMBTU"] = Maximum_Supply_MMBTU

	println("Fuels_data.csv Successfully Read!")

	return inputs_fuel, fuel_costs, fuel_CO2
end
