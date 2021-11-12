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
	load_generators_data(setup::Dict, path::AbstractString, sep::AbstractString, inputs_gen::Dict, fuel_costs::Dict, fuel_CO2::Dict)

Function for reading input parameters related to electricity generators (plus storage and flexible demand resources)
"""
function load_generators_data(setup::Dict, path::AbstractString, sep::AbstractString, inputs_gen::Dict, fuel_costs::Dict, fuel_CO2::Dict)

	# Generator related inputs
	gen_in = DataFrame(CSV.File(string(path,sep,"Generators_data.csv"), header=true), copycols=true)

	# Add Resource IDs after reading to prevent user errors
	gen_in[!,:R_ID] = 1:size(collect(skipmissing(gen_in[!,1])),1)

	# Store DataFrame of generators/resources input data for use in model
	inputs_gen["dfGen"] = gen_in

	# Number of resources
	inputs_gen["G"] = size(collect(skipmissing(gen_in[!,:R_ID])),1)

	# Set indices for internal use
	G = inputs_gen["G"]   # Number of resources (generators, storage, DR, and DERs)

	## Defining sets of generation and storage resources

	# Set of storage resources with symmetric charge/discharge capacity
	inputs_gen["STOR_SYMMETRIC"] = gen_in[gen_in.STOR.==1,:R_ID]
	# Set of storage resources with asymmetric (separte) charge/discharge capacity components
	inputs_gen["STOR_ASYMMETRIC"] = gen_in[gen_in.STOR.==2,:R_ID]
	# Set of all storage resources
	inputs_gen["STOR_ALL"] = union(inputs_gen["STOR_SYMMETRIC"],inputs_gen["STOR_ASYMMETRIC"])

	# Set of storage resources with long duration storage capabilitites
	inputs_gen["STOR_HYDRO_LONG_DURATION"] = gen_in[gen_in.LDS.==1,:R_ID]
	inputs_gen["STOR_LONG_DURATION"] = gen_in[gen_in.LDS.==2,:R_ID]

	# Set of all reservoir hydro resources
	inputs_gen["HYDRO_RES"] = gen_in[(gen_in[!,:HYDRO].==1),:R_ID]
	# Set of reservoir hydro resources modeled with known reservoir energy capacity
	inputs_gen["HYDRO_RES_KNOWN_CAP"] = intersect(gen_in[gen_in.Hydro_Energy_to_Power_Ratio.>0,:R_ID], inputs_gen["HYDRO_RES"])

	# Set of flexible demand-side resources
	inputs_gen["FLEX"] = gen_in[gen_in.FLEX.==1,:R_ID]

	# Set of must-run plants - could be behind-the-meter PV, hydro run-of-river, must-run fossil or thermal plants
	inputs_gen["MUST_RUN"] = gen_in[gen_in.MUST_RUN.==1,:R_ID]

	# Set of controllable variable renewable resources
	inputs_gen["VRE"] = gen_in[gen_in.VRE.>=1,:R_ID]

	# Set of thermal generator resources
	if setup["UCommit"]>=1
		# Set of thermal resources eligible for unit committment
		inputs_gen["THERM_COMMIT"] = gen_in[gen_in.THERM.==1,:R_ID]
		# Set of thermal resources not eligible for unit committment
		inputs_gen["THERM_NO_COMMIT"] = gen_in[gen_in.THERM.==2,:R_ID]
	else # When UCommit == 0, no thermal resources are eligible for unit committment
		inputs_gen["THERM_COMMIT"] = Int64[]
		inputs_gen["THERM_NO_COMMIT"] = union(gen_in[gen_in.THERM.==1,:R_ID], gen_in[gen_in.THERM.==2,:R_ID])
	end
	inputs_gen["THERM_ALL"] = union(inputs_gen["THERM_COMMIT"],inputs_gen["THERM_NO_COMMIT"])

	# For now, the only resources eligible for UC are themal resources
	inputs_gen["COMMIT"] = inputs_gen["THERM_COMMIT"]

	if setup["Reserves"] >= 1
		# Set for resources with regulation reserve requirements
		inputs_gen["REG"] = gen_in[(gen_in[!,:Reg_Max].>0),:R_ID]
		# Set for resources with spinning reserve requirements
		inputs_gen["RSV"] = gen_in[(gen_in[!,:Rsv_Max].>0),:R_ID]
	end

	# Set of all resources eligible for new capacity
	inputs_gen["NEW_CAP"] = intersect(gen_in[gen_in.New_Build.==1,:R_ID], gen_in[gen_in.Max_Cap_MW.!=0,:R_ID])
	# Set of all resources eligible for capacity retirements
	inputs_gen["RET_CAP"] = intersect(gen_in[gen_in.New_Build.!=-1,:R_ID], gen_in[gen_in.Existing_Cap_MW.>=0,:R_ID])

	# Set of all storage resources eligible for new energy capacity
	inputs_gen["NEW_CAP_ENERGY"] = intersect(gen_in[gen_in.New_Build.==1,:R_ID], gen_in[gen_in.Max_Cap_MWh.!=0,:R_ID], inputs_gen["STOR_ALL"])
	# Set of all storage resources eligible for energy capacity retirements
	inputs_gen["RET_CAP_ENERGY"] = intersect(gen_in[gen_in.New_Build.!=-1,:R_ID], gen_in[gen_in.Existing_Cap_MWh.>=0,:R_ID], inputs_gen["STOR_ALL"])

	# Set of asymmetric charge/discharge storage resources eligible for new charge capacity
	inputs_gen["NEW_CAP_CHARGE"] = intersect(gen_in[gen_in.New_Build.==1,:R_ID], gen_in[gen_in.Max_Charge_Cap_MW.!=0,:R_ID], inputs_gen["STOR_ASYMMETRIC"])
	# Set of asymmetric charge/discharge storage resources eligible for charge capacity retirements
	inputs_gen["RET_CAP_CHARGE"] = intersect(gen_in[gen_in.New_Build.!=-1,:R_ID], gen_in[gen_in.Existing_Charge_Cap_MW.>=0,:R_ID], inputs_gen["STOR_ASYMMETRIC"])

	# Names of resources
	inputs_gen["RESOURCES"] = collect(skipmissing(gen_in[!,:Resource][1:inputs_gen["G"]]))
	# Zones resources are located in
	zones = collect(skipmissing(gen_in[!,:Zone][1:inputs_gen["G"]]))
	# Resource identifiers by zone (just zones in resource order + resource and zone concatenated)
	inputs_gen["R_ZONES"] = zones
	inputs_gen["RESOURCE_ZONES"] = inputs_gen["RESOURCES"] .* "_z" .* string.(zones)

	if setup["ParameterScale"] ==1  # Parameter scaling turned on - adjust values of subset of parameter values

		# The existing capacity of a power plant in megawatts
		inputs_gen["dfGen"][!,:Existing_Charge_Cap_MW] = gen_in[!,:Existing_Charge_Cap_MW]/ModelScalingFactor # Convert to GW
		# The existing capacity of storage in megawatt-hours STOR = 1 or STOR = 2
		inputs_gen["dfGen"][!,:Existing_Cap_MWh] = gen_in[!,:Existing_Cap_MWh]/ModelScalingFactor # Convert to GWh
		# The existing charging capacity for resources where STOR = 2
		inputs_gen["dfGen"][!,:Existing_Cap_MW] = gen_in[!,:Existing_Cap_MW]/ModelScalingFactor # Convert to GW

		# Cap_Size scales only capacities for those technologies with capacity >1
		# Step 1: convert vector to float
		inputs_gen["dfGen"][!,:Cap_Size] =convert(Array{Float64}, gen_in[!,:Cap_Size])
		for g in 1:G  # Scale only those capacities for which Cap_Size > 1
			if inputs_gen["dfGen"][!,:Cap_Size][g]>1.0
				inputs_gen["dfGen"][!,:Cap_Size][g] = gen_in[!,:Cap_Size][g]/ModelScalingFactor # Convert to GW
			end
		end

		# Min capacity terms
		# Limit on minimum discharge capacity of the resource. -1 if no limit on minimum capacity
		inputs_gen["dfGen"][!,:Min_Cap_MW] = gen_in[!,:Min_Cap_MW]/ModelScalingFactor # Convert to GW
		# Limit on minimum energy capacity of the resource. -1 if no limit on minimum capacity
		inputs_gen["dfGen"][!,:Min_Cap_MWh] = gen_in[!,:Min_Cap_MWh]/ModelScalingFactor # Convert to GWh
		# Limit on minimum charge capacity of the resource. -1 if no limit on minimum capacity
		inputs_gen["dfGen"][!,:Min_Charge_Cap_MW] = gen_in[!,:Min_Charge_Cap_MW]/ModelScalingFactor # Convert to GWh

		## Max capacity terms
		# Limit on maximum discharge capacity of the resource. -1 if no limit on maximum capacity
		inputs_gen["dfGen"][!,:Max_Cap_MW] = gen_in[!,:Max_Cap_MW]/ModelScalingFactor # Convert to GW
		# Limit on maximum energy capacity of the resource. -1 if no limit on maximum capacity
		inputs_gen["dfGen"][!,:Max_Cap_MWh] = gen_in[!,:Max_Cap_MWh]/ModelScalingFactor # Convert to GWh
		# Limit on maximum charge capacity of the resource. -1 if no limit on maximum capacity
		inputs_gen["dfGen"][!,:Max_Charge_Cap_MW] = gen_in[!,:Max_Charge_Cap_MW]/ModelScalingFactor # Convert to GW

		## Investment cost terms
		# Annualized capacity investment cost of a generation technology
		inputs_gen["dfGen"][!,:Inv_Cost_per_MWyr] = gen_in[!,:Inv_Cost_per_MWyr]/ModelScalingFactor # Convert to $ million/GW/yr with objective function in millions
		# Annualized investment cost of the energy capacity for a storage technology with STOR = 1 or STOR = 2
		inputs_gen["dfGen"][!,:Inv_Cost_per_MWhyr] = gen_in[!,:Inv_Cost_per_MWhyr]/ModelScalingFactor # Convert to $ million/GWh/yr  with objective function in millions
		# Annualized capacity investment cost for the charging portion of a storage technology with STOR = 2
		inputs_gen["dfGen"][!,:Inv_Cost_Charge_per_MWyr] = gen_in[!,:Inv_Cost_Charge_per_MWyr]/ModelScalingFactor # Convert to $ million/GWh/yr  with objective function in millions

		## Fixed O&M cost terms
		# Fixed operations and maintenance cost of a generation or storage technology
		inputs_gen["dfGen"][!,:Fixed_OM_Cost_per_MWyr] = gen_in[!,:Fixed_OM_Cost_per_MWyr]/ModelScalingFactor # Convert to $ million/GW/yr with objective function in millions
		# Fixed operations and maintenance cost of the power aspect of a storage technology of type STOR = 1 or STOR = 2
		inputs_gen["dfGen"][!,:Fixed_OM_Cost_per_MWhyr] = gen_in[!,:Fixed_OM_Cost_per_MWhyr]/ModelScalingFactor # Convert to $ million/GW/yr with objective function in millions
		# Fixed operations and maintenance cost of the charging aspect of a storage technology of type STOR = 2
		inputs_gen["dfGen"][!,:Fixed_OM_Cost_Charge_per_MWyr] = gen_in[!,:Fixed_OM_Cost_Charge_per_MWyr]/ModelScalingFactor # Convert to $ million/GW/yr with objective function in millions

		## Variable O&M cost terms
		# Variable operations and maintenance cost of a generation or storage technology
		inputs_gen["dfGen"][!,:Var_OM_Cost_per_MWh] = gen_in[!,:Var_OM_Cost_per_MWh]/ModelScalingFactor # Convert to $ million/GWh with objective function in millions
		# Variable operations and maintenance cost of the charging aspect of a storage technology with STOR = 2,
		# or variable operations and maintenance costs associated with flexible demand with FLEX = 1
		inputs_gen["dfGen"][!,:Var_OM_Cost_per_MWh_In] = gen_in[!,:Var_OM_Cost_per_MWh_In]/ModelScalingFactor # Convert to $ million/GWh with objective function in millions
		# Cost of providing regulation reserves
		inputs_gen["dfGen"][!,:Reg_Cost] = gen_in[!,:Reg_Cost]/ModelScalingFactor # Convert to $ million/GW with objective function in millions
		# Cost of providing spinning reserves
		inputs_gen["dfGen"][!,:Rsv_Cost] = gen_in[!,:Rsv_Cost]/ModelScalingFactor # Convert to $ million/GW with objective function in millions

	end

# Dharik - Done, we have scaled fuel costs above so any parameters on per MMBtu do not need to be scaled
	if setup["UCommit"]>=1
		if setup["ParameterScale"] ==1  # Parameter scaling turned on - adjust values of subset of parameter values
			# Cost per MW of nameplate capacity to start a generator
			inputs_gen["dfGen"][!,:Start_Cost_per_MW] = gen_in[!,:Start_Cost_per_MW]/ModelScalingFactor # Convert to $ million/GW with objective function in millions
		end

		# Fuel consumed on start-up (million BTUs per MW per start) if unit commitment is modelled
		start_fuel = convert(Array{Float64}, collect(skipmissing(gen_in[!,:Start_Fuel_MMBTU_per_MW])))
		# Fixed cost per start-up ($ per MW per start) if unit commitment is modelled
		start_cost = convert(Array{Float64}, collect(skipmissing(inputs_gen["dfGen"][!,:Start_Cost_per_MW])))
		inputs_gen["C_Start"] = zeros(Float64, G, inputs_gen["T"])
		inputs_gen["dfGen"][!,:CO2_per_Start] = zeros(Float64, G)
	end

	# Heat rate of all resources (million BTUs/MWh)
	heat_rate = convert(Array{Float64}, collect(skipmissing(gen_in[!,:Heat_Rate_MMBTU_per_MWh])) )
	# Fuel used by each resource
	fuel_type = collect(skipmissing(gen_in[!,:Fuel]))
	# Maximum fuel cost in $ per MWh and CO2 emissions in tons per MWh
	inputs_gen["C_Fuel_per_MWh"] = zeros(Float64, G, inputs_gen["T"])
	inputs_gen["dfGen"][!,:CO2_per_MWh] = zeros(Float64, G)
	for g in 1:G
		# NOTE: When Setup[ParameterScale] =1, fuel costs are scaled in fuels_data.csv, so no if condition needed to scale C_Fuel_per_MWh
		inputs_gen["C_Fuel_per_MWh"][g,:] = fuel_costs[fuel_type[g]].*heat_rate[g]
		inputs_gen["dfGen"][!,:CO2_per_MWh][g] = fuel_CO2[fuel_type[g]]*heat_rate[g]
		if setup["ParameterScale"] ==1
			inputs_gen["dfGen"][!,:CO2_per_MWh][g] = inputs_gen["dfGen"][!,:CO2_per_MWh][g] * ModelScalingFactor
		end
		# kton/MMBTU * MMBTU/MWh = kton/MWh, to get kton/GWh, we need to mutiply 1000
		if g in inputs_gen["COMMIT"]
			# Start-up cost is sum of fixed cost per start plus cost of fuel consumed on startup.
			# CO2 from fuel consumption during startup also calculated

			inputs_gen["C_Start"][g,:] = inputs_gen["dfGen"][!,:Cap_Size][g] * (fuel_costs[fuel_type[g]] .* start_fuel[g] .+ start_cost[g])
			# No need to re-scale C_Start since Cap_size, fuel_costs and start_cost are scaled When Setup[ParameterScale] =1 - Dharik
			inputs_gen["dfGen"][!,:CO2_per_Start][g]  = inputs_gen["dfGen"][!,:Cap_Size][g]*(fuel_CO2[fuel_type[g]]*start_fuel[g])
			if setup["ParameterScale"] ==1
				inputs_gen["dfGen"][!,:CO2_per_Start][g] = inputs_gen["dfGen"][!,:CO2_per_Start][g] * ModelScalingFactor
			end
			# Setup[ParameterScale] =1, inputs_gen["dfGen"][!,:Cap_Size][g] is GW, fuel_CO2[fuel_type[g]] is ktons/MMBTU, start_fuel is MMBTU/MW,
			#   thus the overall is MTons/GW, and thus inputs_gen["dfGen"][!,:CO2_per_Start][g] is Mton, to get kton, change we need to multiply 1000
			# Setup[ParameterScale] =0, inputs_gen["dfGen"][!,:Cap_Size][g] is MW, fuel_CO2[fuel_type[g]] is tons/MMBTU, start_fuel is MMBTU/MW,
			#   thus the overall is MTons/GW, and thus inputs_gen["dfGen"][!,:CO2_per_Start][g] is ton
		end
	end
	println("Generators_data.csv Successfully Read!")

	return inputs_gen
end
