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
	write_energy_revenue(path::AbstractString, inputs::Dict, setup::Dict, EP::Model, dfPower::DataFrame, dfPrice::DataFrame, dfCharge::DataFrame)

Function for writing energy revenue from the different generation technologies.
"""
function write_energy_revenue(path::AbstractString, inputs::Dict, setup::Dict, EP::Model, dfPower::DataFrame, dfPrice::DataFrame, dfCharge::DataFrame)
	dfGen = inputs["dfGen"]
	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
	# dfEnergyRevenue = DataFrame(Resource = inputs["RESOURCES"], Zone = dfGen[!,:Zone], AnnualSum = Array{Union{Missing,Float32}}(undef, G))
	# the price is already US$/MWh, and dfPower and dfCharge is already in MW, so no scaling is needed
	dfEnergyRevenue = DataFrame(Region = dfGen[!,:region], Resource = inputs["RESOURCES"], Zone = dfGen[!,:Zone], Cluster = dfGen[!,:cluster], AnnualSum = Array{Union{Missing,Float32}}(undef, G), )
	# initiation
	i = 1
	dfEnergyRevenue_ = (DataFrame([[names(dfPower)]; collect.(eachrow(dfPower))], [:column; Symbol.(axes(dfPower, 1))])[4:T+3,2] .*
	DataFrame([[names(dfPrice)]; collect.(eachrow(dfPrice))], [:column; Symbol.(axes(dfPrice, 1))])[2:T+1,dfPower[1,:Zone]+1].*
	inputs["omega"])
	if i in inputs["FLEX"]
		dfEnergyRevenue_ = (DataFrame([[names(dfCharge)]; collect.(eachrow(dfCharge))], [:column; Symbol.(axes(dfCharge, 1))])[4:T+3,2] .*
		DataFrame([[names(dfPrice)]; collect.(eachrow(dfPrice))], [:column; Symbol.(axes(dfPrice, 1))])[2:T+1,dfPower[1,:Zone]+1].*
		inputs["omega"])
	end
	for i in 2:G
		if i in inputs["FLEX"]
			dfEnergyRevenue_1 = (DataFrame([[names(dfCharge)]; collect.(eachrow(dfCharge))], [:column; Symbol.(axes(dfCharge, 1))])[4:T+3,i+1] .*
			DataFrame([[names(dfPrice)]; collect.(eachrow(dfPrice))], [:column; Symbol.(axes(dfPrice, 1))])[2:T+1,dfPower[i,:Zone]+1].*
			inputs["omega"])
		else
			dfEnergyRevenue_1 = (DataFrame([[names(dfPower)]; collect.(eachrow(dfPower))], [:column; Symbol.(axes(dfPower, 1))])[4:T+3,i+1] .*
			DataFrame([[names(dfPrice)]; collect.(eachrow(dfPrice))], [:column; Symbol.(axes(dfPrice, 1))])[2:T+1,dfPower[i,:Zone]+1].*
			inputs["omega"])
		end
		dfEnergyRevenue_ = hcat(dfEnergyRevenue_, dfEnergyRevenue_1)
	end
	dfEnergyRevenue = hcat(dfEnergyRevenue, DataFrame(dfEnergyRevenue_', :auto))
	for i in 1:G
		dfEnergyRevenue[!,:AnnualSum][i] = sum(dfEnergyRevenue[i,6:T+5])
	end
	dfEnergyRevenue_annualonly = dfEnergyRevenue[!,1:5]
	CSV.write(joinpath(path, "EnergyRevenue.csv"), dfEnergyRevenue_annualonly)
	return dfEnergyRevenue
end
#=function write_energy_revenue(path::AbstractString, inputs::Dict, setup::Dict, EP::Model, dfPower::DataFrame, dfPrice::DataFrame, dfCharge::DataFrame)
	dfGen = inputs["dfGen"]
	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
	dfEnergyRevenue = DataFrame(Resource = inputs["RESOURCES"], Zone = dfGen[!,:Zone], AnnualSum = Array{Union{Missing,Float32}}(undef, G))
	# the price is already US$/MWh, and dfPower and dfCharge is already in MW, so no scaling is needed

	# dfEnergyRevenue_ = (DataFrame([[names(dfPower)]; collect.(eachrow(dfPower))], [:column; Symbol.(axes(dfPower, 1))])[4:T+3,2] .*
	# DataFrame([[names(dfPrice)]; collect.(eachrow(dfPrice))], [:column; Symbol.(axes(dfPrice, 1))])[2:T+1,dfPower[1,:][:Zone]+1] .*
	# inputs["omega"])
	# for i in 2:G
	# 	dfEnergyRevenue_1 = (DataFrame([[names(dfPower)]; collect.(eachrow(dfPower))], [:column; Symbol.(axes(dfPower, 1))])[4:T+3,i+1] .*
	# 	DataFrame([[names(dfPrice)]; collect.(eachrow(dfPrice))], [:column; Symbol.(axes(dfPrice, 1))])[2:T+1,dfPower[i,:][:Zone]+1] .*
	# 	inputs["omega"])
	# 	dfEnergyRevenue_ = hcat(dfEnergyRevenue_, dfEnergyRevenue_1)
	# end
	for i in 1:G
		if i in inputs["FLEX"]
			dfEnergyRevenue_1 = (DataFrame([[names(dfCharge)]; collect.(eachrow(dfCharge))], [:column; Symbol.(axes(dfCharge, 1))])[4:T+3,i+1] .*
			DataFrame([[names(dfPrice)]; collect.(eachrow(dfPrice))], [:column; Symbol.(axes(dfPrice, 1))])[2:T+1,dfPower[i,:][:Zone]+1] .*
			inputs["omega"])
		else
			dfEnergyRevenue_1 = (DataFrame([[names(dfPower)]; collect.(eachrow(dfPower))], [:column; Symbol.(axes(dfPower, 1))])[4:T+3,i+1] .*
			DataFrame([[names(dfPrice)]; collect.(eachrow(dfPrice))], [:column; Symbol.(axes(dfPrice, 1))])[2:T+1,dfPower[i,:][:Zone]+1] .*
			inputs["omega"])
		end
		dfEnergyRevenue = hcat(dfEnergyRevenue, convert(DataFrame, dfEnergyRevenue_1'))
	end

	# dfEnergyRevenue = hcat(dfEnergyRevenue, convert(DataFrame, dfEnergyRevenue_'))
	for i in 1:G
		dfEnergyRevenue[!,:AnnualSum][i] = sum(dfEnergyRevenue[i,6:T+5])
	end
	CSV.write(joinpath(path, "EnergyRevenue.csv"), dfEnergyRevenue)
	return dfEnergyRevenue
end
=#
