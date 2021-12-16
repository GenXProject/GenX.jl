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

function write_rsv(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]

	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)

	# Contingency reserves contribution for each resource in each time step
	dfRsv = DataFrame(Resource = vcat(inputs["RESOURCES"], "unmet"), Zone = vcat(dfGen[!,:Zone], "na"), Sum = Array{Union{Missing,Float32}}(undef, G+1))
	rsv = zeros(G,T)
	for i in 1:G
		if i in inputs["RSV"]
			rsv[i,:] = value.(EP[:vRSV])[i,:]
		end
		dfRsv[!,:Sum][i] = sum(rsv[i,:])
	end
	dfRsv[!,:Sum][G+1] = sum(value.(EP[:vUNMET_RSV]))
	reg = DataFrame(rsv, :auto)
	push!(reg, transpose(convert(Array{Union{Missing,Float32}}, value.(EP[:vUNMET_RSV]))))
	dfRsv = hcat(dfRsv, reg)
	auxNew_Names=[Symbol("Resource");Symbol("Zone");Symbol("Sum");[Symbol("t$t") for t in 1:T]]
	rename!(dfRsv,auxNew_Names)
	total = DataFrame(["Total" 0 sum(dfRsv[!,:Sum]) fill(0.0, (1,T))], :auto)
	for t in 1:T
		total[!,t+3] .= sum(dfRsv[!,Symbol("t$t")][1:G])
	end
	rename!(total,auxNew_Names)
	dfRsv = vcat(dfRsv, total)
	CSV.write(string(path,sep,"reg_dn.csv"), dftranspose(dfRsv, false), writeheader=false)
end
