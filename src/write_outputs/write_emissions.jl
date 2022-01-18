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
	write_emissions(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for reporting time-dependent CO$_2$ emissions by zone.

"""
function write_emissions(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]
	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
	Z = inputs["Z"]     # Number of zones
	L = inputs["L"]     # Number of transmission lines
	W = inputs["REP_PERIOD"]     # Number of subperiods
    SEG = inputs["SEG"] # Number of load curtailment segments


	if (setup["WriteShadowPrices"]==1 || setup["UCommit"]==0 || (setup["UCommit"]==2 && (setup["Reserves"]==0 || (setup["Reserves"]>0 && inputs["pDynamic_Contingency"]==0)))) # fully linear model
		# CO2 emissions by zone

		if setup["CO2Cap"]>=1
			# Dual variable of CO2 constraint = shadow price of CO2
			tempCO2Price = zeros(Z,inputs["NCO2Cap"])
			if has_duals(EP) == 1
				for cap in 1:inputs["NCO2Cap"]
					for z in findall(x->x==1, inputs["dfCO2CapZones"][:,cap])
						tempCO2Price[z,cap] = dual.(EP[:cCO2Emissions_systemwide])[cap]
						# when scaled, The objective function is in unit of Million US$/kton, thus k$/ton, to get $/ton, multiply 1000
						if setup["ParameterScale"] ==1
							tempCO2Price[z,cap] = tempCO2Price[z,cap]* ModelScalingFactor
						end
					end
				end
			end
			dfEmissions = hcat(DataFrame(Zone = 1:Z), DataFrame(tempCO2Price, :auto), DataFrame(AnnualSum = Array{Union{Missing,Float64}}(undef, Z)))
			auxNew_Names=[Symbol("Zone"); [Symbol("CO2_Price_$cap") for cap in 1:inputs["NCO2Cap"]]; Symbol("AnnualSum")]
			rename!(dfEmissions,auxNew_Names)
		else
			dfEmissions = DataFrame(Zone = 1:Z, AnnualSum = Array{Union{Missing,Float32}}(undef, Z))
		end

		for i in 1:Z
			if setup["ParameterScale"]==1
				dfEmissions[!,:AnnualSum][i] = sum(inputs["omega"].*value.(EP[:eEmissionsByZone])[i,:])*ModelScalingFactor
			else
				dfEmissions[!,:AnnualSum][i] = sum(inputs["omega"].*value.(EP[:eEmissionsByZone])[i,:])/ModelScalingFactor
			end
		end

		if setup["ParameterScale"]==1
			dfEmissions = hcat(dfEmissions, DataFrame(value.(EP[:eEmissionsByZone])*ModelScalingFactor, :auto))
		else
			dfEmissions = hcat(dfEmissions, DataFrame(value.(EP[:eEmissionsByZone])/ModelScalingFactor, :auto))
		end


		if setup["CO2Cap"]>=1
			auxNew_Names=[Symbol("Zone");[Symbol("CO2_Price_$cap") for cap in 1:inputs["NCO2Cap"]];Symbol("AnnualSum");[Symbol("t$t") for t in 1:T]]
			rename!(dfEmissions,auxNew_Names)
			total = DataFrame(["Total" zeros(1,inputs["NCO2Cap"]) sum(dfEmissions[!,:AnnualSum]) fill(0.0, (1,T))], :auto)
			for t in 1:T
				if v"1.3" <= VERSION < v"1.4"
					total[!,t+inputs["NCO2Cap"]+2] .= sum(dfEmissions[!,Symbol("t$t")][1:Z])
				elseif v"1.4" <= VERSION < v"1.7"
					total[:,t+inputs["NCO2Cap"]+2] .= sum(dfEmissions[:,Symbol("t$t")][1:Z])
				end
			end
			rename!(total,auxNew_Names)
			dfEmissions = vcat(dfEmissions, total)
		else
			auxNew_Names=[Symbol("Zone"); Symbol("AnnualSum"); [Symbol("t$t") for t in 1:T]]
			rename!(dfEmissions,auxNew_Names)
			total = DataFrame(["Total" sum(dfEmissions[!,:AnnualSum]) fill(0.0, (1,T))], :auto)
			for t in 1:T
				if v"1.3" <= VERSION < v"1.4"
					total[!,t+2] .= sum(dfEmissions[!,Symbol("t$t")][1:Z])
				elseif v"1.4" <= VERSION < v"1.7"
					total[:,t+2] .= sum(dfEmissions[:,Symbol("t$t")][1:Z])
				end
			end
			rename!(total,auxNew_Names)
			dfEmissions = vcat(dfEmissions, total)
		end


## Aaron - Combined elseif setup["Dual_MIP"]==1 block with the first block since they were identical. Why do we have this third case? What is different about it?
	else
		# CO2 emissions by zone
		dfEmissions = hcat(DataFrame(Zone = 1:Z), DataFrame(AnnualSum = Array{Union{Missing,Float64}}(undef, Z)))
		for i in 1:Z
			if setup["ParameterScale"]==1
				dfEmissions[!,:AnnualSum][i] = sum(inputs["omega"].*value.(EP[:eEmissionsByZone])[i,:]) *ModelScalingFactor
			else
				dfEmissions[!,:AnnualSum][i] = sum(inputs["omega"].*value.(EP[:eEmissionsByZone])[i,:])/ModelScalingFactor
			end
		end
		if setup["ParameterScale"]==1
			dfEmissions = hcat(dfEmissions, DataFrame(value.(EP[:eEmissionsByZone])*ModelScalingFactor, :auto))
		else
			dfEmissions = hcat(dfEmissions, DataFrame(value.(EP[:eEmissionsByZone])/ModelScalingFactor, :auto))
		end
		auxNew_Names=[Symbol("Zone");Symbol("AnnualSum");[Symbol("t$t") for t in 1:T]]
		rename!(dfEmissions,auxNew_Names)
		total = DataFrame(["Total" sum(dfEmissions[!,:AnnualSum]) fill(0.0, (1,T))], :auto)
		for t in 1:T
			if v"1.3" <= VERSION < v"1.4"
				total[!,t+2] .= sum(dfEmissions[!,Symbol("t$t")][1:Z])
			elseif v"1.4" <= VERSION < v"1.7"
				total[:,t+2] .= sum(dfEmissions[:,Symbol("t$t")][1:Z])
			end
		end
		rename!(total,auxNew_Names)
		dfEmissions = vcat(dfEmissions, total)
	end
	CSV.write(joinpath(path, "emissions.csv"), dftranspose(dfEmissions, false), writeheader=false)
end
