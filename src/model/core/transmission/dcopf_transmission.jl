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

    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones
    L = inputs["L"]     # Number of transmission lines

    IntegerInvestments = setup["IntegerInvestments"]
    NetworkExpansion = setup["NetworkExpansion"]

    ### DC-OPF variables ###

    # Voltage angle variables of each zone "z" at hour "t" 
    @variable(EP, vANGLE[z = 1:Z, t = 1:T])

    # Slack Bus angle limit
    @constraint(EP, cANGLE_SLACK[t = 1:T], vANGLE[1, t]==0)

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

    ### DC-OPF constraints ###

    # If there are no integer investments, or if integer investments are on, but newtork expansion is off
    if setup["IntegerInvestments"] == 1 ? !(length(inputs["INTEGER_BUILD_LINES"]) > 0 && NetworkExpansion == 1) : true
        # Power flow constraint:: vFLOW = DC_OPF_coeff * (vANGLE[START_ZONE] - vANGLE[END_ZONE])
        @constraint(EP,
            cPOWER_FLOW_OPF[l = 1:L, t = 1:T],
            EP[:vFLOW][l,
                t]==inputs["pDC_OPF_coeff"][l] *
                    sum(inputs["pNet_Map"][l, z] * vANGLE[z, t] for z in 1:Z))

        # Since lines can expand, make sure the flow is limited by available transmission capacity
        @constraints(EP,
            begin
                cMaxFlow_out_fixed[l in FIXED_LINES, t = 1:T], EP[:vFLOW][l, t] <= EP[:eAvail_Trans_Cap][l]
                cMaxFlow_in_fixed[l in FIXED_LINES, t = 1:T], EP[:vFLOW][l, t] >= -EP[:eAvail_Trans_Cap][l]
            end)

    else
        # Separate lines that are fixed and lines that are new
        FIXED_LINES = setdiff(1:L, inputs["INTEGER_BUILD_LINES"])
        INTEGER_BUILD_LINES = inputs["INTEGER_BUILD_LINES"]
        BigM = inputs["BigM"]

        # Set DC_OPF constraints on the fixed lines
        @constraint(EP,
            cPOWER_FLOW_FIXED_LINES[l in FIXED_LINES, t = 1:T],
            EP[:vFLOW][l,t]==inputs["pDC_OPF_coeff"][l] *
                    sum(inputs["pNet_Map"][l, z] * vANGLE[z, t] for z in 1:Z))

        # Set limits on fixed lines; these lines could potentially be expanded, which expansion is captured by the eAvail_Trans_Cap expression
        @constraints(EP,
            begin
                cMaxFlow_out_fixed[l in FIXED_LINES, t = 1:T], EP[:vFLOW][l, t] <= EP[:eAvail_Trans_Cap][l]
                cMaxFlow_in_fixed[l in FIXED_LINES, t = 1:T], EP[:vFLOW][l, t] >= -EP[:eAvail_Trans_Cap][l]
            end)

        # Set DC_OPF constraints on the new lines; constrained by the binary variable and big M constraint
        # if line is not built, vFLOW is unconstrained; it is fixed to zero by the cMaxFlow_*_new constraint
        @constraint(EP,
            cPOWER_FLOW_BUILD_FORWARD[l in INTEGER_BUILD_LINES, t = 1:T],
                EP[:vFLOW][l,t]-inputs["pDC_OPF_coeff"][l] *
                        sum(inputs["pNet_Map"][l, z] * vANGLE[z, t] for z in 1:Z) <= BigM[l]*(1-EP[:vNEW_TRANS_LINES][l]))
        @constraint(EP,
            cPOWER_FLOW_BUILD_REVERSE[l in INTEGER_BUILD_LINES, t = 1:T],
                EP[:vFLOW][l,t]-inputs["pDC_OPF_coeff"][l] *
                        sum(inputs["pNet_Map"][l, z] * vANGLE[z, t] for z in 1:Z) >= -BigM[l]*(1-EP[:vNEW_TRANS_LINES][l]))

        # Set limits on new lines; Line_Reinforcement_Cap_Size serves as a big M constraint
        # if line is not built, vFLOW must be zero
        @constraints(EP,
            begin
                cMaxFlow_out_new[l in INTEGER_BUILD_LINES, t = 1:T], EP[:vFLOW][l, t] <= EP[:vNEW_TRANS_LINES][l]*inputs["Line_Reinforcement_Cap_Size"][l]
                cMaxFlow_in_new[l in INTEGER_BUILD_LINES, t = 1:T], EP[:vFLOW][l, t] >= -EP[:vNEW_TRANS_LINES][l]*inputs["Line_Reinforcement_Cap_Size"][l]
            end)

        # When there are identical lines, we can enforce that they are built in a certain order to reduce symmetry in the solution space. This is done by enforcing that if line i is built, then line i-1 must also be built.
        if haskey(inputs, "INTEGER_BUILD_LINE_GROUPS")
            INTEGER_BUILD_LINE_GROUPS = inputs["INTEGER_BUILD_LINE_GROUPS"]
            for g in INTEGER_BUILD_LINE_GROUPS
                if length(g) > 1
                    for i in 2:length(g)
                        @constraint(EP, EP[:vNEW_TRANS_LINES][g[i-1]] >= EP[:vNEW_TRANS_LINES][g[i]])
                    end
                end
            end            
        end
    end
end
