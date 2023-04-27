function write_opwrap_lds_stor_init(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	## Extract data frames from input dictionary
	dfGen = inputs["dfGen"]
	G = inputs["G"]

	# Initial level of storage in each modeled period
	NPeriods = size(inputs["Period_Map"])[1]
	dfStorageInit = DataFrame(Resource = inputs["RESOURCES"], Zone = dfGen[!,:Zone])
	socw = zeros(G,NPeriods)
	for i in 1:G
		if i in inputs["STOR_LONG_DURATION"]
			socw[i,:] = value.(EP[:vSOCw])[i,:]
		end
	end
	dfStorageInit = hcat(dfStorageInit, DataFrame(socw, :auto))
	auxNew_Names=[Symbol("Resource");Symbol("Zone");[Symbol("n$t") for t in 1:NPeriods]]
	rename!(dfStorageInit,auxNew_Names)
	CSV.write(joinpath(path, "StorageInit.csv"), dftranspose(dfStorageInit, false), writeheader=false)
end
