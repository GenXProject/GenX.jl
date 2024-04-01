@doc raw"""
	electrolyzer!(EP::Model, inputs::Dict, setup::Dict)

This function defines the expressions and constraints for operation of hydrogen electrolyzers ($y \in \mathcal{EL} \subseteq \mathcal{G}$).
	This is a basic implementation of hydrogen electrolyzers that allows the specification of an hourly clean supply constraint.
	For a richer formulation, please see the DOLPHYN code at https://github.com/macroenergy/DOLPHYN.

**Expressions**

Consumption of electricity by electrolyzer $y$ in time $t$, denoted by $\Pi_{y,z}$, is subtracted from power balance expression `ePowerBalance` (as per other demands or battery charging) and added to Energy Share Requirement policy balance (if applicable), `eESR`.

Revenue from hydrogen production by each electrolyzer $y$, equal to $\omega_t \times \Pi_{y,t} / \eta^{electrolyzer}_y \times \$^{hydrogen}_y$, is subtracted from the objective function, where $\eta^{electrolyzer}_y$ is the efficiency of the electrolyzer $y$ in megawatt-hours (MWh) of electricity per metric tonne of hydrogen produced and $\$^{hydrogen}_y$ is the price of hydrogen per metric tonne for electrolyzer $y$.

**Ramping limits**

Electrolyzers adhere to the following ramping limits on hourly changes in power output:

```math
\begin{aligned}
	\Pi_{y,t-1} - \Pi_{y,t} \leq \kappa_{y}^{down} \Delta^{\text{total}}_{y}, \hspace{1cm} \forall y \in \mathcal{EL}, \forall t \in \mathcal{T}
\end{aligned}
```

```math
\begin{aligned}
	\Pi_{y,t} - \Pi_{y,t-1} \leq \kappa_{y}^{up} \Delta^{\text{total}}_{y} \hspace{1cm} \forall y \in \mathcal{EL}, \forall t \in \mathcal{T}
\end{aligned}
```
(See Constraints 1-2 in the code)

This set of time-coupling constraints wrap around to ensure the power output in the first time step of each year (or each representative period), $t \in \mathcal{T}^{start}$, is within the eligible ramp of the power output in the final time step of the year (or each representative period), $t+\tau^{period}-1$.

**Minimum and maximum power output**

Electrolyzers are bound by the following limits on maximum and minimum power output:

```math
\begin{aligned}
	\Pi_{y,t} \geq \rho^{min}_{y} \times \Delta^{total}_{y}
	\hspace{1cm} \forall y \in \mathcal{EL}, \forall t \in \mathcal{T}
\end{aligned}
```

```math
\begin{aligned}
	\Theta_{y,t} \leq \rho^{max}_{y,t} \times \Pi_^{total}_{y}
	\hspace{1cm} \forall y \in \mathcal{EL}, \forall t \in \mathcal{T}
\end{aligned}
```
(See Constraints 3-4 in the code)

**Minimum annual hydrogen production**

The sum of annual hydrogen production by each electrolyzer $y \in \mathcal{EL}$ must exceed a minimum quantity specified in inputs:

```math
\begin{aligned}
	\sum_{t \in T} (\omega_{t} \times \Pi_{y,t} / \eta^{electrolyzer}_y) \geq \mathcal{Min kt}_y \times 10^3
	\hspace{1cm} \forall y \in \mathcal{EL}
\end{aligned}
```

where $\eta^{electrolyzer}_y$ is the efficiency of the electrolyzer $y$ in megawatt-hours (MWh) of electricity per metric tonne of hydrogen produced and $\mathcal{Min kt}_y$ is the minimum annual quantity of hydrogen that must be produced by electrolyzer $y$ in kilotonnes.
(See constraint 5 in the code)

**Hourly clean supply matching constraint**

This optional constraint (enabled by setting `HydrogenHourlyMatching==1` in `genx_settings.yml`) requires generation from qualified resources ($y \in \mathcal{Qualified}$, indicated by `Qualified_Hydrogen_Supply==1` in the resource `.csv` files) from within the same zone $z$ as the electrolyzers are located to be >= hourly consumption from electrolyzers in the zone (and any charging by qualified storage within the zone used to help increase electrolyzer utilization):

```math
\begin{aligned}
	\sum_{y \in \{z \cap \mathcal{Qualified}\}} \Theta_{y,t} \geq \sum_{y \in \{z \cap \mathcal{EL}\}} \Pi_{y,t} + \sum_{y \in \{z \cap \mathcal{Qualified} \cap \mathcal{STOR}\}}  \Pi_{y,t}
	\hspace{1cm} \forall z \in \mathcal{Z}, \forall t \in \mathcal{T},
\end{aligned}
```
(See constraint 6 in the code)

This constraint permits modeling of the 'three pillars' requirements for clean hydrogen supply of (1) new clean supply (if only new clean resources are designated as eligible), (2) that is deliverable to the electrolyzer (assuming co-location within the same modeled zone = deliverability), and (3) produced within the same hour as the electrolyzer consumes power (otherwise known as 'additionality/new supply', 'deliverability', and 'temporal matching requirements') See Ricks, Xu & Jenkins (2023), ''Minimizing emissions from grid-based hydrogen production in the United States'' *Environ. Res. Lett.* 18 014025 [doi:10.1088/1748-9326/acacb5](https://iopscience.iop.org/article/10.1088/1748-9326/acacb5/meta) for more.
"""
function electrolyzer!(EP::Model, inputs::Dict, setup::Dict)
    println("Electrolyzer Resources Module")

    gen = inputs["RESOURCES"]

    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones

    ELECTROLYZERS = inputs["ELECTROLYZER"]
    STORAGE = inputs["STOR_ALL"]

    p = inputs["hours_per_subperiod"] #total number of hours per subperiod

    ### Variables ###

    # Electrical energy consumed by electrolyzer resource "y" at hour "t"
    @variable(EP, vUSE[y = ELECTROLYZERS, t in 1:T]>=0)

    ### Expressions ###

    ## Power Balance Expressions ##

    @expression(EP, ePowerBalanceElectrolyzers[t in 1:T, z in 1:Z],
        sum(EP[:vUSE][y, t]
            for y in intersect(ELECTROLYZERS, resources_in_zone_by_rid(gen, z))))

    # Electrolyzers consume electricity so their vUSE is subtracted from power balance
    EP[:ePowerBalance] -= ePowerBalanceElectrolyzers

    # Capacity Reserves Margin policy
    ## Electrolyzers currently do not contribute to capacity reserve margin. Could allow them to contribute as a curtailable demand in future.

    ### Constraints ###

    ### Maximum ramp up and down between consecutive hours (Constraints #1-2)
    @constraints(EP,
        begin
            ## Maximum ramp up between consecutive hours
            [y in ELECTROLYZERS, t in 1:T],
            EP[:vUSE][y, t] - EP[:vUSE][y, hoursbefore(p, t, 1)] <=
            ramp_up_fraction(gen[y]) * EP[:eTotalCap][y]

            ## Maximum ramp down between consecutive hours
            [y in ELECTROLYZERS, t in 1:T],
            EP[:vUSE][y, hoursbefore(p, t, 1)] - EP[:vUSE][y, t] <=
            ramp_down_fraction(gen[y]) * EP[:eTotalCap][y]
        end)

    ### Minimum and maximum power output constraints (Constraints #3-4)
    # Electrolyzers currently do not contribute to operating reserves, so there is not
    # special case (for OperationalReserves == 1) here.
    # Could allow them to contribute as a curtailable demand in future.
    @constraints(EP,
        begin
            # Minimum stable power generated per technology "y" at hour "t" Min_Power
            [y in ELECTROLYZERS, t in 1:T],
            EP[:vUSE][y, t] >= min_power(gen[y]) * EP[:eTotalCap][y]

            # Maximum power generated per technology "y" at hour "t"
            [y in ELECTROLYZERS, t in 1:T],
            EP[:vUSE][y, t] <= inputs["pP_Max"][y, t] * EP[:eTotalCap][y]
        end)

    ### Minimum hydrogen production constraint (if any) (Constraint #5)
    kt_to_t = 10^3
    @constraint(EP,
        cHydrogenMin[y in ELECTROLYZERS],
        sum(inputs["omega"][t] * EP[:vUSE][y, t] / hydrogen_mwh_per_tonne(gen[y])
            for t in 1:T)>=electrolyzer_min_kt(gen[y]) * kt_to_t)

    ### Remove vP (electrolyzers do not produce power so vP = 0 for all periods)
    @constraints(EP, begin
        [y in ELECTROLYZERS, t in 1:T], EP[:vP][y, t] == 0
    end)

    ### Hydrogen Hourly Supply Matching Constraint (Constraint #6) ###
    # Requires generation from qualified resources (indicated by Qualified_Hydrogen_Supply==1 in the resource .csv files)
    # from within the same zone as the electrolyzers are located to be >= hourly consumption from electrolyzers in the zone
    # (and any charging by qualified storage within the zone used to help increase electrolyzer utilization).
    if setup["HydrogenHourlyMatching"] == 1
        HYDROGEN_ZONES = unique(zone_id.(gen.Electrolyzer))
        QUALIFIED_SUPPLY = ids_with(gen, qualified_hydrogen_supply)
        @constraint(EP, cHourlyMatching[z in HYDROGEN_ZONES, t in 1:T],
            sum(EP[:vP][y, t]
                for y in intersect(resources_in_zone_by_rid(gen, z), QUALIFIED_SUPPLY))>=sum(EP[:vUSE][y,
                t] for y in intersect(resources_in_zone_by_rid(gen,
                    z),
                ELECTROLYZERS)) + sum(EP[:vCHARGE][y,
                t] for y in intersect(resources_in_zone_by_rid(gen,
                    z),
                QUALIFIED_SUPPLY,
                STORAGE)))
    end

    ### Energy Share Requirement Policy ###
    # Since we're using vUSE to denote electrolyzer consumption, we subtract this from the eESR Energy Share Requirement balance to increase demand for clean resources if desired
    # Electrolyzer demand is only accounted for in an ESR that the electrolyzer resources is tagged in in Generates_data.csv (e.g. ESR_N > 0) and
    # a share of electrolyzer demand equal to df[y,:ESR_N] must be met by resources qualifying for ESR_N for each electrolyzer resource y.
    if setup["EnergyShareRequirement"] >= 1
        @expression(EP,
            eElectrolyzerESR[ESR in 1:inputs["nESR"]],
            sum(inputs["omega"][t] * EP[:vUSE][y, t]
                for y in intersect(ELECTROLYZERS, ids_with_policy(gen, esr, tag = ESR)),
            t in 1:T))
        EP[:eESR] -= eElectrolyzerESR
    end

    ### Objective Function ###
    # Subtract hydrogen revenue from objective function
    scale_factor = setup["ParameterScale"] == 1 ? 10^6 : 1  # If ParameterScale==1, costs are in millions of $
    @expression(EP,
        eHydrogenValue[y in ELECTROLYZERS, t in 1:T],
        (inputs["omega"][t] * EP[:vUSE][y, t] / hydrogen_mwh_per_tonne(gen[y]) *
         hydrogen_price_per_tonne(gen[y])/scale_factor))
    @expression(EP,
        eTotalHydrogenValueT[t in 1:T],
        sum(eHydrogenValue[y, t] for y in ELECTROLYZERS))
    @expression(EP, eTotalHydrogenValue, sum(eTotalHydrogenValueT[t] for t in 1:T))
    EP[:eObj] -= eTotalHydrogenValue
end
