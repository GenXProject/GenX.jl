function write_reg(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]

	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)

	# Regulation contributions for each resource in each time step
	dfReg = DataFrame(Resource = inputs["RESOURCES"], Zone = dfGen[!,:Zone], Sum = Array{Union{Missing,Float32}}(undef, G))
	reg = zeros(G,T)
	for i in 1:G
		if i in inputs["REG"]
			reg[i,:] = value.(EP[:vREG])[i,:]
		end
		dfReg[!,:Sum][i] = sum(reg[i,:])
	end
	dfReg = hcat(dfReg, convert(DataFrame, reg))
	auxNew_Names=[Symbol("Resource");Symbol("Zone");Symbol("Sum");[Symbol("t$t") for t in 1:T]]
	rename!(dfReg,auxNew_Names)
	total = convert(DataFrame, ["Total" 0 sum(dfReg[!,:Sum]) fill(0.0, (1,T))])
	for t in 1:T
		total[!,t+3] .= sum(dfReg[!,Symbol("t$t")][1:G])
	end
	rename!(total,auxNew_Names)
	dfReg = vcat(dfReg, total)
	CSV.write(string(path,sep,"reg.csv"), dftranspose(dfReg, false), writeheader=false)
end