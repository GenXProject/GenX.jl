@doc raw"""
	discharge!(EP::Model, inputs::Dict, setup::Dict)

This module defines the power decision variable $\Theta_{y,t} \forall y \in \mathcal{G}, t \in \mathcal{T}$, representing energy injected into the grid by resource $y$ by at time period $t$.
This module additionally defines contributions to the objective function from variable costs of generation (variable O&M) from all resources $y \in \mathcal{G}$ over all time periods $t \in \mathcal{T}$:
```math
\begin{aligned}
	Obj_{Var\_gen} =
	\sum_{y \in \mathcal{G} } \sum_{t \in \mathcal{T}}\omega_{t}\times(\pi^{VOM}_{y})\times \Theta_{y,t}
\end{aligned}
```
"""
function discharge!(EP::Model, inputs::Dict, setup::Dict)
    println("Discharge Module")

    gen = inputs["RESOURCES"]

    G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
    T = inputs["T"]     # Number of time steps

    ### Variables ###

    # Energy injected into the grid by resource "y" at hour "t"
    @variable(EP, vP[y = 1:G, t = 1:T]>=0)

    ### Expressions ###

    ## Objective Function Expressions ##

    # Variable costs of "generation" for resource "y" during hour "t" = variable O&M
    @expression(EP,
        eCVar_out[y = 1:G, t = 1:T],
        (inputs["omega"][t]*(var_om_cost_per_mwh(gen[y]) * vP[y, t])))
    # Sum individual resource contributions to variable discharging costs to get total variable discharging costs
    @expression(EP, eTotalCVarOutT[t = 1:T], sum(eCVar_out[y, t] for y in 1:G))
    @expression(EP, eTotalCVarOut, sum(eTotalCVarOutT[t] for t in 1:T))

    # Add total variable discharging cost contribution to the objective function
    add_to_expression!(EP[:eObj], eTotalCVarOut)

    # ESR Policy
    if setup["EnergyShareRequirement"] >= 1
        @expression(EP, eESRDischarge[ESR = 1:inputs["nESR"]],
            +sum(inputs["omega"][t] * esr(gen[y], tag = ESR) * EP[:vP][y, t]
                 for y in ids_with_policy(gen, esr, tag = ESR), t in 1:T)
            -sum(inputs["dfESR"][z, ESR] * inputs["omega"][t] * inputs["pD"][t, z]
                 for t in 1:T, z in findall(x -> x > 0, inputs["dfESR"][:, ESR])))
        add_similar_to_expression!(EP[:eESR], eESRDischarge)
    end
end
