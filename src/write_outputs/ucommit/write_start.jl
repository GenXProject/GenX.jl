function write_start(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]
	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
	COMMIT = inputs["COMMIT"]
	# Startup state for each resource in each time step
	dfStart = DataFrame(Resource = inputs["RESOURCES"], Zone = dfGen[!, :Zone])
	start = zeros(G,T)
	start[COMMIT, :] = value.(EP[:vSTART][COMMIT, :])
	dfStart.AnnualSum = start * inputs["omega"]
	dfStart = hcat(dfStart, DataFrame(start, :auto))
	auxNew_Names=[Symbol("Resource");Symbol("Zone");Symbol("AnnualSum");[Symbol("t$t") for t in 1:T]]
	rename!(dfStart,auxNew_Names)

	total = DataFrame(["Total" 0 sum(dfStart.AnnualSum) fill(0.0, (1,T))], :auto)
	total[:, 4:T+3] .= sum(start, dims = 1)
	rename!(total,auxNew_Names)
	dfStart = vcat(dfStart, total)
	CSV.write(joinpath(path, "start.csv"), dftranspose(dfStart, false), writeheader=false)
end
