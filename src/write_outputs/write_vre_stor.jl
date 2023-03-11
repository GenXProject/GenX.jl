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
	SOLAR = inputs["VS_SOLAR"]
	WIND = inputs["VS_WIND"]
	DC = inputs["VS_DC"]
	STOR = inputs["VS_STOR"]
	dfGen = inputs["dfGen"]
	dfVRE_STOR = inputs["dfVRE_STOR"]

	# Solar capacity
	capsolar = zeros(size(inputs["RESOURCES_VRE_STOR"]))
	retcapsolar = zeros(size(inputs["RESOURCES_VRE_STOR"]))

	# Wind capacity
	capwind = zeros(size(inputs["RESOURCES_VRE_STOR"]))
	retcapwind = zeros(size(inputs["RESOURCES_VRE_STOR"]))

	# Inverter capacity
	capdc = zeros(size(inputs["RESOURCES_VRE_STOR"]))
	retcapdc = zeros(size(inputs["RESOURCES_VRE_STOR"]))

	# Grid connection capacity
	capgrid = zeros(size(inputs["RESOURCES_VRE_STOR"]))
	retcapgrid = zeros(size(inputs["RESOURCES_VRE_STOR"]))
	existingcapgrid = zeros(size(inputs["RESOURCES_VRE_STOR"]))

	# Energy storage capacity
	capenergy = zeros(size(inputs["RESOURCES_VRE_STOR"]))
	retcapenergy = zeros(size(inputs["RESOURCES_VRE_STOR"]))
	existingcapenergy = zeros(size(inputs["RESOURCES_VRE_STOR"]))

	# Charge storage capacity DC
	capchargedc = zeros(size(inputs["RESOURCES_VRE_STOR"]))
	retcapchargedc = zeros(size(inputs["RESOURCES_VRE_STOR"]))

	# Charge storage capacity AC
	capchargeac = zeros(size(inputs["RESOURCES_VRE_STOR"]))
	retcapchargeac = zeros(size(inputs["RESOURCES_VRE_STOR"]))

	# Discharge storage capacity DC
	capdischargedc = zeros(size(inputs["RESOURCES_VRE_STOR"]))
	retcapdischargedc = zeros(size(inputs["RESOURCES_VRE_STOR"]))

	# Discharge storage capacity AC
	capdischargeac = zeros(size(inputs["RESOURCES_VRE_STOR"]))
	retcapdischargeac = zeros(size(inputs["RESOURCES_VRE_STOR"]))
	
	j = 1
	for i in VRE_STOR
		capgrid[j] = value(EP[:vGRIDCAP][i])
		retcapgrid[j] = value(EP[:vRETGRIDCAP][i])

		if i in intersect(inputs["NEW_CAP_SOLAR"], SOLAR)
			capsolar[j] = value(EP[:vSOLARCAP][i])
		end
		if i in intersect(inputs["RET_CAP_SOLAR"], SOLAR)
			retcapsolar[j] = first(value.(EP[:vRETSOLARCAP][i]))
		end

		if i in intersect(inputs["NEW_CAP_WIND"], WIND)
			capwind[j] = value(EP[:vWINDCAP][i])
		end
		if i in intersect(inputs["RET_CAP_WIND"], WIND)
			retcapwind[j] = first(value.(EP[:vRETWINDCAP][i]))
		end

		if i in intersect(inputs["NEW_CAP_DC"], DC)
			capdc[j] = value(EP[:vDCCAP][i])
		end
		if i in intersect(inputs["RET_CAP_DC"], DC)
			retcapdc[j] = first(value.(EP[:vRETDCCAP][i]))
		end

		if !isempty(STOR)
			if i in inputs["NEW_CAP_STOR"]
				capenergy[j] = value(EP[:vCAPENERGY_VS][i])
			end
			if i in inputs["RET_CAP_STOR"]
				retcapenergy[j] = first(value.(EP[:vRETCAPENERGY_VS][i]))
			end

			if !isempty(inputs["VS_ASYM_DC_CHARGE"])
				if !isempty(inputs["NEW_CAP_CHARGE_DC"])
					capchargedc[j] = value(EP[:vCAPCHARGE_DC][i])
				end
				if !isempty(inputs["RET_CAP_CHARGE_DC"])
					retcapchargedc[j] = value(EP[:vRETCAPCHARGE_DC][i])
				end
			end
			if !isempty(inputs["VS_ASYM_AC_CHARGE"])
				if !isempty(inputs["NEW_CAP_CHARGE_AC"])
					capchargeac[j] = value(EP[:vCAPCHARGE_AC][i])
				end
				if !isempty(inputs["RET_CAP_CHARGE_AC"])
					retcapchargeac[j] = value(EP[:vRETCAPCHARGE_AC][i])
				end
			end
			if !isempty(inputs["VS_ASYM_DC_DISCHARGE"])
				if !isempty(inputs["NEW_CAP_DISCHARGE_DC"])
					capdischargedc[j] = value(EP[:vCAPDISCHARGE_DC][i])
				end
				if !isempty(inputs["RET_CAP_DISCHARGE_DC"])
					retcapdischargedc[j] = value(EP[:vRETCAPDISCHARGE_DC][i])
				end
			end
			if !isempty(inputs["VS_ASYM_AC_DISCHARGE"])
				if !isempty(inputs["NEW_CAP_DISCHARGE_AC"])
					capdischargeac[j] = value(EP[:vCAPDISCHARGE_AC][i])
				end
				if !isempty(inputs["RET_CAP_DISCHARGE_AC"])
					retcapdischargeac[j] = value(EP[:vRETCAPDISCHARGE_AC][i])
				end
			end
		end

		existingcapgrid[j] = dfGen[!,:Existing_Cap_MW][i]
		existingcapenergy[j] = dfGen[!,:Existing_Cap_MWh][i]
		j += 1
	end

	dfCap = DataFrame(
		Resource = inputs["RESOURCES_VRE_STOR"], Zone = dfVRE_STOR[!,:Zone], Resource_Type = dfVRE_STOR[!,:Resource_Type], Cluster=dfVRE_STOR[!,:cluster], 
		StartCapSolar = dfVRE_STOR[!,:Existing_Cap_Solar_MW],
		RetCapSolar = retcapsolar[:],
		NewCapSolar = capsolar[:],
		EndCapSolar = dfVRE_STOR[!,:Existing_Cap_Solar_MW] - retcapsolar[:] + capsolar[:],
		StartCapWind = dfVRE_STOR[!,:Existing_Cap_Wind_MW],
		RetCapWind = retcapwind[:],
		NewCapWind = capwind[:],
		EndCapWind = dfVRE_STOR[!,:Existing_Cap_Wind_MW] - retcapwind[:] + capwind[:],
		StartCapDC = dfVRE_STOR[!,:Existing_Cap_Inverter_MW],
		RetCapDC = retcapdc[:],
		NewCapDC = capdc[:],
		EndCapDC = dfVRE_STOR[!,:Existing_Cap_Inverter_MW] - retcapdc[:] + capdc[:],
		StartCapGrid = existingcapgrid[:],
		RetCapGrid = retcapgrid[:],
		NewCapGrid = capgrid[:],
		EndCapGrid = existingcapgrid[:] - retcapgrid[:] + capgrid[:],
		StartEnergyCap = existingcapenergy[:],
		RetEnergyCap = retcapenergy[:],
		NewEnergyCap = capenergy[:],
		EndEnergyCap = existingcapenergy[:] - retcapenergy[:] + capenergy[:],
		StartChargeDCCap = dfVRE_STOR[!,:Existing_Charge_DC_Cap_MW],
		RetChargeDCCap = retcapchargedc[:],
		NewChargeDCCap = capchargedc[:],
		EndChargeDCCap = dfVRE_STOR[!,:Existing_Charge_DC_Cap_MW] - retcapchargedc[:] + capchargedc[:],
		StartChargeACCap = dfVRE_STOR[!,:Existing_Charge_AC_Cap_MW],
		RetChargeACCap = retcapchargeac[:],
		NewChargeACCap = capchargeac[:],
		EndChargeACCap = dfVRE_STOR[!,:Existing_Charge_AC_Cap_MW] - retcapchargeac[:] + capchargeac[:],
		StartDischargeDCCap = dfVRE_STOR[!,:Existing_Discharge_DC_Cap_MW],
		RetDischargeDCCap = retcapdischargedc[:],
		NewDischargeDCCap = capdischargedc[:],
		EndDischargeDCCap = dfVRE_STOR[!,:Existing_Discharge_DC_Cap_MW] - retcapdischargedc[:] + capdischargedc[:],
		StartDischargeACCap = dfVRE_STOR[!,:Existing_Discharge_AC_Cap_MW],
		RetDischargeACCap = retcapdischargeac[:],
		NewDischargeACCap = capdischargeac[:],
		EndDischargeACCap = dfVRE_STOR[!,:Existing_Discharge_AC_Cap_MW] - retcapdischargeac[:] + capdischargeac[:]
	)

	if setup["ParameterScale"] ==1
		dfCap.StartCapSolar = dfCap.StartCapSolar * ModelScalingFactor
		dfCap.RetCapSolar = dfCap.RetCapSolar * ModelScalingFactor
		dfCap.NewCapSolar = dfCap.NewCapSolar * ModelScalingFactor
		dfCap.EndCapSolar = dfCap.EndCapSolar * ModelScalingFactor

		dfCap.StartCapWind = dfCap.StartCapWind * ModelScalingFactor
		dfCap.RetCapWind = dfCap.RetCapWind * ModelScalingFactor
		dfCap.NewCapWind = dfCap.NewCapWind * ModelScalingFactor
		dfCap.EndCapWind = dfCap.EndCapWind * ModelScalingFactor

		dfCap.StartCapGrid = dfCap.StartCapGrid * ModelScalingFactor
		dfCap.RetCapGrid = dfCap.RetCapGrid * ModelScalingFactor
		dfCap.NewCapGrid = dfCap.NewCapGrid * ModelScalingFactor
		dfCap.EndCapGrid = dfCap.EndCapGrid * ModelScalingFactor

		dfCap.StartEnergyCap = dfCap.StartEnergyCap * ModelScalingFactor
		dfCap.RetEnergyCap = dfCap.RetEnergyCap * ModelScalingFactor
		dfCap.NewEnergyCap = dfCap.NewEnergyCap * ModelScalingFactor
		dfCap.EndEnergyCap = dfCap.EndEnergyCap * ModelScalingFactor

		dfCap.StartChargeACCap = dfCap.StartChargeACCap * ModelScalingFactor
		dfCap.RetChargeACCap = dfCap.RetChargeACCap * ModelScalingFactor
		dfCap.NewChargeACCap = dfCap.NewChargeACCap * ModelScalingFactor
		dfCap.EndChargeACCap = dfCap.EndChargeACCap * ModelScalingFactor

		dfCap.StartChargeDCCap = dfCap.StartChargeDCCap * ModelScalingFactor
		dfCap.RetChargeDCCap = dfCap.RetChargeDCCap * ModelScalingFactor
		dfCap.NewChargeDCCap = dfCap.NewChargeDCCap * ModelScalingFactor
		dfCap.EndChargeDCCap = dfCap.EndChargeDCCap * ModelScalingFactor

		dfCap.StartDischargeDCCap = dfCap.StartDischargeDCCap * ModelScalingFactor
		dfCap.RetDischargeDCCap = dfCap.RetDischargeDCCap * ModelScalingFactor
		dfCap.NewDischargeDCCap = dfCap.NewDischargeDCCap * ModelScalingFactor
		dfCap.EndDischargeDCCap = dfCap.EndDischargeDCCap * ModelScalingFactor

		dfCap.StartDischargeACCap = dfCap.StartDischargeACCap * ModelScalingFactor
		dfCap.RetDischargeACCap = dfCap.RetDischargeACCap * ModelScalingFactor
		dfCap.NewDischargeACCap = dfCap.NewDischargeACCap * ModelScalingFactor
		dfCap.EndDischargeACCap = dfCap.EndDischargeACCap * ModelScalingFactor
	end

	total = DataFrame(
		Resource = "Total", Zone = "n/a", Resource_Type = "Total", Cluster= "n/a", 
		StartCapSolar = sum(dfCap[!,:StartCapSolar]), RetCapSolar = sum(dfCap[!,:RetCapSolar]),
		NewCapSolar = sum(dfCap[!,:NewCapSolar]), EndCapSolar = sum(dfCap[!,:EndCapSolar]),
		StartCapWind = sum(dfCap[!,:StartCapWind]), RetCapWind = sum(dfCap[!,:RetCapWind]),
		NewCapWind = sum(dfCap[!,:NewCapWind]), EndCapWind = sum(dfCap[!,:EndCapWind]),
		StartCapDC = sum(dfCap[!,:StartCapDC]), RetCapDC = sum(dfCap[!,:RetCapDC]),
		NewCapDC = sum(dfCap[!,:NewCapDC]), EndCapDC = sum(dfCap[!,:EndCapDC]),
		StartCapGrid = sum(dfCap[!,:StartCapGrid]), RetCapGrid = sum(dfCap[!,:RetCapGrid]),
		NewCapGrid = sum(dfCap[!,:NewCapGrid]), EndCapGrid = sum(dfCap[!,:EndCapGrid]),
		StartEnergyCap = sum(dfCap[!,:StartEnergyCap]), RetEnergyCap = sum(dfCap[!,:RetEnergyCap]),
		NewEnergyCap = sum(dfCap[!,:NewEnergyCap]), EndEnergyCap = sum(dfCap[!,:EndEnergyCap]),
		StartChargeACCap = sum(dfCap[!,:StartChargeACCap]), RetChargeACCap = sum(dfCap[!,:RetChargeACCap]),
		NewChargeACCap = sum(dfCap[!,:NewChargeACCap]), EndChargeACCap = sum(dfCap[!,:EndChargeACCap]),
		StartChargeDCCap = sum(dfCap[!,:StartChargeDCCap]), RetChargeDCCap = sum(dfCap[!,:RetChargeDCCap]),
		NewChargeDCCap = sum(dfCap[!,:NewChargeDCCap]), EndChargeDCCap = sum(dfCap[!,:EndChargeDCCap]),
		StartDischargeDCCap = sum(dfCap[!,:StartDischargeDCCap]), RetDischargeDCCap = sum(dfCap[!,:RetDischargeDCCap]),
		NewDischargeDCCap = sum(dfCap[!,:NewDischargeDCCap]), EndDischargeDCCap = sum(dfCap[!,:EndDischargeDCCap]),
		StartDischargeACCap = sum(dfCap[!,:StartDischargeACCap]), RetDischargeACCap = sum(dfCap[!,:RetDischargeACCap]),
		NewDischargeACCap = sum(dfCap[!,:NewDischargeACCap]), EndDischargeACCap = sum(dfCap[!,:EndDischargeACCap])
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
	charge_dc = zeros(size(VRE_STOR)[1], T)
	charge_dc = value.(EP[:vP_DC_CHARGE]).data * (setup["ParameterScale"]==1 ? ModelScalingFactor : 1)
	dfCharge_DC.AnnualSum .= charge_dc * inputs["omega"]
	dfCharge_DC = hcat(dfCharge_DC, DataFrame(charge_dc, :auto))
	auxNew_Names=[Symbol("Resource");Symbol("Zone");Symbol("AnnualSum");[Symbol("t$t") for t in 1:T]]
	rename!(dfCharge_DC,auxNew_Names)
	total = DataFrame(["Total" 0 sum(dfCharge_DC[!,:AnnualSum]) fill(0.0, (1,T))], :auto)
	total[:, 4:T+3] .= sum(charge_dc, dims = 1)
	rename!(total,auxNew_Names)
	dfCharge_DC = vcat(dfCharge_DC, total)
	CSV.write(joinpath(path,"vre_stor_dc_charge.csv"), dftranspose(dfCharge_DC, false), writeheader=false)

	# AC charging of battery dataframe
	dfCharge_AC = DataFrame(Resource = inputs["RESOURCES_VRE_STOR"], Zone = dfVRE_STOR[!,:Zone], AnnualSum = Array{Union{Missing,Float32}}(undef, size(VRE_STOR)[1]))
	charge_ac = zeros(size(VRE_STOR)[1], T)
	charge_ac = value.(EP[:vP_AC_CHARGE]).data * (setup["ParameterScale"]==1 ? ModelScalingFactor : 1)
	dfCharge_AC.AnnualSum .= charge_ac * inputs["omega"]
	dfCharge_AC = hcat(dfCharge_AC, DataFrame(charge_ac, :auto))
	auxNew_Names=[Symbol("Resource");Symbol("Zone");Symbol("AnnualSum");[Symbol("t$t") for t in 1:T]]
	rename!(dfCharge_AC,auxNew_Names)
	total = DataFrame(["Total" 0 sum(dfCharge_AC[!,:AnnualSum]) fill(0.0, (1,T))], :auto)
	total[:, 4:T+3] .= sum(charge_ac, dims = 1)
	rename!(total,auxNew_Names)
	dfCharge_AC = vcat(dfCharge_AC, total)
	CSV.write(joinpath(path,"vre_stor_ac_charge.csv"), dftranspose(dfCharge_AC, false), writeheader=false)
end

@doc raw"""
	write_vre_stor_discharge(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing the vre-storage discharging decision variables/expressions.
"""
function write_vre_stor_discharge(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfVRE_STOR = inputs["dfVRE_STOR"]
	VRE_STOR = inputs["VRE_STOR"]
	T = inputs["T"] 

	# DC discharging of battery dataframe
	dfDischarge_DC = DataFrame(Resource = inputs["RESOURCES_VRE_STOR"], Zone = dfVRE_STOR[!,:Zone], AnnualSum = Array{Union{Missing,Float32}}(undef, size(VRE_STOR)[1]))
	power_vre_stor = value.(EP[:vP_DC_DISCHARGE]).data
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
	CSV.write(joinpath(path, "vre_stor_dc_discharge.csv"), dftranspose(dfDischarge_DC, false), writeheader=false)

	# AC discharging of battery dataframe
	dfDischarge_AC = DataFrame(Resource = inputs["RESOURCES_VRE_STOR"], Zone = dfVRE_STOR[!,:Zone], AnnualSum = Array{Union{Missing,Float32}}(undef, size(VRE_STOR)[1]))
	power_vre_stor = value.(EP[:vP_AC_DISCHARGE]).data
	if setup["ParameterScale"] == 1
		power_vre_stor *= ModelScalingFactor
	end
	dfDischarge_AC.AnnualSum .= power_vre_stor * inputs["omega"]
	dfDischarge_AC = hcat(dfDischarge_AC, DataFrame(power_vre_stor, :auto))
	auxNew_Names=[Symbol("Resource");Symbol("Zone");Symbol("AnnualSum");[Symbol("t$t") for t in 1:T]]
	rename!(dfDischarge_AC,auxNew_Names)
	total = DataFrame(["Total" 0 sum(dfDischarge_AC[!,:AnnualSum]) fill(0.0, (1,T))], :auto)
	total[:, 4:T+3] .= sum(power_vre_stor, dims = 1)
	rename!(total,auxNew_Names)
	dfDischarge_AC = vcat(dfDischarge_AC, total)
	CSV.write(joinpath(path, "vre_stor_ac_discharge.csv"), dftranspose(dfDischarge_AC, false), writeheader=false)

	# Wind generation of co-located resource dataframe
	dfVP_VRE_STOR = DataFrame(Resource = inputs["RESOURCES_VRE_STOR"], Zone = dfVRE_STOR[!,:Zone], AnnualSum = Array{Union{Missing,Float32}}(undef, size(VRE_STOR)[1]))
	vre_vre_stor = value.(EP[:vP_WIND]).data 
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
	CSV.write(joinpath(path,"vre_stor_wind_power.csv"), dftranspose(dfVP_VRE_STOR, false), writeheader=false)

	# Solar generation of co-located resource dataframe
	dfVP_VRE_STOR = DataFrame(Resource = inputs["RESOURCES_VRE_STOR"], Zone = dfVRE_STOR[!,:Zone], AnnualSum = Array{Union{Missing,Float32}}(undef, size(VRE_STOR)[1]))
	vre_vre_stor = value.(EP[:vP_SOLAR]).data .* dfVRE_STOR[!,:EtaInverter]
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
	CSV.write(joinpath(path,"vre_stor_solar_power.csv"), dftranspose(dfVP_VRE_STOR, false), writeheader=false)
end
