function write_opwrap_lds_dstor(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	## Extract data frames from input dictionary
	dfGen = inputs["dfGen"]
	W = inputs["REP_PERIOD"]     # Number of subperiods
	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)

	#Excess inventory of storage period built up during representative period w
	dfdStorage = DataFrame(Resource = inputs["RESOURCES"], Zone = dfGen[!,:Zone])
	dsoc = zeros(G,W)
	for i in 1:G
		if i in inputs["STOR_ALL"]
			dsoc[i,:] = value.(EP[:vdSOC])[i,:]
		end
	end
	dfdStorage = hcat(dfdStorage, convert(DataFrame, dsoc))
	auxNew_Names=[Symbol("Resource");Symbol("Zone");[Symbol("w$t") for t in 1:W]]
	rename!(dfdStorage,auxNew_Names)
	CSV.write(string(path,sep,"dStorage.csv"), dftranspose(dfdStorage, false), writeheader=false)
end
