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
	write_storage(path::AbstractString, inputs::Dict,setup::Dict, EP::Model)

Function for writing the capacities of different storage technologies, including hydro reservoir, flexible storage tech etc.
"""
function write_storage(path::AbstractString, inputs::Dict,setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]
	T = inputs["T"]     # Number of time steps (hours)
	G = inputs["G"]
	STOR_ALL = inputs["STOR_ALL"]
	HYDRO_RES = inputs["HYDRO_RES"]
	FLEX = inputs["FLEX"]
	VRE_STOR = inputs["VRE_STOR"]
	# Storage level (state of charge) of each resource in each time step
	dfStorage = DataFrame(Resource = inputs["RESOURCES"], Zone = dfGen[!,:Zone])
	storagevcapvalue = zeros(G,T)

	if !isempty(inputs["STOR_ALL"])
	    storagevcapvalue[STOR_ALL, :] = value.(EP[:vS][STOR_ALL, :])
	end
	if !isempty(inputs["HYDRO_RES"])
	    storagevcapvalue[HYDRO_RES, :] = value.(EP[:vS_HYDRO][HYDRO_RES, :])
	end
	if !isempty(inputs["FLEX"])
	    storagevcapvalue[FLEX, :] = value.(EP[:vS_FLEX][FLEX, :])
	end
	if !isempty(VRE_STOR)
	    storagevcapvalue[VRE_STOR, :] = value.(EP[:vS_VRE_STOR][VRE_STOR, :])
	end
	if setup["ParameterScale"] == 1
	    storagevcapvalue *= ModelScalingFactor
	end

	dfStorage = hcat(dfStorage, DataFrame(storagevcapvalue, :auto))
	auxNew_Names=[Symbol("Resource");Symbol("Zone");[Symbol("t$t") for t in 1:T]]
	rename!(dfStorage,auxNew_Names)
	
	CSV.write(joinpath(path, "storage.csv"), dftranspose(dfStorage, false), writeheader=false)
end
