@doc raw"""
    investment_transmission!(EP::Model, inputs::Dict, setup::Dict)
This function model transmission expansion and adds transmission reinforcement or construction costs to the objective function. Transmission reinforcement costs are equal to the sum across all lines of the product between the transmission reinforcement/construction cost, $\pi^{TCAP}_{l}$, times the additional transmission capacity variable, $\bigtriangleup\varphi^{cap}_{l}$.
```math
\begin{aligned}
    & \sum_{l \in \mathcal{L}}\left(\pi^{TCAP}_{l} \times \bigtriangleup\varphi^{cap}_{l}\right)
\end{aligned}
```
Note that fixed O\&M and replacement capital costs (depreciation) for existing transmission capacity is treated as a sunk cost and not included explicitly in the GenX objective function.

**Accounting for Transmission Between Zones**

Available transmission capacity between zones is set equal to the existing line's maximum power transfer capacity, $\overline{\varphi^{cap}_{l}}$, plus any transmission capacity added on that line (for lines eligible for expansion in the set $\mathcal{E}$). 
```math
\begin{aligned}
    &\varphi^{cap}_{l} = \overline{\varphi^{cap}_{l}} , &\quad \forall l \in (\mathcal{L} \setminus \mathcal{E} ),\forall t  \in \mathcal{T}\\
    % trasmission expansion
    &\varphi^{cap}_{l} = \overline{\varphi^{cap}_{l}} + \bigtriangleup\varphi^{cap}_{l} , &\quad \forall l \in \mathcal{E},\forall t  \in \mathcal{T}        
\end{aligned}
```
The additional transmission capacity, $\bigtriangleup\varphi^{cap}_{l} $, is constrained by a maximum allowed reinforcement, $\overline{\bigtriangleup\varphi^{cap}_{l}}$, for each line $l \in \mathcal{E}$.
```math
\begin{aligned}
    & \bigtriangleup\varphi^{cap}_{l}  \leq \overline{\bigtriangleup\varphi^{cap}_{l}}, &\quad \forall l \in \mathcal{E}
\end{aligned}
```
"""
function investment_transmission!(EP::Model, inputs::Dict, setup::Dict)
    println("Investment Transmission Module")

    L = inputs["L"]     # Number of transmission lines
    NetworkExpansion = setup["NetworkExpansion"]
    MultiStage = setup["MultiStage"]

    if NetworkExpansion == 1
        if setup["DC_OPF"] == 1
            L_cand = inputs["L_cand"]     # Number of candidate transmission lines
            # Network lines and zones that are expandable have non-negative maximum reinforcement inputs
            CANDIDATE_LINES = inputs["CANDIDATE_LINES"]
            REINFORCEMENT_CAP_SIZE = inputs["Line_Reinforcement_Cap_Size"]
            MAX_TRAN_EXPANSION_LIMIT=inputs["Max_Trans_Cap"]
            EXPANSION_LEVELS=Dict{Int,Vector{Float64}}()
            for l in CANDIDATE_LINES
                EXPANSION_LEVELS[l] = (0:1:MAX_TRAN_EXPANSION_LIMIT[l]) #-Might not need multiplication of this part -->* REINFORCEMENT_CAP_SIZE[l]
            end
            inputs["EXPANSION_LEVELS"] = EXPANSION_LEVELS
            if setup["ptdf"] == 1
                line_map = Dict()

                line_adj = inputs["pNet_Map"]
                for i in 1:size(line_adj)[1]
                    from_idx = findfirst(x -> x == 1, line_adj[i, :])
                    to_idx = findfirst(x -> x == -1, line_adj[i, :])
                    line_map[i] = (from_idx, to_idx)
                end

                inputs["Line_Map"] = line_map
            end
        else
            CANDIDATE_LINES = inputs["EXPANSION_LINES"]
        end
    end

    ### Variables ###

    if MultiStage == 1
        @variable(EP, vTRANSMAX[l = 1:L]>=0)
    end
    if NetworkExpansion == 1
        if setup["DC_OPF"] == 1
            RECONDUCTOR_LINES = inputs["RECONDUCTOR_LINES"]
            MAX_TRANS_EXPANSION_LIMIT=inputs["Max_Trans_Cap"]
            @variable(EP, vRECONDUCTOR_SLACK_LOW[l in RECONDUCTOR_LINES] >= 0)
            @variable(EP, vRECONDUCTOR_SLACK_HIGH[l in RECONDUCTOR_LINES] >= 0)
            for l in RECONDUCTOR_LINES
                set_upper_bound(vRECONDUCTOR_SLACK_LOW[l], 0.1 * inputs["pTrans_Max"][l])
                set_upper_bound(vRECONDUCTOR_SLACK_HIGH[l], 0.15 * inputs["pTrans_Max"][l])
            end

            @variable(EP, vNEW_TRANS_CAP_DECISION_INT[l in CANDIDATE_LINES], Bin)
        elseif setup["IntegerInvestments"] == 1
            # Transmission network capacity reinforcements per line, integer
            @variable(EP, vNEW_TRANS_LINES[l in CANDIDATE_LINES], Int, lower_bound=0)
            for l in CANDIDATE_LINES
                set_upper_bound(vNEW_TRANS_LINES[l], 1) #"Max_Trans_Cap
            end
        else
            # Transmission network capacity reinforcements per line
            @variable(EP, vNEW_TRANS_CAP[l in CANDIDATE_LINES]>=0)
        end
    end

    ### Expressions ###

    if MultiStage == 1
        @expression(EP, eTransMax[l = 1:L], vTRANSMAX[l])
    else
        @expression(EP, eTransMax[l = 1:L], inputs["pTrans_Max"][l]) #TODO: Add vRECONDUCTOR_SLACK1
    end

    ## Transmission power flow and loss related expressions:
    # Total availabile maximum transmission capacity is the sum of existing maximum transmission capacity plus new transmission capacity
    if NetworkExpansion == 1
        if setup["DC_OPF"] == 1
            @expression(EP, eAvail_Trans_Cap[l = 1:L],
            if l in CANDIDATE_LINES
                if l in RECONDUCTOR_LINES
                    eTransMax[l] + vNEW_TRANS_CAP_DECISION_INT[l]*inputs["Line_Reinforcement_Cap_Size"][l] + vRECONDUCTOR_SLACK_LOW[l] + vRECONDUCTOR_SLACK_HIGH[l]
                else
                    eTransMax[l] + vNEW_TRANS_CAP_DECISION_INT[l]*inputs["Line_Reinforcement_Cap_Size"][l]
                end
            else
                if l in RECONDUCTOR_LINES
                    eTransMax[l] + vRECONDUCTOR_SLACK_LOW[l] + vRECONDUCTOR_SLACK_HIGH[l]
                else
                    eTransMax[l]
                end
            end)
        elseif setup["IntegerInvestments"] == 1
            @expression(EP, eAvail_Trans_Cap[l = 1:L],
            if l in CANDIDATE_LINES
                eTransMax[l] + vNEW_TRANS_LINES[l]*inputs["Line_Reinforcement_Cap_Size"][l]
            else
                eTransMax[l]
            end)
        else
            @expression(EP, eAvail_Trans_Cap[l = 1:L],
            if l in CANDIDATE_LINES
                eTransMax[l] + vNEW_TRANS_CAP[l]
            else
                eTransMax[l]
            end)
        end
    else
        @expression(EP, eAvail_Trans_Cap[l = 1:L], eTransMax[l])
    end

    ## Objective Function Expressions ##

    if NetworkExpansion == 1
        if setup["DC_OPF"] == 1
            @expression(EP,
            eTotalCNetworkExp,
            sum(vNEW_TRANS_CAP_DECISION_INT[l] * inputs["Line_Reinforcement_Cap_Size"][l]* inputs["pC_Line_Reinforcement"][l] 
            for l in CANDIDATE_LINES) + sum(vRECONDUCTOR_SLACK_LOW[l] * inputs["pC_Line_Reconductor_Low"][l] + vRECONDUCTOR_SLACK_HIGH[l] * inputs["pC_Line_Reconductor_High"][l] for l in RECONDUCTOR_LINES))
        elseif setup["IntegerInvestments"] == 1
            @expression(EP,
                eTotalCNetworkExp,
                sum(vNEW_TRANS_LINES[l] * inputs["Line_Reinforcement_Cap_Size"][l] * inputs["pC_Line_Reinforcement"][l]
                for l in CANDIDATE_LINES))
        else
            @expression(EP,
                eTotalCNetworkExp,
                sum(vNEW_TRANS_CAP[l] * inputs["pC_Line_Reinforcement"][l]
                for l in CANDIDATE_LINES))
        end
        if MultiStage == 1
            # OPEX multiplier to count multiple years between two model stages
            # We divide by OPEXMULT since we are going to multiply the entire objective function by this term later,
            # and we have already accounted for multiple years between stages for fixed costs.
            add_to_expression!(EP[:eObj], (1 / inputs["OPEXMULT"]), eTotalCNetworkExp)
        else
            add_to_expression!(EP[:eObj], eTotalCNetworkExp)
        end
    end

    ## End Objective Function Expressions ##

    ### Constraints ###

    if MultiStage == 1
        # Linking constraint for existing transmission capacity
        @constraint(EP, cExistingTransCap[l = 1:L], vTRANSMAX[l]==inputs["pTrans_Max"][l])
    end

    # If network expansion is used:
    if NetworkExpansion == 1
        # Transmission network related power flow and capacity constraints
        if MultiStage == 1
            # Constrain maximum possible flow for lines eligible for expansion regardless of previous expansions
            EXPANSION_LINES = inputs["EXPANSION_LINES"]
            @constraint(EP,
                cMaxFlowPossible[l in EXPANSION_LINES],
                eAvail_Trans_Cap[l]<=inputs["pTrans_Max_Possible"][l])
        end
        # Constrain maximum single-stage line capacity reinforcement for lines eligible for expansion
        if haskey(EP, :vNEW_TRANS_CAP)
            EXPANSION_LINES = inputs["EXPANSION_LINES"]
            @constraint(EP,
                cMaxLineReinforcement[l in EXPANSION_LINES],
                vNEW_TRANS_CAP[l]<=inputs["pMax_Line_Reinforcement"][l])
        end
    end
    #END network expansion contraints

end
