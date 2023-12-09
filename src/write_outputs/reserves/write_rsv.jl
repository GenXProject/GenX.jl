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

function write_rsv(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]

	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
	RSV = inputs["RSV"]

	dfRsv = DataFrame(Resource = inputs["RESOURCES"], Zone = dfGen[!, :Zone])
	rsv = zeros(G,T)
	unmet_vec = zeros(T)
	rsv[RSV, :] = value.(EP[:vRSV][RSV, :]) * scale_factor
	unmet_vec = value.(EP[:vUNMET_RSV]) * scale_factor
	total_unmet = sum(unmet_vec)
	dfRsv.AnnualSum = rsv * inputs["omega"]
	dfRsv = hcat(dfRsv, DataFrame(rsv, :auto))
	auxNew_Names=[Symbol("Resource");Symbol("Zone");Symbol("AnnualSum");[Symbol("t$t") for t in 1:T]]
	rename!(dfRsv,auxNew_Names)

	total = DataFrame(["Total" 0 sum(dfRsv.AnnualSum) zeros(1, T)], :auto)
	unmet = DataFrame(["unmet" 0 total_unmet zeros(1, T)], :auto)
	total[!, 4:T+3] .= sum(rsv, dims = 1)
	unmet[!, 4:T+3] .= transpose(unmet_vec)
	rename!(total,auxNew_Names)
	rename!(unmet,auxNew_Names)
	dfRsv = vcat(dfRsv, unmet, total)
	CSV.write(joinpath(path, "reg_dn.csv"), dftranspose(dfRsv, false), writeheader=false)
end
