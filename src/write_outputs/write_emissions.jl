function write_emissions(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)
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
			dfEmissions = hcat(DataFrame(Zone = 1:Z), DataFrame(tempCO2Price), DataFrame(AnnualSum = Array{Union{Missing,Float64}}(undef, Z)))
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
			dfEmissions = hcat(dfEmissions, convert(DataFrame, value.(EP[:eEmissionsByZone])*ModelScalingFactor))
		else
			dfEmissions = hcat(dfEmissions, convert(DataFrame, value.(EP[:eEmissionsByZone])/ModelScalingFactor))
		end


		if setup["CO2Cap"]>=1
			auxNew_Names=[Symbol("Zone");[Symbol("CO2_Price_$cap") for cap in 1:inputs["NCO2Cap"]];Symbol("AnnualSum");[Symbol("t$t") for t in 1:T]]
			rename!(dfEmissions,auxNew_Names)
			total = convert(DataFrame, ["Total" zeros(1,inputs["NCO2Cap"]) sum(dfEmissions[!,:AnnualSum]) fill(0.0, (1,T))])
			for t in 1:T
				total[!,t+inputs["NCO2Cap"]+2] .= sum(dfEmissions[!,Symbol("t$t")][1:Z])
			end
			rename!(total,auxNew_Names)
			dfEmissions = vcat(dfEmissions, total)
		else
			auxNew_Names=[Symbol("Zone"); Symbol("AnnualSum"); [Symbol("t$t") for t in 1:T]]
			rename!(dfEmissions,auxNew_Names)
			total = convert(DataFrame, ["Total" sum(dfEmissions[!,:AnnualSum]) fill(0.0, (1,T))])
			for t in 1:T
				total[!,t+2] .= sum(dfEmissions[!,Symbol("t$t")][1:Z])
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
			dfEmissions = hcat(dfEmissions, convert(DataFrame, value.(EP[:eEmissionsByZone])*ModelScalingFactor))
		else
			dfEmissions = hcat(dfEmissions, convert(DataFrame, value.(EP[:eEmissionsByZone])/ModelScalingFactor))
		end
		auxNew_Names=[Symbol("Zone");Symbol("AnnualSum");[Symbol("t$t") for t in 1:T]]
		rename!(dfEmissions,auxNew_Names)
		total = convert(DataFrame, ["Total" sum(dfEmissions[!,:AnnualSum]) fill(0.0, (1,T))])
		for t in 1:T
			total[!,t+2] .= sum(dfEmissions[!,Symbol("t$t")][1:Z])
		end
		rename!(total,auxNew_Names)
		dfEmissions = vcat(dfEmissions, total)
	end
	CSV.write(string(path,sep,"emissions.csv"), dftranspose(dfEmissions, false), writeheader=false)
end
