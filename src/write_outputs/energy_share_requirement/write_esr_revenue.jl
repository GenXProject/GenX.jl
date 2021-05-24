function write_esr_revenue(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, dfPower::DataFrame, dfESR::DataFrame)
	dfGen = inputs["dfGen"]
	dfESRRev = DataFrame(region = dfGen[!,:region], Resource = inputs["RESOURCES"], zone = dfGen[!,:Zone], Cluster = dfGen[!,:cluster], R_ID = dfGen[!,:R_ID])

	for i in 1:inputs["nESR"]
		dfESRRev =  hcat(dfESRRev, dfPower[1:end-1,:AnnualSum] .* dfGen[!,Symbol("ESR_$i")] * dfESR[i,:ESR_Price])
		# dfpower is in MWh already, price is in $/MWh already, no need to scale
		# if setup["ParameterScale"] == 1
		# 	#dfESRRev[!,:x1] = dfESRRev[!,:x1] * (1e+3) # MillionUS$ to US$
		# 	dfESRRev[!,:x1] = dfESRRev[!,:x1] * ModelScalingFactor # MillionUS$ to US$  # Is this right? -Jack 4/29/2021
		# end
		rename!(dfESRRev, Dict(:x1 => Symbol("ESR_$i")))
	end
	dfESRRev.AnnualSum = sum(eachcol(dfESRRev[:,6:inputs["nESR"]+5]))
	CSV.write(string(path,sep,"ESR_Revenue.csv"), dfESRRev)
	return dfESRRev
end
