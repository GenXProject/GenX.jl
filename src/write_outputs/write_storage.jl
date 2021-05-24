@doc raw"""
	write_storage(path::AbstractString, sep::AbstractString, inputs::Dict,setup::Dict, EP::Model)

Function for writing the capacities of different storage technologies, including hydro reservoir, flexible storage tech etc.
"""
function write_storage(path::AbstractString, sep::AbstractString, inputs::Dict,setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]
	T = inputs["T"]     # Number of time steps (hours)
	G = inputs["G"]

	# Storage level (state of charge) of each resource in each time step
	dfStorage = DataFrame(Resource = inputs["RESOURCES"], Zone = dfGen[!,:Zone])
	s = zeros(G,T)
	storagevcapvalue = zeros(G,T)
	for i in 1:G
		if i in inputs["STOR_ALL"]
			s[i,:] = value.(EP[:vS])[i,:]
		elseif i in inputs["HYDRO_RES"]
			s[i,:] = value.(EP[:vS_HYDRO])[i,:]
		elseif i in inputs["FLEX"]
			s[i,:] = value.(EP[:vS_FLEX])[i,:]
		end
	end

	# Incorporating effect of Parameter scaling (ParameterScale=1) on output values
	for y in 1:G
		if setup["ParameterScale"]==1
			storagevcapvalue[y,:] = s[y,:].*ModelScalingFactor 
		else
			storagevcapvalue[y,:] = s[y,:] 
		end
	end


	dfStorage = hcat(dfStorage, convert(DataFrame, storagevcapvalue))
	auxNew_Names=[Symbol("Resource");Symbol("Zone");[Symbol("t$t") for t in 1:T]]
	rename!(dfStorage,auxNew_Names)
	CSV.write(string(path,sep,"storage.csv"), dftranspose(dfStorage, false), writeheader=false)
end