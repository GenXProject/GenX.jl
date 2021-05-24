@doc raw"""
	write_curtailment(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing the curtailment values of the different variable renewable resources.
"""
function write_curtailment(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]
	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
	dfCurtailment = DataFrame(Resource = inputs["RESOURCES"], Zone = dfGen[!,:Zone], AnnualSum = Array{Union{Missing,Float32}}(undef, G))
	for i in 1:G
		if i in inputs["VRE"]
			dfCurtailment[!,:AnnualSum][i] = sum(inputs["omega"].*(inputs["pP_Max"][i,:]).*value.(EP[:eTotalCap])[i,:].- inputs["omega"].*value.(EP[:vP])[i,:])
		else
			dfCurtailment[!,:AnnualSum][i] = 0
		end
	end
	if setup["ParameterScale"] ==1
		dfCurtailment.AnnualSum = dfCurtailment.AnnualSum * ModelScalingFactor
		dfCurtailment = hcat(dfCurtailment, convert(DataFrame, ( ModelScalingFactor * (inputs["pP_Max"]).*value.(EP[:eTotalCap]).- value.(EP[:vP]))))
	else
		dfCurtailment = hcat(dfCurtailment, convert(DataFrame, ((inputs["pP_Max"]).*value.(EP[:eTotalCap]).- value.(EP[:vP]))))
	end


	auxNew_Names=[Symbol("Resource");Symbol("Zone");Symbol("AnnualSum");[Symbol("t$t") for t in 1:T]]
	rename!(dfCurtailment,auxNew_Names)
	total = convert(DataFrame, ["Total" 0 sum(dfCurtailment[!,:AnnualSum]) fill(0.0, (1,T))])
	for t in 1:T
		total[!,t+3] .= sum(dfCurtailment[!,Symbol("t$t")][1:G])
	end
	rename!(total,auxNew_Names)
	dfCurtailment = vcat(dfCurtailment, total)
	CSV.write(string(path,sep,"curtail.csv"), dftranspose(dfCurtailment, false), writeheader=false)
	return dfCurtailment
end
