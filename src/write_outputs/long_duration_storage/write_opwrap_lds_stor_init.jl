function write_opwrap_lds_stor_init(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	## Extract data frames from input dictionary
	dfGen = inputs["dfGen"]
	G = inputs["G"]

	# Initial level of storage in each modeled period
	NPeriods = size(inputs["Period_Map"])[1]
	dfStorageInit = DataFrame(Resource = inputs["RESOURCES"], Zone = dfGen[!,:Zone])
	socw = zeros(G,NPeriods)
	for i in 1:G
		if i in inputs["STOR_ALL"]
			socw[i,:] = value.(EP[:vSOCw])[i,:]
		end
	end
	dfStorageInit = hcat(dfStorageInit, convert(DataFrame, socw))
	auxNew_Names=[Symbol("Resource");Symbol("Zone");[Symbol("n$t") for t in 1:NPeriods]]
	rename!(dfStorageInit,auxNew_Names)
	CSV.write(string(path,sep,"StorageInit.csv"), dftranspose(dfStorageInit, false), writeheader=false)
end
