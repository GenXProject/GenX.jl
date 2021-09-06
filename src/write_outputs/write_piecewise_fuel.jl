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
	write_power(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing the different values of heat input when piecewise heat rate module is on.
"""
function write_piecewise_fuel(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]
	G = inputs["G"]
	COMMIT = inputs["COMMIT"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)

	fuel = zeros(G,T)

	for i in inputs["COMMIT"]
		fuel[i,:] = value.(EP[:vFuel])[i,:]
	end

	# Fuel consumption by each resource in each time step
	dfFuel = DataFrame(Resource = inputs["RESOURCES"], Zone = dfGen[!,:Zone], AnnualSum = Array{Union{Missing,Float32}}(undef,  G))

	if setup["ParameterScale"] ==1
		for i in inputs["COMMIT"]
			dfFuel[!,:AnnualSum][i] = sum(inputs["omega"].* (value.(EP[:vFuel])[i,:])) * ModelScalingFactor
		end
		dfFuel = hcat(dfFuel, DataFrame(fuel* ModelScalingFactor, :auto))
	else
		for i in inputs["COMMIT"]
			dfFuel[!,:AnnualSum][i] = sum(inputs["omega"].* (value.(EP[:vFuel])[i,:]))
		end
		dfFuel = hcat(dfFuel, DataFrame(fuel, :auto))
	end

	auxNew_Names=[Symbol("Resource");Symbol("Zone");Symbol("AnnualSum");[Symbol("t$t") for t in 1:T]]
	rename!(dfFuel,auxNew_Names)

	total = DataFrame(["Total" 0 sum(dfFuel[!,:AnnualSum]) fill(0.0, (1,T))], :auto)
	for t in 1:T
		if v"1.3" <= VERSION < v"1.4"
			total[!,t+3] .= sum(dfFuel[!,Symbol("t$t")][COMMIT])
		elseif v"1.4" <= VERSION < v"1.7"
			total[:,t+3] .= sum(dfFuel[:,Symbol("t$t")][COMMIT])
		end
	end
	rename!(total,auxNew_Names)
	dfFuel = vcat(dfFuel, total)
 	CSV.write(string(path,sep,"piecewise_fuel.csv"), dftranspose(dfFuel, false), writeheader=false)
	return dfFuel
end
