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
	write_reserve_margin_revenue_fleccs(path::AbstractString, inputs::Dict, setup::Dict, dfPower::DataFrame, dfCharge::DataFrame, dfResMar::DataFrame, dfCap::DataFrame)

Function for reporting the capacity revenue earned by each generator listed in the input file. GenX will print this file only when capacity reserve margin is modeled and the shadow price can be obtained form the solver. Each row corresponds to a generator, and each column starting from the 6th to the second last is the total revenue from each capacity reserve margin constraint. The revenue is calculated as the capacity contribution of each time steps multiplied by the shadow price, and then the sum is taken over all modeled time steps. The last column is the total revenue received from all capacity reserve margin constraints.  As a reminder, GenX models the capacity reserve margin (aka capacity market) at the time-dependent level, and each constraint either stands for an overall market or a locality constraint.
"""
function write_reserve_margin_revenue_fleccs(path::AbstractString, inputs::Dict, setup::Dict, dfResMar::DataFrame, EP::Model)
	dfGen_ccs = inputs["dfGen_ccs"]
	G_F = inputs["G_F"]
	N_F = inputs["N_F"]
	N = length(N_F)

	dfResRevenue_FLECCS = DataFrame( Resource = dfGen_ccs[!,"Resource"][inputs["BOP_id"]], Zone = dfGen_ccs[!,:Zone][G_F], R_ID = dfGen_ccs[!,:R_ID][G_F], x1 = 0)
	# initiation

	for i in 1:inputs["NCapacityReserveMargin"]
		# initiate the process by assuming everything is thermal
		# since we are testing fleccs in a single USA region so I set this to be 1 for simplicity..
		y = 1
        dfResRevenue_FLECCS[y,:x1] = round.(Int, sum(value.(EP[:eCCS_net])[1,:] .*
        DataFrame([[names(dfResMar)]; collect.(eachrow(dfResMar))], [:column; Symbol.(axes(dfResMar, 1))])[!,i+1] .* dfGen_ccs[N*(G_F-1)+1,Symbol("CapRes_$i")]))
		rename!(dfResRevenue_FLECCS, Dict(:x1 => Symbol("CapRes_$i")))
	end
	
	dfResRevenue_FLECCS.AnnualSum = sum(eachcol(dfResRevenue_FLECCS[:,3:inputs["NCapacityReserveMargin"]+3]))


	CSV.write(joinpath(path, "ReserveMarginRevenue_FLECCS.csv"), dfResRevenue_FLECCS)
	return dfResRevenue_FLECCS
end
