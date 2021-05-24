@doc raw"""
	load_energy_share_requirement(setup::Dict, path::AbstractString, sep::AbstractString, inputs_ESR::Dict)

Function for reading input parameters related to mimimum energy share requirement constraints (e.g. renewable portfolio standard or clean electricity standard policies)
"""
function load_energy_share_requirement(setup::Dict, path::AbstractString, sep::AbstractString, inputs_ESR::Dict)
	# Definition of ESR requirements by zone (as % of load)
	# e.g. any policy requiring a min share of qualifying resources (Renewable Portfolio Standards / Renewable Energy Obligations / Clean Energy Standards etc.)
	inputs_ESR["dfESR"] = CSV.read(string(path,sep,"Energy_share_requirement.csv"), header=true)

	# Ensure float format values:
	ESR = count(s -> startswith(String(s), "ESR"), names(inputs_ESR["dfESR"]))
	first_col = findall(s -> s == Symbol("ESR_1"), names(inputs_ESR["dfESR"]))[1]
	last_col = findall(s -> s == Symbol("ESR_$ESR"), names(inputs_ESR["dfESR"]))[1]

	inputs_ESR["dfESR"] = convert(Matrix{Float64}, inputs_ESR["dfESR"][:,first_col:last_col])
	inputs_ESR["nESR"] = ESR

	println("Energy_share_requirement.csv Successfully Read!")
	return inputs_ESR
end
