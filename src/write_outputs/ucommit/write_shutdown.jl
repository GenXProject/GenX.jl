function write_shutdown(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]
	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
	# Operational decision variable states

	# Shutdown state for each resource in each time step
	dfShutdown = DataFrame(Resource = inputs["RESOURCES"], Zone = dfGen[!,:Zone], Sum = Array{Union{Missing,Float32}}(undef, G))
	shut = zeros(G,T)
	for i in 1:G
		if i in inputs["COMMIT"]
			shut[i,:] = value.(EP[:vSHUT])[i,:]
		end
		dfShutdown[!,:Sum][i] = sum(shut[i,:])
	end
	dfShutdown = hcat(dfShutdown, convert(DataFrame, shut))
	auxNew_Names=[Symbol("Resource");Symbol("Zone");Symbol("Sum");[Symbol("t$t") for t in 1:T]]
	rename!(dfShutdown,auxNew_Names)
	total = convert(DataFrame, ["Total" 0 sum(dfShutdown[!,:Sum]) fill(0.0, (1,T))])
	for t in 1:T
		total[!,t+3] .= sum(dfShutdown[!,Symbol("t$t")][1:G])
	end
	rename!(total,auxNew_Names)
	dfShutdown = vcat(dfShutdown, total)
	CSV.write(string(path,sep,"shutdown.csv"), dftranspose(dfShutdown, false), writeheader=false)
end