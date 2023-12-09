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
	write_curtailment(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing the curtailment values of the different variable renewable resources (both standalone and 
	co-located).
"""
function write_curtailment(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]
	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
	VRE = inputs["VRE"]
	dfCurtailment = DataFrame(Resource = inputs["RESOURCES"], Zone = dfGen[!, :Zone], AnnualSum = Array{Union{Missing,Float64}}(undef, G))
	curtailment = zeros(G, T)
	scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
	curtailment[VRE, :] = scale_factor * (value.(EP[:eTotalCap][VRE]) .* inputs["pP_Max"][VRE, :] .- value.(EP[:vP][VRE, :]))
	
	VRE_STOR = inputs["VRE_STOR"]
	if !isempty(VRE_STOR)
        SOLAR = setdiff(inputs["VS_SOLAR"],inputs["VS_WIND"])
        WIND = setdiff(inputs["VS_WIND"],inputs["VS_SOLAR"])
        SOLAR_WIND = intersect(inputs["VS_SOLAR"],inputs["VS_WIND"])
		dfVRE_STOR = inputs["dfVRE_STOR"]
		if !isempty(SOLAR)
			curtailment[SOLAR, :] = scale_factor * (value.(EP[:eTotalCap_SOLAR][SOLAR]).data .* inputs["pP_Max_Solar"][SOLAR, :] .- value.(EP[:vP_SOLAR][SOLAR, :]).data) .* dfVRE_STOR[(dfVRE_STOR.SOLAR.!=0), :EtaInverter]
		end
		if !isempty(WIND)
			curtailment[WIND, :] = scale_factor * (value.(EP[:eTotalCap_WIND][WIND]).data .* inputs["pP_Max_Wind"][WIND, :] .- value.(EP[:vP_WIND][WIND, :]).data)
		end
		if !isempty(SOLAR_WIND)
			curtailment[SOLAR_WIND, :] = scale_factor * ((value.(EP[:eTotalCap_SOLAR])[SOLAR_WIND].data 
				.* inputs["pP_Max_Solar"][SOLAR_WIND, :] .- value.(EP[:vP_SOLAR][SOLAR_WIND, :]).data) 
				.* dfVRE_STOR[((dfVRE_STOR.SOLAR.!=0) .& (dfVRE_STOR.WIND.!=0)), :EtaInverter]
				+ (value.(EP[:eTotalCap_WIND][SOLAR_WIND]).data .* inputs["pP_Max_Wind"][SOLAR_WIND, :] .- value.(EP[:vP_WIND][SOLAR_WIND, :]).data))
		end
	end
	dfCurtailment.AnnualSum = curtailment * inputs["omega"]
	dfCurtailment = hcat(dfCurtailment, DataFrame(curtailment, :auto))
	auxNew_Names=[Symbol("Resource");Symbol("Zone");Symbol("AnnualSum");[Symbol("t$t") for t in 1:T]]
	rename!(dfCurtailment,auxNew_Names)

	total = DataFrame(["Total" 0 sum(dfCurtailment[!,:AnnualSum]) fill(0.0, (1,T))], :auto)
	total[:, 4:T+3] .= sum(curtailment, dims = 1)
	rename!(total,auxNew_Names)
	dfCurtailment = vcat(dfCurtailment, total)
	CSV.write(joinpath(path, "curtail.csv"), dftranspose(dfCurtailment, false), writeheader=false)
	return dfCurtailment
end
