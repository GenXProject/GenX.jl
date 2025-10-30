@doc raw"""
    production_tax_credits!(EP::Model, inputs::Dict, setup::Dict)

This function implements production tax credit (PTC) policies that provide ongoing credits 
based on energy production from eligible resources. The PTC provides a credit per unit of 
energy produced (e.g., $/MWh).

For each PTC policy $p \in \mathcal{P}^{PTC}$, the credit value is calculated as:

```math
\begin{aligned}
    \text{PTC\_Value}_p = \sum_{y \in \mathcal{G}} \sum_{z \in \mathcal{Z}} \sum_{t \in \mathcal{T}}
    \left( \omega_t \times \epsilon_{y,z,p}^{PTC} \times \text{PTC\_Rate}_p \times \Theta_{y,z,t} \right)
\end{aligned}
```

where:
- $\omega_t$ is the time weight for time step $t$ (number of hours represented)
- $\epsilon_{y,z,p}^{PTC}$ is the eligibility (0 or 1) of resource $y$ in zone $z$ for PTC policy $p$
- $\text{PTC\_Rate}_p$ is the PTC rate ($/MWh) for policy $p$
- $\Theta_{y,z,t}$ is the generation/discharge from resource $y$ in zone $z$ at time $t$

The total PTC value is subtracted from the objective function to reflect the production 
subsidy revenue.
"""
function production_tax_credits!(EP::Model, inputs::Dict, setup::Dict)
    println("Production Tax Credit Module")
    
    gen = inputs["RESOURCES"]
    T = inputs["T"]  # Number of time steps
    NumberOfPTC = inputs["NumberOfPTC"]
    
    # Create expression for total PTC benefits for each policy
    @expression(EP, ePTCBenefit[ptc = 1:NumberOfPTC], 
        sum(
            inputs["omega"][t] * 
            inputs["PTC_Rate"][ptc] * 
            EP[:vP][y, t]
            for y in ids_with_policy(gen, :ptc, tag = ptc), t in 1:T
        )
    )
    
    # Total PTC benefits across all policies
    @expression(EP, eTotalPTCBenefit, sum(EP[:ePTCBenefit][ptc] for ptc in 1:NumberOfPTC))
    
    # Subtract PTC benefits from the objective function (credits reduce costs)
    add_to_expression!(EP[:eObj], -1 * eTotalPTCBenefit)
    
    return EP
end
