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

function write_capacity_value(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, dfPower::DataFrame, dfCharge::DataFrame, dfResMar::DataFrame, dfCap::DataFrame, EP::Model)
	dfGen = inputs["dfGen"]
	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
	SEG = inputs["SEG"]  # Number of lines
	L = inputs["L"] # Number of lines
	THERM_ALL = inputs["THERM_ALL"]
	VRE = inputs["VRE"]
	HYDRO_RES = inputs["HYDRO_RES"]
	STOR_ALL = inputs["STOR_ALL"]
	FLEX = inputs["FLEX"]
	MUST_RUN = inputs["MUST_RUN"]
	if setup["ParameterScale"] == 1
		existingplant_position = findall(x -> x >= 1, (value.(EP[:eTotalCap])) * ModelScalingFactor)
	else
		existingplant_position = findall(x -> x >= 1, (value.(EP[:eTotalCap])))
	end
	THERM_ALL_EX = intersect(THERM_ALL, existingplant_position)
	VRE_EX = intersect(VRE, existingplant_position)
	HYDRO_RES_EX = intersect(HYDRO_RES, existingplant_position)
	STOR_ALL_EX = intersect(STOR_ALL, existingplant_position)
	FLEX_EX = intersect(FLEX, existingplant_position)
	MUST_RUN_EX = intersect(MUST_RUN, existingplant_position)
	totalcap = repeat((value.(EP[:eTotalCap])), 1, T)
	
	temp_G = G
	if setup["VreStor"]==1
		dfGen_VRE_STOR = inputs["dfGen_VRE_STOR"]
		VRE_STOR = inputs["VRE_STOR"]
		temp_G = G + VRE_STOR
		VRE_STOR_ = (G+1):temp_G
		grid_index = (VRE_STOR * 2) 

		# create separate dataframe for two resources
		dfCapValue_VRE = DataFrame()
		for i in 1:inputs["NCapacityReserveMargin"]
			dfCapValue_VRE_STOR_ = dfPower[G+1:G+VRE_STOR,:]
			dfCapValue_VRE_STOR_ = select!(dfCapValue_VRE_STOR_, Not(:AnnualSum))
			dfCapValue_VRE_STOR_.Reserve = fill(Symbol("CapRes_$i"), size(dfCapValue_VRE_STOR_, 1))
			for t in 1:T
				if dfResMar[i,t] > 0.0001
					for y in 1:VRE_STOR
						dfCapValue_VRE_STOR_[y,Symbol("t$t")] = ((inputs["pP_Max_VRE_STOR"][y,t]) * dfGen_VRE_STOR[y,Symbol("CapRes_$i")] * dfGen_VRE_STOR[y,:EtaInverter])
					end
				else
					dfCapValue_VRE_STOR_[!,Symbol("t$t")] .= 0
				end
			end
			dfCapValue_VRE = vcat(dfCapValue_VRE, dfCapValue_VRE_STOR_)
		end
		CSV.write(string(path,sep,"CapacityValue_VRE.csv"),dfCapValue_VRE)

		# Create DC charge DataFrame
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
		
		dfDischarge_DC = DataFrame(Resource = inputs["RESOURCES_VRE_STOR"], Zone = dfGen_VRE_STOR[!,:Zone], AnnualSum = Array{Union{Missing,Float32}}(undef, VRE_STOR))
		discharge_dc = zeros(VRE_STOR, T)
		for i in 1:VRE_STOR
			discharge_dc[i,:] = value.(EP[:vDISCHARGE_DC][i,:]) * (setup["ParameterScale"]==1 ? ModelScalingFactor : 1)
			dfDischarge_DC[!,:AnnualSum][i] = sum(inputs["omega"] .* discharge_dc[i,:])
		end

		dfDischarge_DC = hcat(dfDischarge_DC, DataFrame(discharge_dc, :auto))
		auxNew_Names=[Symbol("Resource");Symbol("Zone");Symbol("AnnualSum");[Symbol("t$t") for t in 1:T]]
		rename!(dfDischarge_DC,auxNew_Names)

		total = DataFrame(["Total" 0 sum(dfDischarge_DC[!,:AnnualSum]) fill(0.0, (1,T))], :auto)
		for t in 1:T
			total[:,t+3] .= sum(dfDischarge_DC[:,Symbol("t$t")][1:VRE_STOR])
		end
		rename!(total,auxNew_Names)
		dfDischarge_DC = vcat(dfDischarge_DC, total)
		
		dfCapValue_STOR = DataFrame()
		for i in 1:inputs["NCapacityReserveMargin"]
			dfCapValue_VRE_STOR_ = dfPower[G+1:G+VRE_STOR,:]
			dfCapValue_VRE_STOR_ = select!(dfCapValue_VRE_STOR_, Not(:AnnualSum))
			dfCapValue_VRE_STOR_.Reserve = fill(Symbol("CapRes_$i"), size(dfCapValue_VRE_STOR_, 1))
			for t in 1:T
				if dfResMar[i,t] > 0.0001
					for y in 1:VRE_STOR
						dfCapValue_VRE_STOR_[y,Symbol("t$t")] = ((dfDischarge_DC[y,Symbol("t$t")]-dfCharge_DC[y,Symbol("t$t")]) * dfGen_VRE_STOR[y,:EtaInverter] * dfGen_VRE_STOR[y,Symbol("CapRes_$i")])/dfCap[y+G+VRE_STOR,:EndCap]
					end
				else
					dfCapValue_VRE_STOR_[!,Symbol("t$t")] .= 0
				end
			end
			dfCapValue_STOR = vcat(dfCapValue_STOR, dfCapValue_VRE_STOR_)
		end
		CSV.write(string(path,sep,"CapacityValue_STOR.csv"),dfCapValue_STOR)

		
	end
	
	#calculating capacity value under reserve margin constraint, added by NP on 10/21/2020
	dfCapValue = DataFrame()
	for i in 1:inputs["NCapacityReserveMargin"]
		temp_dfCapValue = DataFrame(Resource = inputs["RESOURCES"], Zone = dfGen[!, :Zone], Reserve = fill(Symbol("CapRes_$i"), G))
		temp_capvalue = zeros(G, T)
		temp_riskyhour = zeros(G, T)
		temp_cap_derate = zeros(G, T)
		if setup["ParameterScale"] == 1
			riskyhour_position = findall(x -> x >= 1, ((dual.(EP[:cCapacityResMargin][i, :])) ./ inputs["omega"] * ModelScalingFactor))
		else
			riskyhour_position = findall(x -> x >= 1, ((dual.(EP[:cCapacityResMargin][i, :])) ./ inputs["omega"]))
		end
		temp_riskyhour[:, riskyhour_position] = ones(Int, G, length(riskyhour_position))
		temp_cap_derate[existingplant_position, :] = repeat(dfGen[existingplant_position, Symbol("CapRes_$i")], 1, T)

		temp_capvalue[THERM_ALL_EX, :] = temp_cap_derate[THERM_ALL_EX, :] .* temp_riskyhour[THERM_ALL_EX, :]
		temp_capvalue[VRE_EX, :] = temp_cap_derate[VRE_EX, :] .* (inputs["pP_Max"][VRE_EX, :]) .* temp_riskyhour[VRE_EX, :]
		temp_capvalue[MUST_RUN_EX, :] = temp_cap_derate[MUST_RUN_EX, :] .* (inputs["pP_Max"][MUST_RUN_EX, :]) .* temp_riskyhour[MUST_RUN_EX, :]
		temp_capvalue[HYDRO_RES_EX, :] = temp_cap_derate[HYDRO_RES_EX, :] .* (value.(EP[:vP][HYDRO_RES_EX, :])) .* temp_riskyhour[HYDRO_RES_EX, :] ./ totalcap[HYDRO_RES_EX, :]
		if !isempty(STOR_ALL_EX)
			temp_capvalue[STOR_ALL_EX, :] = temp_cap_derate[STOR_ALL_EX, :] .* ((value.(EP[:vP][STOR_ALL_EX, :]) - value.(EP[:vCHARGE][STOR_ALL_EX, :]).data)) .* temp_riskyhour[STOR_ALL_EX, :] ./ totalcap[STOR_ALL_EX, :]
		end
		if !isempty(FLEX_EX)
			temp_capvalue[FLEX_EX, :] = temp_cap_derate[FLEX_EX, :] .* ((value.(EP[:vCHARGE_FLEX][FLEX_EX, :]).data - value.(EP[:vP][FLEX_EX, :]))) .* temp_riskyhour[FLEX_EX, :] ./ totalcap[FLEX_EX, :]
		end
		temp_dfCapValue = hcat(temp_dfCapValue, DataFrame(temp_capvalue, :auto))
		auxNew_Names = [Symbol("Resource"); Symbol("Zone"); Symbol("Reserve"); [Symbol("t$t") for t in 1:T]]
		rename!(temp_dfCapValue, auxNew_Names)
		append!(dfCapValue, temp_dfCapValue)
	end
	CSV.write(joinpath(path, "CapacityValue.csv"), dfCapValue)
end
