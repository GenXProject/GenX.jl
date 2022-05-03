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
	load_reserves(setup::Dict,path::AbstractString, inputs_res::Dict)

Function for reading input parameters related to frequency regulation and operating reserve requirements
"""
function load_reserves(setup::Dict,path::AbstractString, inputs_res::Dict)
	##Reserve inputs
	res_in = DataFrame(CSV.File(joinpath(path, "Reserves.csv"), header=true), copycols=true)

	# Regulation requirement as a percent of hourly load; here load is the total across all model zones
	inputs_res["pReg_Req_Load"] = convert(Float64, res_in[1,:Reg_Req_Percent_Load])
	# Regulation requirement as a percent of hourly wind and solar generation (summed across all model zones)
	inputs_res["pReg_Req_VRE"] = convert(Float64, res_in[1,:Reg_Req_Percent_VRE])
	# Spinning up reserve requirement as a percent of hourly load (which is summed across all zones)
	inputs_res["pRsv_Req_Load"] = convert(Float64, res_in[1,:Rsv_Req_Percent_Load])
	# Spinning up reserve requirement as a percent of hourly wind and solar generation (which is summed across all zones)
	inputs_res["pRsv_Req_VRE"] = convert(Float64, res_in[1,:Rsv_Req_Percent_VRE])

	if setup["ParameterScale"] == 1  # Parameter scaling turned on - adjust values of subset of parameter values
		# Penalty for not meeting hourly spinning reserve requirement
		inputs_res["pC_Rsv_Penalty"] = convert(Float64, res_in[1,:Unmet_Rsv_Penalty_Dollar_per_MW])/ModelScalingFactor # convert to million $/GW with objective function in millions
		inputs_res["pStatic_Contingency"] = convert(Float64, res_in[1,:Static_Contingency_MW])/ModelScalingFactor # convert to GW
	else
		# Penalty for not meeting hourly spinning reserve requirement
		inputs_res["pC_Rsv_Penalty"] = convert(Float64, res_in[1,:Unmet_Rsv_Penalty_Dollar_per_MW])
		inputs_res["pStatic_Contingency"] = convert(Float64, res_in[1,:Static_Contingency_MW])
	end
	if setup["UCommit"] >= 1
		inputs_res["pDynamic_Contingency"] = convert(Int8, res_in[1,:Dynamic_Contingency] )
		# Set BigM value used for dynamic contingencies cases to be largest possible cluster size
		# Note: this BigM value is only relevant for units in the COMMIT set. See reserves.jl for details on implementation of dynamic contingencies
		if inputs_res["pDynamic_Contingency"] > 0
			inputs_res["pContingency_BigM"] = zeros(Float64, inputs_res["G"])
			for y in inputs_res["COMMIT"]
				inputs_res["pContingency_BigM"][y] = inputs_res["dfGen"][y,:Max_Cap_MW]
				# When Max_Cap_MW == -1, there is no limit on capacity size
				if inputs_res["pContingency_BigM"][y] < 0
					# NOTE: this effectively acts as a maximum cluster size when not otherwise specified, adjust accordingly
					inputs_res["pContingency_BigM"][y] = 5000*inputs_res["dfGen"][y,:Cap_Size]
				end
			end
		end
	end

	println("Reserves.csv Successfully Read!")

	return inputs_res
end
