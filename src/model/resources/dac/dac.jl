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
	DAC
"""

function dac(EP::Model, inputs::Dict)

	println("DAC module")

	dfGen = inputs["dfGen"]

	T = inputs["T"]     # Number of time steps (hours)
	Z = inputs["Z"]     # Number of zones
	G = inputs["G"] 	# Number of generators

	DAC = inputs["DAC"]

	### Expressions ###
	## Power Balance Expressions ##

	@expression(EP, ePowerBalanceDAC[t=1:T, z=1:Z],
		sum(EP[:vP][y,t] for y in intersect(DAC, dfGen[dfGen[!,:Zone].==z,:][!,:R_ID])))
		
	EP[:ePowerBalance] = EP[:ePowerBalance] - ePowerBalanceDAC

	@constraint(EP, [y in DAC, t=1:T], EP[:vP][y,t] <= inputs["pP_Max"][y,t]*EP[:eTotalCap][y])


	return EP
end
