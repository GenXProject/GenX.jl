# Objective Function

The objective function of GenX minimizes total annual electricity system costs over the following components shown in the below equation:


```math
\begin{aligned}
    \text{min} \quad
    &\sum_{y \in \mathcal{G}} \sum_{z \in \mathcal{Z}} \left((\pi^{INVEST}_{y,z} \times \overline{\Omega}^{size}_{y,z} \times  \Omega_{y,z}) + (\pi^{FOM}_{y,z} \times \overline{\Omega}^{size}_{y,z} \times  \Delta^{total}_{y,z})\right) +  \\
    &\sum_{y \in \mathcal{O}} \sum_{z \in \mathcal{Z}} \left( (\pi^{INVEST,energy}_{y,z} \times    \Omega^{energy}_{y,z}) + (\pi^{FOM,energy}_{y,z} \times  \Delta^{total,energy}_{y,z})\right) +  \\
    &\sum_{y \in \mathcal{O}^{asym}}  \sum_{z \in \mathcal{Z}} \left( (\pi^{INVEST,charge}_{y,z} \times    \Omega^{charge}_{y,z}) + (\pi^{FOM,charge}_{y,z} \times  \Delta^{total,charge}_{y,z})\right) +  \\
    & \sum_{y \in \mathcal{G}} \sum_{z \in \mathcal{Z}} \sum_{t \in \mathcal{T}} \left( \omega_{t}\times(\pi^{VOM}_{y,z} + \pi^{FUEL}_{y,z})\times \Theta_{y,z,t}\right) + \sum_{y \in \mathcal{O \cup DF} } \sum_{z \in \mathcal{Z}} \sum_{t \in \mathcal{T}} \left( \omega_{t}\times\pi^{VOM,charge}_{y,z} \times \Pi_{y,z,t}\right) + \\
    &\sum_{s \in \mathcal{S}} \sum_{z \in \mathcal{Z}} \sum_{t \in \mathcal{T}} \left(\omega_{t} \times n_{s}^{slope} \times \Lambda_{s,z,t}\right) + \sum_{t \in \mathcal{T}} \left(\omega_{t} \times \pi^{unmet}_{rsv} \times r^{unmet}_{t}\right)  \\
    &\sum_{y \in \mathcal{H}} \sum_{z \in \mathcal{Z}} \sum_{t \in \mathcal{T}}\left(\omega_{t} \times \pi^{START}_{y,z} \times \chi_{s,z,t}\right) +  \\
    & \sum_{l \in \mathcal{L}}\left(\pi^{TCAP}_{l} \times \bigtriangleup\varphi^{max}_{l}\right) + \\
    &\sum_{y \in \mathcal{VS}^{inv}} \sum_{z \in \mathcal{Z}} \left( (\pi^{INVEST, inv}_{y,z} \times \Omega^{inv}_{y,z})
    + (\pi^{FOM, inv}_{y,z} \times  \Delta^{total,inv}_{y,z})\right) + \\
    &\sum_{y \in \mathcal{VS}^{pv}} \sum_{z \in \mathcal{Z}} \left( (\pi^{INVEST, pv}_{y,z} \times \Omega^{pv}_{y,z})
    + (\pi^{FOM, pv}_{y,z} \times  \Delta^{total,pv}_{y,z})\right) + \\
    &\sum_{y \in \mathcal{VS}^{wind}} \sum_{z \in \mathcal{Z}} \left( (\pi^{INVEST, wind}_{y,z} \times \Omega^{pv}_{y,z})
    + (\pi^{FOM, wind}_{y,z} \times  \Delta^{total,wind}_{y,z})\right) + \\
    &\sum_{y \in \mathcal{VS}^{asym,dc,dis}} \sum_{z \in \mathcal{Z}} \left( (\pi^{INVEST,dc,dis}_{y,z} \times \Omega^{dc,dis}_{y,z})
    + (\pi^{FOM,dc,dis}_{y,z} \times  \Delta^{total,dc,dis}_{y,z})\right) + \\
    &\sum_{y \in \mathcal{VS}^{asym,dc,cha}} \sum_{z \in \mathcal{Z}} \left( (\pi^{INVEST,dc,cha}_{y,z} \times \Omega^{dc,cha}_{y,z})
    + (\pi^{FOM,dc,cha}_{y,z} \times  \Delta^{total,dc,cha}_{y,z})\right) + \\
    &\sum_{y \in \mathcal{VS}^{asym,ac,dis}} \sum_{z \in \mathcal{Z}} \left( (\pi^{INVEST,ac,dis}_{y,z} \times \Omega^{ac,dis}_{y,z})
    + (\pi^{FOM,ac,dis}_{y,z} \times  \Delta^{total,ac,dis}_{y,z})\right) + \\
    &\sum_{y \in \mathcal{VS}^{asym,ac,cha}} \sum_{z \in \mathcal{Z}} \left( (\pi^{INVEST,ac,cha}_{y,z} \times \Omega^{ac,cha}_{y,z})
    + (\pi^{FOM,ac,cha}_{y,z} \times  \Delta^{total,ac,cha}_{y,z})\right) + \\
    & \sum_{y \in \mathcal{VS}^{pv}} \sum_{z \in \mathcal{Z}} \sum_{t \in \mathcal{T}} \left( \omega_{t}\times\pi^{VOM,pv}_{y,z}\times \eta^{inverter}_{y,z} \times \Theta^{pv}_{y,z,t}\right) + \\
    & \sum_{y \in \mathcal{VS}^{wind}} \sum_{z \in \mathcal{Z}} \sum_{t \in \mathcal{T}} \left( \omega_{t}\times\pi^{VOM,wind}_{y,z} \times \Theta^{wind}_{y,z,t}\right) + \\
    & \sum_{y \in \mathcal{VS}^{sym,dc} \cup \mathcal{VS}^{asym,dc,dis}} \sum_{z \in \mathcal{Z}} \sum_{t \in \mathcal{T}} \left( \omega_{t}\times\pi^{VOM,dc,dis}_{y,z} \times\eta^{inverter}_{y,z} \times \Theta^{dc}_{y,z,t}\right) + \\
    & \sum_{y \in \mathcal{VS}^{sym,dc} \cup \mathcal{VS}^{asym,dc,cha}} \sum_{z \in \mathcal{Z}} \sum_{t \in \mathcal{T}} \left( \omega_{t}\times\pi^{VOM,dc,cha}_{y,z} \times \frac{\Pi^{dc}_{y,z,t}}{\eta^{inverter}_{y,z}}\right) + \\
    & \sum_{y \in \mathcal{VS}^{sym,ac} \cup \mathcal{VS}^{asym,ac,dis}} \sum_{z \in \mathcal{Z}} \sum_{t \in \mathcal{T}} \left( \omega_{t}\times\pi^{VOM,ac,dis}_{y,z} \times \Theta^{ac}_{y,z,t}\right) + \\
    & \sum_{y \in \mathcal{VS}^{sym,ac} \cup \mathcal{VS}^{asym,ac,cha}} \sum_{z \in \mathcal{Z}} \sum_{t \in \mathcal{T}} \left( \omega_{t}\times\pi^{VOM,ac,cha}_{y,z} \times \Pi^{ac}_{y,z,t}\right)
\end{aligned}
```


