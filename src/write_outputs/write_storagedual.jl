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
	write_storagedual(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for reporting dual of storage level (state of charge) balance of each resource in each time step.
"""
function write_storagedual(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]

	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)

	START_SUBPERIODS = inputs["START_SUBPERIODS"]
	INTERIOR_SUBPERIODS = inputs["INTERIOR_SUBPERIODS"]
	REP_PERIOD = inputs["REP_PERIOD"]
	STOR_ALL = inputs["STOR_ALL"]
	VRE_STOR = inputs["VRE_STOR"]
	hours_per_subperiod = inputs["hours_per_subperiod"] #total number of hours per subperiod

	# # Dual of storage level (state of charge) balance of each resource in each time step
	dfStorageDual = DataFrame(Resource = inputs["RESOURCES"], Zone = dfGen[!, :Zone])
	dual_values = zeros(G, T)

	# Loop over W separately hours_per_subperiod
	STOR_ALL_NONLDS = setdiff(STOR_ALL, inputs["STOR_LONG_DURATION"])
	STOR_ALL_LDS = intersect(STOR_ALL, inputs["STOR_LONG_DURATION"])
	dual_values[STOR_ALL, INTERIOR_SUBPERIODS] = (dual.(EP[:cSoCBalInterior][INTERIOR_SUBPERIODS, STOR_ALL]).data ./ inputs["omega"][INTERIOR_SUBPERIODS])'
	dual_values[STOR_ALL_NONLDS, START_SUBPERIODS] = (dual.(EP[:cSoCBalStart][START_SUBPERIODS, STOR_ALL_NONLDS]).data ./ inputs["omega"][START_SUBPERIODS])'
	if !isempty(STOR_ALL_LDS)
		if setup["OperationWrapping"] == 1
			dual_values[STOR_ALL_LDS, START_SUBPERIODS] = (dual.(EP[:cSoCBalLongDurationStorageStart][1:REP_PERIOD, STOR_ALL_LDS]).data ./ inputs["omega"][START_SUBPERIODS])'
		else
			dual_values[STOR_ALL_LDS, START_SUBPERIODS] = (dual.(EP[:cSoCBalStart][START_SUBPERIODS, STOR_ALL_LDS]).data ./ inputs["omega"][START_SUBPERIODS])'
		end
	end

	# Loop over W for VRE-Storage resources
	if !isempty(VRE_STOR)
		dfVRE_STOR = inputs["dfVRE_STOR"]
		VRE_STOR_ALL_NONLDS = setdiff(VRE_STOR, inputs["VRE_STOR_and_LDS"])
		VRE_STOR_ALL_LDS = intersect(VRE_STOR, inputs["VRE_STOR_and_LDS"])
		dual_values[VRE_STOR, INTERIOR_SUBPERIODS] = (dual.(EP[:cSoCBalInterior_VRE_STOR][INTERIOR_SUBPERIODS, VRE_STOR]).data ./ inputs["omega"][INTERIOR_SUBPERIODS])'
		dual_values[VRE_STOR_ALL_NONLDS, START_SUBPERIODS] = (dual.(EP[:cSoCBalStart_VRE_STOR][START_SUBPERIODS, VRE_STOR_ALL_NONLDS]).data ./ inputs["omega"][START_SUBPERIODS])'
		if !isempty(VRE_STOR_ALL_LDS)
			if setup["OperationWrapping"] == 1
				dual_values[VRE_STOR_ALL_LDS, START_SUBPERIODS] = (dual.(EP[:cVreStorSoCBalLongDurationStorageStart][1:REP_PERIOD, VRE_STOR_ALL_LDS]).data ./ inputs["omega"][START_SUBPERIODS])'
			else
				dual_values[VRE_STOR_ALL_LDS, START_SUBPERIODS] = (dual.(EP[:cSoCBalStart_VRE_STOR][START_SUBPERIODS, VRE_STOR_ALL_LDS]).data ./ inputs["omega"][START_SUBPERIODS])'
			end
		end
	end

	if setup["ParameterScale"] == 1
	    dual_values *= ModelScalingFactor
	end

	dfStorageDual=hcat(dfStorageDual, DataFrame(dual_values, :auto))
	rename!(dfStorageDual,[Symbol("Resource");Symbol("Zone");[Symbol("t$t") for t in 1:T]])

	CSV.write(joinpath(path, "storagebal_duals.csv"), dftranspose(dfStorageDual, false), writeheader=false)
end
