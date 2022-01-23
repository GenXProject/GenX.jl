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

function write_capacity_value(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    dfGen = inputs["dfGen"]
    G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
    T = inputs["T"]     # Number of time steps (hours)
    SEG = inputs["SEG"]  # Number of lines
    Z = inputs["Z"]     # Number of zonests
    L = inputs["L"] # Number of lines
    THERM_ALL = inputs["THERM_ALL"]
    VRE = inputs["VRE"]
    HYDRO_RES = inputs["HYDRO_RES"]
    STOR_ALL = inputs["STOR_ALL"]
    FLEX = inputs["FLEX"]
    MUST_RUN = inputs["MUST_RUN"]
    #calculating capacity value under reserve margin constraint, added by NP on 10/21/2020; modified by QX on Jan 23, 2022
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
    dfCapValue = DataFrame()
    for i in 1:inputs["NCapacityReserveMargin"]
        temp_dfCapValue = DataFrame(Region = dfGen[!, :region], Resource = inputs["RESOURCES"], Zone = dfGen[!, :Zone], Cluster = dfGen[!, :cluster], Reserve = fill(Symbol("CapRes_$i"), G), AnnualAverage = zeros(G))
        temp_capvalue = zeros(G, T)
        temp_riskyhour = zeros(G, T)
        temp_cap_derate = zeros(G, T)
        if setup["ParameterScale"] == 1
            riskyhour_position = findall(x -> x >= 1, ((dual.(EP[:cCapacityResMargin][i, :])) ./ inputs["omega"] * ModelScalingFactor))
        else
            riskyhour_position = findall(x -> x >= 1, ((dual.(EP[:cCapacityResMargin][i, :])) ./ inputs["omega"]))
        end
        temp_riskyhour[:, riskyhour_position] = repeat(transpose(repeat(1:1, inner = length(riskyhour_position))), G, 1)
        temp_cap_derate[existingplant_position, :] = repeat(dfGen[existingplant_position, Symbol("CapRes_$i")], 1, T)

        temp_capvalue[THERM_ALL_EX, :] = temp_cap_derate[THERM_ALL_EX, :]
        temp_capvalue[VRE_EX, :] = temp_cap_derate[VRE_EX, :] .* (inputs["pP_Max"][VRE_EX, :]) .* temp_riskyhour[VRE_EX, :]
        temp_capvalue[MUST_RUN_EX, :] = temp_cap_derate[MUST_RUN_EX, :] .* (inputs["pP_Max"][MUST_RUN_EX, :]) .* temp_riskyhour[MUST_RUN_EX, :]
        temp_capvalue[HYDRO_RES_EX, :] = temp_cap_derate[HYDRO_RES_EX, :] .* (value.(EP[:vP][HYDRO_RES_EX, :])) .* temp_riskyhour[HYDRO_RES_EX, :] ./ totalcap[HYDRO_RES_EX, :]
        temp_capvalue[STOR_ALL_EX, :] = temp_cap_derate[STOR_ALL_EX, :] .* ((value.(EP[:vP][STOR_ALL_EX, :]) - value.(EP[:vCHARGE][STOR_ALL_EX, :]).data)) .* temp_riskyhour[STOR_ALL_EX, :] ./ totalcap[STOR_ALL_EX, :]
        temp_capvalue[FLEX_EX, :] = temp_cap_derate[FLEX_EX, :] .* ((value.(EP[:vCHARGE_FLEX][FLEX_EX, :]).data - value.(EP[:vP][FLEX_EX, :]))) .* temp_riskyhour[FLEX_EX, :] ./ totalcap[FLEX_EX, :]
        temp_dfCapValue.AnnualAverage .= temp_capvalue * inputs["omega"] / sum(inputs["omega"])
        temp_dfCapValue = hcat(temp_dfCapValue, DataFrame(temp_capvalue, :auto))
        auxNew_Names = [Symbol("Region"); Symbol("Resource"); Symbol("Zone"); Symbol("Cluster"); Symbol("Reserve"); Symbol("AnnualAverage"); [Symbol("t$t") for t in 1:T]]
        rename!(temp_dfCapValue, auxNew_Names)
        # dfCapValue_ = dfPower[1:end-1,:]
        # dfCapValue_ = select!(dfCapValue_, Not(:AnnualSum))
        # if v"1.3" <= VERSION < v"1.4"
        # 	dfCapValue_[!,:Reserve] .= Symbol("CapRes_$i")
        # elseif v"1.4" <= VERSION < v"1.7"
        # 	#dfCapValue_.Reserve = Symbol("CapRes_$i")
        # 	dfCapValue_.Reserve = fill(Symbol("CapRes_$i"), size(dfCapValue_, 1))
        # end
        # for t in 1:T
        # 	if dfResMar[i,t] > 0.0001
        # 		for y in 1:G
        # 			if (dfCap[y, :EndCap] > 0.0001) .& (y in STOR_ALL) # including storage
        # 			    dfCapValue_[y, Symbol("t$t")] = ((dfPower[y, Symbol("t$t")] - dfCharge[y, Symbol("t$t")]) * dfGen[y, Symbol("CapRes_$i")]) / dfCap[y, :EndCap]
        # 			elseif (dfCap[y, :EndCap] > 0.0001) .& (y in HYDRO_RES) # including hydro and VRE
        # 			    dfCapValue_[y, Symbol("t$t")] = ((dfPower[y, Symbol("t$t")]) * dfGen[y, Symbol("CapRes_$i")]) / dfCap[y, :EndCap]
        # 			elseif (dfCap[y, :EndCap] > 0.0001) .& (y in VRE) # including hydro and VRE
        # 			    dfCapValue_[y, Symbol("t$t")] = ((inputs["pP_Max"][y, t]) * dfGen[y, Symbol("CapRes_$i")])
        # 			elseif (dfCap[y, :EndCap] > 0.0001) .& (y in FLEX) # including flexible load
        # 			    dfCapValue_[y, Symbol("t$t")] = ((dfCharge[y, Symbol("t$t")] - dfPower[y, Symbol("t$t")]) * dfGen[y, Symbol("CapRes_$i")]) / dfCap[y, :EndCap]
        # 			elseif (dfCap[y, :EndCap] > 0.0001) .& (y in THERM_ALL) # including thermal
        # 			    dfCapValue_[y, Symbol("t$t")] = dfGen[y, Symbol("CapRes_$i")]
        # 			elseif (dfCap[y, :EndCap] > 0.0001) .& (y in MUST_RUN) # Must run technologies are not considered for reserve margin
        # 			    dfCapValue_[y, Symbol("t$t")] = ((inputs["pP_Max"][y, t]) * dfGen[y, Symbol("CapRes_$i")])
        # 			end
        # 		end
        # 	else
        # 		dfCapValue_[!,Symbol("t$t")] .= 0
        # 	end
        # end
        dfCapValue = vcat(dfCapValue, temp_dfCapValue)
    end
    CSV.write(string(path, sep, "CapacityValue.csv"), dfCapValue)
end
