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
	write_esr_revenue(path::AbstractString, inputs::Dict, setup::Dict, dfPower::DataFrame, dfESR::DataFrame)

Function for reporting the renewable/clean credit revenue earned by each generator listed in the input file. GenX will print this file only when RPS/CES is modeled and the shadow price can be obtained form the solver. Each row corresponds to a generator, and each column starting from the 6th to the second last is the total revenue earned from each RPS constraint. The revenue is calculated as the total annual generation (if elgible for the corresponding constraint) multiplied by the RPS/CES price. The last column is the total revenue received from all constraint. The unit is \$.
"""
function write_esr_revenue(path::AbstractString, inputs::Dict, setup::Dict, dfPower::DataFrame, dfESR::DataFrame)
	dfGen = inputs["dfGen"]
	dfESRRev = DataFrame(region = dfGen[!,:region], Resource = inputs["RESOURCES"], zone = dfGen[!,:Zone], Cluster = dfGen[!,:cluster], R_ID = dfGen[!,:R_ID])
	G = inputs["G"]
	VRE_STOR = inputs["VRE_STOR"]
	dfVRE_STOR = inputs["dfVRE_STOR"]
	by_rid(rid, sym) = by_rid_df(rid, sym, dfVRE_STOR)
	for i in 1:inputs["nESR"]
		dfESRRev =  hcat(dfESRRev, dfPower[1:G,:AnnualSum] .* dfGen[!,Symbol("ESR_$i")] * dfESR[i,:ESR_Price])
		if !isempty(VRE_STOR)
			dfESRRev[VRE_STOR, :] = sum(EP[:vP_DC][y,t] for t=1:T) .* dfVRE_STOR[!, :EtaInverter] .* dfVRE_STOR[!,Symbol("ESR_$i")] * dfESR[i,:ESR_Price]
		end
		# dfpower is in MWh already, price is in $/MWh already, no need to scale
		# if setup["ParameterScale"] == 1
		# 	#dfESRRev[!,:x1] = dfESRRev[!,:x1] * (1e+3) # MillionUS$ to US$
		# 	dfESRRev[!,:x1] = dfESRRev[!,:x1] * ModelScalingFactor # MillionUS$ to US$  # Is this right? -Jack 4/29/2021
		# end
		rename!(dfESRRev, Dict(:x1 => Symbol("ESR_$i")))
	end
	dfESRRev.AnnualSum = sum(eachcol(dfESRRev[:,6:inputs["nESR"]+5]))
	CSV.write(joinpath(path, "ESR_Revenue.csv"), dfESRRev)
	return dfESRRev
end
