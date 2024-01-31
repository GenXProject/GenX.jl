function write_commit(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]
	T = inputs["T"]     # Number of time steps (hours)
	COMMIT = inputs["COMMIT"]

	# Commitment state for each resource in each time step
	commit = value.(EP[:vCOMMIT][COMMIT, :].data)
	resources = inputs["RESOURCES"][COMMIT]
	zones = dfGen[COMMIT, :Zone]

	dfCommit = DataFrame(Resource = resources, Zone = zones)
	dfCommit = hcat(dfCommit, DataFrame(commit, :auto))
	auxNew_Names=[Symbol("Resource");Symbol("Zone");[Symbol("t$t") for t in 1:T]]
	rename!(dfCommit,auxNew_Names)
	CSV.write(joinpath(path, "commit.csv"), dftranspose(dfCommit, false), writeheader=false)
end
