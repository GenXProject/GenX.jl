"""
GenX: An Configurable Capacity Expansion Model
Copyright (C) 2021,  Massachusetts Institute of Technology
This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
A complete copy of the GNU General Public License v2 (GPLv2) is available
in LICENSE.txt.  Users uncompressing this from an archive may not have
received this license file.  If not, see <http://www.gnu.org/licenses/>.
"""

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

	if setup["VreStor"]==1
		dfGen_VRE_STOR = inputs["dfGen_VRE_STOR"]
		VRE_STOR = inputs["VRE_STOR"]
		dfStorageVRESTOR = DataFrame(Resource = inputs["RESOURCES_VRE_STOR"], Zone = dfGen_VRE_STOR[!,:Zone])
		s_vre_storage = zeros(VRE_STOR,T)
		for i in 1:VRE_STOR
			s_vre_storage[i,:] = value.(EP[:vS_VRE_STOR])[i,:] 
			if setup["ParameterScale"]==1
				s_vre_storage[i,:] =  s_vre_storage[i,:] .* ModelScalingFactor
			end
		end

		dfStorageVRESTOR = hcat(dfStorageVRESTOR, convert(DataFrame, s_vre_storage))
		auxNew_Names=[Symbol("Resource");Symbol("Zone");[Symbol("t$t") for t in 1:T]]
		rename!(dfStorageVRESTOR,auxNew_Names)
		dfStorage = vcat(dfStorage, dfStorageVRESTOR)
	end

	CSV.write(string(path,sep,"storage.csv"), dftranspose(dfStorage, false), writeheader=false)
end
