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
	load_cap_reserve_margin(setup::Dict, path::AbstractString, inputs_crm::Dict)

Function for reading input parameters related to planning reserve margin constraints
"""
function load_cap_reserve_margin(setup::Dict, path::AbstractString, inputs_crm::Dict)
	# Definition of capacity reserve margin (crm) by locational deliverability area (LDA)
	inputs_crm["dfCapRes_slack"] = DataFrame(CSV.File(joinpath(path, "Capacity_reserve_margin_slack.csv"), header=true), copycols=true)
	if setup["ParameterScale"] == 1
		inputs_crm["dfCapRes_slack"][!,:PriceCap] ./= ModelScalingFactor
	end
	inputs_crm["NCapacityReserveMargin"] = size(collect(skipmissing(inputs_crm["dfCapRes_slack"][!,:CRM_Constraint])),1)
	# Definition of capacity reserve margin (crm) by locational deliverability area (LDA)
	inputs_crm["dfCapRes"] = DataFrame(CSV.File(joinpath(path, "Capacity_reserve_margin.csv"), header=true), copycols=true)
	println("Capacity_reserve_margin.csv Successfully Read!")

	return inputs_crm
end

@doc raw"""
	load_cap_reserve_margin_trans(setup::Dict, inputs_crm::Dict, network_var::DataFrame)

Function for reading input parameters related to participation of transmission imports/exports in capacity reserve margin constraint.
"""
function load_cap_reserve_margin_trans(setup::Dict, inputs_crm::Dict, network_var::DataFrame)
	res = inputs_crm["NCapacityReserveMargin"]
	inputs_crm["dfCapRes_network"] = network_var[!, [[Symbol("DerateCapRes_$i") for i in 1:res];[Symbol("CapRes_Excl_$i") for i in 1:res]]]
	return inputs_crm
end
