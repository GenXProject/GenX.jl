function write_commit(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]
	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
		
	# Commitment state for each resource in each time step
	commit = zeros(G,T)
	for i in inputs["COMMIT"]
		commit[i,:] = value.(EP[:vCOMMIT])[i,:]
	end
	dfCommit = DataFrame(Resource = inputs["RESOURCES"], Zone = dfGen[!,:Zone])
	dfCommit = hcat(dfCommit, convert(DataFrame, commit))
	auxNew_Names=[Symbol("Resource");Symbol("Zone");[Symbol("t$t") for t in 1:T]]
	rename!(dfCommit,auxNew_Names)
	CSV.write(string(path,sep,"commit.csv"), dftranspose(dfCommit, false), writeheader=false)
end