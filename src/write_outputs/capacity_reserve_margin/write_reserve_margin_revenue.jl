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
	write_reserve_margin_revenue(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, dfPower::DataFrame, dfCharge::DataFrame, dfResMar::DataFrame, dfCap::DataFrame)

Function for reporting the capacity revenue earned by each generator listed in the input file. GenX will print this file only when capacity reserve margin is modeled and the shadow price can be obtained form the solver. Each row corresponds to a generator, and each column starting from the 6th to the second last is the total revenue from each capacity reserve margin constraint. The revenue is calculated as the capacity contribution of each time steps multiplied by the shadow price, and then the sum is taken over all modeled time steps. The last column is the total revenue received from all capacity reserve margin constraints.  As a reminder, GenX models the capacity reserve margin (aka capacity market) at the time-dependent level, and each constraint either stands for an overall market or a locality constraint.
"""
function write_reserve_margin_revenue(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)
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
    ### calculating capacity reserve revenue

    dfResRevenue = DataFrame(Region = dfGen[!, :region], Resource = inputs["RESOURCES"], Zone = dfGen[!, :Zone], Cluster = dfGen[!, :cluster], AnnualSum = zeros(G))
    for i in 1:inputs["NCapacityReserveMargin"]
        tempresrev = zeros(G)
        tempresrev[THERM_ALL] = dfGen[THERM_ALL, Symbol("CapRes_$i")] .* (value.(EP[:eTotalCap][THERM_ALL])) * sum(dual.(EP[:cCapacityResMargin][i, :]).data)
        tempresrev[VRE] = dfGen[VRE, Symbol("CapRes_$i")] .* (value.(EP[:eTotalCap][VRE])) .* (inputs["pP_Max"][VRE, :] * transpose(dual.(EP[:cCapacityResMargin][i, :]).data))
        tempresrev[MUST_RUN] = dfGen[MUST_RUN, Symbol("CapRes_$i")] .* (value.(EP[:eTotalCap][MUST_RUN])) .* (inputs["pP_Max"][MUST_RUN, :] * transpose(dual.(EP[:cCapacityResMargin][i, :]).data))
        tempresrev[HYDRO_RES] = dfGen[HYDRO_RES, Symbol("CapRes_$i")] .* (value.(EP[:vP][HYDRO_RES, :]) * transpose(dual.(EP[:cCapacityResMargin][i, :]).data))
        tempresrev[STOR_ALL] = dfGen[STOR_ALL, Symbol("CapRes_$i")] .* ((value.(EP[:vP][STOR_ALL, :]).data - value.(EP[:vCHARGE][STOR_ALL, :]).data) * transpose(dual.(EP[:cCapacityResMargin][i, :]).data))
        tempresrev[FLEX] = dfGen[FLEX, Symbol("CapRes_$i")] .* ((value.(EP[:vCHARGE_FLEX][FLEX, :]).data - value.(EP[:vP][FLEX, :]).data) * transpose(dual.(EP[:cCapacityResMargin][i, :]).data))
        if setup["ParameterScale"] == 1
            tempresrev = tempresrev * (ModelScalingFactor^2)
        end
        # # transpose(dual.(EP[:cCapacityResMargin])) ./ inputs["omega"]
        # # initiate the process by assuming everything is thermal
        # dfResRevenue = hcat(dfResRevenue, round.(Int, dfCap[1:end-1, :EndCap] .* dfGen[!, Symbol("CapRes_$i")] .* sum(dfResMar[i, :])))
        # for y in 1:G
        #     if (y in STOR_ALL)
        #         dfResRevenue[y, :x1] = round.(Int, sum(
        #             (DataFrame([[names(dfPower)]; collect.(eachrow(dfPower))], [:column; Symbol.(axes(dfPower, 1))])[4:T+3, y+1] .-
        #              DataFrame([[names(dfPower)]; collect.(eachrow(dfCharge))], [:column; Symbol.(axes(dfPower, 1))])[4:T+3, y+1]) .*
        #             DataFrame([[names(dfResMar)]; collect.(eachrow(dfResMar))], [:column; Symbol.(axes(dfResMar, 1))])[!, i+1] .* dfGen[y, Symbol("CapRes_$i")]))
        #     elseif (y in HYDRO_RES)
        #         dfResRevenue[y, :x1] = round.(Int, sum((DataFrame([[names(dfPower)]; collect.(eachrow(dfPower))], [:column; Symbol.(axes(dfPower, 1))])[4:T+3, y+1]) .*
        #                                                DataFrame([[names(dfResMar)]; collect.(eachrow(dfResMar))], [:column; Symbol.(axes(dfResMar, 1))])[!, i+1] .* dfGen[y, Symbol("CapRes_$i")]))
        #     elseif (y in VRE)
        #         dfResRevenue[y, :x1] = round.(Int, sum(dfCap[y, :EndCap] .* inputs["pP_Max"][y, :] .*
        #                                                DataFrame([[names(dfResMar)]; collect.(eachrow(dfResMar))], [:column; Symbol.(axes(dfResMar, 1))])[!, i+1] .* dfGen[y, Symbol("CapRes_$i")]))
        #     elseif (y in FLEX)
        #         dfResRevenue[y, :x1] = round.(Int, sum(
        #             (DataFrame([[names(dfPower)]; collect.(eachrow(dfCharge))], [:column; Symbol.(axes(dfPower, 1))])[4:T+3, y+1] .-
        #              DataFrame([[names(dfPower)]; collect.(eachrow(dfPower))], [:column; Symbol.(axes(dfPower, 1))])[4:T+3, y+1]) .*
        #             DataFrame([[names(dfResMar)]; collect.(eachrow(dfResMar))], [:column; Symbol.(axes(dfResMar, 1))])[!, i+1] .* dfGen[y, Symbol("CapRes_$i")]))
        #     end
        # end
        # the capacity and power is in MW already, no need to scale
        # if setup["ParameterScale"] == 1
        # 	dfResRevenue[!,:x1] = dfResRevenue[!,:x1] * ModelScalingFactor #(1e+3) # This is because although the unit of price is US$/MWh, the capacity or generation is in GW
        # end
        dfResRevenue.AnnualSum .= dfResRevenue.AnnualSum + tempresrev
        dfResRevenue = hcat(dfResRevenue, DataFrame(Symbol("CapRes_$i") = tempresrev))
        # rename!(dfResRevenue, Dict(:x1 => Symbol("CapRes_$i")))
    end
    # dfResRevenue.AnnualSum = sum(eachcol(dfResRevenue[:,6:inputs["NCapacityReserveMargin"]+5]))


    CSV.write(string(path, sep, "ReserveMarginRevenue.csv"), dfResRevenue)
    return dfResRevenue
end