The first summation represents the fixed costs of generation/discharge over all zones and technologies, which reflects the sum of the annualized capital cost, $\pi^{INVEST}_{y,z}$, times the total new capacity added (if any), plus the Fixed O&M cost, $\pi^{FOM}_{y,z}$, times the net installed generation capacity, $\overline{\Omega}^{size}_{y,z} \times \Delta^{total}_{y,z}$ (e.g., existing capacity less retirements plus additions).

The second summation corresponds to the fixed cost of installed energy storage capacity and is summed over only the storage resources ($y \in \mathcal{O} \cup \mathcal{VS}^{stor}$).
This term includes the sum of the annualized energy capital cost, $\pi^{INVEST,energy}_{y,z}$, times the total new energy capacity added (if any), plus the Fixed O&M cost, $\pi^{FOM, energy}_{y,z}$, times the net installed energy storage capacity, $\Delta^{total}_{y,z}$ (e.g., existing capacity less retirements plus additions).

The third summation corresponds to the fixed cost of installed charging power capacity and is summed over only over storage resources with independent/asymmetric charge and discharge power components ($y \in \mathcal{O}^{asym}$).
This term includes the sum of the annualized charging power capital cost, $\pi^{INVEST,charge}_{y,z}$, times the total new charging power capacity added (if any), plus the Fixed O&M cost, $\pi^{FOM, energy}_{y,z}$, times the net installed charging power capacity, $\Delta^{total}_{y,z}$ (e.g., existing capacity less retirements plus additions).

The fourth and fifth summations correspond to the operational cost across all zones, technologies, and time steps.
The fourth summation represents the sum of fuel cost, $\pi^{FUEL}_{y,z}$ (if any), plus variable O&M cost, $\pi^{VOM}_{y,z}$ times the energy generation/discharge by generation or storage resources (or demand satisfied via flexible demand resources, $y\in\mathcal{DF}$) in time step $t$, $\Theta_{y,z,t}$, and the weight of each time step $t$, $\omega_t$. The fifth summation represents the variable charging O&M cost, $\pi^{VOM,charge}_{y,z}$ times the energy withdrawn for charging by storage resources (or demand deferred by flexible demand resources) in time step $t$ , $\Pi_{y,z,t}$ and the annual weight of time step $t$,$\omega_t$.
The weight of each time step, $\omega_t$, is equal to 1 when modeling grid operations over the entire year (8760 hours), but otherwise is equal to the number of hours in the year represented by the representative time step, $t$ such that the sum of $\omega_t \forall t \in T = 8760$, approximating annual operating costs.

