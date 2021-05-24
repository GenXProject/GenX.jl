@doc raw"""
	load_cap_reserve_margin(setup::Dict, path::AbstractString, sep::AbstractString, inputs_crm::Dict, network_var::DataFrame)

Function for reading input parameters related to planning reserve margin constraints
"""
function load_cap_reserve_margin(setup::Dict, path::AbstractString, sep::AbstractString, inputs_crm::Dict)
	# Definition of capacity reserve margin (crm) by locational deliverability area (LDA)
	println("About to read Capacity_reserve_margin.csv")

	inputs_crm["dfCapRes"] = CSV.read(string(path,sep,"Capacity_reserve_margin.csv"), header=true)

	# Ensure float format values:

	# Identifying # of planning reserve margin constraints for the system
	res = count(s -> startswith(String(s), "CapRes"), names(inputs_crm["dfCapRes"]))
	first_col = findall(s -> s == Symbol("CapRes_1"), names(inputs_crm["dfCapRes"]))[1]
	last_col = findall(s -> s == Symbol("CapRes_$res"), names(inputs_crm["dfCapRes"]))[1]
	inputs_crm["dfCapRes"] = convert(Matrix{Float64}, inputs_crm["dfCapRes"][:,first_col:last_col])
	inputs_crm["NCapacityReserveMargin"] = res

	println("Capacity_reserve_margin.csv Successfully Read!")



	return inputs_crm
end

function load_cap_reserve_margin_trans(setup::Dict, path::AbstractString, sep::AbstractString, inputs_crm::Dict, network_var::DataFrame)

	println("About to Read Transmission's Participation in Capacity Reserve Margin")

	res = inputs_crm["NCapacityReserveMargin"]
	
	first_col_trans = findall(s -> s == Symbol("CapRes_1"), names(network_var))[1]
	last_col_trans = findall(s -> s == Symbol("CapRes_$res"), names(network_var))[1]
	dfTransCapRes = network_var[:,first_col_trans:last_col_trans]
	inputs_crm["dfTransCapRes"] = convert(Matrix{Float64}, dfTransCapRes[completecases(dfTransCapRes),:])

	first_col_trans_derate = findall(s -> s == Symbol("DerateCapRes_1"), names(network_var))[1]
	last_col_trans_derate = findall(s -> s == Symbol("DerateCapRes_$res"), names(network_var))[1]
	dfDerateTransCapRes = network_var[:,first_col_trans_derate:last_col_trans_derate]
	inputs_crm["dfDerateTransCapRes"] = convert(Matrix{Float64}, dfDerateTransCapRes[completecases(dfDerateTransCapRes),:])

	first_col_trans_excl = findall(s -> s == Symbol("CapRes_Excl_1"), names(network_var))[1]
	last_col_trans_excl = findall(s -> s == Symbol("CapRes_Excl_$res"), names(network_var))[1]
	dfTransCapRes_excl = network_var[:,first_col_trans_excl:last_col_trans_excl]
	inputs_crm["dfTransCapRes_excl"] = convert(Matrix{Float64}, dfTransCapRes_excl[completecases(dfTransCapRes_excl),:])
	println("Transmission's Participation in Capacity Reserve Margin is Successfully Read!")

	return inputs_crm
end