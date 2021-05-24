function write_esr_prices(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfESR = DataFrame(ESR_Price = convert(Array{Union{Missing, Float64}}, dual.(EP[:cESRShare])))
	if setup["ParameterScale"] == 1
		dfESR[!,:ESR_Price] = dfESR[!,:ESR_Price] * ModelScalingFactor # Converting MillionUS$/GWh to US$/MWh
	end
	CSV.write(string(path,sep,"ESR_prices.csv"), dfESR)
	return dfESR
end
