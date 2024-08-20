@doc raw"""
	hourly_matching!(EP::Model, inputs::Dict)

This module defines the hourly matching policy constraint. 
This constraint can be enabled by setting `HourlyMatching==1` in `genx_settings.yml`) requires generation from qualified resources ($y \in \mathcal{Qualified}$, indicated by `Qualified_Supply==1` in the `Resource_hourly_matching.csv` files) to be >= hourly consumption from electrolyzers in the zone and any charging by qualified storage within the zone used to help increase electrolyzer utilization:

```math
\begin{aligned}
	\sum_{y \in \{z \cap \mathcal{Qualified}\}} \Theta_{y,t} \geq \sum_{y \in \{z \cap \mathcal{EL}\}} \Pi_{y,t} + \sum_{y \in \{z \cap \mathcal{Qualified} \cap \mathcal{STOR}\}}  \Pi_{y,t}
	\hspace{1cm} \forall z \in \mathcal{Z}, \forall t \in \mathcal{T},
\end{aligned}
```

# Arguments
- `EP::Model`: The optimization model object.
- `inputs::Dict`: A dictionary containing input data.

"""
function hourly_matching!(EP::Model, inputs::Dict)
    println("Hourly Matching Policies Module")
    T = inputs["T"]
    Z = inputs["Z"]

    @constraint(EP, cHourlyMatching[t = 1:T, z = 1:Z], EP[:eHM][t, z]>=0)
end