The sixth summation represents the total cost of unserved demand across all segments $s$ of a segment-wise price-elastic demand curve, equal to the marginal value of consumption (or cost of non-served energy), $n_{s}^{slope}$, times the amount of non-served energy, $\Lambda_{y,z,t}$, for each segment on each zone during each time step (weighted by $\omega_t$).

The seventh summation represents the total cost of not meeting hourly operating reserve requirements (if modeled), where $\pi^{unmet}_{rsv}$ is the cost penalty per unit of non-served reserve requirement, and $r^{unmet}_t$ is the amount of non-served reserve requirement in each time step (weighted by $\omega_t$).

The eighth summation corresponds to the startup costs incurred by technologies to which unit commitment decisions apply (e.g. $y \in \mathcal{UC}$), equal to the cost of start-up, $\pi^{START}_{y,z}$, times the number of startup events, $\chi_{y,z,t}$, for the cluster of units in each zone and time step (weighted by $\omega_t$).

The ninth term corresponds to the transmission reinforcement or construction costs, for each transmission line (if modeled).
Transmission reinforcement costs are equal to the sum across all lines of the product between the transmission reinforcement/construction cost, $pi^{TCAP}_{l}$, times the additional transmission capacity variable, $\bigtriangleup\varphi^{max}_{l}$. Note that fixed O&M and replacement capital costs (depreciation) for existing transmission capacity is treated as a sunk cost and not included explicitly in the GenX objective function.

The tenth term onwards specifically relates to the breakdown investment, fixed O&M, and variable O&M costs associated with each configurable component of a co-located VRE and storage resource.
The tenth term represents to the fixed cost of installed inverter capacity and is summed over only the co-located resources with an inverter component ($y \in \mathcal{VS}^{inv}$).
This term includes the sum of the annualized inverter capital cost, $\pi^{INVEST,inv}_{y,z}$, times the total new inverter capacity added (if any), plus the Fixed O&M cost, $\pi^{FOM, inv}_{y,z}$, times the net installed inverter capacity, $\Delta^{total,inv}_{y,z}$ (e.g., existing capacity less retirements plus additions).
The eleventh term represents the fixed cost of installed solar PV capacity and is summed over only the co-located resources with a solar PV component ($y \in \mathcal{VS}^{pv}$).
This term includes the sum of the annualized solar PV capital cost, $\pi^{INVEST,pv}_{y,z}$, times the total new solar PV capacity added (if any), plus the Fixed O&M cost, $\pi^{FOM, pv}_{y,z}$, times the net installed solar PV capacity, $\Delta^{total,pv}_{y,z}$ (e.g., existing capacity less retirements plus additions).
The twelveth term represents the fixed cost of installed wind capacity and is summed over only the co-located resources with a wind component ($y \in \mathcal{VS}^{wind}$).
This term includes the sum of the annualized wind capital cost, $\pi^{INVEST,wind}_{y,z}$, times the total new wind capacity added (if any), plus the Fixed O&M cost, $\pi^{FOM, wind}_{y,z}$, times the net installed wind capacity, $\Delta^{total,wind}_{y,z}$ (e.g., existing capacity less retirements plus additions).
The thirteenth term represents the fixed cost of installed storage DC discharge capacity and is summed over only the co-located resources with an asymmetric storage DC discharge component ($y \in \mathcal{VS}^{asym,dc,dis}$).
This term includes the sum of the annualized storage DC discharge capital cost, $\pi^{INVEST,dc,dis}_{y,z}$, times the total new storage DC discharge capacity added (if any), plus the Fixed O&M cost, $\pi^{FOM, dc, dis}_{y,z}$, times the net installed storage DC discharge capacity, $\Delta^{total,dc,dis}_{y,z}$ (e.g., existing capacity less retirements plus additions).
The fourteenth term represents the fixed cost of installed storage DC charge capacity and is summed over only the co-located resources with an asymmetric storage DC charge component ($y \in \mathcal{VS}^{asym,dc,cha}$).
This term includes the sum of the annualized storage DC charge capital cost, $\pi^{INVEST,dc,cha}_{y,z}$, times the total new storage DC charge capacity added (if any), plus the Fixed O&M cost, $\pi^{FOM, dc, cha}_{y,z}$, times the net installed storage DC charge capacity, $\Delta^{total,dc,cha}_{y,z}$ (e.g., existing capacity less retirements plus additions).
The fifteenth term represents the fixed cost of installed storage AC discharge capacity and is summed over only the co-located resources with an asymmetric storage AC discharge component ($y \in \mathcal{VS}^{asym,ac,dis}$).
This term includes the sum of the annualized storage AC discharge capital cost, $\pi^{INVEST,ac,dis}_{y,z}$, times the total new storage AC discharge capacity added (if any), plus the Fixed O&M cost, $\pi^{FOM, ac, dis}_{y,z}$, times the net installed storage AC discharge capacity, $\Delta^{total,ac,dis}_{y,z}$ (e.g., existing capacity less retirements plus additions).
The sixteenth term represents to the fixed cost of installed storage AC charge capacity and is summed over only the co-located resources with an asymmetric storage AC charge component ($y \in \mathcal{VS}^{asym,ac,cha}$).
This term includes the sum of the annualized storage AC charge capital cost, $\pi^{INVEST,ac,cha}_{y,z}$, times the total new storage AC charge capacity added (if any), plus the Fixed O&M cost, $\pi^{FOM, ac, cha}_{y,z}$, times the net installed storage AC charge capacity, $\Delta^{total,ac,cha}_{y,z}$ (e.g., existing capacity less retirements plus additions).

