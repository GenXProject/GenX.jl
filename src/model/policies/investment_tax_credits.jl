@doc raw"""
    investment_tax_credits!(EP::Model, inputs::Dict, setup::Dict)

This function implements investment tax credit (ITC) policies that reduce the effective 
capital cost of new capacity investments. The ITC provides a one-time credit as a percentage 
of the capital investment cost for eligible resources.

For each ITC policy $p \in \mathcal{P}^{ITC}$, the credit value is calculated as:

```math
\begin{aligned}
    \text{ITC\_Value}_p = \sum_{y \in \mathcal{G}} \sum_{z \in \mathcal{Z}} 
    \left( \epsilon_{y,z,p}^{ITC} \times \text{ITC\_Rate}_p \times \pi^{INVEST}_{y,z} 
    \times \overline{\Omega}^{size}_{y,z} \times \Omega_{y,z} \right)
\end{aligned}
```

where:
- $\epsilon_{y,z,p}^{ITC}$ is the eligibility (0 or 1) of resource $y$ in zone $z$ for ITC policy $p$
- $\text{ITC\_Rate}_p$ is the ITC rate (e.g., 0.30 for a 30% credit) for policy $p$
- $\pi^{INVEST}_{y,z}$ is the annualized investment cost per unit capacity
- $\overline{\Omega}^{size}_{y,z}$ is the unit size of resource $y$ in zone $z$
- $\Omega_{y,z}$ is the new capacity investment variable

The total ITC value is subtracted from the objective function to reflect the reduction in 
net capital costs.
"""
function investment_tax_credits!(EP::Model, inputs::Dict, setup::Dict)
    println("Investment Tax Credit Module")
    
    gen = inputs["RESOURCES"]
    NumberOfITC = inputs["NumberOfITC"]
    
    # Create expression for total ITC benefits for each policy
    @expression(EP, eITCBenefit[itc = 1:NumberOfITC], 
        sum(
            inputs["ITC_Rate"][itc] * 
            inv_cost_per_mwyr(gen[y]) * 
            cap_size(gen[y]) * 
            EP[:vCAP][y]
            for y in ids_with_policy(gen, :itc, tag = itc)
        )
    )
    
    # Total ITC benefits across all policies
    @expression(EP, eTotalITCBenefit, sum(EP[:eITCBenefit][itc] for itc in 1:NumberOfITC))
    
    # Subtract ITC benefits from the objective function (credits reduce costs)
    add_to_expression!(EP[:eObj], -1 * eTotalITCBenefit)
    
    return EP
end
