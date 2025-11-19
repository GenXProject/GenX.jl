@doc raw"""
    investment_incentive!(EP::Model, inputs::Dict, setup::Dict)

This function implements investment incentive policies that reduce the effective 
capital cost of new capacity investments. The investment incentive provides a one-time credit as a percentage 
of the capital investment cost for eligible resources.

For each investment incentive policy $p \in \mathcal{P}^{InvIncentive}$, the credit value is calculated as:

```math
\begin{aligned}
    \text{InvIncentive\_Value}_p = \sum_{y \in \mathcal{G}} \sum_{z \in \mathcal{Z}} 
    \left( \epsilon_{y,z,p}^{InvIncentive} \times \text{InvIncentive\_Rate}_p \times \pi^{INVEST}_{y,z} 
    \times \overline{\Omega}^{size}_{y,z} \times \Omega_{y,z} \right)
\end{aligned}
```

where:
- $\epsilon_{y,z,p}^{InvIncentive}$ is the eligibility (0 or 1) of resource $y$ in zone $z$ for investment incentive policy $p$
- $\text{InvIncentive\_Rate}_p$ is the investment incentive rate (e.g., 0.30 for a 30% credit) for policy $p$
- $\pi^{INVEST}_{y,z}$ is the annualized investment cost per unit capacity
- $\overline{\Omega}^{size}_{y,z}$ is the unit size of resource $y$ in zone $z$
- $\Omega_{y,z}$ is the new capacity investment variable

The total investment incentive value is subtracted from the objective function to reflect the reduction in 
net capital costs.
"""
function investment_incentive!(EP::Model, inputs::Dict, setup::Dict)
    println("Investment Incentive Module")
    
    gen = inputs["RESOURCES"]
    G = inputs["G"]
    NumberOfInvIncentive = inputs["NumberOfInvIncentive"]
    
    # Create expression for investment incentive benefits by resource and policy
    @expression(EP, eInvIncentiveBenefitByResource[y = 1:G, incentive = 1:NumberOfInvIncentive],
        if y in ids_with_policy(gen, :inv_incentive, tag = incentive)
            inputs["InvIncentive_Rate"][incentive] * 
            inv_cost_per_mwyr(gen[y]) * 
            cap_size(gen[y]) * 
            EP[:vCAP][y]
        else
            0.0
        end
    )
    
    # Create expression for total investment incentive benefits for each policy
    @expression(EP, eInvIncentiveBenefit[incentive = 1:NumberOfInvIncentive], 
        sum(EP[:eInvIncentiveBenefitByResource][y, incentive] for y in 1:G)
    )
    
    # Total investment incentive benefits across all policies
    @expression(EP, eTotalInvIncentiveBenefit, sum(EP[:eInvIncentiveBenefit][incentive] for incentive in 1:NumberOfInvIncentive))
    
    # Subtract investment incentive benefits from the objective function (credits reduce costs)
    add_to_expression!(EP[:eObj], -1 * eTotalInvIncentiveBenefit)
    
    return EP
end
