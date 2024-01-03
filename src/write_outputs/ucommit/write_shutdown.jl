function write_shutdown(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]
	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
	# Operational decision variable states
	COMMIT = inputs["COMMIT"]
	# Shutdown state for each resource in each time step
	dfShutdown = DataFrame(Resource = inputs["RESOURCES"], Zone = dfGen[!, :Zone])
	shut = zeros(G,T)
	shut[COMMIT, :] = value.(EP[:vSHUT][COMMIT, :])
	dfShutdown.AnnualSum = shut * inputs["omega"]
	dfShutdown = hcat(dfShutdown, DataFrame(shut, :auto))
	auxNew_Names=[Symbol("Resource");Symbol("Zone");Symbol("AnnualSum");[Symbol("t$t") for t in 1:T]]
	rename!(dfShutdown,auxNew_Names)
	total=DataFrame(["Total" 0 sum(dfShutdown.AnnualSum) fill(0.0, (1,T))], :auto)
	total[:, 4:T+3] .= sum(shut, dims = 1)
	rename!(total,auxNew_Names)
	dfShutdown = vcat(dfShutdown, total)
	CSV.write(joinpath(path, "shutdown.csv"), dftranspose(dfShutdown, false), writeheader=false)
end
