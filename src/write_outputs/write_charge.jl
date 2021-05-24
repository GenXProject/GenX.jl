@doc raw"""
	write_charge(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing the charging energy values of the different storage technologies.
"""
function write_charge(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]
	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
	# Power withdrawn to charge each resource in each time step
	dfCharge = DataFrame(Resource = inputs["RESOURCES"], Zone = dfGen[!,:Zone], AnnualSum = Array{Union{Missing,Float32}}(undef, G))
	charge = zeros(G,T)
	for i in 1:G
		if setup["ParameterScale"] ==1
			if i in inputs["STOR_ALL"]
				charge[i,:] = value.(EP[:vCHARGE])[i,:] * ModelScalingFactor
			elseif i in inputs["FLEX"]
				charge[i,:] = value.(EP[:vCHARGE_FLEX])[i,:] * ModelScalingFactor
			end
		else
			if i in inputs["STOR_ALL"]
				charge[i,:] = value.(EP[:vCHARGE])[i,:]
			elseif i in inputs["FLEX"]
				charge[i,:] = value.(EP[:vCHARGE_FLEX])[i,:]
			end
		end
		dfCharge[!,:AnnualSum][i] = sum(inputs["omega"].* charge[i,:])
	end
	dfCharge = hcat(dfCharge, convert(DataFrame, charge))
	auxNew_Names=[Symbol("Resource");Symbol("Zone");Symbol("AnnualSum");[Symbol("t$t") for t in 1:T]]
	rename!(dfCharge,auxNew_Names)
	total = convert(DataFrame, ["Total" 0 sum(dfCharge[!,:AnnualSum]) fill(0.0, (1,T))])
	for t in 1:T
		total[!,t+3] .= sum(dfCharge[!,Symbol("t$t")][union(inputs["STOR_ALL"],inputs["FLEX"])])
	end
	rename!(total,auxNew_Names)
	dfCharge = vcat(dfCharge, total)
	CSV.write(string(path,sep,"charge.csv"), dftranspose(dfCharge, false), writeheader=false)
	return dfCharge
end
