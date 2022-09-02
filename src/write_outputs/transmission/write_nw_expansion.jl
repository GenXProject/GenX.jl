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

function write_nw_expansion(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    L = inputs["L"]     # Number of transmission lines
    EXPANSION_LINES = inputs["EXPANSION_LINES"]
    dfTransCap = DataFrame(
        Line = 1:L,
        End_Trans_Capacity = zeros(L), # Final availability
        New_Trans_Capacity = zeros(L), # Expanded capacity
        Cost_Trans_Capacity = zeros(L) # Expansion Cost
    )
    # Transmission network reinforcements
    dfTransCap.End_Trans_Capacity .+= value.(EP[:eAvail_Trans_Cap])
    if !isempty(EXPANSION_LINES)
        dfTransCap.New_Trans_Capacity[EXPANSION_LINES] .+= value.(EP[:vNEW_TRANS_CAP][EXPANSION_LINES]).data
        dfTransCap.Cost_Trans_Capacity[EXPANSION_LINES] .+= dfTransCap.New_Trans_Capacity[EXPANSION_LINES] .* inputs["pC_Line_Reinforcement"][EXPANSION_LINES]
    end
    if setup["ParameterScale"] == 1
        dfTransCap.End_Trans_Capacity *= ModelScalingFactor
        dfTransCap.New_Trans_Capacity *= ModelScalingFactor
        dfTransCap.Cost_Trans_Capacity *= ModelScalingFactor^2
    end
	CSV.write(joinpath(path, "network_expansion.csv"), dfTransCap)
end
