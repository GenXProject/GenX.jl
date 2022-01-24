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

function write_transmission_flows(path::AbstractString, sep::AbstractString, setup::Dict, inputs::Dict, EP::Model)
    # Transmission related values
    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones
    L = inputs["L"]     # Number of transmission lines
    # Power flows on transmission lines at each time step
    dfFlow = DataFrame(Line = 1:L, AnnualSum = Array{Union{Missing,Float64}}(undef, L))
    if setup["ParameterScale"] == 1
        flow = value.(EP[:vFLOW]) * ModelScalingFactor
    else
        flow = value.(EP[:vFLOW])
    end
    dfFlow.AnnualSum .= flow * inputs["omega"]
    dfFlow = hcat(dfFlow, DataFrame(flow, :auto))
    # if setup["ParameterScale"] == 1
    #     for i in 1:L
    #         dfFlow[!, :AnnualSum][i] = sum(inputs["omega"] .* (value.(EP[:vFLOW])[i, :])) * ModelScalingFactor
    #     end
    #     dfFlow = hcat(dfFlow, DataFrame((value.(EP[:vFLOW])) * ModelScalingFactor, :auto))
    # else
    #     for i in 1:L
    #         dfFlow[!, :AnnualSum][i] = sum(inputs["omega"] .* (value.(EP[:vFLOW])[i, :]))
    #     end
    #     dfFlow = hcat(dfFlow, DataFrame(value.(EP[:vFLOW]), :auto))
    # end
    auxNew_Names = [Symbol("Line"); Symbol("Sum"); [Symbol("t$t") for t in 1:T]]
    rename!(dfFlow, auxNew_Names)
    total = DataFrame(["Total" sum(dfFlow[!, :Sum]) fill(0.0, (1, T))], :auto)
    # for t in 1:T
    #     if v"1.3" <= VERSION < v"1.4"
    #         total[!, t+2] .= sum(dfFlow[!, Symbol("t$t")][1:L])
    #     elseif v"1.4" <= VERSION < v"1.7"
    #         total[:, t+2] .= sum(dfFlow[:, Symbol("t$t")][1:L])
    #     end
    # end
	if v"1.3" <= VERSION < v"1.4"
	    total[!, 3:T+2] .= sum(flow, dims = 1)
	elseif v"1.4" <= VERSION < v"1.7"
	    total[:, 3:T+2] .= sum(flow, dims = 1)
	end
    rename!(total, auxNew_Names)
    dfFlow = vcat(dfFlow, total)

    CSV.write(string(path, sep, "flow.csv"), dftranspose(dfFlow, false), writeheader = false)
end
