function write_price(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	T = inputs["T"]     # Number of time steps (hours)
	Z = inputs["Z"]     # Number of zones

	## Extract dual variables of constraints
	# Electricity price: Dual variable of hourly power balance constraint = hourly price
	dfPrice = DataFrame(Zone = 1:Z) # The unit is $/MWh

	# Dividing dual variable for each hour with corresponding hourly weight to retrieve marginal cost of generation
	if setup["ParameterScale"] == 1
		dfPrice = hcat(dfPrice, convert(DataFrame, transpose(dual.(EP[:cPowerBalance])./inputs["omega"]*ModelScalingFactor)))
	else
		dfPrice = hcat(dfPrice, convert(DataFrame, transpose(dual.(EP[:cPowerBalance])./inputs["omega"])))
	end

	auxNew_Names=[Symbol("Zone");[Symbol("t$t") for t in 1:T]]
	rename!(dfPrice,auxNew_Names)

	## Linear configuration final output
	CSV.write(string(path,sep,"prices.csv"), dftranspose(dfPrice, false), writeheader=false)
	return dfPrice
end
