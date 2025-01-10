function write_nw_expansion(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    # Number of lines in the network
    L_sym = inputs["L_sym"]
    L_asym = inputs["L_asym"] #Number of transmission lines with different capacities in two directions
    L = inputs["L"]

    NetworkExpansion = setup["NetworkExpansion"]
    MultiStage = setup["MultiStage"]

    SYMMETRIC_LINE_INDEX = inputs["symmetric_line_index"]
    ASYMMETRIC_LINE_INDEX = inputs["asymmetric_line_index"]

    if NetworkExpansion == 1
        # Network lines and zones that are expandable have non-negative maximum reinforcement inputs
        EXPANSION_LINES = inputs["EXPANSION_LINES"]
        EXPANSION_LINES_ASYM = inputs["EXPANSION_LINES_ASYM"]

    end

    # Transmission network reinforcements
    transcap = zeros(L)
    transcap_pos = zeros(L_asym)
    transcap_neg = zeros(L_asym)
    for i in intersect(SYMMETRIC_LINE_INDEX, EXPANSION_LINES)
        transcap[i] = value.(EP[:vNEW_TRANS_CAP][i])
    end
    for i in EXPANSION_LINES_ASYM
        transcap_pos[i] = value.(EP[:vNEW_TRANS_CAP_Pos][i])
        transcap_neg[i] = value.(EP[:vNEW_TRANS_CAP_Neg][i])    
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
