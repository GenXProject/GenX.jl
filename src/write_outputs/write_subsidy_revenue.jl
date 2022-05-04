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
    write_subsidy_revenue(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for reporting subsidy revenue earned if a generator specified `Min_Cap` is provided in the input file. GenX will print this file only the shadow price can be obtained form the solver. Do not confuse this with the Minimum Capacity Carveout constraint, which is for a subset of generators, and a separate revenue term will be calculated in other files. The unit is \$.
"""
function write_subsidy_revenue(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    dfGen = inputs["dfGen"]
    G = inputs["G"]

    dfSubRevenue = DataFrame(Region = dfGen[!, :region], Resource = inputs["RESOURCES"], Zone = dfGen[!, :Zone], Cluster = dfGen[!, :cluster], SubsidyRevenue = zeros(G))
    MIN_CAP = dfGen[(dfGen[!, :Min_Cap_MW].>0), :R_ID]
    dfSubRevenue.SubsidyRevenue[MIN_CAP] .= (value.(EP[:eTotalCap])[MIN_CAP]) .* (dual.(EP[:cMinCap][MIN_CAP])).data

    if setup["ParameterScale"] == 1
        dfSubRevenue.SubsidyRevenue *= ModelScalingFactor^2 #convert from Million US$ to US$
    end

    CSV.write(joinpath(path, "SubsidyRevenue.csv"), dfSubRevenue)
    return dfSubRevenue
end
