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



function write_core_behaviors(EP::Model, inputs::Dict, symbol::Symbol, filename::AbstractString)
	dfTS = inputs["dfTS"]
	T = inputs["T"]

	df = DataFrame(Resource = dfTS.Resource, Zone = dfTS.Zone)
	THERMAL_STORAGE = dfTS.R_ID
	event = value.(EP[symbol][THERMAL_STORAGE,:]).data
	df.Sum = vec(sum(event, dims=2))

	df = hcat(df, DataFrame(event, :auto))
	auxNew_Names=[:Resource; :Zone; :Sum; [Symbol("t$t") for t in 1:T]]
	rename!(df,auxNew_Names)
	total = DataFrame(["Total" 0 sum(df[!,:Sum]) zeros(1,T)], :auto)
	total[:, 4:T+3] .= sum(event, dims=1)
	rename!(total,auxNew_Names)
	df = vcat(df, total)

	CSV.write(filename, dftranspose(df, false), writeheader=false)
	return df
end

function write_scaled_values(EP::Model, inputs::Dict, symbol::Symbol, filename::AbstractString, msf)
	dfTS = inputs["dfTS"]
	T = inputs["T"]

	df = DataFrame(Resource = dfTS.Resource, Zone=dfTS.Zone)
	THERMAL_STORAGE = dfTS.R_ID
	quantity = value.(EP[symbol][THERMAL_STORAGE,:]).data * msf
	df.AnnualSum = quantity * inputs["omega"]

	df = hcat(df, DataFrame(quantity, :auto))
	auxNew_Names=[:Resource; :Zone; :AnnualSum; [Symbol("t$t") for t in 1:T]]
	rename!(df,auxNew_Names)
	total = DataFrame(["Total" 0 sum(df.AnnualSum) zeros(1,T)], :auto)
	total[:, 4:T+3] .= sum(quantity, dims=1)
	rename!(total,auxNew_Names)
	df = vcat(df, total)
	CSV.write(filename, dftranspose(df, false), writeheader=false)

	return df
end

function write_thermal_storage_system_max_dual(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfTS = inputs["dfTS"]

	FIRST_ROW = 1
	if dfTS[FIRST_ROW, :System_Max_Cap_MWe_net] >= 0
		val = -1*dual.(EP[:cCSystemTot])
		val *= setup["ParameterScale"] == 1 ? ModelScalingFactor : 1.0
		df = DataFrame(:System_Max_Cap_MW_th_dual => val)
		filename = joinpath(path, "System_Max_TS_Cap_dual.csv")
		CSV.write(filename, dftranspose(df, false), writeheader=false)
	end
end


@doc raw"""
	write_capacity(path::AbstractString, inputs::Dict, setup::Dict, EP::Model))

Function for writing the diferent capacities for the different generation technologies (starting capacities or, existing capacities, retired capacities, and new-built capacities).
"""
function write_thermal_storage(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	# Capacity decisions
	dfGen = inputs["dfGen"]
	dfTS = inputs["dfTS"]
	T = inputs["T"]


	TSResources = dfTS[!,:Resource]
	TSG = length(TSResources)
	corecappower = zeros(TSG)
	for i in 1:TSG
		corecappower[i] = first(value.(EP[:vCCAP][dfTS[i,:R_ID]]))
	end

	corecapenergy = zeros(TSG)
	for i in 1:TSG
		corecapenergy[i] = first(value.(EP[:vTSCAP][dfTS[i,:R_ID]]))
	end

	dfCoreCap = DataFrame(
		Resource = TSResources, Zone = dfTS[!,:Zone],
		CorePowerCap = corecappower[:],
		TSEnergyCap = corecapenergy[:]
	)

	# set a single scalar to avoid future branching
	msf = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

	dfCoreCap.CorePowerCap = dfCoreCap.CorePowerCap * msf
	dfCoreCap.TSEnergyCap = dfCoreCap.TSEnergyCap * msf
	CSV.write(joinpath(path,"TS_capacity.csv"), dfCoreCap)

	### CORE POWER TIME SERIES ###
	dfCorePwr = write_scaled_values(EP, inputs, :vCP, joinpath(path, "TSCorePwr.csv"), msf)

	### THERMAL SOC TIME SERIES ###
	dfTSOC = write_scaled_values(EP, inputs, :vTS, joinpath(path, "TS_SOC.csv"), msf)

	### RECIRCULATING POWER TIME SERIES ###
	dfRecirc = write_scaled_values(EP, inputs, :eTotalRecircFus, joinpath(path, "TS_Recirc.csv"), msf)

	### CORE STARTS, SHUTS, COMMITS, and MAINTENANCE TIMESERIES ###
	dfFStart = write_core_behaviors(EP, inputs, :vFSTART, joinpath(path, "f_start.csv"))
	dfFShut = write_core_behaviors(EP, inputs, :vFSHUT, joinpath(path, "f_shut.csv"))
	dfFCommit = write_core_behaviors(EP, inputs, :vFCOMMIT, joinpath(path, "f_commit.csv"))

	if setup["OperationWrapping"] == 0 && !isempty(get_maintenance(inputs))
		dfMaint = write_core_behaviors(EP, inputs, :vFMDOWN, joinpath(path, "f_maint.csv"))
		dfMShut = write_core_behaviors(EP, inputs, :vFMSHUT, joinpath(path, "f_maintshut.csv"))
	end

	# Write dual values of certain constraints
	write_thermal_storage_system_max_dual(path, inputs, setup, EP)

	return dfCoreCap, dfCorePwr, dfTSOC, dfFStart, dfFShut, dfFCommit
end