The seventeeth term onwards corresponds to the operational cost across all zones, technologies, and time steps for co-located VRE and storage resources.
The seventeenth summation represents the variable O&M cost, $\pi^{VOM,pv}_{y,z}$, times the energy generation by solar PV resources ($y\in\mathcal{VS}^{pv}$) in time step $t$, $\Theta^{pv}_{y,z,t}$, the inverter efficiency, $\eta^{inverter}_{y,z}$, and the weight of each time step $t$, $\omega_t$.
The eighteenth summation represents the variable O&M cost, $\pi^{VOM,wind}_{y,z}$, times the energy generation by wind resources ($y\in\mathcal{VS}^{wind}$) in time step $t$, $\Theta^{wind}_{y,z,t}$, and the weight of each time step $t$, $\omega_t$.
The nineteenth summation represents the variable O&M cost, $\pi^{VOM,dc,dis}_{y,z}$, times the energy discharge by storage DC components ($y\in\mathcal{VS}^{sym,dc} \cup \mathcal{VS}^{asym,dc,dis}$) in time step $t$, $\Theta^{dc}_{y,z,t}$, the inverter efficiency, $\eta^{inverter}_{y,z}$, and the weight of each time step $t$, $\omega_t$.
The twentieth summation represents the variable O&M cost, $\pi^{VOM,dc,cha}_{y,z}$, times the energy withdrawn by storage DC components ($y\in\mathcal{VS}^{sym,dc} \cup \mathcal{VS}^{asym,dc,cha}$) in time step $t$, $\Pi^{dc}_{y,z,t}$, and the weight of each time step $t$, $\omega_t$, and divided by the inverter efficiency, $\eta^{inverter}_{y,z}$.
The twenty-first summation represents the variable O&M cost, $\pi^{VOM,ac,dis}_{y,z}$, times the energy discharge by storage AC components ($y\in\mathcal{VS}^{sym,ac} \cup \mathcal{VS}^{asym,ac,dis}$) in time step $t$, $\Theta^{ac}_{y,z,t}$, and the weight of each time step $t$, $\omega_t$.
The twenty-second summation represents the variable O&M cost, $\pi^{VOM,ac,cha}_{y,z}$, times the energy withdrawn by storage AC components ($y\in\mathcal{VS}^{sym,ac} \cup \mathcal{VS}^{asym,ac,cha}$) in time step $t$, $\Pi^{ac}_{y,z,t}$, and the weight of each time step $t$, $\omega_t$.

In summary, the objective function can be understood as the minimization of costs associated with five sets of different decisions:
1. where and how to invest on capacity,
2. how to dispatch or operate that capacity,
3. which consumer demand segments to serve or curtail,
4. how to cycle and commit thermal units subject to unit commitment decisions,
5. and where and how to invest in additional transmission network capacity to increase power transfer capacity between zones.

Note however that each of these components are considered jointly and the optimization is performed over the whole problem at once as a monolithic co-optimization problem.

While the objective function is formulated as a cost minimization problem, it is also equivalent to a social welfare maximization problem, with the bulk of demand treated as inelastic and always served, and the utility of consumption for price-elastic consumers represented as a segment-wise approximation, as per the cost of unserved demand summation above.

# Objective Scaling
Sometimes the model will be built into an ill form if some objective terms are quite large or small. To alleviate this problem, we could add a scaling factor to scale the objective function during solving while leaving all other expressions untouched. The default ```ObjScale``` is set to 1 which has no effect on objective. If you want to scale the objective, you can set the ```ObjScale``` to an appropriate value in the ```genx_settings.yml```. The objective function will be multiplied by the ```ObjScale``` value during the solving process.