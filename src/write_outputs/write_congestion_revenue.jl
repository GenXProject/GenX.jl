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
	write_congestion_revenue(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing congestion revenue of each line.
"""
function write_congestion_revenue(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    Z = inputs["Z"]
    L = inputs["L"]
    T = inputs["T"]     # Number of time steps (hours)
    dfCongestionRevenue = DataFrame(Line = 1:L, AnnualSum = zeros(L))
    dfCongestionRevenue.AnnualSum = (-1) * vec(sum(value.(EP[:vFLOW]) .* (inputs["pNet_Map"] * transpose(dual.(EP[:cPowerBalance]))), dims = 2))
    if setup["ParameterScale"] == 1
        dfCongestionRevenue.AnnualSum *= (ModelScalingFactor^2)
    end
    CSV.write(joinpath(path, "CongestionRevenue.csv"), dfCongestionRevenue)
    return dfCongestionRevenue
end
