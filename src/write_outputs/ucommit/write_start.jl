function write_start(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]
	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)

	# Startup state for each resource in each time step
	dfStart = DataFrame(Resource = inputs["RESOURCES"], Zone = dfGen[!,:Zone], Sum = Array{Union{Missing,Float32}}(undef, G))
	start = zeros(G,T)
	for i in 1:G
		if i in inputs["COMMIT"]
			start[i,:] = value.(EP[:vSTART])[i,:]
		end
		dfStart[!,:Sum][i] = sum(start[i,:])
	end
	dfStart = hcat(dfStart, convert(DataFrame, start))
	auxNew_Names=[Symbol("Resource");Symbol("Zone");Symbol("Sum");[Symbol("t$t") for t in 1:T]]
	rename!(dfStart,auxNew_Names)
	total = convert(DataFrame, ["Total" 0 sum(dfStart[!,:Sum]) fill(0.0, (1,T))])
	for t in 1:T
		total[!,t+3] .= sum(dfStart[:,Symbol("t$t")][1:G])
	end
	rename!(total,auxNew_Names)
	dfStart = vcat(dfStart, total)
	CSV.write(string(path,sep,"start.csv"), dftranspose(dfStart, false), writeheader=false)
end