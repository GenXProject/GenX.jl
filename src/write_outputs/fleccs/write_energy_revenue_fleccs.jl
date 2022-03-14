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
	write_energy_revenue(path::AbstractString, inputs::Dict, setup::Dict, EP::Model, dfPower_FLECCS::DataFrame, dfPrice::DataFrame, dfCharge::DataFrame)

Function for writing energy revenue from the different generation technologies.
"""
function write_energy_revenue_fleccs(path::AbstractString, inputs::Dict, setup::Dict, EP::Model, dfPower_FLECCS::DataFrame, dfPrice::DataFrame)
	
	dfGen_ccs = inputs["dfGen_ccs"]
	T = inputs["T"]     # Number of time steps (hours)
	# fleccs generators
	FLECCS_ALL = inputs["FLECCS_ALL"]
	G_F = inputs["G_F"]
	N_F = inputs["N_F"]
	N = length(N_F)

	i = inputs["BOP_id"]
	# dfEnergyRevenue = DataFrame(Resource = inputs["RESOURCES"], Zone = dfGen_ccs[!,:Zone], AnnualSum = Array{Union{Missing,Float32}}(undef, G))
	# the price is already US$/MWh, and dfPower_FLECCS and dfCharge is already in MW, so no scaling is needed
	dfEnergyRevenue = DataFrame( Resource = dfGen_ccs[!,"Resource"][i], Zone = dfGen_ccs[!,:Zone][i], AnnualSum = Array{Union{Missing,Float32}}(undef, G_F), )
	# initiation
	dfEnergyRevenue_FLECCS1 = (DataFrame([[names(dfPower_FLECCS)]; collect.(eachrow(dfPower_FLECCS))], [:column; Symbol.(axes(dfPower_FLECCS, 1))])[4:T+3,i+1] .*
	DataFrame([[names(dfPrice)]; collect.(eachrow(dfPrice))], [:column; Symbol.(axes(dfPrice, 1))])[2:T+1,dfPower_FLECCS[i,:][:Zone]+1].*
	inputs["omega"])
	dfEnergyRevenue_FLECCS = hcat(dfEnergyRevenue, DataFrame(dfEnergyRevenue_FLECCS1', :auto))
	dfEnergyRevenue_FLECCS[!,:AnnualSum][1] = sum(dfEnergyRevenue_FLECCS1)


	if G_F > 1
		# right now we only evaluate fleccs technologies in a single zone so we will not use the following code.. will come back later
		i = inputs["BOP_id"]
		# dfEnergyRevenue = DataFrame(Resource = inputs["RESOURCES"], Zone = dfGen_ccs[!,:Zone], AnnualSum = Array{Union{Missing,Float32}}(undef, G))
		# the price is already US$/MWh, and dfPower_FLECCS and dfCharge is already in MW, so no scaling is needed
		dfEnergyRevenue = DataFrame( Resource = dfGen_ccs[!,"Resource"][i], Zone = dfGen_ccs[!,:Zone][i], AnnualSum = Array{Union{Missing,Float32}}(undef, G_F), )
		# initiation
		dfEnergyRevenue_FLECCS1 = (DataFrame([[names(dfPower_FLECCS)]; collect.(eachrow(dfPower_FLECCS))], [:column; Symbol.(axes(dfPower_FLECCS, 1))])[4:T+3,i+1] .*
		DataFrame([[names(dfPrice)]; collect.(eachrow(dfPrice))], [:column; Symbol.(axes(dfPrice, 1))])[2:T+1,dfPower_FLECCS[i,:][:Zone]+1].*
		inputs["omega"])
		dfEnergyRevenue_FLECCS = hcat(dfEnergyRevenue, DataFrame(dfEnergyRevenue_FLECCS1', :auto))
		dfEnergyRevenue_FLECCS[!,:AnnualSum][1] = sum(dfEnergyRevenue_FLECCS1)
	

	end


	dfEnergyRevenue_FLECCS_annualonly = dfEnergyRevenue_FLECCS[!,1:3]
	CSV.write(joinpath(path, "EnergyRevenue_FLECCS.csv"), dfEnergyRevenue_FLECCS_annualonly)
	return dfEnergyRevenue_FLECCS
end
