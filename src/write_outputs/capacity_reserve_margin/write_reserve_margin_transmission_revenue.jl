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
	write_reserve_margin_payment(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
"""
function write_reserve_margin_transmission_revenue(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    L = inputs["L"]     # Number of lines
    dfResTransRevenue = DataFrame(Line = 1:L, AnnualSum = zeros(L))
    for i in 1:inputs["NCapacityReserveMargin"]
        restransrevenue = (-1) * ((value.(EP[:vFLOW])) .* inputs["dfTransCapRes_excl"][:, i] .* inputs["dfDerateTransCapRes"][:, i]) * dual.(EP[:cCapacityResMargin][i, :])
        if setup["ParameterScale"] == 1
            restransrevenue *= (ModelScalingFactor^2)
        end
        dfResTransRevenue.AnnualSum .+= restransrevenue
        dfResTransRevenue = hcat(dfResTransRevenue, DataFrame([restransrevenue], [Symbol("CapRes_$i")]))
    end
    CSV.write(joinpath(path, "ReserveMarginTransmissionRevenue.csv"), dfResTransRevenue)
    return dfResTransRevenue
end
