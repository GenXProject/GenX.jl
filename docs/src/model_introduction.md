# GenX Model Introduction

## Introduction

GenX allows for the simultaneous co-optimization of several interlinked power system decision layers, described below:

1. Capacity expansion planning (e.g., investment and retirement decisions for a full range of centralized and distributed generation, storage, and demand-side resources)
2. Hourly dispatch of generation, storage, and demand-side resources,
3. Unit commitment decisions and operational constraints for thermal generators, 
4. Commitment of generation, storage, and demand-side capacity to meet system operating reserves requirements, 
5. Commitment of generation, storage, and demand-side capacity to meet capacity reserve requirements, 
6. Transmission network power flows (including losses) and network expansion decisions, and
7. Several optional policy constraints 

Depending on the dimensionality of the problem, it may not be possible to model all decision layers at the highest possible resolution of detail, so the GenX model is designed to be highly configurable, allowing the user to specify the level of detail or abstraction along each of these layers or to omit one or more layers from consideration entirely. 

For example, while investment and dispatch decisions (Layers 1 and 2) are a consistent feature of the model under all configurations, the user has several options with regards to representing the operational constraints on various thermal power plants (e.g., coal, gas, nuclear, and biomass generators). Unit commitment (e.g., start-up and shut-down) decisions \cite{Morales-Espana2013} (Layer 3) can be modeled at the individual power plant level (as per \cite{Sisternes2014}); by using an efficient clustering of similar or identical units (as per \cite{Palmintier2011, Palmintier2013, Palmintier2014}); by using a linear relaxation (or convex hull) of the integer unit commitment constraints set; or ignoring unit commitment decisions entirely and treating generator output as fully continuous. Furthermore, different levels of resolution can be selected for each individual resource type, as desired (e.g., larger thermal units can be represented with integer unit commitment decisions while smaller units can be treated as fully continuous). In such a manner, the model can be configured to represent operating constraints on thermal generators at a level of resolution that achieves a desired balance between abstraction error and computational tractability and provides sufficient accuracy to generate insights for the problem at hand.

The model can also be configured to consider commitment of capacity to supply frequency regulation (symmetric up and down) and operating reserves (up) needed by system operators to robustly resolve short-term uncertainty in load and renewable energy forecasts and power plant or transmission network failures (Layer 4). Alternatively, reserve commitments can be ignored if desired. 

Additionally, the model can approximate resource adequacy requirements through capacity reserve margin requirements at the zonal and/or system level (Layer 5). In this way, the model can approximate varying structure of capacity markets seen in deregulated electricity markets in the U.S. and other regions.

The model also allows for transmission networks to be represented at several levels of detail (Layer 6) including at a zonal level with transport constraints on power flows between zones (as per \cite{Mai2013, Johnston2013, Hirth2017}); or as a single zone problem where transmission constraints and flows are ignored. (A DC optimal power flow formulation is in development.) In cases where a nodal or zonal transmission model is employed, network capacity expansion decisions can be modeled or ignored, and transmission losses can be represented either as a linear function of power flows or a piecewise linear approximation of a quadratic function of power flows between nodes or zones (as per \cite{Zhang2013, Fitiwi2016}), with the number of segments in the piecewise approximation specified by the user as desired. In a multi-zonal or nodal configuration, GenX can therefore consider siting generators in different locations, including balancing tradeoffs between access to different renewable resource quality, siting restrictions, and impacts on network congestions, power flows and losses. 

GenX also allows the user to specify several optional public policy constraints, such as CO2 emissions limits, minimum energy share requirements (such as renewable portfolio standard or clean energy standard policies), and minimum technology capacity requirements (e.g. technology deployment mandates).

