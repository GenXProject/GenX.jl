# Objective Function

The objective function of GenX minimizes total annual electricity system costs over the following six components shown in the below equation:

```math
\begin{aligned}
	\text{min} \quad
	&\sum_{y \in \mathcal{G}} \sum_{z \in \mathcal{Z}} \left((\pi^{INVEST}_{y,z} \times \overline{\Omega}^{size}_{y,z} \times  \Omega_{y,z}) + (\pi^{FOM}_{y,z} \times \overline{\Omega}^{size}_{y,z} \times  \Delta^{total}_{y,z})\right) +  \\
	&\sum_{y \in \mathcal{O}} \sum_{z \in \mathcal{Z}} \left( (\pi^{INVEST,energy}_{y,z} \times    \Omega^{energy}_{y,z}) + (\pi^{FOM,energy}_{y,z} \times  \Delta^{total,energy}_{y,z})\right) +  \\
	&\sum_{y \in \mathcal{O}^{asym}}  \sum_{z \in \mathcal{Z}} \left( (\pi^{INVEST,charge}_{y,z} \times    \Omega^{charge}_{y,z}) + (\pi^{FOM,charge}_{y,z} \times  \Delta^{total,charge}_{y,z})\right) +  \\
	& \sum_{y \in \mathcal{G}} \sum_{z \in \mathcal{Z}} \sum_{t \in \mathcal{T}} \left( \omega_{t}\times(\pi^{VOM}_{y,z} + \pi^{FUEL}_{y,z})\times \Theta_{y,z,t}\right) + \sum_{y \in \mathcal{O \cup DF} } \sum_{z \in \mathcal{Z}} \sum_{t \in \mathcal{T}} \left( \omega_{t}\times\pi^{VOM,charge}_{y,z} \times \Pi_{y,z,t}\right) + \\
	&\sum_{s \in \mathcal{S}} \sum_{z \in \mathcal{Z}} \sum_{t \in \mathcal{T}} \left(\omega_{t} \times n_{s}^{slope} \times \Lambda_{s,z,t}\right) + \sum_{t \in \mathcal{T}} \left(\omega_{t} \times \pi^{unmet}_{rsv} \times r^{unmet}_{t}\right)  \\
	&\sum_{y \in \mathcal{H}} \sum_{z \in \mathcal{Z}} \sum_{t \in \mathcal{T}}\left(\omega_{t} \times \pi^{START}_{y,z} \times \chi_{s,z,t}\right) +  \\
	& \sum_{l \in \mathcal{L}}\left(\pi^{TCAP}_{l} \times \bigtriangleup\varphi^{max}_{l}\right)
\end{aligned}
```

The first summation represents the fixed costs of generation/discharge over all zones and technologies, which reflects the sum of the annualized capital cost, $\pi^{INVEST}_{y,z}$, times the total new capacity added (if any), plus the Fixed O&M cost, $\pi^{FOM}_{y,z}$, times the net installed generation capacity, $\overline{\Omega}^{size}_{y,z} \times \Delta^{total}_{y,z}$ (e.g., existing capacity less retirements plus additions).

The second summation corresponds to the fixed cost of installed energy storage capacity and is summed over only the storage resources ($y \in \mathcal{O}$). This term includes the sum of the annualized energy capital cost, $\pi^{INVEST,energy}_{y,z}$, times the total new energy capacity added (if any), plus the Fixed O&M cost, $\pi^{FOM, energy}_{y,z}$, times the net installed energy storage capacity, $\Delta^{total}_{y,z}$ (e.g., existing capacity less retirements plus additions).

The third summation corresponds to the fixed cost of installed charging power capacity and is summed over only over storage resources with independent/asymmetric charge and discharge power components ($y \in \mathcal{O}^{asym}$). This term includes the sum of the annualized charging power capital cost, $\pi^{INVEST,charge}_{y,z}$, times the total new charging power capacity added (if any), plus the Fixed O&M cost, $\pi^{FOM, energy}_{y,z}$, times the net installed charging power capacity, $\Delta^{total}_{y,z}$ (e.g., existing capacity less retirements plus additions).

The fourth and fifth summations correspond to the operational cost across all zones, technologies, and time steps. The fourth summation represents the sum of fuel cost, $\pi^{FUEL}_{y,z}$ (if any), plus variable O&M cost, $\pi^{VOM}_{y,z}$ times the energy generation/discharge by generation or storage resources (or demand satisfied via flexible demand resources, $y\in\mathcal{DF}$) in time step $t$, $\Theta_{y,z,t}$, and the weight of each time step $t$, $\omega_t$. The fifth summation represents the variable charging O&M cost, $\pi^{VOM,charge}_{y,z}$ times the energy withdrawn for charging by storage resources (or demand deferred by flexible demand resources) in time step $t$ , $\Pi_{y,z,t}$ and the annual weight of time step $t$,$\omega_t$. The weight of each time step, $\omega_t$, is equal to 1 when modeling grid operations over the entire year (8760 hours), but otherwise is equal to the number of hours in the year represented by the representative time step, $t$ such that the sum of $\omega_t \forall t \in T = 8760$, approximating annual operating costs.

The sixth summation represents the total cost of unserved demand across all segments $s$ of a segment-wise price-elastic demand curve, equal to the marginal value of consumption (or cost of non-served energy), $n_{s}^{slope}$, times the amount of non-served energy, $\Lambda_{y,z,t}$, for each segment on each zone during each time step (weighted by $\omega_t$).

The seventh summation represents the total cost of not meeting hourly operating reserve requirements (if modeled), where $\pi^{unmet}_{rsv}$ is the cost penalty per unit of non-served reserve requirement, and $r^{unmet}_t$ is the amount of non-served reserve requirement in each time step (weighted by $\omega_t$).

The eighth summation corresponds to the startup costs incurred by technologies to which unit commitment decisions apply (e.g. $y \in \mathcal{UC}$), equal to the cost of start-up, $\pi^{START}_{y,z}$, times the number of startup events, $\chi_{y,z,t}$, for the cluster of units in each zone and time step (weighted by $\omega_t$).

The last term corresponds to the transmission reinforcement or construction costs, for each transmission line (if modeled). Transmission reinforcement costs are equal to the sum across all lines of the product between the transmission reinforcement/construction cost, $pi^{TCAP}_{l}$, times the additional transmission capacity variable, $\bigtriangleup\varphi^{max}_{l}$. Note that fixed O\&M and replacement capital costs (depreciation) for existing transmission capacity is treated as a sunk cost and not included explicitly in the GenX objective function.

In summary, the objective function can be understood as the minimization of costs associated with five sets of different decisions: (1) where and how to invest on capacity, (2) how to dispatch or operate that capacity, (3) which consumer demand segments to serve or curtail, (4) how to cycle and commit thermal units subject to unit commitment decisions, (5) and where and how to invest in additional transmission network capacity to increase power transfer capacity between zones. Note however that each of these components are considered jointly and the optimization is performed over the whole problem at once as a monolithic co-optimization problem.

While the objective function is formulated as a cost minimization problem, it is also equivalent to a social welfare maximization problem, with the bulk of demand treated as inelastic and always served, and the utility of consumption for price-elastic consumers represented as a segment-wise approximation, as per the cost of unserved demand summation above.
