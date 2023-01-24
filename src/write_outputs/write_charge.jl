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
	write_charge(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing the charging energy values of the different storage technologies.
"""
function write_charge(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]
	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
	STOR_ALL = inputs["STOR_ALL"]
	FLEX = inputs["FLEX"]
	VRE_STOR = inputs["VRE_STOR"]
	# Power withdrawn to charge each resource in each time step
	dfCharge = DataFrame(Resource = inputs["RESOURCES"], Zone = dfGen[!,:Zone], AnnualSum = Array{Union{Missing,Float64}}(undef, G))
	charge = zeros(G,T)
	if setup["ParameterScale"] == 1
	    if !isempty(inputs["STOR_ALL"])
	        charge[STOR_ALL, :] = value.(EP[:vCHARGE][STOR_ALL, :]) * ModelScalingFactor
	    end
	    if !isempty(inputs["FLEX"])
	        charge[FLEX, :] = value.(EP[:vCHARGE_FLEX][FLEX, :]) * ModelScalingFactor
	    end
		if !isempty(VRE_STOR)
			charge[VRE_STOR, :] = value.(EP[:vCHARGE_VRE_STOR][VRE_STOR, :]) * ModelScalingFactor
		end
	    dfCharge.AnnualSum .= charge * inputs["omega"]
	else
	    if !isempty(inputs["STOR_ALL"])
	        charge[STOR_ALL, :] = value.(EP[:vCHARGE][STOR_ALL, :])
	    end
	    if !isempty(inputs["FLEX"])
	        charge[FLEX, :] = value.(EP[:vCHARGE_FLEX][FLEX, :])
	    end
		if !isempty(VRE_STOR)
			charge[VRE_STOR, :] = value.(EP[:vCHARGE_VRE_STOR][VRE_STOR, :])
		end
	    dfCharge.AnnualSum .= charge * inputs["omega"]
	end
	dfCharge = hcat(dfCharge, DataFrame(charge, :auto))
	auxNew_Names=[Symbol("Resource");Symbol("Zone");Symbol("AnnualSum");[Symbol("t$t") for t in 1:T]]
	rename!(dfCharge,auxNew_Names)

	if setup["VreStor"] == 1
		dfGen_VRE_STOR = inputs["dfGen_VRE_STOR"]
		VRE_STOR = inputs["VRE_STOR"]

		# Power withdrawn to charge each VRE-Storage in each time step (AC grid charging)
		dfChargeVRESTOR = DataFrame(Resource = inputs["RESOURCES_VRE_STOR"], Zone = dfGen_VRE_STOR[!,:Zone], AnnualSum = Array{Union{Missing,Float32}}(undef, VRE_STOR))
		charge_vre_stor = zeros(VRE_STOR, T)
		charge_vre_stor = value.(EP[:vCHARGE_VRE_STOR]) * (setup["ParameterScale"]==1 ? ModelScalingFactor : 1)
		dfChargeVRESTOR.AnnualSum .= charge_vre_stor * inputs["omega"]
		dfChargeVRESTOR = hcat(dfChargeVRESTOR, DataFrame(charge_vre_stor, :auto))
		auxNew_Names=[Symbol("Resource");Symbol("Zone");Symbol("AnnualSum");[Symbol("t$t") for t in 1:T]]
		rename!(dfChargeVRESTOR,auxNew_Names)
		dfCharge = vcat(dfCharge, dfChargeVRESTOR)
	end

	total = DataFrame(["Total" 0 sum(dfCharge[!,:AnnualSum]) fill(0.0, (1,T))], :auto)

	total[:, 4:T+3] .= sum(charge, dims = 1)
	rename!(total,auxNew_Names)
	dfCharge = vcat(dfCharge, total)
	CSV.write(joinpath(path, "charge.csv"), dftranspose(dfCharge, false), writeheader=false)
	return dfCharge
end
