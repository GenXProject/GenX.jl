@doc raw"""
	hydrogen_demand!(EP::Model, inputs::Dict, setup::Dict)

This policy constraints add hydrogen prodcution demand requirement for electrolyzers.

The hydrogen demand requirement can be defined in on the following ways:
a) a resource-level limit defined in terms of annual hydrogen production (in 1,000 tonnes of hydrogen) and
b) a zonal limit defined in terms of annual hydrogen production (in 1,000 tonnes of hydrogen).

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
(See constraint 5 in the code)

**Resource-level limit constraint**
The sum of annual hydrogen production by each electrolyzer $y \in \mathcal{EL}$ must exceed a minimum quantity specified in "Electrolyzer_Min_kt" in Generates_data.csv:

```math
\begin{aligned}
	\sum_{t \in T} (\omega_{t} \times \Pi_{y,t} / \eta^{electrolyzer}_y) \geq \mathcal{Min kt}_y \times 10^3
	\hspace{1cm} \forall y \in \mathcal{EL}
\end{aligned}
```

where $\eta^{electrolyzer}_y$ is the efficiency of the electrolyzer $y$ in megawatt-hours (MWh) of electricity per metric tonne of hydrogen produced and $\mathcal{Min kt}_y$ is the minimum annual quantity of hydrogen that must be produced by electrolyzer $y$ in kilotonnes.
"""
function hydrogen_demand!(EP::Model, inputs::Dict, setup::Dict)
    println("Hydrogen Demand Module")

	omega = inputs["omega"]
	gen = inputs["RESOURCES"]
	T = inputs["T"]     # Number of time steps (hours)
	Z = inputs["Z"]     # Number of zones
	ELECTROLYZERS = inputs["ELECTROLYZER"]      # Set of electrolyzers connected to the grid (indices)
	VRE_STOR = inputs["VRE_STOR"] 	            # Set of VRE-STOR generators (indices)
    gen_VRE_STOR = gen.VreStorage               # Set of VRE-STOR generators (objects)
	if !isempty(VRE_STOR)
		VS_ELEC = inputs["VS_ELEC"]             # Set of VRE-STOR co-located electrolyzers (indices)
	else
		VS_ELEC = Vector{Int}[]
	end

	if (!isempty(ELECTROLYZERS)) && (!isempty(VS_ELEC))
		HYDROGEN_ZONES = unique(union(zone_id(gen[ELECTROLYZERS]), zone_id(gen[VS_ELEC])))
	elseif !isempty(ELECTROLYZERS)
		HYDROGEN_ZONES = unique(zone_id(gen[ELECTROLYZERS]))
	else
		HYDROGEN_ZONES = unique(zone_id(gen[VS_ELEC]))
	end

    kt_to_t = 10^3
    by_rid(rid, sym) = by_rid_res(rid, sym, gen_VRE_STOR)
    
    ## Resource-level limit constraint
    if setup["HydrogenMimimumProduction"] == 1
        @constraint(EP,                                    # Electrolyzers connected to the grid
            cHydrogenMinGrid[y in ELECTROLYZERS],
            sum(inputs["omega"][t] * EP[:vUSE][y,t] / hydrogen_mwh_per_tonne(gen[y]) for t=1:T) >= electrolyzer_min_kt(gen[y]) * kt_to_t)
        @constraint(EP,
            cHydrogenMinVS[y in VS_ELEC],
            sum(inputs["omega"][t] * EP[:vP_ELEC][y,t] / by_rid(y,:hydrogen_mwh_per_tonne_elec) for t=1:T) >= by_rid(y,:electrolyzer_min_kt) * kt_to_t)


        @expression(EP, eHydrogenMin[z in HYDROGEN_ZONES],
            if !isempty(VS_ELEC)
                sum(omega[t] * EP[:vUSE][y,t] / hydrogen_mwh_per_tonne(gen[y]) for t=1:T, y = resources_in_zone_by_rid(gen[ELECTROLYZERS], z); init=0) +
                sum(omega[t] * EP[:vP_ELEC][y,t] / by_rid(y,:hydrogen_mwh_per_tonne_elec) for t=1:T, y = resources_in_zone_by_rid(gen[VS_ELEC], z); init=0)
            else
                sum(omega[t] * EP[:vUSE][y,t] / hydrogen_mwh_per_tonne(gen[y]) for t=1:T, y = resources_in_zone_by_rid(gen[ELECTROLYZERS], z); init=0)
            end
        )

    ## Zonal level limit constraint
    elseif setup["HydrogenMimimumProduction"] == 2
		Hydrogen_demand = inputs["dfH2Demand"]
		@constraint(EP,
			cHydrogenMin[z in HYDROGEN_ZONES],
			EP[:eHydrogenMin][z] >= Hydrogen_demand[findfirst(Zone->Zone==z, Hydrogen_demand[!,:Zone]), :Hydrogen_Demand_kt] * kt_to_t)
			
	end
end