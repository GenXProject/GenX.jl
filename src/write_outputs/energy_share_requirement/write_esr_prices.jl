function write_esr_prices(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    dfESR = DataFrame(ESR_Price = convert(Array{Float64}, dual.(EP[:cESRShare])))

    if haskey(inputs, "dfESR_slack")
        dfESR[!, :ESR_AnnualSlack] = convert(Array{Float64}, value.(EP[:vESR_slack]))
        dfESR[!, :ESR_AnnualPenalty] = convert(Array{Float64}, value.(EP[:eCESRSlack]))
    end
    CSV.write(joinpath(path, "ESR_prices_and_penalties.csv"), dfESR)
    return dfESR
end
