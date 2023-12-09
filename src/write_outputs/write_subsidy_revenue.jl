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
	write_subsidy_revenue(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for reporting subsidy revenue earned if a generator specified `Min_Cap` is provided in the input file. GenX will print this file only the shadow price can be obtained form the solver. Do not confuse this with the Minimum Capacity Carveout constraint, which is for a subset of generators, and a separate revenue term will be calculated in other files. The unit is \$.
"""
function write_subsidy_revenue(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]
	G = inputs["G"]

	dfSubRevenue = DataFrame(Region = dfGen[!, :region], Resource = inputs["RESOURCES"], Zone = dfGen[!, :Zone], Cluster = dfGen[!, :cluster], R_ID=dfGen[!, :R_ID], SubsidyRevenue = zeros(G))
	MIN_CAP = dfGen[(dfGen[!, :Min_Cap_MW].>0), :R_ID]
	if !isempty(inputs["VRE_STOR"])
		dfVRE_STOR = inputs["dfVRE_STOR"]
		MIN_CAP_SOLAR = dfVRE_STOR[(dfVRE_STOR[!, :Min_Cap_Solar_MW].>0), :R_ID]
		MIN_CAP_WIND = dfVRE_STOR[(dfVRE_STOR[!, :Min_Cap_Wind_MW].>0), :R_ID]
		MIN_CAP_STOR = dfGen[(dfGen[!, :Min_Cap_MWh].>0), :R_ID]
		if !isempty(MIN_CAP_SOLAR)
			dfSubRevenue.SubsidyRevenue[MIN_CAP_SOLAR] .+= (value.(EP[:eTotalCap_SOLAR])[MIN_CAP_SOLAR]) .* (dual.(EP[:cMinCap_Solar][MIN_CAP_SOLAR])).data
		end
		if !isempty(MIN_CAP_WIND)
			dfSubRevenue.SubsidyRevenue[MIN_CAP_WIND] .+= (value.(EP[:eTotalCap_WIND])[MIN_CAP_WIND]) .* (dual.(EP[:cMinCap_Wind][MIN_CAP_WIND])).data
		end
		if !isempty(MIN_CAP_STOR)
			dfSubRevenue.SubsidyRevenue[MIN_CAP_STOR] .+= (value.(EP[:eTotalCap_STOR])[MIN_CAP_STOR]) .* (dual.(EP[:cMinCap_Stor][MIN_CAP_STOR])).data
		end
	end
	dfSubRevenue.SubsidyRevenue[MIN_CAP] .= (value.(EP[:eTotalCap])[MIN_CAP]) .* (dual.(EP[:cMinCap][MIN_CAP])).data

	### calculating tech specific subsidy revenue
	dfRegSubRevenue = DataFrame(Region = dfGen[!, :region], Resource = inputs["RESOURCES"], Zone = dfGen[!, :Zone], Cluster = dfGen[!, :cluster], R_ID=dfGen[!, :R_ID], SubsidyRevenue = zeros(G))
	if (setup["MinCapReq"] >= 1)
		for mincap in 1:inputs["NumberOfMinCapReqs"] # This key only exists if MinCapReq >= 1, so we can't get it at the top outside of this condition.
			MIN_CAP_GEN = dfGen[(dfGen[!, Symbol("MinCapTag_$mincap")].==1), :R_ID]
			dfRegSubRevenue.SubsidyRevenue[MIN_CAP_GEN] .= dfRegSubRevenue.SubsidyRevenue[MIN_CAP_GEN] + (value.(EP[:eTotalCap][MIN_CAP_GEN])) * (dual.(EP[:cZoneMinCapReq][mincap]))
			if !isempty(inputs["VRE_STOR"])
				mincap_solar_sym = Symbol("MinCapTagSolar_$mincap")
				mincap_stor_sym = Symbol("MinCapTagStor_$mincap")
				MIN_CAP_GEN_SOLAR = dfVRE_STOR[(dfVRE_STOR[!, mincap_solar_sym].==1), :R_ID]
				MIN_CAP_GEN_WIND = dfVRE_STOR[(dfVRE_STOR[!, Symbol("MinCapTagWind_$mincap")].==1), :R_ID]
				MIN_CAP_GEN_ASYM_DC_DIS = intersect(inputs["VS_ASYM_DC_DISCHARGE"], dfVRE_STOR[(dfVRE_STOR[!, mincap_stor_sym].==1), :R_ID])
				MIN_CAP_GEN_ASYM_AC_DIS = intersect(inputs["VS_ASYM_AC_DISCHARGE"], dfVRE_STOR[(dfVRE_STOR[!, mincap_stor_sym].==1), :R_ID])
				MIN_CAP_GEN_SYM_DC = intersect(inputs["VS_SYM_DC"], dfVRE_STOR[(dfVRE_STOR[!, mincap_stor_sym].==1), :R_ID])
				MIN_CAP_GEN_SYM_AC = intersect(inputs["VS_SYM_AC"], dfVRE_STOR[(dfVRE_STOR[!, mincap_stor_sym].==1), :R_ID])
				if !isempty(MIN_CAP_GEN_SOLAR)
					dfRegSubRevenue.SubsidyRevenue[MIN_CAP_GEN_SOLAR] .+= (
						(value.(EP[:eTotalCap_SOLAR][MIN_CAP_GEN_SOLAR]).data)
						.* dfVRE_STOR[((dfVRE_STOR[!, mincap_solar_sym].==1)), :EtaInverter]
						* (dual.(EP[:cZoneMinCapReq][mincap]))
					)
				end
				if !isempty(MIN_CAP_GEN_WIND)
					dfRegSubRevenue.SubsidyRevenue[MIN_CAP_GEN_WIND] .+= (
						(value.(EP[:eTotalCap_WIND][MIN_CAP_GEN_WIND]).data)
						* (dual.(EP[:cZoneMinCapReq][mincap]))
					)
				end
				if !isempty(MIN_CAP_GEN_ASYM_DC_DIS)
					MIN_CAP_GEN_ASYM_DC_DIS = intersect(inputs["VS_ASYM_DC_DISCHARGE"], dfVRE_STOR[(dfVRE_STOR[!, mincap_stor_sym].==1), :R_ID])
					dfRegSubRevenue.SubsidyRevenue[MIN_CAP_GEN_ASYM_DC_DIS] .+= (
						(value.(EP[:eTotalCapDischarge_DC][MIN_CAP_GEN_ASYM_DC_DIS].data)
						.* dfVRE_STOR[((dfVRE_STOR[!, mincap_stor_sym].==1) .& (dfVRE_STOR.STOR_DC_DISCHARGE.==2)), :EtaInverter])
						* (dual.(EP[:cZoneMinCapReq][mincap]))
					)
				end
				if !isempty(MIN_CAP_GEN_ASYM_AC_DIS)
					dfRegSubRevenue.SubsidyRevenue[MIN_CAP_GEN_ASYM_AC_DIS] .+= (
						(value.(EP[:eTotalCapDischarge_AC][MIN_CAP_GEN_ASYM_AC_DIS]).data)
						* (dual.(EP[:cZoneMinCapReq][mincap]))
					)
				end		
				if !isempty(MIN_CAP_GEN_SYM_DC)
					dfRegSubRevenue.SubsidyRevenue[MIN_CAP_GEN_SYM_DC] .+= (
						(value.(EP[:eTotalCap_STOR][MIN_CAP_GEN_SYM_DC]).data
						.* dfVRE_STOR[((dfVRE_STOR[!, mincap_stor_sym].==1) .& (dfVRE_STOR.STOR_DC_DISCHARGE.==1)), :Power_to_Energy_DC]
						.* dfVRE_STOR[((dfVRE_STOR[!, mincap_stor_sym].==1) .& (dfVRE_STOR.STOR_DC_DISCHARGE.==1)), :EtaInverter])
						* (dual.(EP[:cZoneMinCapReq][mincap]))
					)
				end
				if !isempty(MIN_CAP_GEN_SYM_AC)
					dfRegSubRevenue.SubsidyRevenue[MIN_CAP_GEN_SYM_AC] .+= (
						(value.(EP[:eTotalCap_STOR][MIN_CAP_GEN_SYM_AC]).data
						.* dfVRE_STOR[((dfVRE_STOR[!, mincap_stor_sym].==1) .& (dfVRE_STOR.STOR_AC_DISCHARGE.==1)), :Power_to_Energy_AC])
						* (dual.(EP[:cZoneMinCapReq][mincap]))
					)
				end
			end
		end
	end

	if setup["ParameterScale"] == 1
		dfSubRevenue.SubsidyRevenue *= ModelScalingFactor^2 #convert from Million US$ to US$
		dfRegSubRevenue.SubsidyRevenue *= ModelScalingFactor^2 #convert from Million US$ to US$
	end

	CSV.write(joinpath(path, "SubsidyRevenue.csv"), dfSubRevenue)
	CSV.write(joinpath(path, "RegSubsidyRevenue.csv"), dfRegSubRevenue)
	return dfSubRevenue, dfRegSubRevenue
end
