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

function write_nw_expansion(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	L = inputs["L"]     # Number of transmission lines

	# Transmission network reinforcements
	transcap = zeros(L)
	for i in 1:L
		if i in inputs["EXPANSION_LINES"]
			transcap[i] = value.(EP[:vNEW_TRANS_CAP][i])
		end
	end
	dfTransCap = DataFrame(
	Line = 1:L, New_Trans_Capacity = convert(Array{Union{Missing,Float32}}, transcap),
	Cost_Trans_Capacity = convert(Array{Union{Missing,Float32}}, transcap.*inputs["pC_Line_Reinforcement"]),
	)
	CSV.write(string(path,sep,"network_expansion.csv"), dfTransCap)
end
