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
	write_charge(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing the charging energy values of the different storage technologies.
"""
function write_charge(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    dfGen = inputs["dfGen"]
    G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
    T = inputs["T"]     # Number of time steps (hours)
    STOR_ALL = inputs["STOR_ALL"]
    FLEX = inputs["FLEX"]
    # Power withdrawn to charge each resource in each time step
    dfCharge = DataFrame(Resource = inputs["RESOURCES"], Zone = dfGen[!, :Zone], AnnualSum = Array{Union{Missing,Float64}}(undef, G))
    charge = zeros(G, T)
    if setup["ParameterScale"] == 1
        if !isempty(inputs["STOR_ALL"])
            charge[STOR_ALL, :] = value.(EP[:vCHARGE][STOR_ALL, :]) * ModelScalingFactor
        end
        if !isempty(inputs["FLEX"])
            charge[FLEX, :] = value.(EP[:vCHARGE_FLEX][FLEX, :]) * ModelScalingFactor
        end
        dfCharge.AnnualSum .= charge * inputs["omega"] * ModelScalingFactor
    else
        if !isempty(inputs["STOR_ALL"])
            charge[STOR_ALL, :] = value.(EP[:vCHARGE][STOR_ALL, :])
        end
        if !isempty(inputs["FLEX"])
            charge[FLEX, :] = value.(EP[:vCHARGE_FLEX][FLEX, :])
        end
        dfCharge.AnnualSum .= charge * inputs["omega"]
    end
    dfCharge = hcat(dfCharge, DataFrame(charge, :auto))

    auxNew_Names = [Symbol("Resource"); Symbol("Zone"); Symbol("AnnualSum"); [Symbol("t$t") for t in 1:T]]
    rename!(dfCharge, auxNew_Names)
    total = DataFrame(["Total" 0 sum(dfCharge[!, :AnnualSum]) fill(0.0, (1, T))], :auto)

    if v"1.3" <= VERSION < v"1.4"
        total[!, 4:T+3] .= sum(charge, dims = 1) # summing over the first dimension, g, so the result is a horizonalal array with dimension t
    elseif v"1.4" <= VERSION < v"1.7"
        total[:, 4:T+3] .= sum(charge, dims = 1)
    end
    rename!(total, auxNew_Names)
    dfCharge = vcat(dfCharge, total)
    CSV.write(string(path, sep, "charge.csv"), dftranspose(dfCharge, false), writeheader = false)
    return dfCharge
end
