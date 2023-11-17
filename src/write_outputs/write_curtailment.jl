@doc raw"""
	write_curtailment(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing the curtailment values of the different variable renewable resources.
"""
function write_curtailment(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]
	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
	VRE = inputs["VRE"]
	dfCurtailment = DataFrame(Resource = inputs["RESOURCES"], Zone = dfGen[!, :Zone], AnnualSum = zeros(G))
	curtailment = zeros(G, T)
	scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
	curtailment[VRE, :] = scale_factor * (value.(EP[:eTotalCap][VRE]) .* inputs["pP_Max"][VRE, :] .- value.(EP[:vP][VRE, :]))

	dfCurtailment.AnnualSum = curtailment * inputs["omega"]
	dfCurtailment = hcat(dfCurtailment, DataFrame(curtailment, :auto))
	auxNew_Names=[Symbol("Resource");Symbol("Zone");Symbol("AnnualSum");[Symbol("t$t") for t in 1:T]]
	rename!(dfCurtailment,auxNew_Names)

	total = DataFrame(["Total" 0 sum(dfCurtailment[!,:AnnualSum]) fill(0.0, (1,T))], :auto)
	total[:, 4:T+3] .= sum(curtailment, dims = 1)
	rename!(total,auxNew_Names)
	dfCurtailment = vcat(dfCurtailment, total)
	CSV.write(joinpath(path, "curtail.csv"), dftranspose(dfCurtailment, false), writeheader=false)
	return dfCurtailment
end
