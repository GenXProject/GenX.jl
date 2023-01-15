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
	write_vre_stor(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing the vre-storage internal/DC charging, discharging energy values.
"""

function write_vre_stor(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

        dfGen_VRE_STOR = inputs["dfGen_VRE_STOR"]
		VRE_STOR = inputs["VRE_STOR"]

		# DC charging of battery dataframe
		dfCharge_DC = DataFrame(Resource = inputs["RESOURCES_VRE_STOR"], Zone = dfGen_VRE_STOR[!,:Zone], AnnualSum = Array{Union{Missing,Float32}}(undef, VRE_STOR))
		charge_dc = zeros(VRE_STOR, T)
		for i in 1:VRE_STOR
			charge_dc[i,:] = value.(EP[:vCHARGE_DC][i,:]) * (setup["ParameterScale"]==1 ? ModelScalingFactor : 1)
			dfCharge_DC[!,:AnnualSum][i] = sum(inputs["omega"] .* charge_dc[i,:])
		end

		dfCharge_DC = hcat(dfCharge_DC, DataFrame(charge_dc, :auto))
		auxNew_Names=[Symbol("Resource");Symbol("Zone");Symbol("AnnualSum");[Symbol("t$t") for t in 1:T]]
		rename!(dfCharge_DC,auxNew_Names)
		total = DataFrame(["Total" 0 sum(dfCharge_DC[!,:AnnualSum]) fill(0.0, (1,T))], :auto)
		for t in 1:T
			total[:,t+3] .= sum(dfCharge_DC[:,Symbol("t$t")][1:VRE_STOR])
		end
		rename!(total,auxNew_Names)
		dfCharge_DC = vcat(dfCharge_DC, total)
		CSV.write(string(path,sep,"vre_stor_dc_charge.csv"), dftranspose(dfCharge_DC, false), writeheader=false)

		# DC charging of battery (specifically from VRE resource) datafrfame
		dfCharge_VRE = DataFrame(Resource = inputs["RESOURCES_VRE_STOR"], Zone = dfGen_VRE_STOR[!,:Zone], AnnualSum = Array{Union{Missing,Float32}}(undef, VRE_STOR))
		charge_vre = zeros(VRE_STOR, T)
		for i in 1:VRE_STOR
			charge_vre[i,:] = value.(EP[:eVRECharging][i,:]) * (setup["ParameterScale"]==1 ? ModelScalingFactor : 1)
			dfCharge_VRE[!,:AnnualSum][i] = sum(inputs["omega"] .* charge_vre[i,:])
		end

		dfCharge_VRE = hcat(dfCharge_VRE, DataFrame(charge_vre, :auto))
		auxNew_Names=[Symbol("Resource");Symbol("Zone");Symbol("AnnualSum");[Symbol("t$t") for t in 1:T]]
		rename!(dfCharge_VRE,auxNew_Names)
		total = DataFrame(["Total" 0 sum(dfCharge_VRE[!,:AnnualSum]) fill(0.0, (1,T))], :auto)
		for t in 1:T
			total[:,t+3] .= sum(dfCharge_VRE[:,Symbol("t$t")][1:VRE_STOR])
		end
		rename!(total,auxNew_Names)
		dfCharge_VRE = vcat(dfCharge_VRE, total)
		CSV.write(string(path,sep,"vre_stor_vre_charge.csv"), dftranspose(dfCharge_VRE, false), writeheader=false)

        dfGen_VRE_STOR = inputs["dfGen_VRE_STOR"]
		VRE_STOR = inputs["VRE_STOR"]

		# DC discharging of battery dataframe
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

        # VRE generation of co-located resource dataframe
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

        # Capacity Factor code
        dfCapacityfactorVRESTOR = DataFrame(Resource=inputs["RESOURCES_VRE"], Zone=dfGen_VRE_STOR[!, :Zone], AnnualSum=zeros(VRE_STOR), Capacity=zeros(VRE_STOR), CapacityFactor=zeros(VRE_STOR))
        if setup["ParameterScale"] == 1
            dfCapacityfactorVRESTOR.AnnualSum .= value.(EP[:vP_DC]) * dfGen_VRE_STOR[!,:EtaInverter] * inputs["omega"] * ModelScalingFactor
            dfCapacityfactorVRESTOR.Capacity .= value.(EP[:eTotalCap_VRE]) * ModelScalingFactor
        else
            dfCapacityfactorVRESTOR.AnnualSum .= value.(EP[:vP_DC]) * dfGen_VRE_STOR[!,:EtaInverter]
            dfCapacityfactorVRESTOR.Capacity .= value.(EP[:eTotalCap_VRE])
        end
        # We only calculate the resulted capacity factor with total capacity > 1MW and total generation > 1MWh
        EXISTING = intersect(findall(x -> x >= 1, dfCapacityfactorVRESTOR.AnnualSum), findall(x -> x >= 1, dfCapacityfactorVRESTOR.Capacity))
        dfCapacityfactorVRESTOR.CapacityFactor[EXISTING] .= (dfCapacityfactorVRESTOR.AnnualSum[EXISTING] ./ dfCapacityfactorVRESTOR.Capacity[EXISTING]) / sum(inputs["omega"][t] for t in 1:T)
        CSV.write(joinpath(path, "vrestor_capacityfactor.csv"), dfCapacityfactorVRESTOR)

end
