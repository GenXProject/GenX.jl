function write_nw_expansion(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    L_sym = inputs["L_sym"] # Number of transmission lines with symmetrical bidirectional flow
    L_asym = 0 #Default number of asymmetrical lines
    # Number of lines in the network
    if setup["asymmetrical_trans_flow_limit"] == 1
        L_asym = inputs["L_asym"] #Number of transmission lines with different capacities in two directions
    end
    L = L_sym + L_asym

    # Transmission network reinforcements
    transcap = zeros(L)
    transcap_pos = zeros(L_asym)
    transcap_neg = zeros(L_asym)
    for i in 1:L
        if i in inputs["EXPANSION_LINES"]
            transcap[i] = value.(EP[:vNEW_TRANS_CAP][i])
        elseif i in inputs["EXPANSION_LINES_ASYM"]
            transcap_pos[i] = value.(EP[:vNEW_TRANS_CAP_Pos][i])
            transcap_neg[i] = value.(EP[:vNEW_TRANS_CAP_Neg][i])    
        end
    end

    dfTransCap = DataFrame(Line = 1:L,
        New_Trans_Capacity = convert(Array{Float64}, transcap),
        Cost_Trans_Capacity = convert(Array{Float64},
            transcap .* inputs["pC_Line_Reinforcement"]))

    if setup["ParameterScale"] == 1
        dfTransCap.New_Trans_Capacity *= ModelScalingFactor  # GW to MW
        dfTransCap.Cost_Trans_Capacity *= ModelScalingFactor^2  # MUSD to USD
    end

    CSV.write(joinpath(path, "network_expansion.csv"), dfTransCap)
end
