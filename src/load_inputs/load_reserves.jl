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
	load_reserves!(setup::Dict,path::AbstractString, inputs::Dict)

Read input parameters related to frequency regulation and operating reserve requirements
"""
function load_reserves!(setup::Dict, path::AbstractString, inputs::Dict)
    filename = "Reserves.csv"
	res_in = DataFrame(CSV.File(joinpath(path, filename), header=true), copycols=true)

    function load_field_with_deprecated_symbol(df::DataFrame, columns::Vector{Symbol})
        best = popfirst!(columns)
        firstrow = 1
        all_columns = Symbol.(names(df))
        if best in all_columns
            return float(df[firstrow, best])
        end
        for col in columns
            if col in all_columns
                @info "The column name $col in file $filename is deprecated; prefer $best"
                return float(df[firstrow, col])
            end
        end
        error("None of the columns $columns were found in the file $filename")
    end

	# Regulation requirement as a percent of hourly demand; here demand is the total across all model zones
	inputs["pReg_Req_Demand"] = load_field_with_deprecated_symbol(res_in,
                                                                  [:Reg_Req_Percent_Demand,
                                                                   :Reg_Req_Percent_Load])

	# Regulation requirement as a percent of hourly wind and solar generation (summed across all model zones)
	inputs["pReg_Req_VRE"] = float(res_in[1,:Reg_Req_Percent_VRE])
	# Spinning up reserve requirement as a percent of hourly demand (which is summed across all zones)
	inputs["pRsv_Req_Demand"] = load_field_with_deprecated_symbol(res_in,
                                                                  [:Rsv_Req_Percent_Demand,
                                                                   :Rsv_Req_Percent_Load])
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
