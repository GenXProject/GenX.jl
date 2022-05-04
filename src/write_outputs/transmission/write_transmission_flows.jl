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

function write_transmission_flows(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    # Transmission related values
    T = inputs["T"]     # Number of time steps (hours)
    L = inputs["L"]     # Number of transmission lines
    # Power flows on transmission lines at each time step
    dfFlow = DataFrame(Line = 1:L, AnnualSum = zeros(L))
    flow = value.(EP[:vFLOW])
    if setup["ParameterScale"] == 1
        flow *= ModelScalingFactor
    end
    dfFlow.AnnualSum .= flow * inputs["omega"]
    dfFlow = hcat(dfFlow, DataFrame(flow, :auto))
    auxNew_Names = [Symbol("Line"); Symbol("AnnualSum"); [Symbol("t$t") for t in 1:T]]
    rename!(dfFlow, auxNew_Names)

    total = DataFrame(["Total" sum(dfFlow.AnnualSum) fill(0.0, (1, T))], :auxNew_Names)
    total[:, 3:T+2] .= sum(flow, dims = 1)
    
    dfFlow = vcat(dfFlow, total)

    CSV.write(joinpath(path, "flow.csv"), dftranspose(dfFlow, false), writeheader = false)
end
