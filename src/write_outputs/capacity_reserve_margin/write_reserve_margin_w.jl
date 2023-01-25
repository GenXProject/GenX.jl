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

function write_reserve_margin_w(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	T = inputs["T"]     # Number of time steps (hours)
	p = inputs["hours_per_subperiod"]
	#dfResMar dataframe with weights included for calculations
	dfResMar_w = DataFrame(Constraint = [Symbol("t$t") for t in 1:T])
	temp_ResMar_w = transpose(dual.(EP[:cCapacityResMargin]))./inputs["omega"]
	if setup["ParameterScale"] == 1
		temp_ResMar_w = temp_ResMar_w * ModelScalingFactor # Convert from MillionUS$/GWh to US$/MWh
	end
	dfResMar_w = hcat(dfResMar_w, DataFrame(temp_ResMar_w, :auto))
	auxNew_Names_res=[Symbol("Constraint"); [Symbol("CapRes_$i") for i in 1:inputs["NCapacityReserveMargin"]]]
	rename!(dfResMar_w,auxNew_Names_res)

	maxbindinglength = 0
	for i in 1:inputs["NCapacityReserveMargin"]
		resmar_ts = dfResMar_w[!,Symbol("CapRes_$i")]
		t = 1
		currentmax = 0
		while t <= T
			if resmar_ts[t] > 0.1
				if hoursbefore(p, t, 1) == (t-1)
					currentmax += 1
					t = t+1
				else 
					maxbindinglength = max(currentmax, maxbindinglength)
					currentmax = 1
					t = t+1
				end
			else
				maxbindinglength = max(currentmax, maxbindinglength)
				currentmax = 0
				t = t+1
			end
		end
	end
				

	println("Maximum number of consecutive binding hours for a capacity reserve margin constraint is:")
	println(maxbindinglength)
	println("CapResPeriodLength parameter is:")
	println(setup["CapResPeriodLength"])
	println("Consider adjusting CapResPeriodLength if it does not match the observed binding period length")

	CSV.write(joinpath(path, "ReserveMargin_w.csv"), dfResMar_w)
end
