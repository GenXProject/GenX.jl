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
	write_zonalnse(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for reporting non-served energy for every model zone and time step.
"""
function write_zonalnse(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    dfGen = inputs["dfGen"]
    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones
    SEG = inputs["SEG"] # Number of load curtailment segments
    # Non-served energy/demand curtailment by segment in each time step
    dfZonalNse = DataFrame(Zone = 1:Z, AnnualSum = zeros(Z))
    znse = transpose(value.(EP[:eZonalNSE]))
    if setup["ParameterScale"] == 1
        znse = znse * ModelScalingFactor
    end
    dfZonalNse.AnnualSum .= (znse * inputs["omega"])
    dfZonalNse = hcat(dfZonalNse, DataFrame(znse, [Symbol("t$t") for t in 1:T]))
    auxNew_Names = [Symbol("Zone"); Symbol("AnnualSum"); [Symbol("t$t") for t in 1:T]]
    # rename!(dfZonalNse, auxNew_Names)

    total = DataFrame(["Total" sum(dfZonalNse[!, :AnnualSum]) fill(0.0, (1, T))], auxNew_Names)
    if v"1.3" <= VERSION < v"1.4"
        total[!, 3:T+2] .= sum(znse, dims = 1)
    elseif v"1.4" <= VERSION < v"1.7"
        total[:, 3:T+2] .= sum(znse, dims = 1)
    end
    # rename!(total, auxNew_Names)
    dfZonalNse = vcat(dfZonalNse, total)

    CSV.write(joinpath(path, "zonalnse.csv"), dftranspose(dfZonalNse, false), writeheader = false)
    return dfZonalNse
end
