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
write hourly fuel consumption of each power plant. This module is applicable even if piecewiseheatrate is off.
"""
function write_fuel_consumption(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]
	G = inputs["G"]
	COMMIT = inputs["COMMIT"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)

	fuel = zeros(G,T)
	# this module include the hourly fuel consumption of thermal units. 
	for y in COMMIT
		# eCFuelout = $ of fuel ; inputs["fuel_costs"][dfGen[!, :Fuel][y]][t] = $/MMTBU for generator y at time t.
		# eCFuelOut/inputs["fuel_costs"][dfGen[!, :Fuel][y]][t]  = MMTBU of generator at time t
		for t in 1:T
			fuel[y,t] = value.(EP[:eCFuel_out][y,t]) /inputs["fuel_costs"][dfGen[!, :Fuel][y]][t]
		end 
		# replace the fuel consumption of piecewise fuel consumption is on 
		if (setup["PieceWiseHeatRate"] == 1) & (!isempty(inputs["THERM_COMMIT"]))
			fuel[y,:] = value.(EP[:vFuel])[y,:]
		end
	end
			

	# Fuel consumption by each resource in each time step
	dfFuel = DataFrame(Resource = inputs["RESOURCES"], Zone = dfGen[!,:Zone], AnnualSum = Array{Union{Missing,Float32}}(undef,  G))

	
	if setup["ParameterScale"] ==1
		for y in 1:G
			dfFuel[!,:AnnualSum][y] = sum(inputs["omega"].* (fuel[y,:])) * ModelScalingFactor
		end
		dfFuel = hcat(dfFuel, DataFrame(fuel* ModelScalingFactor, :auto))
	else
		for y in 1:G
			dfFuel[!,:AnnualSum][y] = sum(inputs["omega"].* (fuel[y,:]))
		end
		dfFuel = hcat(dfFuel, DataFrame(fuel, :auto))
	end

	auxNew_Names=[Symbol("Resource");Symbol("Zone");Symbol("AnnualSum");[Symbol("t$t") for t in 1:T]]
	rename!(dfFuel,auxNew_Names)

	total = DataFrame(["Total" 0 sum(dfFuel[!,:AnnualSum]) fill(0.0, (1,T))], :auto)
	for t in 1:T
		total[:,t+3] .= sum(dfFuel[:,Symbol("t$t")][COMMIT])
	end
	rename!(total,auxNew_Names)
	dfFuel = vcat(dfFuel, total)
 	CSV.write(joinpath(path,"fuel_consumption.csv"), dftranspose(dfFuel, false), writeheader=false)
end
