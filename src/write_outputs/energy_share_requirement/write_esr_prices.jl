function write_esr_prices(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    dfESR = DataFrame(ESR_Price = convert(Array{Float64}, dual.(EP[:cESRShare])))
    if setup["ParameterScale"] == 1
        dfESR[!, :ESR_Price] = dfESR[!, :ESR_Price] * ModelScalingFactor # Converting MillionUS$/GWh to US$/MWh
    end

    if haskey(inputs, "dfESR_slack")
        dfESR[!, :ESR_AnnualSlack] = convert(Array{Float64}, value.(EP[:vESR_slack]))
        dfESR[!, :ESR_AnnualPenalty] = convert(Array{Float64}, value.(EP[:eCESRSlack]))
        if setup["ParameterScale"] == 1
            dfESR[!, :ESR_AnnualSlack] *= ModelScalingFactor # Converting GWh to MWh
            dfESR[!, :ESR_AnnualPenalty] *= (ModelScalingFactor^2) # Converting MillionUSD to USD
        end
    end
    CSV.write(joinpath(path, "ESR_prices_and_penalties.csv"), dfESR)
    return dfESR
end
