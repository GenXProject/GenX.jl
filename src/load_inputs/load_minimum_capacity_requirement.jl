@doc raw"""
	load_minimum_capacity_requirement(path::AbstractString,sep::AbstractString, inputs::Dict, setup::Dict)

Function for reading input parameters related to mimimum capacity requirement constraints (e.g. technology specific deployment mandates)
"""
function load_minimum_capacity_requirement(path::AbstractString,sep::AbstractString, inputs::Dict, setup::Dict)
	MinCapReq = CSV.read(string(path,sep,"Minimum_capacity_requirement.csv"), header=true)
	NumberOfMinCapReqs = size(collect(skipmissing(MinCapReq[!,:MinCapReqConstraint])),1)
	inputs["NumberOfMinCapReqs"] = NumberOfMinCapReqs
	inputs["MinCapReq"] = MinCapReq[!,:Min_MW]
	if setup["ParameterScale"] == 1
		inputs["MinCapReq"] = inputs["MinCapReq"]/ModelScalingFactor # Convert to GW
	end
	println("Minimum_capacity_requirement.csv Successfully Read!")
	return inputs
end
