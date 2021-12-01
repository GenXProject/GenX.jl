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
	load_cap_reserve_margin(setup::Dict, path::AbstractString, inputs_crm::Dict, network_var::DataFrame)

Function for reading input parameters related to planning reserve margin constraints
"""
function load_cap_reserve_margin(setup::Dict, path::AbstractString, inputs_crm::Dict)
	# Definition of capacity reserve margin (crm) by locational deliverability area (LDA)
	println("About to read Capacity_reserve_margin.csv")

	inputs_crm["dfCapRes"] = DataFrame(CSV.File(joinpath(path, "Capacity_reserve_margin.csv"), header=true), copycols=true)

	# Ensure float format values:

	# Identifying # of planning reserve margin constraints for the system
	res = count(s -> startswith(String(s), "CapRes"), names(inputs_crm["dfCapRes"]))
	first_col = findall(s -> s == "CapRes_1", names(inputs_crm["dfCapRes"]))[1]
	last_col = findall(s -> s == "CapRes_$res", names(inputs_crm["dfCapRes"]))[1]
	inputs_crm["dfCapRes"] = Matrix{Float64}(inputs_crm["dfCapRes"][:,first_col:last_col])
	inputs_crm["NCapacityReserveMargin"] = res

	println("Capacity_reserve_margin.csv Successfully Read!")



	return inputs_crm
end

function load_cap_reserve_margin_trans(setup::Dict, path::AbstractString, inputs_crm::Dict, network_var::DataFrame)

	println("About to Read Transmission's Participation in Capacity Reserve Margin")

	res = inputs_crm["NCapacityReserveMargin"]

	first_col_trans = findall(s -> s == "CapRes_1", names(network_var))[1]
	last_col_trans = findall(s -> s == "CapRes_$res", names(network_var))[1]
	dfTransCapRes = network_var[:,first_col_trans:last_col_trans]
	inputs_crm["dfTransCapRes"] = Matrix{Float64}(dfTransCapRes[completecases(dfTransCapRes),:])

	first_col_trans_derate = findall(s -> s == "DerateCapRes_1", names(network_var))[1]
	last_col_trans_derate = findall(s -> s == "DerateCapRes_$res", names(network_var))[1]
	dfDerateTransCapRes = network_var[:,first_col_trans_derate:last_col_trans_derate]
	inputs_crm["dfDerateTransCapRes"] = Matrix{Float64}(dfDerateTransCapRes[completecases(dfDerateTransCapRes),:])

	first_col_trans_excl = findall(s -> s == "CapRes_Excl_1", names(network_var))[1]
	last_col_trans_excl = findall(s -> s == "CapRes_Excl_$res", names(network_var))[1]
	dfTransCapRes_excl = network_var[:,first_col_trans_excl:last_col_trans_excl]
	inputs_crm["dfTransCapRes_excl"] = Matrix{Float64}(dfTransCapRes_excl[completecases(dfTransCapRes_excl),:])
	println("Transmission's Participation in Capacity Reserve Margin is Successfully Read!")

	return inputs_crm
end