Finally, the model is usually configured to consider a full year of operating decisions at an hourly resolution, but as this is often not tractable when considering large-scale problems with high resolution in other dimensions, GenX is also designed to model a number of subperiods -- typically multiday periods of chronologically sequential hourly operating decisions -- that can be selected via appropriate statistical clustering methods to represent a full year of operations.\cite{Sisternes2013, Sisternes2014, Poncelet2016, Nahmmacher2016, Blanford2016, Merrick2016, Mallapragada2018}. GenX ships with a [built-in time-domain reduction package](https://genxproject.github.io/GenX/docs/build/time_domain_reduction.html) that uses k-means or k-medoids to cluster raw time series data for load (demand) profiles and resource capacity factor profiles into representative periods during the input processing stage of the model. This method can also consider extreme points in the time series to capture noteworthy periods or periods with notably poor fits.

With appropriate configuration of the model, GenX thus allows the user to tractably consider several interlinking decision layers in a single, monolithic optimization problem that would otherwise have been necessary to solve in different separated stages or models. The following figure reflects the range of configurations currently possible along the three key dimensions of chronological detail, operational detail, and network detail. 

![Range of configurations currently implemented in GenX along three key dimensions of model resolution](/assets/Dimensions_graphic3.png)
*Figure. Range of configurations currently implemented in GenX along three key dimensions of model resolution*

The model is usually configured to consider a single future planning year. In this sense, the current formulation is *static* because its objective is not to determine when investments should take place over time, but rather to produce a snapshot of the minimum-cost generation capacity mix under some pre-specified future conditions. However, the current implementation of the model can be run in sequence (with outputs from one planning year used as inputs for another subsequent planning year) to represent a step-wise or myopic expansion of the electricity system. Future updates of the model will include the option to allow simultaneous co-optimization of sequential planning decisions over multiple investment periods, where we leverage dual dynamic programming techniques to improve computational tractability. 

##Uses##

From a centralized planning perspective, the GenX model can help to determine the investments needed to supply future electricity demand at minimum cost, as is common in least-cost utility planning or integrated resource planning processes. In the context of liberalized markets, the model can be used by regulators and policy makers for indicative energy planning or policy analysis in order to establish a long-term vision of efficient market and policy outcomes. The model can also be used for techno-economic assessment of emerging electricity generation, storage, and demand-side resources and to enumerate the effect of parametric uncertainty (e.g., technology costs, fuel costs, demand, policy decisions) on the system-wide value or role of different resources. 

##Structure of the Model##

FILL IN WITH FLOW-THROUGH OF MODEL AS IT RUNS: CONFIGURE MODEL -> CONFIGURE SOLVER ->  INPUTS -> SETUP MODEL -> SOLVE MODEL -> OUTPUTS

##Objective Function##

The objective function of GenX minimizes total annual electricity system costs over the following six components shown in the below equation:

```math
\begin{aligned}\allowdisplaybreaks
&\sum_{y \in \mathcal{G} } \sum_{z \in \mathcal{Z}} 
\left( (\pi^{INVEST}_{y,z} \times \overline{\Omega}^{size}_{y,z} \times  \Omega_{y,z}) 
+ (\pi^{FOM}_{y,z} \times \overline{\Omega}^{size}_{y,z} \times  \Delta^{total}_{y,z})\right) + \notag \\
&\sum_{y \in \mathcal{O} } \sum_{z \in \mathcal{Z}} 
\left( (\pi^{INVEST,energy}_{y,z} \times    \Omega^{energy}_{y,z}) 
+ (\pi^{FOM,energy}_{y,z} \times  \Delta^{total,energy}_{y,z})\right) + \notag \\
&\sum_{y \in \mathcal{O}^{asym}}  \sum_{z \in \mathcal{Z}} 
\left( (\pi^{INVEST,charge}_{y,z} \times    \Omega^{charge}_{y,z}) 
+ (\pi^{FOM,charge}_{y,z} \times  \Delta^{total,charge}_{y,z})\right) + \notag \\
& \sum_{y \in \mathcal{G} } \sum_{z \in \mathcal{Z}} \sum_{t \in \mathcal{T}} \left( \omega_{t}\times(\pi^{VOM}_{y,z} + \pi^{FUEL}_{y,z})\times \Theta_{y,z,t}\right) + \sum_{y \in \mathcal{O \cup DF} } \sum_{z \in \mathcal{Z}} \sum_{t \in \mathcal{T}} \left( \omega_{t}\times\pi^{VOM,charge}_{y,z} \times \Pi_{y,z,t}\right) +\notag \\
&\sum_{s \in \mathcal{S} } \sum_{z \in \mathcal{Z}} \sum_{t \in \mathcal{T}}\left(\omega_{t} \times n_{s}^{slope} \times \Lambda_{s,z,t}\right) + \sum_{t \in \mathcal{T} } \left(\omega_{t} \times \pi^{unmet}_{rsv} \times r^{unmet}_{t}\right) \notag \\
&\sum_{y \in \mathcal{H} } \sum_{z \in \mathcal{Z}} \sum_{t \in \mathcal{T}}\left(\omega_{t} \times \pi^{START}_{y,z} \times \chi_{s,z,t}\right) + \notag \\
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

##Power Balance Constraint##

The power balance constraint of the model ensures that electricity demand is met at every time step in each zone. As shown in the constraint, electricity demand, $D_{t,z}$, at each time step and for each zone must be strictly equal to the sum of generation, $\Theta_{y,z,t}$, from thermal technologies ($\mathcal{H}$), curtailable variable renewable energy resources ($\mathcal{VRE}$), must-run resources ($\mathcal{MR}$), and hydro resources ($\mathcal{W}$). At the same time, energy storage devices ($\mathcal{O}$) can discharge energy, $\Theta_{y,z,t}$ to help satisfy demand, while when these devices are charging, $\Pi_{y,z,t}$, they increase demand. For the case of flexible demand resources ($\mathcal{DF}$), delaying demand, $\Pi_{y,z,t}$, decreases demand while satisfying delayed demand, $\Theta_{y,z,t}$, increases demand. Price-responsive demand curtailment, $\Lambda_{s,z,t}$, also reduces demand. Finally, power flows, $\Phi_{l,t}$, on each line $l$ into or out of a zone (defined by the network map $\varphi^{map}_{l,z}$), are considered in the demand balance equation for each zone. By definition, power flows leaving their reference zone are positive, thus the minus sign in the below constraint. At the same time losses due to power flows increase demand, and one-half of losses across a line linking two zones are attributed to each connected zone. The losses function $\beta_{l,t}(\cdot)$ will depend on the configuration used to model losses (see [Transmission](https://genxproject.github.io/GenX/docs/build/transmission.html)). 

```math
\begin{align}\allowdisplaybreaks
&\sum_{y\in \mathcal{H}}{\Theta_{y,z,t}} +\sum_{y\in \mathcal{VRE}}{\Theta_{y,z,t}} +\sum_{y\in \mathcal{MR}}{\Theta_{y,z,t}} + \sum_{y\in \mathcal{O}}{(\Theta_{y,z,t}-\Pi_{y,z,t})} + \notag\\
& \sum_{y\in \mathcal{DF}}{(-\Theta_{y,z,t}+\Pi_{y,z,t})} +\sum_{y\in \mathcal{W}}{\Theta_{y,z,t}}+ \notag\\
&+ \sum_{s\in \mathcal{S}}{\Lambda_{s,z,t}}  - \sum_{l\in \mathcal{L}}{(\varphi^{map}_{l,z} \times \Phi_{l,t})} -\frac{1}{2} \sum_{l\in \mathcal{L}}{(\varphi^{map}_{l,z} \times \beta_{l,t}(\cdot))} = D_{z,t} 
 \forall z\in \mathcal{Z},  t \in \mathcal{T}
\end{aligned}
```

