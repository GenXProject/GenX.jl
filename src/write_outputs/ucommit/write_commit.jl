function write_commit(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	gen = inputs["RESOURCES"]
	zones = zone_id.(gen)

	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
	COMMIT = inputs["COMMIT"]
	# Commitment state for each resource in each time step
	commit = zeros(G,T)
	commit[COMMIT, :] = value.(EP[:vCOMMIT][COMMIT, :])
	dfCommit = DataFrame(Resource = inputs["RESOURCE_NAMES"], Zone = zones)
	dfCommit = hcat(dfCommit, DataFrame(commit, :auto))
	auxNew_Names=[Symbol("Resource");Symbol("Zone");[Symbol("t$t") for t in 1:T]]
	rename!(dfCommit,auxNew_Names)
	CSV.write(joinpath(path, "commit.csv"), dftranspose(dfCommit, false), header=false)
end
