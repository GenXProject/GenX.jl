@doc raw"""
	load_reserves!(setup::Dict,path::AbstractString, inputs::Dict)

Read input parameters related to frequency regulation and operating reserve requirements
"""
function load_reserves!(setup::Dict, path::AbstractString, inputs::Dict)
    filename = "Reserves.csv"
    res_in = load_dataframe(joinpath(path, filename))

	# Regulation requirement as a percent of hourly load; here load is the total across all model zones
	inputs["pReg_Req_Load"] = float(res_in[1,:Reg_Req_Percent_Load])
	# Regulation requirement as a percent of hourly wind and solar generation (summed across all model zones)
	inputs["pReg_Req_VRE"] = float(res_in[1,:Reg_Req_Percent_VRE])
	# Spinning up reserve requirement as a percent of hourly load (which is summed across all zones)
	inputs["pRsv_Req_Load"] = float(res_in[1,:Rsv_Req_Percent_Load])
	# Spinning up reserve requirement as a percent of hourly wind and solar generation (which is summed across all zones)
	inputs["pRsv_Req_VRE"] = float(res_in[1,:Rsv_Req_Percent_VRE])

    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    # Penalty for not meeting hourly spinning reserve requirement
    inputs["pC_Rsv_Penalty"] = float(res_in[1,:Unmet_Rsv_Penalty_Dollar_per_MW]) / scale_factor # convert to million $/GW with objective function in millions
    inputs["pStatic_Contingency"] = float(res_in[1,:Static_Contingency_MW]) / scale_factor # convert to GW

	if setup["UCommit"] >= 1
		inputs["pDynamic_Contingency"] = convert(Int8, res_in[1,:Dynamic_Contingency] )
		# Set BigM value used for dynamic contingencies cases to be largest possible cluster size
		# Note: this BigM value is only relevant for units in the COMMIT set. See reserves.jl for details on implementation of dynamic contingencies
		if inputs["pDynamic_Contingency"] > 0
			inputs["pContingency_BigM"] = zeros(Float64, inputs["G"])
			for y in inputs["COMMIT"]
				inputs["pContingency_BigM"][y] = inputs["dfGen"][y,:Max_Cap_MW]
				# When Max_Cap_MW == -1, there is no limit on capacity size
				if inputs["pContingency_BigM"][y] < 0
					# NOTE: this effectively acts as a maximum cluster size when not otherwise specified, adjust accordingly
					inputs["pContingency_BigM"][y] = 5000*inputs["dfGen"][y,:Cap_Size]
				end
			end
		end
	end

	println(filename * " Successfully Read!")
end
