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

function write_opwrap_lds_dstor(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	## Extract data frames from input dictionary
	dfGen = inputs["dfGen"]
	W = inputs["REP_PERIOD"]     # Number of subperiods
	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)

	#Excess inventory of storage period built up during representative period w
	dfdStorage = DataFrame(Resource = inputs["RESOURCES"], Zone = dfGen[!,:Zone])
	dsoc = zeros(G,W)
	for i in 1:G
		if i in inputs["STOR_LONG_DURATION"]
			dsoc[i,:] = value.(EP[:vdSOC])[i,:]
		end
		if i in inputs["VRE_STOR_and_LDS"]
			dsoc[i,:] = value.(EP[:vdSOC_VRE_STOR])[i,:]
		end
	end
	dfdStorage = hcat(dfdStorage, DataFrame(dsoc, :auto))
	auxNew_Names=[Symbol("Resource");Symbol("Zone");[Symbol("w$t") for t in 1:W]]
	rename!(dfdStorage,auxNew_Names)
	CSV.write(joinpath(path, "dStorage.csv"), dftranspose(dfdStorage, false), writeheader=false)
end
