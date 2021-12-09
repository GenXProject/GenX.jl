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
	write_reliability(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for reporting dual variable of maximum non-served energy constraint (shadow price of reliability constraint) for each model zone and time step.
"""
function write_reliability(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	T = inputs["T"]     # Number of time steps (hours)
	Z = inputs["Z"]     # Number of zones

	# reliability: Dual variable of maximum NSE constraint = shadow value of reliability constraint
	dfReliability = DataFrame(Zone = 1:Z)
	# Dividing dual variable for each hour with corresponding hourly weight to retrieve marginal cost of generation
	if setup["ParameterScale"] == 1
		dfReliability = hcat(dfReliability, DataFrame(transpose(dual.(EP[:cMaxNSE])./inputs["omega"]*ModelScalingFactor), :auto))
	else
		dfReliability = hcat(dfReliability, DataFrame(transpose(dual.(EP[:cMaxNSE])./inputs["omega"]), :auto))
	end


	auxNew_Names=[Symbol("Zone");[Symbol("t$t") for t in 1:T]]
	rename!(dfReliability,auxNew_Names)

	CSV.write(string(path,sep,"reliabilty.csv"), dftranspose(dfReliability, false), writeheader=false)

end
