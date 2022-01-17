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
	write_power(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing the different values of power generated by the different technologies in operation.
"""
function write_power(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]
	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)

	# Power injected by each resource in each time step
	dfPower = DataFrame(Resource = dfGen[!,:technology], Zone = dfGen[!,:Zone], AnnualSum = Array{Union{Missing,Float32}}(undef, G))
	if setup["ParameterScale"] ==1
		for i in 1:G
			dfPower[!,:AnnualSum][i] = sum(inputs["omega"].* (value.(EP[:vP])[i,:])) * ModelScalingFactor
		end
		dfPower = hcat(dfPower, DataFrame((value.(EP[:vP]))* ModelScalingFactor, :auto))
	else
		for i in 1:G
			dfPower[!,:AnnualSum][i] = sum(inputs["omega"].* (value.(EP[:vP])[i,:]))
		end
		dfPower = hcat(dfPower, DataFrame(value.(EP[:vP]), :auto))
	end

	auxNew_Names=[Symbol("Resource");Symbol("Zone");Symbol("AnnualSum");[Symbol("t$t") for t in 1:T]]
	rename!(dfPower,auxNew_Names)

	if setup["VreStor"] == 1
		dfGen_VRE_STOR = inputs["dfGen_VRE_STOR"]
		VRE_STOR = inputs["VRE_STOR"]

		# Create separate csvs for discharge_dc & AC power generation
		dfDischarge_DC = DataFrame(Resource = dfGen_VRE_STOR[!,:technology], Zone = dfGen_VRE_STOR[!,:Zone], AnnualSum = Array{Union{Missing,Float32}}(undef, VRE_STOR))
		if setup["ParameterScale"] == 1
			for i in 1:VRE_STOR
				dfDischarge_DC[!,:AnnualSum][i] = sum(inputs["omega"] .* value.(EP[:vDISCHARGE_DC])[i,:]) * ModelScalingFactor * dfGen_VRE_STOR[!,:EtaInverter][i]
			end
			dfDischarge_DC = hcat(dfDischarge_DC, DataFrame((value.(EP[:vDISCHARGE_DC])) * ModelScalingFactor, :auto))
		else
			for i in 1:VRE_STOR
				dfDischarge_DC[!,:AnnualSum][i] = sum(inputs["omega"] .* value.(EP[:vDISCHARGE_DC])[i,:]) * dfGen_VRE_STOR[!,:EtaInverter][i]
			end
			dfDischarge_DC = hcat(dfDischarge_DC, DataFrame((value.(EP[:vDISCHARGE_DC])), :auto))
		end
		auxNew_Names=[Symbol("Resource");Symbol("Zone");Symbol("AnnualSum");[Symbol("t$t") for t in 1:T]]
		rename!(dfDischarge_DC,auxNew_Names)
		total = DataFrame(["Total" 0 sum(dfDischarge_DC[!,:AnnualSum]) fill(0.0, (1,T))], :auto)
		for t in 1:T
			total[:,t+3] .= sum(dfDischarge_DC[:,Symbol("t$t")][1:VRE_STOR])
		end
		rename!(total,auxNew_Names)
		dfDischarge_DC = vcat(dfDischarge_DC, total)
		CSV.write(string(path,sep,"vre_stor_bat_discharge.csv"), dftranspose(dfDischarge_DC, false), writeheader=false)

		dfVP_VRE_STOR = DataFrame(Resource = dfGen_VRE_STOR[!,:technology], Zone = dfGen_VRE_STOR[!,:Zone], AnnualSum = Array{Union{Missing,Float32}}(undef, VRE_STOR))
		if setup["ParameterScale"] == 1
			for i in 1:VRE_STOR
				dfVP_VRE_STOR[!,:AnnualSum][i] = sum(inputs["omega"] .* value.(EP[:vP_DC])[i,:]) * ModelScalingFactor * dfGen_VRE_STOR[!,:EtaInverter][i]
			end
			dfVP_VRE_STOR = hcat(dfVP_VRE_STOR, DataFrame((value.(EP[:vP_DC])) * ModelScalingFactor, :auto))
		else
			for i in 1:VRE_STOR
				dfVP_VRE_STOR[!,:AnnualSum][i] = sum(inputs["omega"] .* value.(EP[:vP_DC])[i,:]) * dfGen_VRE_STOR[!,:EtaInverter][i]
			end
			dfVP_VRE_STOR = hcat(dfVP_VRE_STOR, DataFrame((value.(EP[:vP_DC])), :auto))
		end
		auxNew_Names=[Symbol("Resource");Symbol("Zone");Symbol("AnnualSum");[Symbol("t$t") for t in 1:T]]
		rename!(dfVP_VRE_STOR,auxNew_Names)
		total = DataFrame(["Total" 0 sum(dfVP_VRE_STOR[!,:AnnualSum]) fill(0.0, (1,T))], :auto)
		for t in 1:T
			total[:,t+3] .= sum(dfVP_VRE_STOR[:,Symbol("t$t")][1:VRE_STOR])
		end
		rename!(total,auxNew_Names)
		dfVP_VRE_STOR = vcat(dfVP_VRE_STOR, total)
		CSV.write(string(path,sep,"vre_stor_power.csv"), dftranspose(dfVP_VRE_STOR, false), writeheader=false)

		dfPowerVRESTOR = DataFrame(Resource = dfGen_VRE_STOR[!,:technology], Zone = dfGen_VRE_STOR[!,:Zone], AnnualSum = Array{Union{Missing,Float32}}(undef, VRE_STOR))
		if setup["ParameterScale"] == 1
			for i in 1:VRE_STOR
				dfPowerVRESTOR[!,:AnnualSum][i] = sum(inputs["omega"] .* value.(EP[:vP_VRE_STOR])[i,:]) * ModelScalingFactor
			end
			dfPowerVRESTOR = hcat(dfPowerVRESTOR, DataFrame((value.(EP[:vP_VRE_STOR])) * ModelScalingFactor, :auto))
		else
			for i in 1:VRE_STOR
				dfPowerVRESTOR[!,:AnnualSum][i] = sum(inputs["omega"] .* value.(EP[:vP_VRE_STOR])[i,:])  
			end
			dfPowerVRESTOR = hcat(dfPowerVRESTOR, DataFrame((value.(EP[:vP_VRE_STOR])), :auto))
		end
		auxNew_Names=[Symbol("Resource");Symbol("Zone");Symbol("AnnualSum");[Symbol("t$t") for t in 1:T]]
		rename!(dfPowerVRESTOR,auxNew_Names)

		# Concatenate VRE-storage resources to power csv
		dfPower = vcat(dfPower, dfPowerVRESTOR)
	end

	total = DataFrame(["Total" 0 sum(dfPower[!,:AnnualSum]) fill(0.0, (1,T))], :auto)
	for t in 1:T
		if v"1.3" <= VERSION < v"1.4"
			total[!,t+3] .= sum(dfPower[!,Symbol("t$t")][1:G]) + (setup["VreStor"]==1 ? sum(dfPowerVRESTOR[!,Symbol("t$t")][1:VRE_STOR]) : 0)
		elseif v"1.4" <= VERSION < v"1.7"
			total[:,t+3] .= sum(dfPower[:,Symbol("t$t")][1:G]) + (setup["VreStor"]==1 ? sum(dfPowerVRESTOR[:,Symbol("t$t")][1:VRE_STOR]) : 0)
		end
	end
	rename!(total,auxNew_Names)
	dfPower = vcat(dfPower, total)
 	CSV.write(string(path,sep,"power.csv"), dftranspose(dfPower, false), writeheader=false)
	return dfPower
end
