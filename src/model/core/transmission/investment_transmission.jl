@doc raw"""
    investment_transmission!(EP::Model, inputs::Dict, setup::Dict)
This function model transmission expansion and adds transmission reinforcement or construction costs to the objective function. Transmission reinforcement costs are equal to the sum across all lines of the product between the transmission reinforcement/construction cost, $\pi^{TCAP}_{l}$, times the additional transmission capacity variable, $\bigtriangleup\varphi^{cap}_{l}$. 
For asymmetric bidirectional flows, the reinforcement costs are equal to the sum across all lines of the product between the transmission reinforcement/construction costs for the onward and return directions, $\pi^{TCAP+}_{l}$ and $\pi^{TCAP-}_{l}$, respectively, times the additional transmission capacity variables, $\bigtriangleup\varphi^{cap+}_{l}$ and $\bigtriangleup\varphi^{cap-}_{l}$
```math
\begin{aligned}
    & \sum_{l \in \mathcal{L}}\left(\pi^{TCAP}_{l} \times \bigtriangleup\varphi^{cap}_{l}\right)
\end{aligned}
```
For asymmetric bidirectional lines

```math
\begin{aligned}
    & \sum_{l \in \mathcal{L_{asym}}}\left(\pi^{TCAP+}_{l} \times \bigtriangleup\varphi^{cap+}_{l}\right)
\end{aligned}
```

and 

```math
\begin{aligned}
    & \sum_{l \in \mathcal{L_{asym}}}\left(\pi^{TCAP-}_{l} \times \bigtriangleup\varphi^{cap-}_{l}\right)
\end{aligned}
```

Note that fixed O\&M and replacement capital costs (depreciation) for existing transmission capacity is treated as a sunk cost and not included explicitly in the GenX objective function.

**Accounting for Transmission Between Zones**

Available transmission capacity between zones is set equal to the existing line's maximum power transfer capacity, $\overline{\varphi^{cap}_{l}}$ ($\overline{\varphi^{cap+}_{l}}$ 
and $\overline{\varphi^{cap-}_{l}}$ for positive and negative directions, respectively, for asymmetrical lines), plus any transmission capacity added on that line (for lines eligible for expansion in the set $\mathcal{E}$). 
```math
\begin{aligned}
    &\varphi^{cap}_{l} = \overline{\varphi^{cap}_{l}} , &\quad \forall l \in (\mathcal{L} \setminus \mathcal{E} ),\forall t  \in \mathcal{T}\\
    % trasmission expansion
    &\varphi^{cap}_{l} = \overline{\varphi^{cap}_{l}} + \bigtriangleup\varphi^{cap}_{l} , &\quad \forall l \in \mathcal{E},\forall t  \in \mathcal{T}        
\end{aligned}
```
The additional transmission capacity, $\bigtriangleup\varphi^{cap}_{l} $ ($\bigtriangleup\varphi^{cap+}_{l} $ and $\bigtriangleup\varphi^{cap-}_{l} $ respectively for asymmetric lines), 
is constrained by a maximum allowed reinforcement, $\overline{\bigtriangleup\varphi^{cap}_{l}}$ ($\overline{\bigtriangleup\varphi^{cap+}_{l}}$ 
and $\overline{\bigtriangleup\varphi^{cap-}_{l}}$ respectively for asymmetric lines), for each line $l \in \mathcal{E}$.
```math
\begin{aligned}
    & \bigtriangleup\varphi^{cap}_{l}  \leq \overline{\bigtriangleup\varphi^{cap}_{l}}, &\quad \forall l \in \mathcal{E}
\end{aligned}
```
"""
function investment_transmission!(EP::Model, inputs::Dict, setup::Dict)
    println("Investment Transmission Module")

    
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
    

    ### Variables ###

    if MultiStage == 1
        @variable(EP, vTRANSMAX[l in SYMMETRIC_LINE_INDEX]>=0)
        @variable(EP, vTRANSMAX_Pos[l in ASYMMETRIC_LINE_INDEX]>=0)
        @variable(EP, vTRANSMAX_Neg[l in ASYMMETRIC_LINE_INDEX]>=0)
    end

    if NetworkExpansion == 1
        # Transmission network capacity reinforcements per line
        
        #if setup["asymmetrical_trans_flow_limit"] == 1
            @variable(EP, vNEW_TRANS_CAP_Pos[l in EXPANSION_LINES_ASYM]>=0)
            @variable(EP, vNEW_TRANS_CAP_Neg[l in EXPANSION_LINES_ASYM]>=0)
            @variable(EP, vNEW_TRANS_CAP[l in intersect(SYMMETRIC_LINE_INDEX, EXPANSION_LINES)]>=0)
        #else
            #@variable(EP, vNEW_TRANS_CAP[l in EXPANSION_LINES]>=0)
        #end
    end

    ### Expressions ###

    if MultiStage == 1
        @expression(EP, eTransMax[l in SYMMETRIC_LINE_INDEX], vTRANSMAX[l])
        @expression(EP, eTransMax_Pos[l in ASYMMETRIC_LINE_INDEX], vTRANSMAX_Pos[l])
        @expression(EP, eTransMax_Neg[l in ASYMMETRIC_LINE_INDEX], vTRANSMAX_Neg[l])
    else
        @expression(EP, eTransMax_Pos[l in ASYMMETRIC_LINE_INDEX], inputs["pTrans_Max"][l])
        @expression(EP, eTransMax_Neg[l in ASYMMETRIC_LINE_INDEX], inputs["pTrans_Max_Neg"][l])
        @expression(EP, eTransMax[l in SYMMETRIC_LINE_INDEX], inputs["pTrans_Max"][l])
    end

    ## Transmission power flow and loss related expressions:
    # Total availabile maximum transmission capacity is the sum of existing maximum transmission capacity plus new transmission capacity
    if NetworkExpansion == 1
        @expression(EP, eAvail_Trans_Cap[l in SYMMETRIC_LINE_INDEX],
            if l in intersect(SYMMETRIC_LINE_INDEX, EXPANSION_LINES)
                eTransMax[l] + vNEW_TRANS_CAP[l]
            else
                eTransMax[l]
            end)
        @expression(EP, eAvail_Trans_Cap_Pos[l in ASYMMETRIC_LINE_INDEX],
            if l in EXPANSION_LINES_ASYM
                eTransMax_Pos[l] + vNEW_TRANS_CAP_Pos[l]
            else
                eTransMax_Pos[l]
            end)
        @expression(EP, eAvail_Trans_Cap_Neg[l in ASYMMETRIC_LINE_INDEX],
            if l in EXPANSION_LINES_ASYM
                eTransMax_Neg[l] + vNEW_TRANS_CAP_Neg[l]
            else
                eTransMax_Neg[l]
            end)
    else
        @expression(EP, eAvail_Trans_Cap[l in SYMMETRIC_LINE_INDEX], eTransMax[l])
        @expression(EP, eAvail_Trans_Cap_Pos[l in ASYMMETRIC_LINE_INDEX], eTransMax_Pos[l])
        @expression(EP, eAvail_Trans_Cap_Neg[l in ASYMMETRIC_LINE_INDEX], eTransMax_Neg[l])
    end
    ## Objective Function Expressions ##

    if NetworkExpansion == 1
        @expression(EP,
            eTotalCNetworkExp,
            #if setup["asymmetrical_trans_flow_limit"] == 1
                sum(vNEW_TRANS_CAP[l] * inputs["pC_Line_Reinforcement"][l]
                    for l in intersect(SYMMETRIC_LINE_INDEX, EXPANSION_LINES); init = 0) + 
                sum((vNEW_TRANS_CAP_Pos[l] + vNEW_TRANS_CAP_Neg[l]) * inputs["pC_Line_Reinforcement"][l]
                    for l in EXPANSION_LINES_ASYM; init = 0)
            #else
                #sum(vNEW_TRANS_CAP[l] * inputs["pC_Line_Reinforcement"][l]
                    #for l in EXPANSION_LINES; init = 0)
            #end
            )

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
        @constraint(EP, cExistingTransCap[l in SYMMETRIC_LINE_INDEX], vTRANSMAX[l]==inputs["pTrans_Max"][l])
        @constraint(EP, cExistingTransCapPos[l in ASYMMETRIC_LINE_INDEX], vTRANSMAX_Pos[l]==inputs["pTrans_Max_Pos"][l])
        @constraint(EP, cExistingTransCapNeg[l in ASYMMETRIC_LINE_INDEX], vTRANSMAX_Neg[l]==inputs["pTrans_Max_Neg"][l])
    end

    # If network expansion is used:
    if NetworkExpansion == 1
        # Transmission network related power flow and capacity constraints
        if MultiStage == 1
            # Constrain maximum possible flow for lines eligible for expansion regardless of previous expansions
                #if setup["asymmetrical_trans_flow_limit"] == 1
                    @constraint(EP,
                        cMaxFlowPossible[l in intersect(SYMMETRIC_LINE_INDEX, EXPANSION_LINES)],
                        eAvail_Trans_Cap[l]<=inputs["pTrans_Max_Possible"][l])
                    @constraint(EP,
                        cMaxFlowPossible_Pos[l in EXPANSION_LINES_ASYM],
                        eAvail_Trans_Cap_Pos[l]<=inputs["pTrans_Max_Possible"][l])
                    @constraint(EP,
                        cMaxFlowPossible_Neg[l in EXPANSION_LINES_ASYM],
                        eAvail_Trans_Cap_Neg[l]<=inputs["pTrans_Max_Possible_Neg"][l])
                #else
                    #@constraint(EP,
                        #cMaxFlowPossible[l in EXPANSION_LINES],
                        #eAvail_Trans_Cap[l]<=inputs["pTrans_Max_Possible"][l])
                #end
        end
        # Constrain maximum single-stage line capacity reinforcement for lines eligible for expansion
        #if setup["asymmetrical_trans_flow_limit"] == 1
            @constraint(EP,
                cMaxLineReinforcement[l in intersect(SYMMETRIC_LINE_INDEX, EXPANSION_LINES)],
                vNEW_TRANS_CAP[l]<=inputs["pMax_Line_Reinforcement"][l])
            @constraint(EP,
                cMaxLineReinforcement_Pos[l in EXPANSION_LINES_ASYM],
                vNEW_TRANS_CAP_Pos[l]<=inputs["pMax_Line_Reinforcement"][l])
            @constraint(EP,
                cMaxLineReinforcement_Neg[l in EXPANSION_LINES_ASYM],
                vNEW_TRANS_CAP_Neg[l]<=inputs["pMax_Line_Reinforcement_Neg"][l])
        #else
            #@constraint(EP,
                #cMaxLineReinforcement[l in EXPANSION_LINES],
                #vNEW_TRANS_CAP[l]<=inputs["pMax_Line_Reinforcement"][l])
        #end
    end
    #END network expansion contraints

end