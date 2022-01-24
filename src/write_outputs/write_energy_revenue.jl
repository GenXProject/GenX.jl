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
	write_energy_revenue(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model, dfPower::DataFrame, dfPrice::DataFrame, dfCharge::DataFrame)

Function for writing energy revenue from the different generation technologies.
"""
function write_energy_revenue(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    dfGen = inputs["dfGen"]
    G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
    T = inputs["T"]     # Number of time steps (hours)
    FLEX = inputs["FLEX"]
    NONFLEX = setdiff(G, FLEX)
    dfEnergyRevenue = DataFrame(Region = dfGen[!, :region], Resource = inputs["RESOURCES"], Zone = dfGen[!, :Zone], Cluster = dfGen[!, :cluster], AnnualSum = Array{Union{Missing,Float64}}(undef, G),)
    energyrevenue = zeros(G, T)
    energyrevenue[NONFLEX, :] = value.(EP[:vP][NONFLEX, :]) .* transpose(dual.(EP[:cPowerBalance]) ./ inputs["omega"])[dfGen[NONFLEX, :Zone], :]
    if !isempty(FLEX)
        energyrevenue[FLEX, :] = value.(EP[:vCHARGE_FLEX][FLEX, :]) .* transpose(dual.(EP[:cPowerBalance]) ./ inputs["omega"])[dfGen[FLEX, :Zone], :]
    end
    if setup["ParameterScale"] == 1
        energyrevenue = energyrevenue * (ModelScalingFactor^2)
    end
    dfEnergyRevenue.AnnualSum .= energyrevenue * inputs["omega"]
    dfEnergyRevenue = hcat(dfEnergyRevenue, DataFrame(energyrevenue, :auto))
    auxNew_Names = [Symbol("Region"); Symbol("Resource"); Symbol("Zone"); Symbol("Cluster"); Symbol("AnnualSum"); [Symbol("t$t") for t in 1:T]]
    rename!(dfEnergyRevenue, auxNew_Names)
    # the price is already US$/MWh, and dfPower and dfCharge is already in MW, so no scaling is needed
    # initiation
    # i = 1
    # dfEnergyRevenue_ = (DataFrame([[names(dfPower)]; collect.(eachrow(dfPower))], [:column; Symbol.(axes(dfPower, 1))])[4:T+3, 2] .*
    #                     DataFrame([[names(dfPrice)]; collect.(eachrow(dfPrice))], [:column; Symbol.(axes(dfPrice, 1))])[2:T+1, dfPower[1, :][:Zone]+1] .*
    #                     inputs["omega"])
    # if i in inputs["FLEX"]
    #     dfEnergyRevenue_ = (DataFrame([[names(dfCharge)]; collect.(eachrow(dfCharge))], [:column; Symbol.(axes(dfCharge, 1))])[4:T+3, 2] .*
    #                         DataFrame([[names(dfPrice)]; collect.(eachrow(dfPrice))], [:column; Symbol.(axes(dfPrice, 1))])[2:T+1, dfPower[1, :][:Zone]+1] .*
    #                         inputs["omega"])
    # end
    # for i in 2:G
    #     if i in inputs["FLEX"]
    #         dfEnergyRevenue_1 = (DataFrame([[names(dfCharge)]; collect.(eachrow(dfCharge))], [:column; Symbol.(axes(dfCharge, 1))])[4:T+3, i+1] .*
    #                              DataFrame([[names(dfPrice)]; collect.(eachrow(dfPrice))], [:column; Symbol.(axes(dfPrice, 1))])[2:T+1, dfPower[i, :][:Zone]+1] .*
    #                              inputs["omega"])
    #     else
    #         dfEnergyRevenue_1 = (DataFrame([[names(dfPower)]; collect.(eachrow(dfPower))], [:column; Symbol.(axes(dfPower, 1))])[4:T+3, i+1] .*
    #                              DataFrame([[names(dfPrice)]; collect.(eachrow(dfPrice))], [:column; Symbol.(axes(dfPrice, 1))])[2:T+1, dfPower[i, :][:Zone]+1] .*
    #                              inputs["omega"])
    #     end
    #     dfEnergyRevenue_ = hcat(dfEnergyRevenue_, dfEnergyRevenue_1)
    # end
    # dfEnergyRevenue = hcat(dfEnergyRevenue, DataFrame(dfEnergyRevenue_', :auto))
    # for i in 1:G
    #     dfEnergyRevenue[!, :AnnualSum][i] = sum(dfEnergyRevenue[i, 6:T+5])
    # end
    # dfEnergyRevenue_annualonly = dfEnergyRevenue[!, 1:5]
    CSV.write(string(path, sep, "EnergyRevenue.csv"), dftranspose(dfEnergyRevenue, false), writeheader = false)
    return dfEnergyRevenue
end
