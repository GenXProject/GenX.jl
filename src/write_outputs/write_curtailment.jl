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
	write_curtailment(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing the curtailment values of the different variable renewable resources.
"""
function write_curtailment(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]
	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
	dfCurtailment = DataFrame(Resource = dfGen[!,:technology], Zone = dfGen[!,:Zone], AnnualSum = Array{Union{Missing,Float32}}(undef, G))
	for i in 1:G
		if i in inputs["VRE"]
			dfCurtailment[!,:AnnualSum][i] = sum(inputs["omega"].*(inputs["pP_Max"][i,:]).*value.(EP[:eTotalCap])[i,:].- inputs["omega"].*value.(EP[:vP])[i,:])
		else
			dfCurtailment[!,:AnnualSum][i] = 0
		end
	end
	if setup["ParameterScale"] ==1
		dfCurtailment.AnnualSum = dfCurtailment.AnnualSum * ModelScalingFactor
		dfCurtailment = hcat(dfCurtailment, DataFrame(( ModelScalingFactor * (inputs["pP_Max"]).*value.(EP[:eTotalCap]).- value.(EP[:vP])), :auto))
	else
		dfCurtailment = hcat(dfCurtailment, DataFrame(((inputs["pP_Max"]).*value.(EP[:eTotalCap]).- value.(EP[:vP])), :auto))
	end
	auxNew_Names=[Symbol("Resource");Symbol("Zone");Symbol("AnnualSum");[Symbol("t$t") for t in 1:T]]
	rename!(dfCurtailment,auxNew_Names)

	if setup["VreStor"]==1
		VRE_STOR = inputs["VRE_STOR"]
		dfGen_VRE_STOR = inputs["dfGen_VRE_STOR"]
		dfCurtailmentVRESTOR = DataFrame(Resource = dfGen_VRE_STOR[!,:technology], Zone = dfGen_VRE_STOR[!,:Zone], AnnualSum = Array{Union{Missing,Float32}}(undef, VRE_STOR))
		for i in 1:VRE_STOR
			dfCurtailmentVRESTOR[!,:AnnualSum][i] = sum(inputs["omega"].*(inputs["pP_Max_VRE_STOR"][i,:]).*value.(EP[:eTotalCap_VRE])[i,:].- inputs["omega"].*value.(EP[:vP_DC])[i,:])
		end

		if setup["ParameterScale"]==1
			dfCurtailmentVRESTOR.AnnualSum = dfCurtailmentVRESTOR.AnnualSum * ModelScalingFactor
			dfCurtailmentVRESTOR = hcat(dfCurtailmentVRESTOR, DataFrame((ModelScalingFactor * (inputs["pP_Max_VRE_STOR"]).*value.(EP[:eTotalCap_VRE]).- value.(EP[:vP_DC])), :auto))
		else
			dfCurtailmentVRESTOR = hcat(dfCurtailmentVRESTOR, DataFrame(((inputs["pP_Max_VRE_STOR"]).*value.(EP[:eTotalCap_VRE]).- value.(EP[:vP_DC])), :auto))
		end
		auxNew_Names=[Symbol("Resource");Symbol("Zone");Symbol("AnnualSum");[Symbol("t$t") for t in 1:T]]
		rename!(dfCurtailmentVRESTOR,auxNew_Names)
		dfCurtailment = vcat(dfCurtailment, dfCurtailmentVRESTOR)
	end

	total = DataFrame(["Total" 0 sum(dfCurtailment[!,:AnnualSum]) fill(0.0, (1,T))], :auto)
	for t in 1:T
		if v"1.3" <= VERSION < v"1.4"
			total[!,t+3] .= sum(dfCurtailment[!,Symbol("t$t")][1:G]) + (setup["VreStor"]==1 ? sum(dfCurtailmentVRESTOR[!,Symbol("t$t")][1:VRE_STOR]) : 0)
		elseif v"1.4" <= VERSION < v"1.7"
			total[:,t+3] .= sum(dfCurtailment[:,Symbol("t$t")][1:G]) + (setup["VreStor"]==1 ? sum(dfCurtailmentVRESTOR[:,Symbol("t$t")][1:VRE_STOR]) : 0)
		end
	end
	rename!(total,auxNew_Names)
	dfCurtailment = vcat(dfCurtailment, total)
	CSV.write(string(path,sep,"curtail.csv"), dftranspose(dfCurtailment, false), writeheader=false)
	return dfCurtailment
end
