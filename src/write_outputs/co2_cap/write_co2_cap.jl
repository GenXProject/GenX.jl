@doc raw"""
	write_co2_cap(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for reporting carbon price associated with carbon cap constraints.

"""
function write_co2_cap(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    dfCO2Price = DataFrame(CO2_Cap = [Symbol("CO2_Cap_$cap") for cap in 1:inputs["NCO2Cap"]],
        CO2_Price = (-1) * (dual.(EP[:cCO2Emissions_systemwide])))
    if setup["ParameterScale"] == 1
        dfCO2Price.CO2_Price .*= ModelScalingFactor # Convert Million$/kton to $/ton
    end
    if haskey(inputs, "dfCO2Cap_slack")
        dfCO2Price[!, :CO2_Mass_Slack] = convert(Array{Float64}, value.(EP[:vCO2Cap_slack]))
        dfCO2Price[!, :CO2_Penalty] = convert(Array{Float64}, value.(EP[:eCCO2Cap_slack]))
        if setup["ParameterScale"] == 1
            dfCO2Price.CO2_Mass_Slack .*= ModelScalingFactor # Convert ktons to tons
            dfCO2Price.CO2_Penalty .*= ModelScalingFactor^2 # Convert Million$ to $
        end
    end

    CSV.write(joinpath(path, "CO2_prices_and_penalties.csv"), dfCO2Price)

    return nothing
end
