function write_reliability(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	T = inputs["T"]     # Number of time steps (hours)
	Z = inputs["Z"]     # Number of zones

	# reliability: Dual variable of maximum NSE constraint = shadow value of reliability constraint
	dfReliability = DataFrame(Zone = 1:Z)
	# Dividing dual variable for each hour with corresponding hourly weight to retrieve marginal cost of generation
	if setup["ParameterScale"] == 1
		dfReliability = hcat(dfReliability, convert(DataFrame, transpose(dual.(EP[:cMaxNSE])./inputs["omega"]*ModelScalingFactor)))
	else
		dfReliability = hcat(dfReliability, convert(DataFrame, transpose(dual.(EP[:cMaxNSE])./inputs["omega"])))
	end

	
	auxNew_Names=[Symbol("Zone");[Symbol("t$t") for t in 1:T]]
	rename!(dfReliability,auxNew_Names)

	CSV.write(string(path,sep,"reliabilty.csv"), dftranspose(dfReliability, false), writeheader=false)

end