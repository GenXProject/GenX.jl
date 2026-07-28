@doc raw"""
    dcopf_transmission!(EP::Model, inputs::Dict, setup::Dict)
The addtional constraints imposed upon the line flows in the case of DC-OPF are as follows:
For the definition of the line flows, in terms of the voltage phase angles:
```math
\begin{aligned}
        & \Phi_{l,t}=\mathcal{B}_{l} \times (\sum_{z\in \mathcal{Z}}{(\varphi^{map}_{l,z} \times \theta_{z,t})}) \quad \forall l \in \mathcal{L}, \; \forall t  \in \mathcal{T}\\
\end{aligned}
```
For imposing the constraint of maximum allowed voltage phase angle difference across lines:
```math
\begin{aligned}
    & \sum_{z\in \mathcal{Z}}{(\varphi^{map}_{l,z} \times \theta_{z,t})} \leq \Delta \theta^{\max}_{l} \quad \forall l \in \mathcal{L}, \forall t  \in \mathcal{T}\\
	& \sum_{z\in \mathcal{Z}}{(\varphi^{map}_{l,z} \times \theta_{z,t})} \geq -\Delta \theta^{\max}_{l} \quad \forall l \in \mathcal{L}, \forall t  \in \mathcal{T}\\
\end{aligned}
```
Finally, we enforce the reference voltage phase angle constraint (for the slack bus/reference bus):
```math
\begin{aligned}
\theta_{1,t} = 0 \quad \forall t  \in \mathcal{T}
\end{aligned}
```

"""
function dcopf_transmission!(EP::Model, inputs::Dict, setup::Dict)
    println("DC-OPF Module")
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones
    L = inputs["L"]     # Number of transmission lines

    if haskey(inputs, "CANDIDATE_LINES") ? length(inputs["CANDIDATE_LINES"]) == 0 : true
        ### DC-OPF variables ###

        # Voltage angle variables of each zone "z" at hour "t" 
        @variable(EP, vANGLE[z = 1:Z, t = 1:T])

        ### DC-OPF constraints ###

        # Power flow constraint:: vFLOW = DC_OPF_coeff * (vANGLE[START_ZONE] - vANGLE[END_ZONE])
        @constraint(EP,
            cPOWER_FLOW_OPF[l = 1:L, t = 1:T],
            EP[:vFLOW][l,
                t]==inputs["pDC_OPF_coeff"][l] *
                    sum(inputs["pNet_Map"][l, z] * vANGLE[z, t] for z in 1:Z))

        # Bus angle limits (except slack bus)
        @constraints(EP,
            begin
                cANGLE_ub[l = 1:L, t = 1:T],
                sum(inputs["pNet_Map"][l, z] * vANGLE[z, t] for z in 1:Z) <=
                inputs["Line_Angle_Limit"][l]
                cANGLE_lb[l = 1:L, t = 1:T],
                sum(inputs["pNet_Map"][l, z] * vANGLE[z, t] for z in 1:Z) >=
                -inputs["Line_Angle_Limit"][l]
            end)

        # Slack Bus angle limit
        @constraint(EP, cANGLE_SLACK[t = 1:T], vANGLE[1, t]==0)
    else
        L_cand = inputs["L_cand"]     # Number of candidate transmission lines
        L_exist = inputs["L_exist"]
        Z_cand = inputs["Z_cand"]     # Number of candidate zones
        NetworkExpansion = setup["NetworkExpansion"]
        quant_val = inputs["Line_Reinforcement_Cap_Size"]

        if haskey(inputs, "BigM")
            if length(inputs["BigM"]) == inputs["L"]
                BigM = inputs["BigM"]
            else
                BigM = zeros((L_exist + L_cand))
                BigM[1:L_exist] .= inputs["pTrans_Max"][1:L_exist] .* 10
                BigM[(1+L_exist):(L_exist+L_cand)] .= inputs["Line_Reinforcement_Cap_Size"][(1+L_exist):(L_exist+L_cand)] .* 10
            end
        else    
            BigM = zeros((L_exist + L_cand))
            BigM[1:L_exist] .= inputs["pTrans_Max"][1:L_exist] .* 10
            BigM[(1+L_exist):(L_exist+L_cand)] .= inputs["Line_Reinforcement_Cap_Size"][(1+L_exist):(L_exist+L_cand)] .* 10
        end

        inputs["BigM"] = BigM

        if NetworkExpansion == 1
            # Network lines and zones that are expandable have non-negative maximum reinforcement inputs
            CANDIDATE_LINES = inputs["CANDIDATE_LINES"]
            EXPANSION_LEVELS = inputs["EXPANSION_LEVELS"]
            if setup["DC_OPF"] == 1
                if setup["ptdf"] == 1
                    line_map = Dict()
                    cand_line_map = Dict()

                    line_adj = inputs["pNet_Map"]
                    for i in 1:size(line_adj)[1]
                        from_idx = findfirst(x -> x == 1, line_adj[i, :])
                        to_idx = findfirst(x -> x == -1, line_adj[i, :])
                        line_map[i] = (from_idx, to_idx)
                    end

                    inputs["Line_Map"] = line_map
                end
            end

            existing_corridor_set = Set()
            for i in 1:inputs["L_exist"]
                from_idx = findfirst(x -> x == 1, inputs["pNet_Map"][i, :])
                to_idx = findfirst(x -> x == -1, inputs["pNet_Map"][i, :])
                push!(existing_corridor_set, (from_idx, to_idx))
                push!(existing_corridor_set, (to_idx, from_idx))
            end
            NEW_CORRIDOR_LINES = []
            for i in CANDIDATE_LINES
                from_idx = findfirst(x -> x == 1, inputs["pNet_Map"][i, :])
                to_idx = findfirst(x -> x == -1, inputs["pNet_Map"][i, :])
                if !((from_idx, to_idx) in existing_corridor_set)
                    push!(NEW_CORRIDOR_LINES, i)
                end
            end
        end

        if setup["ptdf"] == 1 && setup["bilinear"] == 0 #PTDF constraints
            ### DC-OPF variables ###
            # Note, these are definable without overwriting the existing variables in the model because transmission.jl is not called when this file is called.
            # Power flow on each existing transmission line "l" at hour "t"
            @variable(EP, vFLOW[l = 1:L_exist, t = 1:T])

            # Power flow on each candidate transmission line "l" at hour "t"
            @variable(EP, vCANDFLOW[l in CANDIDATE_LINES, t = 1:T])

            ptdf_by_line = calculate_ptdf_matrices(inputs) #TODO: Add slack bus to inputs if we go this route of doing ptdf
            inputs["ptdf_by_line"] = ptdf_by_line
            create_empty_expression!(EP, :eInterzonalFlows, (Z, T))

            if haskey(inputs, "node_to_timeseries")
                scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
                node_to_timeseries = inputs["node_to_timeseries"]
                connected_nodes = sort(collect(keys(node_to_timeseries)))
                voll = inputs["Voll"][1]
                @variable(EP, vINTERZONAL_SLACK_UP[1:length(connected_nodes), 1:T] >= 0)
                @variable(EP, vINTERZONAL_SLACK_DOWN[1:length(connected_nodes), 1:T] >= 0)

                #create empty expression for interzonal; add to cBUS_INJECTION

                for (i, k) in enumerate(connected_nodes)
                    for t in 1:T
                        add_to_expression!(EP[:eInterzonalFlows][k, t], node_to_timeseries[k][t])
                        add_to_expression!(EP[:eInterzonalFlows][k, t], vINTERZONAL_SLACK_UP[i, t] - vINTERZONAL_SLACK_DOWN[i,t])
                        add_to_expression!(EP[:eObj], voll * 1e2 * (vINTERZONAL_SLACK_UP[i, t] + vINTERZONAL_SLACK_DOWN[i,t]))
                    end
                end
            end

            @variable(EP, p_bus[1:Z, 1:T])
            @constraint(EP, cBUS_INJECTION[z = 1:Z, t = 1:T], p_bus[z, t] == EP[:eGenerationByZone][z, t] + EP[:eInterzonalFlows][z, t] + sum(EP[:vNSE][:, t, z]) - inputs["pD"][t, z])

            @constraint(EP, SYSTEM_BALANCE[t = 1:T], sum(p_bus[z, t] for z in 1:Z) == 0)

            CAN_RETIRE_LINES = inputs["CAN_RETIRE_LINES"]
            CANNOT_RETIRE_LINES = inputs["CANNOT_RETIRE_LINES"]
            existing_to_cand_map = inputs["existing_to_cand_map"]
            line_map = inputs["Line_Map"]

            PVIRTUAL_LINES = union(CAN_RETIRE_LINES, CANDIDATE_LINES)
            @variable(EP, p_virtual[l in PVIRTUAL_LINES, t in 1:T])

            @expression(EP, 
                eFLOW_LINES[l in 1:L_exist, t in 1:T],
                sum(get_ptdf_vector(ptdf_by_line, l, line_map)[z] * p_bus[z, t] for z in 1:Z) + 
                sum(
                    (get_ptdf_line_diff(ptdf_by_line, l, ll, line_map)) * p_virtual[ll, t] 
                    for ll in PVIRTUAL_LINES
                )
            )

            for l in CAN_RETIRE_LINES
                for t in 1:T
                    add_to_expression!(eFLOW_LINES[l, t], - p_virtual[l, t])
                end
            end

            F_existing = inputs["pTrans_Max"]
            @constraints(EP,
            begin
                cMaxFlow_out_existing[l = 1:L_exist, t = 1:T], eFLOW_LINES[l, t] <= EP[:eAvail_Trans_Cap][l]
                cMaxFlow_in_existing[l = 1:L_exist, t = 1:T], eFLOW_LINES[l, t] >= -EP[:eAvail_Trans_Cap][l]
            end
            )

            @expression(EP, 
                eCAND_FLOW_LINES[l in CANDIDATE_LINES, t in 1:T],
                p_virtual[l, t] -
                sum(get_ptdf_vector(ptdf_by_line, l, line_map)[z] * p_bus[z, t] for z in 1:Z) - 
                sum(get_ptdf_line_diff(ptdf_by_line, l, ll, line_map) * p_virtual[ll, t] for ll in PVIRTUAL_LINES)
            )


            # Candidate lines
            F_cand = inputs["Line_Reinforcement_Cap_Size"]
            @constraint(EP, 
                cCAND_LINE_FLOWS_LOWER[l in CANDIDATE_LINES, t in 1:T],
                eCAND_FLOW_LINES[l, t] >= -F_cand[l] * EP[:vNEW_TRANS_CAP_DECISION_INT][l]
            ) # 19 for existing lines in paper https://ietresearch.onlinelibrary.wiley.com/doi/epdf/10.1049/iet-gtd.2015.1573

            @constraint(EP, 
                cCAND_LINE_FLOWS_UPPER[l in CANDIDATE_LINES, t in 1:T],
                eCAND_FLOW_LINES[l, t] <= F_cand[l] * EP[:vNEW_TRANS_CAP_DECISION_INT][l]
            ) # 19 for existing lines in paper https://ietresearch.onlinelibrary.wiley.com/doi/epdf/10.1049/iet-gtd.2015.1573
            
            M = 4 .* F_cand
            @constraint(EP, 
                cBIGM_PTDF_LOWER[l in CANDIDATE_LINES, t in 1:T],
                p_virtual[l, t] >= -M[l] * (1 - EP[:vNEW_TRANS_CAP_DECISION_INT][l])
            ) # 20 for existing lines in paper https://ietresearch.onlinelibrary.wiley.com/doi/epdf/10.1049/iet-gtd.2015.1573

            @constraint(EP, 
                cBIGM_PTDF_UPPER[l in CANDIDATE_LINES, t in 1:T],
                p_virtual[l, t] <= M[l] * (1 - EP[:vNEW_TRANS_CAP_DECISION_INT][l])
            ) # 20 for existing lines in paper https://ietresearch.onlinelibrary.wiley.com/doi/epdf/10.1049/iet-gtd.2015.1573


            # Retirement Lines
            F_exist = inputs["pTrans_Max"] * 2
            @constraint(EP, 
                cEXIST_LINE_FLOWS_LOWER[l in CAN_RETIRE_LINES, t in 1:T],
                eFLOW_LINES[l, t] >= -F_exist[l] * (1-EP[:vNEW_TRANS_CAP_DECISION_INT][existing_to_cand_map[l]])
            ) # 19 for existing lines in paper https://ietresearch.onlinelibrary.wiley.com/doi/epdf/10.1049/iet-gtd.2015.1573

            @constraint(EP, 
                cEXIST_LINE_FLOWS_UPPER[l in CAN_RETIRE_LINES, t in 1:T],
                eFLOW_LINES[l, t] <= F_exist[l] * (1-EP[:vNEW_TRANS_CAP_DECISION_INT][existing_to_cand_map[l]])
            ) # 19 for existing lines in paper https://ietresearch.onlinelibrary.wiley.com/doi/epdf/10.1049/iet-gtd.2015.1573
            
            M = 4 .* F_exist
            @constraint(EP, 
                cBIGM_PTDF_LOWER_RETIRE[l in CAN_RETIRE_LINES, t in 1:T],
                p_virtual[l, t] >= -M[l] * (EP[:vNEW_TRANS_CAP_DECISION_INT][existing_to_cand_map[l]])
            ) # 20 for existing lines in paper https://ietresearch.onlinelibrary.wiley.com/doi/epdf/10.1049/iet-gtd.2015.1573

            @constraint(EP, 
                cBIGM_PTDF_UPPER_RETIRE[l in CAN_RETIRE_LINES, t in 1:T],
                p_virtual[l, t] <= M[l] * (EP[:vNEW_TRANS_CAP_DECISION_INT][existing_to_cand_map[l]])
            ) # 20 for existing lines in paper https://ietresearch.onlinelibrary.wiley.com/doi/epdf/10.1049/iet-gtd.2015.1573


            @constraint(EP, [l in 1:L_exist, t in 1:T],
                EP[:vFLOW][l, t] == eFLOW_LINES[l, t]
            )

            #TODO: Add EP[:eAvail_Trans_Cap][l] upper and loewr limits on lines like Btheta

            @constraint(EP, [l in CANDIDATE_LINES, t in 1:T],
                EP[:vCANDFLOW][l, t] == -p_virtual[l, t] + sum(get_ptdf_vector(ptdf_by_line, l, line_map)[z] * p_bus[z, t] for z in 1:Z) + 
                sum(get_ptdf_line_diff(ptdf_by_line, l, ll, line_map) * p_virtual[ll, t] for ll in PVIRTUAL_LINES)
            )

            @expression(EP,
            eCand_Flow[l in CANDIDATE_LINES, t = 1:T], EP[:vCANDFLOW][l, t])

            @expression(EP,
                eNet_Export_Cand_Flows[z = 1:Z, t = 1:T],
                sum(inputs["pNet_Map"][l, z] * EP[:vCANDFLOW][l, t] for l in CANDIDATE_LINES))
        elseif setup["bilinear"] == 1 && setup["ptdf"] == 1
            # Note, these are definable without overwriting the existing variables in the model because transmission.jl is not called when this file is called.
            # Power flow on each existing transmission line "l" at hour "t"
            @variable(EP, vFLOW[l = 1:L_exist, t = 1:T])

            # Power flow on each candidate transmission line "l" at hour "t"
            @variable(EP, vCANDFLOW[l in CANDIDATE_LINES, t = 1:T])

            ptdf_by_line = calculate_ptdf_matrices(inputs) #TODO: Add slack bus to inputs if we go this route of doing ptdf
            inputs["ptdf_by_line"] = ptdf_by_line
            create_empty_expression!(EP, :eInterzonalFlows, (Z, T))
            
            if haskey(inputs, "node_to_timeseries")
                scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
                node_to_timeseries = inputs["node_to_timeseries"]
                connected_nodes = sort(collect(keys(node_to_timeseries)))
                voll = inputs["Voll"][1]
                @variable(EP, vINTERZONAL_SLACK_UP[1:length(connected_nodes), 1:T] >= 0)
                @variable(EP, vINTERZONAL_SLACK_DOWN[1:length(connected_nodes), 1:T] >= 0)

                #create empty expression for interzonal; add to cBUS_INJECTION

                for (i, k) in enumerate(connected_nodes)
                    for t in 1:T
                        add_to_expression!(EP[:eInterzonalFlows][k, t], node_to_timeseries[k][t])
                        add_to_expression!(EP[:eInterzonalFlows][k, t], vINTERZONAL_SLACK_UP[i, t] - vINTERZONAL_SLACK_DOWN[i,t])
                        add_to_expression!(EP[:eObj], voll * 1e2 * (vINTERZONAL_SLACK_UP[i, t] + vINTERZONAL_SLACK_DOWN[i,t]))
                    end
                end
            end

            @variable(EP, p_bus[1:Z, 1:T])
            @constraint(EP, cBUS_INJECTION[z = 1:Z, t = 1:T], p_bus[z, t] == EP[:eGenerationByZone][z, t] + EP[:eInterzonalFlows][z, t] + sum(EP[:vNSE][:, t, z]) - inputs["pD"][t, z])

            @constraint(EP, SYSTEM_BALANCE[t = 1:T], sum(p_bus[z, t] for z in 1:Z) == 0)
            
            CAN_RETIRE_LINES = inputs["CAN_RETIRE_LINES"]
            CANNOT_RETIRE_LINES = inputs["CANNOT_RETIRE_LINES"]
            existing_to_cand_map = inputs["existing_to_cand_map"]
            line_map = inputs["Line_Map"]

            
            PVIRTUAL_LINES = union(CAN_RETIRE_LINES, CANDIDATE_LINES)
            @variable(EP, p_virtual[l in PVIRTUAL_LINES, t in 1:T])
            @variable(EP, vPTDF_BILINEAR[l in PVIRTUAL_LINES, t in 1:T])

            @constraint(EP, cPTDF_BILINEAR_CANDIDATES[l in CANDIDATE_LINES, t in 1:T],
                    (1 - EP[:vNEW_TRANS_CAP_DECISION_INT][l]) * p_virtual[l, t] == vPTDF_BILINEAR[l, t]
            )
            @constraint(EP, cPTDF_BILINEAR_CAN_RETIRE[l in CAN_RETIRE_LINES, t in 1:T],
                    (EP[:vNEW_TRANS_CAP_DECISION_INT][existing_to_cand_map[l]]) * p_virtual[l, t] == vPTDF_BILINEAR[l, t]
            )

            @constraint(EP, 
                cFLOW_LINES_CANNOT_RETIRE[l in CANNOT_RETIRE_LINES, t in 1:T],
                vFLOW[l, t] == sum(get_ptdf_vector(ptdf_by_line, l, line_map)[z] * p_bus[z, t] for z in 1:Z) + 
                sum(
                    (get_ptdf_line_diff(ptdf_by_line, l, ll, line_map)) * vPTDF_BILINEAR[ll, t] 
                    for ll in PVIRTUAL_LINES
                )
            )

            @constraint(EP, 
                cFLOW_LINES_CAN_RETIRE[l in CAN_RETIRE_LINES, t in 1:T],
                vFLOW[l, t] + vPTDF_BILINEAR[l, t] == sum(get_ptdf_vector(ptdf_by_line, l, line_map)[z] * p_bus[z, t] for z in 1:Z) + 
                sum(
                    (get_ptdf_line_diff(ptdf_by_line, l, ll, line_map)) * vPTDF_BILINEAR[ll, t] 
                    for ll in PVIRTUAL_LINES
                )
            )

            @constraint(EP, 
                cCANDFLOW_LINES[l in CANDIDATE_LINES, t in 1:T],
                vCANDFLOW[l, t] == sum(get_ptdf_vector(ptdf_by_line, l, line_map)[z] * p_bus[z, t] for z in 1:Z) + 
                sum(
                    (get_ptdf_line_diff(ptdf_by_line, l, ll, line_map)) * vPTDF_BILINEAR[ll, t] 
                    for ll in PVIRTUAL_LINES
                )
            )

            F_existing = inputs["pTrans_Max"]
            @constraints(EP,
                begin
                    cMaxFlow_out_existing[l = 1:L_exist, t = 1:T], vFLOW[l, t] <= EP[:eAvail_Trans_Cap][l]
                    cMaxFlow_in_existing[l = 1:L_exist, t = 1:T], vFLOW[l, t] >= -EP[:eAvail_Trans_Cap][l]
                end
            )

            # Candidate lines
            F_cand = inputs["Line_Reinforcement_Cap_Size"]
            @constraint(EP, 
                cCAND_LINE_FLOWS_LOWER[l in CANDIDATE_LINES, t in 1:T],
                vPTDF_BILINEAR[l, t] - vCANDFLOW[l, t] >= -F_cand[l] * EP[:vNEW_TRANS_CAP_DECISION_INT][l]
            )

            @constraint(EP, 
                cCAND_LINE_FLOWS_UPPER[l in CANDIDATE_LINES, t in 1:T],
                vPTDF_BILINEAR[l, t] - vCANDFLOW[l, t] <= F_cand[l] * EP[:vNEW_TRANS_CAP_DECISION_INT][l]
            ) 
        
            M = 10 .* F_existing
            @constraint(EP, 
                cBIGM_PTDF_LOWER_RETIRE_FLOW[l in CAN_RETIRE_LINES, t in 1:T],
                vFLOW[l, t] >= -M[l] * (1 - EP[:vNEW_TRANS_CAP_DECISION_INT][existing_to_cand_map[l]])
            ) 

            @constraint(EP, 
                cBIGM_PTDF_UPPER_RETIRE_FLOW[l in CAN_RETIRE_LINES, t in 1:T],
                vFLOW[l, t] <= M[l] * (1 - EP[:vNEW_TRANS_CAP_DECISION_INT][existing_to_cand_map[l]])
            )
            

            @expression(EP,
            eCand_Flow[l in CANDIDATE_LINES, t = 1:T], EP[:vCANDFLOW][l, t])

            @expression(EP,
                eNet_Export_Cand_Flows[z = 1:Z, t = 1:T],
                sum(inputs["pNet_Map"][l, z] * EP[:vCANDFLOW][l, t] for l in CANDIDATE_LINES))

        elseif setup["bilinear"] == 1
            CANDIDATE_LINES = inputs["CANDIDATE_LINES"]
            EXISTING_LINES = inputs["EXISTING_LINES"]
            CAN_RETIRE_LINES = inputs["CAN_RETIRE_LINES"]
            CANNOT_RETIRE_LINES = inputs["CANNOT_RETIRE_LINES"]

            existing_to_cand_map = inputs["existing_to_cand_map"]

            @variable(EP, vFLOW[l = EXISTING_LINES, t = 1:T])
            @variable(EP, vCANDFLOW[l in CANDIDATE_LINES, t = 1:T])
            
            # Voltage angle variables of each zone "z" at hour "t" 
            @variable(EP, vANGLE[z = 1:Z, t = 1:T])

            @constraint(EP,
                cPOWER_FLOW_OPF_NONRETIRE[l in CANNOT_RETIRE_LINES, t = 1:T],
                EP[:vFLOW][l, t]==inputs["pDC_OPF_coeff"][l] *
                        sum(inputs["pNet_Map"][l, z] * vANGLE[z, t] for z in 1:Z))

            @constraint(EP,
                cPOWER_FLOW_OPF_RETIRE[l in CAN_RETIRE_LINES, t = 1:T],
                EP[:vFLOW][l, t]==inputs["pDC_OPF_coeff"][l] *
                        sum(inputs["pNet_Map"][l, z] * vANGLE[z, t] for z in 1:Z) * (1 - EP[:vNEW_TRANS_CAP_DECISION_INT][existing_to_cand_map[l]]))

            @constraint(EP,
                cCANDFLOW[l in CANDIDATE_LINES, t = 1:T],
                vCANDFLOW[l, t] == inputs["pDC_OPF_coeff"][l] *
                            sum(inputs["pNet_Map"][l, z] * vANGLE[z, t] for z in 1:Z) * EP[:vNEW_TRANS_CAP_DECISION_INT][l]
            )

            @constraints(EP,
            begin
                cMaxFlow_out_existing[l = 1:L_exist, t = 1:T], EP[:vFLOW][l, t] <= EP[:eAvail_Trans_Cap][l]
                cMaxFlow_in_existing[l = 1:L_exist, t = 1:T], EP[:vFLOW][l, t] >= -EP[:eAvail_Trans_Cap][l]
            end
            )

            # Slack Bus angle limit
            @constraint(EP, cANGLE_SLACK[t = 1:T], vANGLE[1, t]==0)
            
            @expression(EP,
            eCand_Flow[l in CANDIDATE_LINES, t = 1:T],
            EP[:vCANDFLOW][l, t])

            @expression(EP,
                eNet_Export_Cand_Flows[z = 1:Z, t = 1:T],
                sum(inputs["pNet_Map"][l, z] * EP[:eCand_Flow][l, t] for l in CANDIDATE_LINES))


            @constraints(EP,
            begin
                cMaxFlow_out_candidate[l in CANDIDATE_LINES, t = 1:T], EP[:vCANDFLOW][l, t] <= inputs["Line_Reinforcement_Cap_Size"][l]
                cMaxFlow_in_candidate[l in CANDIDATE_LINES, t = 1:T], EP[:vCANDFLOW][l, t] >= -inputs["Line_Reinforcement_Cap_Size"][l]
            end)

            # Bus angle limits
            @constraints(EP,
                begin
                    cANGLE_ub[l in EXISTING_LINES, t = 1:T],
                    sum(inputs["pNet_Map"][l, z] * vANGLE[z, t] for z in 1:Z) <=
                    inputs["Line_Angle_Limit"][l]
                    cANGLE_lb[l in EXISTING_LINES, t = 1:T],
                    sum(inputs["pNet_Map"][l, z] * vANGLE[z, t] for z in 1:Z) >=
                    -inputs["Line_Angle_Limit"][l]
                end)
            
            M_angle = 2 * pi
            @constraints(EP, 
                begin
                    cANGLE_new_corridor_ub[l in NEW_CORRIDOR_LINES, t = 1:T],
                    sum(inputs["pNet_Map"][l, z] * vANGLE[z, t] for z in 1:Z) <=
                    inputs["Line_Angle_Limit"][l] + M_angle * (1 - EP[:vNEW_TRANS_CAP_DECISION_INT][l])
                    cANGLE_new_corridor_lb[l in NEW_CORRIDOR_LINES, t = 1:T],
                    sum(inputs["pNet_Map"][l, z] * vANGLE[z, t] for z in 1:Z) >=
                    -inputs["Line_Angle_Limit"][l] - M_angle * (1 - EP[:vNEW_TRANS_CAP_DECISION_INT][l])
                end)
        else
            ### DC-OPF variables ###
            # Note, these are definable without overwriting the existing variables in the model because transmission.jl is not called when this file is called.
            # Power flow on each existing transmission line "l" at hour "t"
            CANDIDATE_LINES = inputs["CANDIDATE_LINES"]
            EXISTING_LINES = inputs["EXISTING_LINES"]
            CAN_RETIRE_LINES = inputs["CAN_RETIRE_LINES"]
            CANNOT_RETIRE_LINES = inputs["CANNOT_RETIRE_LINES"]
            existing_to_cand_map = inputs["existing_to_cand_map"]

            @variable(EP, vFLOW[l in EXISTING_LINES, t = 1:T])
            # Power flow on each candidate transmission line "l" at hour "t"
            @variable(EP, vCANDFLOW[l in CANDIDATE_LINES, t = 1:T])

            # Voltage angle variables of each zone "z" at hour "t" 
            @variable(EP, vANGLE[z = 1:Z, t = 1:T])

            @variable(EP, slack_vFLOW[l in CANNOT_RETIRE_LINES, t = 1:T])
            @variable(EP, slackup_vFLOW[l in CAN_RETIRE_LINES, t = 1:T])
            @variable(EP, slackdown_vFLOW[l in CAN_RETIRE_LINES, t = 1:T])
            @variable(EP, slackup_vCANDFLOW[l in CANDIDATE_LINES, t = 1:T])
            @variable(EP, slackdown_vCANDFLOW[l in CANDIDATE_LINES, t = 1:T])

            if haskey(setup, "unfix_slacks")
                if setup["unfix_slacks"] == 0
                    for var in EP[:slack_vFLOW]
                        fix(var, 0, force = true)
                    end
                    for var in EP[:slackup_vFLOW]
                        fix(var, 0, force = true)
                    end
                    for var in EP[:slackdown_vFLOW]
                        fix(var, 0, force = true)
                    end
                    for var in EP[:slackup_vCANDFLOW]
                        fix(var, 0, force = true)
                    end
                    for var in EP[:slackdown_vCANDFLOW]
                        fix(var, 0, force = true)
                    end
                end
            end

            ### DC-OPF constraints ###

            # Power flow constraint existing lines:: vFLOW = DC_OPF_coeff * (vANGLE[START_ZONE] - vANGLE[END_ZONE])
            @constraint(EP,
                cPOWER_FLOW_OPF_NONRETIRE[l in CANNOT_RETIRE_LINES, t = 1:T],
                EP[:vFLOW][l,
                    t]==inputs["pDC_OPF_coeff"][l] *
                        sum(inputs["pNet_Map"][l, z] * vANGLE[z, t] for z in 1:Z) + slack_vFLOW[l, t])


            @constraint(EP,
                cPOWER_FLOW_OPF_RETIRE_FORWARD[l in CAN_RETIRE_LINES, t = 1:T],
                EP[:vFLOW][l, t] - inputs["pDC_OPF_coeff"][l] * sum(inputs["pNet_Map"][l, z] * vANGLE[z, t] for z in 1:Z) + slackup_vFLOW[l,t] <= BigM[l] * (EP[:vNEW_TRANS_CAP_DECISION_INT][existing_to_cand_map[l]]))

            @constraint(EP,
                cPOWER_FLOW_OPF_RETIRE_REVERSE[l in CAN_RETIRE_LINES, t = 1:T],
                EP[:vFLOW][l, t] - inputs["pDC_OPF_coeff"][l] * sum(inputs["pNet_Map"][l, z] * vANGLE[z, t] for z in 1:Z) + slackdown_vFLOW[l,t] >= -BigM[l] * (EP[:vNEW_TRANS_CAP_DECISION_INT][existing_to_cand_map[l]]))



            #Power Flow in the candidate expansion lines
            @constraint(EP,
                cPOWER_FLOW_OPF_EXPANSION_FORWARD[l in CANDIDATE_LINES, t = 1:T],
                    EP[:vCANDFLOW][l,t]-inputs["pDC_OPF_coeff"][l] *
                            sum(inputs["pNet_Map"][l, z] * vANGLE[z, t] for z in 1:Z) + slackup_vCANDFLOW[l,t] <= BigM[l]*(1-EP[:vNEW_TRANS_CAP_DECISION_INT][l]))
            @constraint(EP,
                cPOWER_FLOW_OPF_EXPANSION_REVERSE[l in CANDIDATE_LINES, t = 1:T],
                    EP[:vCANDFLOW][l,t]-inputs["pDC_OPF_coeff"][l] *
                            sum(inputs["pNet_Map"][l, z] * vANGLE[z, t] for z in 1:Z) + slackdown_vCANDFLOW[l,t] >= -BigM[l]*(1-EP[:vNEW_TRANS_CAP_DECISION_INT][l]))



            @constraints(EP,
            begin
                cMaxFlow_out_existing[l = 1:L_exist, t = 1:T], EP[:vFLOW][l, t] <= EP[:eAvail_Trans_Cap][l]
                cMaxFlow_in_existing[l = 1:L_exist, t = 1:T], EP[:vFLOW][l, t] >= -EP[:eAvail_Trans_Cap][l]
            end)


            # Slack Bus angle limit
            @constraint(EP, cANGLE_SLACK[t = 1:T], vANGLE[1, t]==0)

            @expression(EP,
            eCand_Flow[l in CANDIDATE_LINES, t = 1:T],
            EP[:vCANDFLOW][l,t])

            @expression(EP,
                eNet_Export_Cand_Flows[z = 1:Z, t = 1:T],
                sum(inputs["pNet_Map"][l, z] * EP[:eCand_Flow][l, t] for l in CANDIDATE_LINES))

            @constraints(EP,
            begin
                cMaxFlow_out_candidate[l in CANDIDATE_LINES, t = 1:T], EP[:vCANDFLOW][l, t] <= EP[:vNEW_TRANS_CAP_DECISION_INT][l]*inputs["Line_Reinforcement_Cap_Size"][l]
                cMaxFlow_in_candidate[l in CANDIDATE_LINES, t = 1:T], EP[:vCANDFLOW][l, t] >= -EP[:vNEW_TRANS_CAP_DECISION_INT][l]*inputs["Line_Reinforcement_Cap_Size"][l]
            end)

            
            @constraint(EP, 
                cCAN_RETIRE_UPPER_LIMIT[l in CAN_RETIRE_LINES, t = 1:T], EP[:vFLOW][l, t] <= BigM[l] * (1 - EP[:vNEW_TRANS_CAP_DECISION_INT][existing_to_cand_map[l]])
            )

            @constraint(EP, 
                cCAN_RETIRE_LOWER_LIMIT[l in CAN_RETIRE_LINES, t = 1:T], EP[:vFLOW][l, t] >= -BigM[l] * (1 - EP[:vNEW_TRANS_CAP_DECISION_INT][existing_to_cand_map[l]])
            )

            # Bus angle limits
            @constraints(EP,
                begin
                    cANGLE_ub[l in EXISTING_LINES, t = 1:T],
                    sum(inputs["pNet_Map"][l, z] * vANGLE[z, t] for z in 1:Z) <=
                    inputs["Line_Angle_Limit"][l]
                    cANGLE_lb[l in EXISTING_LINES, t = 1:T],
                    sum(inputs["pNet_Map"][l, z] * vANGLE[z, t] for z in 1:Z) >=
                    -inputs["Line_Angle_Limit"][l]
                end)
            
            M_angle = 2 * pi
            @constraints(EP, 
                begin
                    cANGLE_new_corridor_ub[l in NEW_CORRIDOR_LINES, t = 1:T],
                    sum(inputs["pNet_Map"][l, z] * vANGLE[z, t] for z in 1:Z) <=
                    inputs["Line_Angle_Limit"][l] + M_angle * (1 - EP[:vNEW_TRANS_CAP_DECISION_INT][l])
                    cANGLE_new_corridor_lb[l in NEW_CORRIDOR_LINES, t = 1:T],
                    sum(inputs["pNet_Map"][l, z] * vANGLE[z, t] for z in 1:Z) >=
                    -inputs["Line_Angle_Limit"][l] - M_angle * (1 - EP[:vNEW_TRANS_CAP_DECISION_INT][l])
                end)
            
        end
        EXISTING_LINES = inputs["EXISTING_LINES"]
        @expression(EP,
            eNet_Export_Flows[z = 1:Z, t = 1:T],
            sum(inputs["pNet_Map"][l, z] * EP[:vFLOW][l, t] for l in EXISTING_LINES))

        # Export and import expressions
        @expression(EP, ePowerBalanceNetExportFlows[t = 1:T, z = 1:Z],
            -eNet_Export_Flows[z, t])
        @expression(EP, ePowerBalanceCandExportFlows[t = 1:T, z = 1:Z],
            -eNet_Export_Cand_Flows[z, t])

        add_similar_to_expression!(EP[:ePowerBalance], ePowerBalanceCandExportFlows)
        add_similar_to_expression!(EP[:ePowerBalance], ePowerBalanceNetExportFlows)
    end
end
