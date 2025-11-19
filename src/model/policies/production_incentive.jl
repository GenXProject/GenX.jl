@doc raw"""
    production_incentive!(EP::Model, inputs::Dict, setup::Dict)

This function implements production incentive policies that provide ongoing credits 
based on energy production or CO₂ captured from eligible resources. The production incentive provides a credit per unit of 
energy produced (e.g., $/MWh) or per unit of CO₂ captured (e.g., $/tonne).

For each production incentive policy $p \in \mathcal{P}^{ProdIncentive}$, the credit value is calculated based on the incentive type:

**Energy-based incentives (ProdIncentive_Type = "MWh"):**
```math
\begin{aligned}
    \text{ProdIncentive\_Value}_p = \sum_{y \in \mathcal{G}} \sum_{z \in \mathcal{Z}} \sum_{t \in \mathcal{T}}
    \left( \omega_t \times \epsilon_{y,z,p}^{ProdIncentive} \times \text{ProdIncentive\_Rate}_p \times \Theta_{y,z,t} \right)
\end{aligned}
```

**CO₂ capture-based incentives (ProdIncentive_Type = "Tonne_CO2"):**
```math
\begin{aligned}
    \text{ProdIncentive\_Value}_p = \sum_{y \in \mathcal{CCS}} \sum_{t \in \mathcal{T}}
    \left( \omega_t \times \epsilon_{y,p}^{ProdIncentive} \times \text{ProdIncentive\_Rate}_p \times eEmissionsCaptureByPlant_{y,t} \right)
\end{aligned}
```

where:
- $\omega_t$ is the time weight for time step $t$ (number of hours represented)
- $\epsilon_{y,z,p}^{ProdIncentive}$ is the eligibility (0 or 1) of resource $y$ in zone $z$ for production incentive policy $p$
- $\text{ProdIncentive\_Rate}_p$ is the production incentive rate ($/MWh or $/tonne CO₂) for policy $p$
- $\Theta_{y,z,t}$ is the generation/discharge from resource $y$ in zone $z$ at time $t$
- $eEmissionsCaptureByPlant_{y,t}$ is the CO₂ captured by resource $y$ at time $t$ (for CCS resources)

The total production incentive value is subtracted from the objective function to reflect the production 
subsidy revenue.
"""
function production_incentive!(EP::Model, inputs::Dict, setup::Dict)
    println("Production Incentive Module")
    
    gen = inputs["RESOURCES"]
    T = inputs["T"]  # Number of time steps
    NumberOfProdIncentive = inputs["NumberOfProdIncentive"]
    CCS = inputs["CCS"]  # Resources with carbon capture
    
    # Create expression for total production incentive benefits for each policy
    @expression(EP, eProdIncentiveBenefit[incentive = 1:NumberOfProdIncentive], 
        # Energy-based incentives
        if inputs["ProdIncentive_Type"][incentive] == "mwh"
            sum(
                inputs["omega"][t] * 
                inputs["ProdIncentive_Rate"][incentive] * 
                EP[:vP][y, t]
                for y in ids_with_policy(gen, :prod_incentive, tag = incentive), t in 1:T
            )
        # CO₂ capture-based incentives
        elseif inputs["ProdIncentive_Type"][incentive] == "tonne_co2" && !isempty(CCS) && haskey(EP.obj_dict, :eEmissionsCaptureByPlant)
            sum(
                inputs["omega"][t] * 
                inputs["ProdIncentive_Rate"][incentive] * 
                EP[:eEmissionsCaptureByPlant][y, t]
                for y in intersect(ids_with_policy(gen, :prod_incentive, tag = incentive), CCS), t in 1:T
            )
        else
            0.0
        end
    )
    
    # Total production incentive benefits across all policies
    @expression(EP, eTotalProdIncentiveBenefit, sum(EP[:eProdIncentiveBenefit][incentive] for incentive in 1:NumberOfProdIncentive))
    
    # Subtract production incentive benefits from the objective function (credits reduce costs)
    add_to_expression!(EP[:eObj], -1 * eTotalProdIncentiveBenefit)
    
    return EP
end
