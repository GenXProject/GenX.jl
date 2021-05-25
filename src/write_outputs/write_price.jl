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

function write_price(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	T = inputs["T"]     # Number of time steps (hours)
	Z = inputs["Z"]     # Number of zones

	## Extract dual variables of constraints
	# Electricity price: Dual variable of hourly power balance constraint = hourly price
	dfPrice = DataFrame(Zone = 1:Z) # The unit is $/MWh

	# Dividing dual variable for each hour with corresponding hourly weight to retrieve marginal cost of generation
	if setup["ParameterScale"] == 1
		dfPrice = hcat(dfPrice, convert(DataFrame, transpose(dual.(EP[:cPowerBalance])./inputs["omega"]*ModelScalingFactor)))
	else
		dfPrice = hcat(dfPrice, convert(DataFrame, transpose(dual.(EP[:cPowerBalance])./inputs["omega"])))
	end

	auxNew_Names=[Symbol("Zone");[Symbol("t$t") for t in 1:T]]
	rename!(dfPrice,auxNew_Names)

	## Linear configuration final output
	CSV.write(string(path,sep,"prices.csv"), dftranspose(dfPrice, false), writeheader=false)
	return dfPrice
end
