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
	loaderators_data(setup::Dict, path::AbstractString, sep::AbstractString, inputs::Dict, fuel_costs::Dict, fuel_CO2::Dict)

Function for reading input parameters related to electricity generators (plus storage and flexible demand resources)
"""
function load_fleccs_data(setup::Dict, path::AbstractString, sep::AbstractString, inputs_ccs::Dict, fuel_costs::Dict, fuel_CO2::Dict)

	if setup["FLECCS"] == 1
		gen_ccs = DataFrame(CSV.File(string(path,sep,"Fleccs_data1.csv"), header=true), copycols=true)
		inputs_ccs["G_F"] = unique(gen_ccs[!,:R_ID])[1]
		inputs_ccs["n_F"] =nrow(gen_ccs)
		inputs_ccs["dfGen_ccs"] = gen_ccs
		inputs_ccs["FLECCS_ALL"] = unique(gen_ccs[!,:R_ID])
	elseif setup["FLECCS"] == 2
		gen_ccs = DataFrame(CSV.File(string(path,sep,"Fleccs_data2.csv"), header=true), copycols=true)
		inputs_ccs["FLECCS_parameters"] = DataFrame(CSV.File(string(path,sep,"Fleccs_data2_process_parameters.csv"), header=true), copycols=true)
		inputs_ccs["G_F"] = unique(gen_ccs[!,:R_ID])[1]
		inputs_ccs["n_F"] =nrow(gen_ccs)
		inputs_ccs["N_F"] = unique(gen_ccs[!,:FLECCS_NO])
		inputs_ccs["dfGen_ccs"] = gen_ccs
		inputs_ccs["FLECCS_ALL"] = unique(gen_ccs[!,:R_ID])

	elseif setup["FLECCS"] == 3
		gen_ccs = DataFrame(CSV.File(string(path,sep,"Fleccs_data3.csv"), header=true), copycols=true)
		inputs_ccs["G_F"] = unique(gen_ccs[!,:R_ID])[1]
		inputs_ccs["dfGen_ccs"] = gen_ccs
		inputs_ccs["FLECCS_ALL"] = unique(gen_ccs[!,:R_ID])

	elseif setup["FLECCS"] == 4
		gen_ccs = DataFrame(CSV.File(string(path,sep,"Fleccs_data4.csv"), header=true), copycols=true)
		inputs_ccs["G_F"] = unique(gen_ccs[!,:R_ID])[1]
		inputs_ccs["n_F"] =nrow(gen_ccs)
		inputs_ccs["dfGen_ccs"] = gen_ccs
		inputs_ccs["FLECCS_ALL"] = unique(gen_ccs[!,:R_ID])

	elseif setup["FLECCS"] == 4
		gen_ccs = DataFrame(CSV.File(string(path,sep,"Fleccs_data4.csv"), header=true), copycols=true)
		inputs_ccs["G_F"] = unique(gen_ccs[!,:R_ID])[1]
		inputs_ccs["n_F"] =nrow(gen_ccs)
		inputs_ccs["dfGen_ccs"] = gen_ccs
		inputs_ccs["FLECCS_ALL"] = unique(gen_ccs[!,:R_ID])

	elseif setup["FLECCS"] == 5
		gen_ccs = DataFrame(CSV.File(string(path,sep,"Fleccs_data5.csv"), header=true), copycols=true)
		inputs_ccs["G_F"] = unique(gen_ccs[!,:R_ID])[1]
		inputs_ccs["n_F"] =nrow(gen_ccs)
		inputs_ccs["dfGen_ccs"] = gen_ccs
		inputs_ccs["FLECCS_ALL"] = unique(gen_ccs[!,:R_ID])

	elseif setup["FLECCS"] == 6
		gen_ccs = DataFrame(CSV.File(string(path,sep,"Fleccs_data6.csv"), header=true), copycols=true)
		inputs_ccs["G_F"] = unique(gen_ccs[!,:R_ID])[1]
		inputs_ccs["n_F"] =nrow(gen_ccs)
		inputs_ccs["dfGen_ccs"] = gen_ccs
		inputs_ccs["FLECCS_ALL"] = unique(gen_ccs[!,:R_ID])

	elseif setup["FLECCS"] == 7
		gen_ccs = DataFrame(CSV.File(string(path,sep,"Fleccs_data7.csv"), header=true), copycols=true)
		inputs_ccs["G_F"] = unique(gen_ccs[!,:R_ID])[1]
		inputs_ccs["n_F"] =nrow(gen_ccs)
		inputs_ccs["dfGen_ccs"] = gen_ccs
		inputs_ccs["FLECCS_ALL"] = unique(gen_ccs[!,:R_ID])
	end


	n_F =nrow(gen_ccs)
	G_F =unique(gen_ccs[!,:R_ID])[1]
	FLECCS_ALL =unique(gen_ccs[!,:R_ID])

	# save fuel_costs and CO2_fuel
	inputs_ccs["fuel_costs"] = fuel_costs
	inputs_ccs["fuel_CO2"] = fuel_CO2


	# Set of all resources eligible for new capacity
	inputs_ccs["NEW_CAP_fleccs"] = intersect(gen_ccs[gen_ccs.New_Build.==1,:R_ID], gen_ccs[gen_ccs.Max_Cap_MW.!=0,:R_ID])
	# Set of all resources eligible for capacity retirements
	inputs_ccs["RET_CAP_fleccs"] = intersect(gen_ccs[gen_ccs.New_Build.!=-1,:R_ID], gen_ccs[gen_ccs.Existing_Cap_MW.>=0,:R_ID])

	# Names of subcompoents
	inputs_ccs["SUBCOMPONENTS"] = collect(skipmissing(gen_ccs[!,:Resource][1:inputs_ccs["n_F"]]))
	# Zones resources are located in
	zones = collect(skipmissing(gen_ccs[!,:Zone][1:inputs_ccs["n_F"]]))
	# Resource identifiers by zone (just zones in resource order + resource and zone concatenated)
	inputs_ccs["R_ZONES_fleccs"] = zones
	inputs_ccs["SUBCOMPONENTS_ZONES"] = inputs_ccs["SUBCOMPONENTS"] .* "_z" .* string.(zones)

	if setup["ParameterScale"] ==1  # Parameter scaling turned on - adjust values of subset of parameter values
		# The existing charging capacity for resources where STOR = 2
		inputs_ccs["dfGen_ccs"][!,:Existing_Cap_Unit] = gen_ccs[!,:Existing_Cap_Unit]/ModelScalingFactor # Convert from MW to GW, or from tCO2 to kt CO2

		# Cap_Size scales only capacities for those technologies with capacity >1
		# Step 1: convert vector to float
		inputs_ccs["dfGen_ccs"][!,:Cap_Size] =convert(Array{Float64}, gen_ccs[!,:Cap_Size])
		for g in 1:n_F  # Scale only those capacities for which Cap_Size > 1
			if inputs_ccs["dfGen_ccs"][!,:Cap_Size][g]>1.0
				inputs_ccs["dfGen_ccs"][!,:Cap_Size][g] = gen_ccs[!,:Cap_Size][g]/ModelScalingFactor # Convert to GW
			end
		end

		## Investment cost terms
		# Annualized capacity investment cost of a generation technology
		inputs_ccs["dfGen_ccs"][!,:Inv_Cost_per_Unityr] = gen_ccs[!,:Inv_Cost_per_Unityr]/ModelScalingFactor # Convert to $ million/GW/yr with objective function in millions
		## Fixed O&M cost terms
		# Fixed operations and maintenance cost of a generation or storage technology
		inputs_ccs["dfGen_ccs"][!,:Fixed_OM_Cost_per_Unityr] = gen_ccs[!,:Fixed_OM_Cost_per_Unityr]/ModelScalingFactor # Convert to $ million/GW/yr with objective function in millions
		## Variable O&M cost terms
		# Variable operations and maintenance cost of a generation or storage technology
		inputs_ccs["dfGen_ccs"][!,:Var_OM_Cost_per_Unit] = gen_ccs[!,:Var_OM_Cost_per_Unit]/ModelScalingFactor # Convert to $ million/GWh with objective function in millions

	end

# the CO2 emissions assocoated with fleccs are not calculated here
# here we only account for the co2 emissions asscoiated with startup fuel, which can not be captured.
	if setup["UCommit"]>=1

		inputs_ccs["COMMIT_CCS"] = G_F

		if setup["ParameterScale"] ==1  # Parameter scaling turned on - adjust values of subset of parameter values
			# Cost per MW of nameplate capacity to start a generator
			inputs_ccs["dfGen_ccs"][!,:Start_Cost_per_Unit] = gen_ccs[!,:Start_Cost_per_Unit]/ModelScalingFactor # Convert to $ million/GW with objective function in millions
		end

		# Fuel consumed on start-up (million BTUs per MW per start) if unit commitment is modelled
		start_fuel = convert(Array{Float64}, collect(skipmissing(gen_ccs[!,:Start_Fuel_MMBTU_per_Unit])))
		# Fixed cost per start-up ($ per MW per start) if unit commitment is modelled
		start_cost = convert(Array{Float64}, collect(skipmissing(inputs_ccs["dfGen_ccs"][!,:Start_Cost_per_Unit])))
		inputs_ccs["C_Start"] = zeros(Float64, n_F, inputs_ccs["T"])
		inputs_ccs["dfGen_ccs"][!,:CO2_per_Start] = zeros(Float64, n_F)
	    # Fuel used by each resource
	    fuel_type = collect(skipmissing(gen_ccs[!,:Fuel]))

	   # for g in 1:n_F
			# Start-up cost is sum of fixed cost per start plus cost of fuel consumed on startup.
			# CO2 from fuel consumption during startup also calculated
		    #inputs_ccs["C_Start"][g,:] = inputs_ccs["dfGen_ccs"][!,:Cap_Size][g] * (fuel_costs[fuel_type[g]] .* start_fuel[g] .+ start_cost[g])
		#	inputs_ccs["C_Start"][g,:] = inputs_ccs["dfGen_ccs"][!,:Cap_Size][g] * (fuel_costs[fuel_type[g]] .* start_fuel[g] .+ start_cost[g])
			# No need to re-scale C_Start since Cap_size, fuel_costs and start_cost are scaled When Setup[ParameterScale] =1 - Dharik
		#	inputs_ccs["dfGen_ccs"][!,:CO2_per_Start][g] = inputs_ccs["dfGen_ccs"][!,:Cap_Size][g] * (fuel_CO2[fuel_type[g]] .* start_fuel[g])
			
		#	if setup["ParameterScale"] ==1
		#		inputs_ccs["dfGen_ccs"][!,:CO2_per_Start][g] = inputs_ccs["dfGen_ccs"][!,:CO2_per_Start][g] * ModelScalingFactor
		#	end
		#end
	else
		inputs_ccs["COMMIT_CCS"] = Int64[]
	end

	if setup["FLECCS"] == 1
		println("fleccs_data1.csv Successfully Read!, NGCC-CCS without flexible subcompoents")
	elseif setup["FLECCS"] == 2
		println("fleccs_data2.csv Successfully Read!, NGCC-CCS coupled with solvent/sorbent storage")
	elseif setup["FLECCS"] == 3
		println("fleccs_data3.csv Successfully Read!, NGCC-CCS coupled with thermal storage")
	elseif setup["FLECCS"] == 4
		println("fleccs_data4.csv Successfully Read!, NGCC-CCS coupled with H2 generation and storage")
	elseif setup["FLECCS"] == 5
		println("fleccs_data5.csv Successfully Read!, NGCC-CCS coupled with DAC (Gtech or Upitt)")
	elseif setup["FLECCS"] == 6
		println("fleccs_data6.csv Successfully Read!, NGCC-CCS coupled with DAC (MIT)")
	elseif setup["FLECCS"] == 7
		println("fleccs_data7.csv Successfully Read!, Allam cycle coupled with CO2 storage")
	end



	return inputs_ccs
end
