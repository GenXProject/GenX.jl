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
	write_storagedual(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for reporting dual of storage level (state of charge) balance of each resource in each time step.
"""
function write_storagedual(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]

	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
	Z = inputs["Z"]     # Number of zones

	START_SUBPERIODS = inputs["START_SUBPERIODS"]
	INTERIOR_SUBPERIODS = inputs["INTERIOR_SUBPERIODS"]
	REP_PERIOD = inputs["REP_PERIOD"]

	hours_per_subperiod = inputs["hours_per_subperiod"] #total number of hours per subperiod

	# # Dual of storage level (state of charge) balance of each resource in each time step
	dfStorageDual = DataFrame(Resource = inputs["RESOURCES"], Zone = dfGen[!,:Zone])
	# Define an empty array
	x1 = Array{Float64}(undef, G, T)
	dual_values =Array{Float64}(undef, G, T)

	# Loop over W separately hours_per_subperiod
	for y in 1:G
		if y in inputs["STOR_ALL"]
			if setup["OperationWrapping"]==1 && !isempty(inputs["STOR_LONG_DURATION"])
				for w in 1:REP_PERIOD
					x1[y,hours_per_subperiod*(w-1)+1] = dual.(EP[:cSoCBalLongDurationStorageStart][w,y])
				end
			else
				for t in START_SUBPERIODS
					x1[y,t] = dual.(EP[:cSoCBalStart][t,y])
				end
			end
			for t in INTERIOR_SUBPERIODS
				x1[y,t] = dual.(EP[:cSoCBalInterior][t,y]) #Use this for getting dual values and put in the extracted codes from PJM
			end
		else
			x1[y,:] = zeros(T,1) # Empty values for the resource with no ability to store energy
		end
	end

	# Incorporating effect of time step weights (When OperationWrapping=1) and Parameter scaling (ParameterScale=1) on dual variables
	for y in 1:G
		if setup["ParameterScale"]==1
			dual_values[y,:] = x1[y,:]./inputs["omega"] *ModelScalingFactor
		else
			dual_values[y,:] = x1[y,:]./inputs["omega"] *ModelScalingFactor
		end
	end



	dfStorageDual=hcat(dfStorageDual, DataFrame(dual_values, :auto))
	rename!(dfStorageDual,[Symbol("Resource");Symbol("Zone");[Symbol("t$t") for t in 1:T]])

	CSV.write(string(path,sep,"storagebal_duals.csv"), dftranspose(dfStorageDual, false), writeheader=false)
end
