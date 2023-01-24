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

Function for writing the vre-storage specific files.
"""

function write_vre_stor(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

	### CAPACITY DECISIONS ###
	write_vre_stor_capacity(path, inputs, setup, EP)

	### CHARGING DECISIONS ###
	write_vre_stor_charge(path, inputs, setup, EP)

	### DISCHARGING DECISIONS ###
	write_vre_stor_discharge(path, inputs, setup, EP)
end

@doc raw"""
	write_vre_stor_capacity(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing the vre-storage capacities.
"""
function write_vre_stor_capacity(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	VRE_STOR = inputs["VRE_STOR"]

	capdischarge = zeros(size(inputs["RESOURCES_VRE_STOR"]))
	for i in intersect(inputs["NEW_CAP"], VRE_STOR)
		capdischarge[i] = value(EP[:vCAP][i])
	end

	retcapdischarge = zeros(size(inputs["RESOURCES_VRE_STOR"]))
	for i in intersect(inputs["RET_CAP"], VRE_STOR)
		retcapdischarge[i] = first(value.(EP[:vRETCAP][i]))
	end

	existingcap = zeros(size(inputs["RESOURCES_VRE_STOR"]))
	for i in VRE_STOR
		existingcap[i] = dfGen[!,:Existing_Cap_MW][i]
	end

	capenergy = zeros(size(inputs["RESOURCES_VRE_STOR"]))
	for i in inputs["NEW_CAP_ENERGY_VRE_STOR"]
		capenergy[i] = value(EP[:vCAPENERGY_VRE_STOR][i])
	end

	retcapenergy = zeros(size(inputs["RESOURCES_VRE_STOR"]))
	for i in inputs["RET_CAP_ENERGY_VRE_STOR"]
		retcapdischarge[i] = first(value.(EP[:vRETCAPENERGY_VRE_STOR][i]))
	end

	existingcapenergy = zeros(size(inputs["RESOURCES_VRE_STOR"]))
	for i in VRE_STOR
		existingcapenergy[i] = dfGen[!,:Existing_Cap_MWh][i]
	end

	capcharge = zeros(size(inputs["RESOURCES_VRE_STOR"]))
	for i in inputs["NEW_CAP_ENERGY_VRE_STOR"]
		capcharge[i] = value(EP[:vCAPCHARGE_VRE_STOR][i])
	end

	retcapcharge = zeros(size(inputs["RESOURCES_VRE_STOR"]))
	for i in inputs["RET_CAP_ENERGY_VRE_STOR"]
		retcapcharge[i] = first(value.(EP[:vRETCAPCHARGE_VRE_STOR][i]))
	end

	existingcapcharge = zeros(size(inputs["RESOURCES_VRE_STOR"]))
	for i in VRE_STOR
		existingcapcharge[i] = dfGen[!,:Existing_Charge_Cap_MW][i]
	end

	dfCap = DataFrame(
		Resource = inputs["RESOURCES"], Zone = dfGen[!,:Zone], Technology = dfGen[!,:technology], Cluster=dfGen[!,:cluster], 
		StartCap = existingcap[:],
		RetCap = retcapdischarge[:],
		NewCap = capdischarge[:],
		EndCap = existingcap[:] - retcapdischarge[:] - capdischarge[:],
		StartEnergyCap = existingcapenergy[:],
		RetEnergyCap = retcapenergy[:],
		NewEnergyCap = capenergy[:],
		EndEnergyCap = existingcapenergy[:] - retcapenergy[:] + capenergy[:],
		StartChargeCap = existingcapcharge[:],
		RetChargeCap = retcapcharge[:],
		NewChargeCap = capcharge[:],
		EndChargeCap = existingcapcharge[:] - retcapcharge[:] + capcharge[:],
		StartGridCap = value.(EP[:vRETGRIDCAP]),
		RetGridCap = value.(EP[:vRETGRIDCAP]),
		NewGridCap = value.(EP[:vGRIDCAP]),
		EndGridCap = value.(EP[:eTotalCap_GRID])
	)

	if setup["ParameterScale"] ==1
		dfCap.StartCap = dfCap.StartCap * ModelScalingFactor
		dfCap.RetCap = dfCap.RetCap * ModelScalingFactor
		dfCap.NewCap = dfCap.NewCap * ModelScalingFactor
		dfCap.EndCap = dfCap.EndCap * ModelScalingFactor
		dfCap.StartEnergyCap = dfCap.StartEnergyCap * ModelScalingFactor
		dfCap.RetEnergyCap = dfCap.RetEnergyCap * ModelScalingFactor
		dfCap.NewEnergyCap = dfCap.NewEnergyCap * ModelScalingFactor
		dfCap.EndEnergyCap = dfCap.EndEnergyCap * ModelScalingFactor
		dfCap.StartChargeCap = dfCap.StartChargeCap * ModelScalingFactor
		dfCap.RetChargeCap = dfCap.RetChargeCap * ModelScalingFactor
		dfCap.NewChargeCap = dfCap.NewChargeCap * ModelScalingFactor
		dfCap.EndChargeCap = dfCap.EndChargeCap * ModelScalingFactor
		dfCap.StartGridCap = dfCap.StartGridCap * ModelScalingFactor
		dfCap.RetGridCap = dfCap.RetGridCap * ModelScalingFactor
		dfCap.NewGridCap = dfCap.NewGridCap * ModelScalingFactor
		dfCap.EndGridCap = dfCap.EndGridCap * ModelScalingFactor
	end

	total = DataFrame(
		Resource = "Total", Zone = "n/a", Technology = "Total", Cluster= "n/a", 
		StartCap = sum(dfCap[!,:StartCap]), RetCap = sum(dfCap[!,:RetCap]),
		NewCap = sum(dfCap[!,:NewCap]), EndCap = sum(dfCap[!,:EndCap]),
		StartEnergyCap = sum(dfCap[!,:StartEnergyCap]), RetEnergyCap = sum(dfCap[!,:RetEnergyCap]),
		NewEnergyCap = sum(dfCap[!,:NewEnergyCap]), EndEnergyCap = sum(dfCap[!,:EndEnergyCap]),
		StartChargeCap = sum(dfCap[!,:StartChargeCap]), RetChargeCap = sum(dfCap[!,:RetChargeCap]),
		NewChargeCap = sum(dfCap[!,:NewChargeCap]), EndChargeCap = sum(dfCap[!,:EndChargeCap]),
		StartGridCap = sum(dfCap[!, :StartGridCap]), RetGridCap = sum(dfCap[!, :RetGridCap]),
		NewGridCap = sum(dfCap[!, :NewGridCap]), EndGridCap = sum(dfCap[!, :EndGridCap]),
	)

	dfCap = vcat(dfCap, total)
	CSV.write(joinpath(path, "vre_stor_capacity.csv"), dfCap)
end

@doc raw"""
	write_vre_stor_charge(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing the vre-storage charging decision variables/expressions.
"""
function write_vre_stor_charge(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfVRE_STOR = inputs["dfVRE_STOR"]
	VRE_STOR = inputs["VRE_STOR"]
	T = inputs["T"]

	# DC charging of battery dataframe
	dfCharge_DC = DataFrame(Resource = inputs["RESOURCES_VRE_STOR"], Zone = dfVRE_STOR[!,:Zone], AnnualSum = Array{Union{Missing,Float32}}(undef, size(VRE_STOR)[1]))
	charge_dc = zeros(VRE_STOR, T)
	charge_dc = value.(EP[:vCHARGE_DC]) * (setup["ParameterScale"]==1 ? ModelScalingFactor : 1)
	dfCharge_DC.AnnualSum .= charge_dc * inputs["omega"]
	dfCharge_DC = hcat(dfCharge_DC, DataFrame(charge_dc, :auto))
	auxNew_Names=[Symbol("Resource");Symbol("Zone");Symbol("AnnualSum");[Symbol("t$t") for t in 1:T]]
	rename!(dfCharge_DC,auxNew_Names)
	total = DataFrame(["Total" 0 sum(dfCharge_DC[!,:AnnualSum]) fill(0.0, (1,T))], :auto)
	total[:, 4:T+3] .= sum(charge_dc, dims = 1)
	rename!(total,auxNew_Names)
	dfCharge_DC = vcat(dfCharge_DC, total)
	CSV.write(joinpath(path,"vre_stor_dc_charge.csv"), dftranspose(dfCharge_DC, false), writeheader=false)

	# DC charging of battery (specifically from VRE resource) dataframe
	dfCharge_VRE = DataFrame(Resource = inputs["RESOURCES_VRE_STOR"], Zone = dfVRE_STOR[!,:Zone], AnnualSum = Array{Union{Missing,Float32}}(undef, size(VRE_STOR)[1]))
	charge_vre = zeros(VRE_STOR, T)
	charge_vre = value.(EP[:eVRECharging]) * (setup["ParameterScale"]==1 ? ModelScalingFactor : 1)
	dfCharge_VRE.AnnualSum .= charge_vre * inputs["omega"]
	dfCharge_VRE = hcat(dfCharge_VRE, DataFrame(charge_vre, :auto))
	auxNew_Names=[Symbol("Resource");Symbol("Zone");Symbol("AnnualSum");[Symbol("t$t") for t in 1:T]]
	rename!(dfCharge_VRE,auxNew_Names)
	total = DataFrame(["Total" 0 sum(dfCharge_VRE[!,:AnnualSum]) fill(0.0, (1,T))], :auto)
	total[:, 4:T+3] .= sum(charge_vre, dims = 1)
	rename!(total,auxNew_Names)
	dfCharge_VRE = vcat(dfCharge_VRE, total)
	CSV.write(joinpath(path,"vre_stor_vre_charge.csv"), dftranspose(dfCharge_VRE, false), writeheader=false)
end

@doc raw"""
	write_vre_stor_charge(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing the vre-storage discharging decision variables/expressions.
"""
function write_vre_stor_discharge(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfVRE_STOR = inputs["dfVRE_STOR"]
	VRE_STOR = inputs["VRE_STOR"]
	T = inputs["T"] 

	# DC discharging of battery dataframe
	dfDischarge_DC = DataFrame(Resource = dfVRE_STOR[!,:technology], Zone = dfVRE_STOR[!,:Zone], AnnualSum = Array{Union{Missing,Float32}}(undef, size(VRE_STOR)[1]))
	power_vre_stor = value.(EP[:vDISCHARGE_DC])
	if setup["ParameterScale"] == 1
		power_vre_stor *= ModelScalingFactor
	end
	dfDischarge_DC.AnnualSum .= power_vre_stor * inputs["omega"]
	dfDischarge_DC = hcat(dfDischarge_DC, DataFrame(power_vre_stor, :auto))
	auxNew_Names=[Symbol("Resource");Symbol("Zone");Symbol("AnnualSum");[Symbol("t$t") for t in 1:T]]
	rename!(dfDischarge_DC,auxNew_Names)
	total = DataFrame(["Total" 0 sum(dfDischarge_DC[!,:AnnualSum]) fill(0.0, (1,T))], :auto)
	total[:, 4:T+3] .= sum(power_vre_stor, dims = 1)
	rename!(total,auxNew_Names)
	dfDischarge_DC = vcat(dfDischarge_DC, total)
	CSV.write(joinpath(path, "vre_stor_bat_discharge.csv"), dftranspose(dfDischarge_DC, false), writeheader=false)

	# VRE generation of co-located resource dataframe
	dfVP_VRE_STOR = DataFrame(Resource = dfVRE_STOR[!,:technology], Zone = dfVRE_STOR[!,:Zone], AnnualSum = Array{Union{Missing,Float32}}(undef, size(VRE_STOR)[1]))
	vre_vre_stor = value.(EP[:vP_DC]) .* dfVRE_STOR[!,:EtaInverter]
	if setup["ParameterScale"] == 1
		vre_vre_stor *= ModelScalingFactor
	end
	dfVP_VRE_STOR.AnnualSum .= vre_vre_stor * inputs["omega"]
	dfVP_VRE_STOR = hcat(dfVP_VRE_STOR, DataFrame(vre_vre_stor, :auto))
	auxNew_Names=[Symbol("Resource");Symbol("Zone");Symbol("AnnualSum");[Symbol("t$t") for t in 1:T]]
	rename!(dfVP_VRE_STOR,auxNew_Names)
	total = DataFrame(["Total" 0 sum(dfVP_VRE_STOR[!,:AnnualSum]) fill(0.0, (1,T))], :auto)
	total[:, 4:T+3] .= sum(vre_vre_stor, dims = 1)
	rename!(total,auxNew_Names)
	dfVP_VRE_STOR = vcat(dfVP_VRE_STOR, total)
	CSV.write(joinpath(path,"vre_stor_power.csv"), dftranspose(dfVP_VRE_STOR, false), writeheader=false)
end
