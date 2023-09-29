function write_nw_expansion(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    L = inputs["L"]     # Number of transmission lines

    # Transmission network reinforcements
    transcap = zeros(L)
    for i = 1:L
        if i in inputs["EXPANSION_LINES"]
            transcap[i] = value.(EP[:vNEW_TRANS_CAP][i])
        end
    end

    dfTransCap = DataFrame(
        Line = 1:L,
        New_Trans_Capacity = convert(Array{Float64}, transcap),
        Cost_Trans_Capacity = convert(
            Array{Float64},
            transcap .* inputs["pC_Line_Reinforcement"],
        ),
    )

    if setup["ParameterScale"] == 1
        dfTransCap.New_Trans_Capacity *= ModelScalingFactor  # GW to MW
        dfTransCap.Cost_Trans_Capacity *= ModelScalingFactor^2  # MUSD to USD
    end

    CSV.write(joinpath(path, "network_expansion.csv"), dfTransCap)
end
