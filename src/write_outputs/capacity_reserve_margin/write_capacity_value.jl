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

function write_capacity_value(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, dfPower::DataFrame, dfCharge::DataFrame, dfResMar::DataFrame, dfCap::DataFrame)
	dfGen = inputs["dfGen"]
	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
	SEG = inputs["SEG"]  # Number of lines
	Z = inputs["Z"]     # Number of zonests
	L = inputs["L"] # Number of lines
	THERM_ALL = inputs["THERM_ALL"]
	VRE_HYDRO_RES = union(inputs["HYDRO_RES"],inputs["VRE"])
	STOR_ALL = inputs["STOR_ALL"]
	FLEX = inputs["FLEX"]
	#calculating capacity value under reserve margin constraint, added by NP on 10/21/2020
	dfCapValue = DataFrame()
	for i in 1:inputs["NCapacityReserveMargin"]
		dfCapValue_ = dfPower[1:end-1,:]
		dfCapValue_ = select!(dfCapValue_, Not(:AnnualSum))
		dfCapValue_[!,:Reserve] .= Symbol("CapRes_$i")
		for t in 1:T
			if dfResMar[i,t] > 0.0001
				for y in 1:G
					if (dfCap[y,:EndCap] > 0.0001) .& (y in STOR_ALL) # including storage
						dfCapValue_[y,Symbol("t$t")] = ((dfPower[y,Symbol("t$t")]-dfCharge[y,Symbol("t$t")]) * dfGen[y,Symbol("CapRes_$i")])/dfCap[y,:EndCap]
					elseif (dfCap[y,:EndCap] > 0.0001) .& (y in VRE_HYDRO_RES) # including hydro and VRE
						dfCapValue_[y,Symbol("t$t")] = ((dfPower[y,Symbol("t$t")]) * dfGen[y,Symbol("CapRes_$i")])/dfCap[y,:EndCap]
					elseif (dfCap[y,:EndCap] > 0.0001) .& (y in FLEX) # including flexible load
						dfCapValue_[y,Symbol("t$t")] = ((dfCharge[y,Symbol("t$t")] - dfPower[y,Symbol("t$t")]) * dfGen[y,Symbol("CapRes_$i")])/dfCap[y,:EndCap]
					elseif (dfCap[y,:EndCap] > 0.0001) .& (y in THERM_ALL) # including thermal
						dfCapValue_[y,Symbol("t$t")] = dfGen[y,Symbol("CapRes_$i")]
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
