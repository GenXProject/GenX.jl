@doc raw"""
	hourly_matching!(EP::Model, inputs::Dict)

This module defines the hourly matching policy constraint. 
This constraint can be enabled by setting `HourlyMatchingRequirement==1` in `genx_settings.yml`) requires generation from qualified resources ($y \in \mathcal{HM\_i}$, indicated by `HM_i==1` in the `Resource_hourly_matching.csv` file) to be >= hourly consumption from specified sources of demand.

```math
\begin{aligned}
	\sum_{y \in \mathcal{hm}} \Theta_{y,t} - \sum_{y \in \mathcal{hm}} \Pi_{y,t} \geq \sum_{} D_{hm,t}
	\hspace{1cm} \forall hm \in \mathcal{HM}, \forall t \in \mathcal{T},
\end{aligned}
```

# Arguments
- `EP::Model`: The optimization model object.
- `inputs::Dict`: A dictionary containing input data.

"""
function hourly_matching!(EP::Model, inputs::Dict)
    println("Hourly Matching Policies Module")
    T = inputs["T"]
    nHM = inputs["nHM"]
    
    # Construct hourly matching demand by adding absolute profiles with zonal percentages, if applicable
    @expression(EP, eHMDemand[t = 1:T, hm = 1:nHM],
        inputs["dfHM_absolute"][t, hm])
    if haskey(inputs, "dfHM_zonal")
        @expression(EP, eHMDemandZonal[t = 1:T, hm = 1:nHM],
            sum(inputs["pD"][t, z] * inputs["dfHM_zonal"][z, hm]
            for z in findall(x -> x != 0, inputs["dfHM_zonal"][:, hm])))
        add_similar_to_expression!(EP[:eHMDemand], EP[:eHMDemandZonal])
    end

    # Define allowable shortfall in hourly matching requirement
    @variable(EP, vHMShortFall[t = 1:T, hm = 1:nHM]>=0)
    add_similar_to_expression!(EP[:eHM], vHMShortFall)
    @constraint(EP, cHourlyMatchingSFLim[hm = 1:nHM], sum(EP[:vHMShortFall][t, hm] * inputs["omega"][t] for t in 1:T) 
        <= (1-inputs["dfHM_matching_target"][hm])*sum(EP[:eHMDemand][t, hm] * inputs["omega"][t] for t in 1:T))


    # if input files are present, add hourly matching requirement slack variables
    if haskey(inputs, "dfHM_slack")
        @variable(EP, vHMSlack[t = 1:T, hm = 1:nHM]>=0)
        add_similar_to_expression!(EP[:eHM], vHMSlack)

        @expression(EP,
            eHMSlack_Year[hm = 1:nHM],
            sum(EP[:vHMSlack][t, hm] * inputs["omega"][t] for t in 1:T))
        @expression(EP,
            eCHMSlack[hm = 1:nHM],
            inputs["dfHM_slack"][hm, :PriceCap]*EP[:eHMSlack_Year][hm])
        @expression(EP, eCTotalHMSlack, sum(EP[:eCHMSlack][hm] for hm in 1:nHM))
        add_to_expression!(EP[:eObj], eCTotalHMSlack)
    end

    @constraint(EP, cHourlyMatching[t = 1:T, hm = 1:nHM], EP[:eHM][t, hm] >= EP[:eHMDemand][t, hm])
end
