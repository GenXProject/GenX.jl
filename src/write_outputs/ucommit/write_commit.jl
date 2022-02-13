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

function write_commit(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]
	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
	COMMIT = inputs["COMMIT"]
	# Commitment state for each resource in each time step
	commit = zeros(G,T)
	commit[COMMIT, :] = value.(EP[:vCOMMIT][COMMIT, :])
	dfCommit = DataFrame(Resource = inputs["RESOURCES"], Zone = dfGen[!,:Zone])
	dfCommit = hcat(dfCommit, DataFrame(commit, :auto))
	auxNew_Names=[Symbol("Resource");Symbol("Zone");[Symbol("t$t") for t in 1:T]]
	rename!(dfCommit,auxNew_Names)
	CSV.write(string(path,sep,"commit.csv"), dftranspose(dfCommit, false), writeheader=false)
end
