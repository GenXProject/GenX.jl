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

function write_capacity_value(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]
	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
	SEG = inputs["SEG"]  # Number of lines
	Z = inputs["Z"]     # Number of zonests
	L = inputs["L"] # Number of lines
	THERM_ALL = inputs["THERM_ALL"]
	VRE = inputs["VRE"]
	HYDRO_RES = inputs["HYDRO_RES"]
	STOR_ALL = inputs["STOR_ALL"]
	FLEX = inputs["FLEX"]
	MUST_RUN = inputs["MUST_RUN"]
	if setup["ParameterScale"] == 1
		existingplant_position = findall(x -> x >= 1, (value.(EP[:eTotalCap])) * ModelScalingFactor)
	else
		existingplant_position = findall(x -> x >= 1, (value.(EP[:eTotalCap])))
	end
	THERM_ALL_EX = intersect(THERM_ALL, existingplant_position)
	VRE_EX = intersect(VRE, existingplant_position)
	HYDRO_RES_EX = intersect(HYDRO_RES, existingplant_position)
	STOR_ALL_EX = intersect(STOR_ALL, existingplant_position)
	FLEX_EX = intersect(FLEX, existingplant_position)
	MUST_RUN_EX = intersect(MUST_RUN, existingplant_position)
	totalcap = repeat((value.(EP[:eTotalCap])), 1, T)
	dfCapValue = DataFrame()
	for i in 1:inputs["NCapacityReserveMargin"]
		temp_dfCapValue = DataFrame(Resource = inputs["RESOURCES"], Zone = dfGen[!, :Zone], Reserve = fill(Symbol("CapRes_$i"), G))
		temp_capvalue = zeros(G, T)
		temp_riskyhour = zeros(G, T)
		temp_cap_derate = zeros(G, T)
		if setup["ParameterScale"] == 1
			riskyhour_position = findall(x -> x >= 1, ((dual.(EP[:cCapacityResMargin][i, :])) ./ inputs["omega"] * ModelScalingFactor))
		else
			riskyhour_position = findall(x -> x >= 1, ((dual.(EP[:cCapacityResMargin][i, :])) ./ inputs["omega"]))
		end
		temp_riskyhour[:, riskyhour_position] = ones(Int, G, length(riskyhour_position))
		temp_cap_derate[existingplant_position, :] = repeat(dfGen[existingplant_position, Symbol("CapRes_$i")], 1, T)

		temp_capvalue[THERM_ALL_EX, :] = temp_cap_derate[THERM_ALL_EX, :] .* temp_riskyhour[THERM_ALL_EX, :]
		temp_capvalue[VRE_EX, :] = temp_cap_derate[VRE_EX, :] .* (inputs["pP_Max"][VRE_EX, :]) .* temp_riskyhour[VRE_EX, :]
		temp_capvalue[MUST_RUN_EX, :] = temp_cap_derate[MUST_RUN_EX, :] .* (inputs["pP_Max"][MUST_RUN_EX, :]) .* temp_riskyhour[MUST_RUN_EX, :]
		temp_capvalue[HYDRO_RES_EX, :] = temp_cap_derate[HYDRO_RES_EX, :] .* (value.(EP[:vP][HYDRO_RES_EX, :])) .* temp_riskyhour[HYDRO_RES_EX, :] ./ totalcap[HYDRO_RES_EX, :]
		temp_capvalue[STOR_ALL_EX, :] = temp_cap_derate[STOR_ALL_EX, :] .* ((value.(EP[:vP][STOR_ALL_EX, :]) - value.(EP[:vCHARGE][STOR_ALL_EX, :]).data)) .* temp_riskyhour[STOR_ALL_EX, :] ./ totalcap[STOR_ALL_EX, :]
		temp_capvalue[FLEX_EX, :] = temp_cap_derate[FLEX_EX, :] .* ((value.(EP[:vCHARGE_FLEX][FLEX_EX, :]).data - value.(EP[:vP][FLEX_EX, :]))) .* temp_riskyhour[FLEX_EX, :] ./ totalcap[FLEX_EX, :]
		temp_dfCapValue = hcat(temp_dfCapValue, DataFrame(temp_capvalue, :auto))
		auxNew_Names = [Symbol("Resource"); Symbol("Zone"); Symbol("Reserve"); [Symbol("t$t") for t in 1:T]]
		rename!(temp_dfCapValue, auxNew_Names)
		append!(dfCapValue, temp_dfCapValue)
	end
	CSV.write(joinpath(path, "CapacityValue.csv"),dfCapValue)
end
