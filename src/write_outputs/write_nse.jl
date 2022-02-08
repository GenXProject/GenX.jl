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
	write_nse(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for reporting non-served energy for every model zone, time step and cost-segment.
"""
function write_nse(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    dfGen = inputs["dfGen"]
    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones
    SEG = inputs["SEG"] # Number of load curtailment segments
    # Non-served energy/demand curtailment by segment in each time step
    dfNse = DataFrame(Segment = repeat(1:SEG, outer = Z), Zone = repeat(1:Z, inner = SEG), AnnualSum = zeros(SEG * Z))
    nse = zeros(SEG * Z, T)
    for z in 1:Z
        # tempnse = zeros(SEG, T)
        if setup["ParameterScale"] == 1
            nse[((z-1)*SEG+1):z*SEG, :] = value.(EP[:vNSE])[:, :, z] * ModelScalingFactor
        else
            nse[((z-1)*SEG+1):z*SEG, :] = value.(EP[:vNSE])[:, :, z]
        end
        # nse[((z-1)*SEG+1):z*SEG, :] = tempnse
    end
    dfNse.AnnualSum .= (nse * inputs["omega"])
    dfNse = hcat(dfNse, DataFrame(nse, :auto))
    auxNew_Names = [Symbol("Segment"); Symbol("Zone"); Symbol("AnnualSum"); [Symbol("t$t") for t in 1:T]]
    rename!(dfNse, auxNew_Names)

    total = DataFrame(["Total" 0 sum(dfNse[!, :AnnualSum]) fill(0.0, (1, T))], :auto)
    if v"1.3" <= VERSION < v"1.4"
        total[!, 4:T+3] .= sum(nse, dims = 1)
    elseif v"1.4" <= VERSION < v"1.7"
        total[:, 4:T+3] .= sum(nse, dims = 1)
    end
    rename!(total, auxNew_Names)
    dfNse = vcat(dfNse, total)

    CSV.write(string(path, sep, "nse.csv"), dftranspose(dfNse, false), writeheader = false)
    return dfNse
end
