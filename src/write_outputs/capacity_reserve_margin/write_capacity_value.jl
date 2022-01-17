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
	Z = inputs["Z"]     # Number of zonests
	L = inputs["L"] # Number of lines
	THERM_ALL = inputs["THERM_ALL"]
	# VRE_HYDRO_RES = union(inputs["HYDRO_RES"],inputs["VRE"])
	VRE = inputs["VRE"]
	HYDRO_RES = inputs["HYDRO_RES"]
	STOR_ALL = inputs["STOR_ALL"]
	FLEX = inputs["FLEX"]
	MUST_RUN = inputs["MUST_RUN"]
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
		dfCapValue_ = dfPower[1:end-1,:]
		dfCapValue_ = select!(dfCapValue_, Not(:AnnualSum))
		if v"1.3" <= VERSION < v"1.4"
			dfCapValue_[!,:Reserve] .= Symbol("CapRes_$i")
		elseif v"1.4" <= VERSION < v"1.7"
			#dfCapValue_.Reserve = Symbol("CapRes_$i")
			dfCapValue_.Reserve = fill(Symbol("CapRes_$i"), size(dfCapValue_, 1))
		end
		for t in 1:T
			if dfResMar[i,t] > 0.0001
				for y in 1:temp_G
					if (dfCap[y,:EndCap] > 0.0001) .& (y in STOR_ALL) # including storage
						dfCapValue_[y,Symbol("t$t")] = ((dfPower[y,Symbol("t$t")]-dfCharge[y,Symbol("t$t")]) * dfGen[y,Symbol("CapRes_$i")])/dfCap[y,:EndCap]
					elseif (dfCap[y,:EndCap] > 0.0001) .& (y in HYDRO_RES) # including hydro and VRE
						dfCapValue_[y,Symbol("t$t")] = ((dfPower[y,Symbol("t$t")]) * dfGen[y,Symbol("CapRes_$i")])/dfCap[y,:EndCap]
					elseif (dfCap[y,:EndCap] > 0.0001) .& (y in VRE) # including hydro and VRE
						dfCapValue_[y,Symbol("t$t")] = ((inputs["pP_Max"][y,t]) * dfGen[y,Symbol("CapRes_$i")])
					elseif (dfCap[y,:EndCap] > 0.0001) .& (y in FLEX) # including flexible load
						dfCapValue_[y,Symbol("t$t")] = ((dfCharge[y,Symbol("t$t")] - dfPower[y,Symbol("t$t")]) * dfGen[y,Symbol("CapRes_$i")])/dfCap[y,:EndCap]
					elseif (dfCap[y,:EndCap] > 0.0001) .& (y in THERM_ALL) # including thermal
						dfCapValue_[y,Symbol("t$t")] = dfGen[y,Symbol("CapRes_$i")]
					elseif (dfCap[y,:EndCap] > 0.0001) .& (y in MUST_RUN) # Must run technologies are not considered for reserve margin
						dfCapValue_[y,Symbol("t$t")] = dfGen[y,Symbol("CapRes_$i")]
					elseif (dfCap[y,:EndCap] > 0.0001) .& (y in VRE_STOR_) # getting grid capacity for dividing capacity by an amount
						dfCapValue_[y,Symbol("t$t")] = ((dfPower[y,Symbol("t$t")]-dfCharge[y,Symbol("t$t")]) * dfGen_VRE_STOR[y-G,Symbol("CapRes_$i")])/dfCap[y+grid_index,:EndCap]
					end
				end
			else
				dfCapValue_[!,Symbol("t$t")] .= 0
			end
		end
		dfCapValue = vcat(dfCapValue, dfCapValue_)
	end
	CSV.write(string(path,sep,"CapacityValue.csv"),dfCapValue)
end
