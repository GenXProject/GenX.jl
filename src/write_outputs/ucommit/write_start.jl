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

function write_start(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]
	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)

	# Startup state for each resource in each time step
	dfStart = DataFrame(Resource = inputs["RESOURCES"], Zone = dfGen[!,:Zone], Sum = Array{Union{Missing,Float32}}(undef, G))
	start = zeros(G,T)
	for i in 1:G
		if i in inputs["COMMIT"]
			start[i,:] = value.(EP[:vSTART])[i,:]
		end
		dfStart[!,:Sum][i] = sum(start[i,:])
	end
	dfStart = hcat(dfStart, convert(DataFrame, start))
	auxNew_Names=[Symbol("Resource");Symbol("Zone");Symbol("Sum");[Symbol("t$t") for t in 1:T]]
	rename!(dfStart,auxNew_Names)
	total = convert(DataFrame, ["Total" 0 sum(dfStart[!,:Sum]) fill(0.0, (1,T))])
	for t in 1:T
		total[!,t+3] .= sum(dfStart[:,Symbol("t$t")][1:G])
	end
	rename!(total,auxNew_Names)
	dfStart = vcat(dfStart, total)
	CSV.write(string(path,sep,"start.csv"), dftranspose(dfStart, false), writeheader=false)
end
