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

function write_esr_revenue(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, dfPower::DataFrame, dfESR::DataFrame)
	dfGen = inputs["dfGen"]
	dfESRRev = DataFrame(region = dfGen[!,:region], Resource = inputs["RESOURCES"], zone = dfGen[!,:Zone], Cluster = dfGen[!,:cluster], R_ID = dfGen[!,:R_ID])

	for i in 1:inputs["nESR"]
		dfESRRev =  hcat(dfESRRev, dfPower[1:end-1,:AnnualSum] .* dfGen[!,Symbol("ESR_$i")] * dfESR[i,:ESR_Price])
		# dfpower is in MWh already, price is in $/MWh already, no need to scale
		# if setup["ParameterScale"] == 1
		# 	#dfESRRev[!,:x1] = dfESRRev[!,:x1] * (1e+3) # MillionUS$ to US$
		# 	dfESRRev[!,:x1] = dfESRRev[!,:x1] * ModelScalingFactor # MillionUS$ to US$  # Is this right? -Jack 4/29/2021
		# end
		rename!(dfESRRev, Dict(:x1 => Symbol("ESR_$i")))
	end
	dfESRRev.AnnualSum = sum(eachcol(dfESRRev[:,6:inputs["nESR"]+5]))
	CSV.write(string(path,sep,"ESR_Revenue.csv"), dfESRRev)
	return dfESRRev
end
