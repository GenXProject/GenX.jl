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
	EXPANSION_LINES = inputs["EXPANSION_LINES"]

	# Transmission network reinforcements
	transcap = zeros(L)
	transcapcost = zeros(L)
    transendcap = zeros(L)
	for !isempty(inputs["EXPANSION_LINES"])
		transendcap[EXPANSION_LINES] = value.(EP[:vNEW_TRANS_CAP][EXPANSION_LINES])
        transcapcost[EXPANSION_LINES] = transendcap .* inputs["pC_Line_Reinforcement"]
	end
	transendcap = value.(EP[:eAvail_Trans_Cap])
    dfTransCap = DataFrame(
        Line = 1:L,
        End_Trans_Capacity = convert(Array{Union{Missing,Float64}}, transendcap),
        New_Trans_Capacity = convert(Array{Union{Missing,Float64}}, transcap),
        Cost_Trans_Capacity = convert(Array{Union{Missing,Float64}}, transcapcost)
    )
	CSV.write(string(path,sep,"network_expansion.csv"), dfTransCap)
end
