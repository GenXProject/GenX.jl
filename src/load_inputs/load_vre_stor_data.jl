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
	load_vre_stor_data(setup::Dict, path::AbstractString, sep::AbstractString, inputs_vre_stor::Dict, fuel_costs::Dict, fuel_CO2::Dict)

Function for reading input parameters related to specifically co-located VRE-storage generators or co-optimized VRE resources.
"""
function load_vre_stor_data(setup::Dict, path::AbstractString, sep::AbstractString, inputs_vre_stor::Dict, fuel_costs::Dict, fuel_CO2::Dict)

	# VRE-Storage related inputs
	vre_stor_in = CSV.read(string(path,sep,"Vre_and_storage_data.csv"), categorical=false, header=true, copycols=true)

	# Add Resource IDs after reading to prevent user errors
	vre_stor_in[!,:R_ID] = 1:size(collect(skipmissing(vre_stor_in[!,1])),1)

	# Store DataFrame of generators/resources input data for use in model
	inputs_vre_stor["dfGen_VRE_STOR"] = vre_stor_in

	# Number of resources
	inputs_vre_stor["VRE_STOR"] = size(collect(skipmissing(vre_stor_in[!,:R_ID])),1)

	# Set indices for internal use
	VRE_STOR = inputs_vre_stor["VRE_STOR"] # Number of resources 

	## Defining sets of generation and storage resources

	# Set of all VRE resources eligible for new capacity
	inputs_vre_stor["NEW_CAP_VRE_STOR"] = vre_stor_in[vre_stor_in.Max_Cap_VRE_MW.!=0,:R_ID]
	# Set of all VRE resources eligible for capacity retirements
	inputs_vre_stor["RET_CAP_VRE_STOR"] = vre_stor_in[vre_stor_in.Existing_Cap_MW.>=0,:R_ID]

	# Set of all storage resources eligible for new energy capacity
	inputs_vre_stor["NEW_CAP_ENERGY_VRE_STOR"] = vre_stor_in[vre_stor_in.Max_Cap_Stor_MWh.!=0,:R_ID]
	# Set of all storage resources eligible for energy capacity retirements
	inputs_vre_stor["RET_CAP_ENERGY_VRE_STOR"] = vre_stor_in[vre_stor_in.Existing_Cap_MWh.>=0,:R_ID]

	# Set of all grid components eligible for new grid capacity
	inputs_vre_stor["NEW_CAP_GRID"] = vre_stor_in[vre_stor_in.Max_Cap_Grid_MW.!=0,:R_ID]
	# Set of all grid components eligible for grid capacity retirements
	inputs_vre_stor["RET_CAP_GRID"] = vre_stor_in[vre_stor_in.Existing_Cap_Grid_MW.>=0,:R_ID]

	# Names for systemwide resources, VRE-components, and storage components
	inputs_vre_stor["RESOURCES_VRE_STOR"] = collect(skipmissing(vre_stor_in[!,:Resource][1:VRE_STOR]))
	inputs_vre_stor["RESOURCES_VRE"] = collect(skipmissing(vre_stor_in[!,:Resource_VRE][1:VRE_STOR]))
	inputs_vre_stor["RESOURCES_STOR"] = collect(skipmissing(vre_stor_in[!,:Resource_STOR][1:VRE_STOR]))
	inputs_vre_stor["RESOURCES_GRID"] = collect(skipmissing(vre_stor_in[!,:Resource_GRID][1:VRE_STOR]))
	
	# Zones resources are located in
	#zones = collect(skipmissing(vre_stor_in[!,:Zone][1:inputs_vre_stor["VRE_STOR"]]))
	# Resource identifiers by zone (just zones in resource order + resource and zone concatenated)
	#inputs_vre_stor["R_ZONES"] = zones
	#inputs_vre_stor["RESOURCE_ZONES"] = inputs_vre_stor["RESOURCES_VRE_STOR"] .* "_z" .* string.(zones)

	if setup["ParameterScale"] ==1  # Parameter scaling turned on - adjust values of subset of parameter values

		# The existing capacity of VRE sites in megawatts
		inputs_vre_stor["dfGen_VRE_STOR"][!,:Existing_Cap_MW] = vre_stor_in[!,:Existing_Cap_MW]/ModelScalingFactor # Convert to GW
		# The existing capacity of storage in megawatt-hours 
		inputs_vre_stor["dfGen_VRE_STOR"][!,:Existing_Cap_MWh] = vre_stor_in[!,:Existing_Cap_MWh]/ModelScalingFactor # Convert to GWh
		# The existing grid capacity in megawatts
		inputs_vre_stor["dfGen_VRE_STOR"][!,:Existing_Cap_Grid_MW] = vre_stor_in[!,:Existing_Cap_Grid_MW]/ModelScalingFactor # Convert to GW

		# Min capacity terms
		# Limit on minimum VRE capacity of the resource. -1 if no limit on minimum capacity
		inputs_vre_stor["dfGen_VRE_STOR"][!,:Min_Cap_VRE_MW] = vre_stor_in[!,:Min_Cap_VRE_MW]/ModelScalingFactor # Convert to GW
		# Limit on minimum energy capacity of the resource. -1 if no limit on minimum capacity
		inputs_vre_stor["dfGen_VRE_STOR"][!,:Min_Cap_Stor_MWh] = vre_stor_in[!,:Min_Cap_Stor_MWh]/ModelScalingFactor # Convert to GWh
		# Limit on minimum grid capacity of the resource. -1 if no limit on minimum capacity
		inputs_vre_stor["dfGen_VRE_STOR"][!,:Min_Cap_Grid_MW] = vre_stor_in[!,:Min_Cap_Grid_MW]/ModelScalingFactor # Convert to GW

		## Max capacity terms
		# Limit on maximum VRE capacity of the resource. -1 if no limit on maximum capacity
		inputs_vre_stor["dfGen_VRE_STOR"][!,:Max_Cap_VRE_MW] = vre_stor_in[!,:Max_Cap_VRE_MW]/ModelScalingFactor # Convert to GW
		# Limit on maximum energy capacity of the resource. -1 if no limit on maximum capacity
		inputs_vre_stor["dfGen_VRE_STOR"][!,:Max_Cap_Stor_MWh] = vre_stor_in[!,:Max_Cap_Stor_MWh]/ModelScalingFactor # Convert to GWh
		# Limit on maximum grid capacity of the resource. -1 if no limit on maximum capacity
		inputs_vre_stor["dfGen_VRE_STOR"][!,:Max_Cap_Grid_MW] = vre_stor_in[!,:Max_Cap_Grid_MW]/ModelScalingFactor # Convert to GW

		## Investment cost terms
		# Annualized capacity investment cost of the VRE-component 
		inputs_vre_stor["dfGen_VRE_STOR"][!,:Inv_Cost_VRE_per_MWyr] = vre_stor_in[!,:Inv_Cost_VRE_per_MWyr]/ModelScalingFactor # Convert to $ million/GW/yr with objective function in millions
		# Annualized investment cost of the energy capacity of the storage-component 
		inputs_vre_stor["dfGen_VRE_STOR"][!,:Inv_Cost_per_MWhyr] = vre_stor_in[!,:Inv_Cost_per_MWhyr]/ModelScalingFactor # Convert to $ million/GWh/yr  with objective function in millions
		# Annualized capacity investment cost of the grid-component
		inputs_vre_stor["dfGen_VRE_STOR"][!,:Inv_Cost_GRID_per_MWyr] = vre_stor_in[!,:Inv_Cost_GRID_per_MWyr]/ModelScalingFactor # Convert to $ million/GW/yr  with objective function in millions

		## Fixed O&M cost terms
		# Fixed operations and maintenance cost of the VRE-component 
		inputs_vre_stor["dfGen_VRE_STOR"][!,:Fixed_OM_VRE_Cost_per_MWyr] = vre_stor_in[!,:Fixed_OM_VRE_Cost_per_MWyr]/ModelScalingFactor # Convert to $ million/GW/yr with objective function in millions
		# Fixed operations and maintenance cost of the energy capacity of the storage-component 
		inputs_vre_stor["dfGen_VRE_STOR"][!,:Fixed_OM_Cost_per_MWhyr] = vre_stor_in[!,:Fixed_OM_Cost_per_MWhyr]/ModelScalingFactor # Convert to $ million/GW/yr with objective function in millions
		# Fixed operations and maintenance cost of the grid-component
		inputs_vre_stor["dfGen_VRE_STOR"][!,:Fixed_OM_GRID_Cost_per_MWyr] = vre_stor_in[!,:Fixed_OM_GRID_Cost_per_MWyr]/ModelScalingFactor # Convert to $ million/GW/yr with objective function in millions

		## Variable O&M cost terms
		# Variable operations and maintenance cost of a generation or storage technology
		inputs_vre_stor["dfGen_VRE_STOR"][!,:Var_OM_Cost_per_MWh] = vre_stor_in[!,:Var_OM_Cost_per_MWh]/ModelScalingFactor # Convert to $ million/GWh with objective function in millions
		# Variable operations and maintenance cost of the charging aspect of a storage technology with STOR = 2,
		# or variable operations and maintenance costs associated with flexible demand with FLEX = 1
		inputs_vre_stor["dfGen_VRE_STOR"][!,:Var_OM_Cost_per_MWh_In] = vre_stor_in[!,:Var_OM_Cost_per_MWh_In]/ModelScalingFactor # Convert to $ million/GWh with objective function in millions
		# Cost of providing regulation reserves
		#inputs_vre_stor["dfGen_VRE_STOR"][!,:Reg_Cost] = gen_in[!,:Reg_Cost]/ModelScalingFactor # Convert to $ million/GW with objective function in millions
		# Cost of providing spinning reserves
		#inputs_vre_stor["dfGen_VRE_STOR"][!,:Rsv_Cost] = gen_in[!,:Rsv_Cost]/ModelScalingFactor # Convert to $ million/GW with objective function in millions
	end

	# Heat rate of all resources (million BTUs/MWh)
	#heat_rate_vre_stor = convert(Array{Float64}, collect(skipmissing(vre_stor_in[!,:Heat_Rate_MMBTU_per_MWh])) )
	# Fuel used by each resource
	#fuel_type_vre_stor = collect(skipmissing(vre_stor_in[!,:Fuel]))
	# Maximum fuel cost in $ per MWh and CO2 emissions in tons per MWh
	inputs_vre_stor["dfGen_VRE_STOR"][!,:C_Fuel_per_MWh] = zeros(Float64, VRE_STOR)
	inputs_vre_stor["dfGen_VRE_STOR"][!,:CO2_per_MWh] = zeros(Float64, VRE_STOR)

	#for g in 1:VRE_STOR
	#	inputs_vre_stor["dfGen_VRE_STOR"][!,:C_Fuel_per_MWh][g] = fuel_costs[fuel_type_vre_stor[g]]*heat_rate_vre_stor[g]
	#	inputs_vre_stor["dfGen_VRE_STOR"][!,:CO2_per_MWh][g] = fuel_CO2[fuel_type_vre_stor[g]]*heat_rate_vre_stor[g]
	#	
	#	if setup["ParameterScale"] ==1
	#		inputs_vre_stor["dfGen_VRE_STOR"][!,:CO2_per_MWh][g] = inputs_vre_stor["dfGen_VRE_STOR"][!,:CO2_per_MWh][g] * ModelScalingFactor
	#	end
	#end

	println("Vre_and_storage_data.csv Successfully Read!")

	return inputs_vre_stor
end
