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

function write_shutdown(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]
	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
	# Operational decision variable states
	COMMIT = inputs["COMMIT"]
	# Shutdown state for each resource in each time step
	dfShutdown = DataFrame(Resource = inputs["RESOURCES"], Zone = dfGen[!, :Zone])
	shut = zeros(G,T)
	shut[COMMIT, :] = value.(EP[:vSHUT][COMMIT, :])
	dfShutdown.AnnualSum = shut * inputs["omega"]
	dfShutdown = hcat(dfShutdown, DataFrame(shut, :auto))
	auxNew_Names=[Symbol("Resource");Symbol("Zone");Symbol("AnnualSum");[Symbol("t$t") for t in 1:T]]
	rename!(dfShutdown,auxNew_Names)

	total = DataFrame(["Total" 0 sum(dfShutdown.AnnualSum) fill(0.0, (1, T))], :auxNew_Names)
	total[:, 4:T+3] .= sum(shut, dims = 1)
	dfShutdown = vcat(dfShutdown, total)
    
	CSV.write(joinpath(path, "shutdown.csv"), dftranspose(dfShutdown, false), writeheader=false)
end
