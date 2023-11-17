function write_nw_expansion(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    L = inputs["L"]     # Number of transmission lines
    EXPANSION_LINES = inputs["EXPANSION_LINES"]
    dfTransCap = DataFrame(
        Line = 1:L,
        End_Trans_Capacity = zeros(L), # Final availability
        New_Trans_Capacity = zeros(L), # Expanded capacity
        Cost_Trans_Capacity = zeros(L) # Expansion Cost
    )
    # Transmission network reinforcements
    dfTransCap.End_Trans_Capacity .+= value.(EP[:eAvail_Trans_Cap])
    if !isempty(EXPANSION_LINES)
        dfTransCap.New_Trans_Capacity[EXPANSION_LINES] .+= value.(EP[:vNEW_TRANS_CAP][EXPANSION_LINES]).data
        dfTransCap.Cost_Trans_Capacity[EXPANSION_LINES] .+= dfTransCap.New_Trans_Capacity[EXPANSION_LINES] .* inputs["pC_Line_Reinforcement"][EXPANSION_LINES]
    end
    if setup["ParameterScale"] == 1
        dfTransCap.End_Trans_Capacity *= ModelScalingFactor
        dfTransCap.New_Trans_Capacity *= ModelScalingFactor
        dfTransCap.Cost_Trans_Capacity *= ModelScalingFactor^2
    end
	CSV.write(joinpath(path, "network_expansion.csv"), dfTransCap)
end
