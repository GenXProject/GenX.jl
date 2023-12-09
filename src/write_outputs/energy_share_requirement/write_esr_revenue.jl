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
	write_esr_revenue(path::AbstractString, inputs::Dict, setup::Dict, dfPower::DataFrame, dfESR::DataFrame, EP::Model)

Function for reporting the renewable/clean credit revenue earned by each generator listed in the input file. GenX will print this file only when RPS/CES is modeled and the shadow price can be obtained form the solver. Each row corresponds to a generator, and each column starting from the 6th to the second last is the total revenue earned from each RPS constraint. The revenue is calculated as the total annual generation (if elgible for the corresponding constraint) multiplied by the RPS/CES price. The last column is the total revenue received from all constraint. The unit is \$.
"""
function write_esr_revenue(path::AbstractString, inputs::Dict, setup::Dict, dfPower::DataFrame, dfESR::DataFrame, EP::Model)
	dfGen = inputs["dfGen"]
	dfESRRev = DataFrame(region = dfGen[!,:region], Resource = inputs["RESOURCES"], zone = dfGen[!,:Zone], Cluster = dfGen[!,:cluster], R_ID = dfGen[!,:R_ID])
	G = inputs["G"]
	nESR = inputs["nESR"]
	weight = inputs["omega"]
	VRE_STOR = inputs["VRE_STOR"]
	dfVRE_STOR = inputs["dfVRE_STOR"]
	if !isempty(VRE_STOR)
		SOLAR = inputs["VS_SOLAR"]
		WIND = inputs["VS_WIND"]
		SOLAR_ONLY = setdiff(SOLAR, WIND)
		WIND_ONLY = setdiff(WIND, SOLAR)
		SOLAR_WIND = intersect(SOLAR, WIND)
	end

	by_rid(rid, sym) = by_rid_df(rid, sym, dfVRE_STOR)
	for i in 1:nESR
		esr_col = Symbol("ESR_$i")
		price = dfESR[i, :ESR_Price]
		derated_annual_net_generation = dfPower[1:G,:AnnualSum] .* dfGen[!,esr_col]
		revenue = derated_annual_net_generation * price
		dfESRRev[!, esr_col] =  revenue

		if !isempty(VRE_STOR)
			esr_vrestor_col = Symbol("ESRVreStor_$i")
			if !isempty(SOLAR_ONLY)
				solar_resources = ((dfVRE_STOR.WIND.==0) .& (dfVRE_STOR.SOLAR.!=0))
				dfESRRev[SOLAR, esr_col] = (
					value.(EP[:vP_SOLAR][SOLAR, :]).data
					.* dfVRE_STOR[solar_resources, :EtaInverter] * weight
				) .* dfVRE_STOR[solar_resources,esr_vrestor_col] * price
			end
			if !isempty(WIND_ONLY)
				wind_resources = ((dfVRE_STOR.WIND.!=0) .& (dfVRE_STOR.SOLAR.==0))
				dfESRRev[WIND, esr_col] = (
					value.(EP[:vP_WIND][WIND, :]).data
					* weight
				) .* dfVRE_STOR[wind_resources,esr_vrestor_col] * price
			end
			if !isempty(SOLAR_WIND)
				solar_and_wind_resources = ((dfVRE_STOR.WIND.!=0) .& (dfVRE_STOR.SOLAR.!=0))
				dfESRRev[SOLAR_WIND, esr_col] = (
					(
						(value.(EP[:vP_WIND][SOLAR_WIND, :]).data * weight)
						.* dfVRE_STOR[solar_and_wind_resources,esr_vrestor_col] * price
					) + (
						value.(EP[:vP_SOLAR][SOLAR_WIND, :]).data
						.* dfVRE_STOR[solar_and_wind_resources, :EtaInverter]
						* weight
					) .* dfVRE_STOR[solar_and_wind_resources,esr_vrestor_col] * price
				)
			end
		end
	end
	dfESRRev.Total = sum(eachcol(dfESRRev[:, 6:nESR + 5]))
	CSV.write(joinpath(path, "ESR_Revenue.csv"), dfESRRev)
	return dfESRRev
end

