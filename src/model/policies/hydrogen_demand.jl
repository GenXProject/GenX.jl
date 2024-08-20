@doc raw"""
	hydrogen_demand!(EP::Model, inputs::Dict, setup::Dict)

This policy constraints add hydrogen prodcution demand requirement for electrolyzers.

The hydrogen demand requirement can be defined as a zonal limit defined in terms of annual hydrogen production (in 1,000 tonnes of hydrogen).

**Minimum annual hydrogen production**

**Zonal limit**
The sum of annual hydrogen production by each electrolyzer $y \in \mathcal{EL}$ must exceed a minimum quantity specified in inputs in "Hydrogen_demand.csv":

```math
\begin{aligned}
	\sum_{t \in T} (\omega_{t} \times \Pi_{y,t} / \eta^{electrolyzer}_y) \geq \mathcal{Min\_kt}_z \times 10^3
	\hspace{1cm} \forall y \in \mathcal{EL}
\end{aligned}
```

where $\eta^{electrolyzer}_y$ is the efficiency of the electrolyzer $y$ in megawatt-hours (MWh) of electricity per metric tonne of hydrogen produced and $\mathcal{Min\_kt}_z$ is the minimum annual quantity of hydrogen that must be produced in region $z$ in kilotonnes.

"""
function hydrogen_demand!(EP::Model, inputs::Dict, setup::Dict)
    println("Hydrogen Demand Module")
    kt_to_t = 10^3
    NumberOfH2DemandReqs = inputs["NumberOfH2DemandReqs"]

    ## Zonal level limit constraint
    if haskey(inputs, "H2DemandPriceCap")
        @variable(EP, vH2Demand_slack[h2demand = 1:NumberOfH2DemandReqs]>=0)
        add_similar_to_expression!(EP[:eH2DemandRes], vH2Demand_slack)

        @expression(EP,
            eCH2Demand_slack[h2demand = 1:NumberOfH2DemandReqs],
            inputs["H2DemandPriceCap"][h2demand]*EP[:vH2Demand_slack][h2demand])
        @expression(EP,
            eTotalCH2DemandSlack,
            sum(EP[:eCH2Demand_slack][h2demand] for h2demand in 1:NumberOfH2DemandReqs))

        add_to_expression!(EP[:eObj], eTotalCH2DemandSlack)
    end

    @constraint(EP,
        cZoneH2DemandReq[h2demand = 1:NumberOfH2DemandReqs],
        EP[:eH2DemandRes][h2demand]>=inputs["H2DemandReq"][h2demand] * kt_to_t)
end
