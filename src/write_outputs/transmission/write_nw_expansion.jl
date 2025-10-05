function write_nw_expansion(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    # Number of lines in the network
    L_asym = inputs["L_asym"] #Number of transmission lines with different capacities in two directions
    L = inputs["L"]

    NetworkExpansion = setup["NetworkExpansion"]
    MultiStage = setup["MultiStage"]

    SYMMETRIC_LINE_INDEX = inputs["SYMMETRIC_LINE_INDEX"]
    ASYMMETRIC_LINE_INDEX = inputs["ASYMMETRIC_LINE_INDEX"]

    if NetworkExpansion == 1
        # Network lines and zones that are expandable have non-negative maximum reinforcement inputs
        EXPANSION_LINES = inputs["EXPANSION_LINES"]
        EXPANSION_LINES_ASYM = inputs["EXPANSION_LINES_ASYM"]

    end

    # Transmission network reinforcements
    transcap = zeros(L)
    transcap_pos = zeros(L)
    transcap_neg = zeros(L)
    for i in intersect(SYMMETRIC_LINE_INDEX, EXPANSION_LINES)
        transcap[i] = value.(EP[:vNEW_TRANS_CAP][i])
    end
   for i in eachindex(EXPANSION_LINES_ASYM)
        asym_line_index = EXPANSION_LINES_ASYM[i]
        println("Asym line index: ", asym_line_index)
        println("i Index: ", i)
        transcap_pos[asym_line_index] = value.(EP[:vNEW_TRANS_CAP_Pos][asym_line_index])
        transcap_neg[asym_line_index] = value.(EP[:vNEW_TRANS_CAP_Neg][asym_line_index])    
    end

    dfTransCap = DataFrame(Line = 1:L,
        New_Trans_Capacity = convert(Array{Float64}, transcap),
        Cost_Trans_Capacity = convert(Array{Float64},
            transcap .* inputs["pC_Line_Reinforcement"]))

    if L_asym > 0
        asym_costs = zeros(L)
        for i in eachindex(EXPANSION_LINES_ASYM)
            asym_line_index = EXPANSION_LINES_ASYM[i]
            asym_costs[asym_line_index] = inputs["pC_Line_Reinforcement"][asym_line_index]
        end
        # Extract reinforcement costs for asymmetric lines only
        #asym_costs = inputs["pC_Line_Reinforcement"][ASYMMETRIC_LINE_INDEX]
        #asym_costs = inputs["pC_Line_Reinforcement"][EXPANSION_LINES_ASYM]
        
        dfTransCap_asym = DataFrame(Line = EXPANSION_LINES,
            New_Trans_Capacity_Pos = convert(Array{Float64}, transcap_pos),
            New_Trans_Capacity_Neg = convert(Array{Float64}, transcap_neg),
            Cost_Trans_Capacity_Pos = convert(Array{Float64},
                transcap_pos .* asym_costs),
            Cost_Trans_Capacity_Neg = convert(Array{Float64},
                transcap_neg .* asym_costs))
        dfTransCap = leftjoin(dfTransCap, dfTransCap_asym, on = :Line)
    end

    if setup["ParameterScale"] == 1
        dfTransCap.New_Trans_Capacity *= ModelScalingFactor  # GW to MW
        dfTransCap.Cost_Trans_Capacity *= ModelScalingFactor^2  # MUSD to USD
    end

    CSV.write(joinpath(path, "network_expansion.csv"), dfTransCap)
end
