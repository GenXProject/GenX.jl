function write_esr_prices(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfESR = DataFrame(ESR_Price = convert(Array{Float64}, dual.(EP[:cESRShare])))
	if setup["ParameterScale"] == 1
		dfESR[!,:ESR_Price] = dfESR[!,:ESR_Price] * ModelScalingFactor # Converting MillionUS$/GWh to US$/MWh
	end
	CSV.write(joinpath(path, "ESR_prices.csv"), dfESR)
	return dfESR
end
