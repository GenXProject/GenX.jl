# Model Notation

## Model Indices and Sets
---
|**Notation** | **Description**|
| :------------ | :-----------|
|$t \in \mathcal{T}$ | where $t$ denotes an time step and $\mathcal{T}$ is the set of time steps over which grid operations are modeled|
|$\mathcal{T}^{interior} \subseteq \mathcal{T}^{}$ | where $\mathcal{T}^{interior}$ is the set of interior timesteps in the data series|
|$\mathcal{T}^{start} \subseteq \mathcal{T}$ |  where $\mathcal{T}^{start}$ is the set of initial timesteps in the data series. $\mathcal{T}^{start}={1}$ when representing entire year as a single contiguous period; $\mathcal{T}^{start}=\{\left(m-1\right) \times \tau^{period}+1 \| m \in \mathcal{M}\}$, which corresponds to the first time step of each representative period $m \in \mathcal{M}$|
|$n \in \mathcal{N}$ | where $n$ corresponds to a contiguous time period and $\mathcal{N}$ corresponds to the set of contiguous periods of length $\tau^{period}$ that make up the input time series (e.g. demand, variable renewable energy availability) to the model|
|$\mathcal{N}^{rep} \subseteq \mathcal{N}$ | where $\mathcal{N}^{rep}$ corresponds to the set of representative time periods that are selected from the set of contiguous periods, $\mathcal{M}$|
|$m \in \mathcal{M}$ | where $m$ corresponds to a representative time period and $\mathcal{M}$ corresponds to the set of representative time periods indexed as per their chronological ocurrence in the set of contiguous periods spanning the input time series data, i.e. $\mathcal{N}$|
$z \in \mathcal{Z}$ | where $z$ denotes a zone and $\mathcal{Z}$ is the set of zones in the network|
|$l \in \mathcal{L}$ | where $l$ denotes a line and $\mathcal{L}$ is the set of transmission lines in the network|
|$y \in \mathcal{G}$ | where $y$ denotes a technology and $\mathcal{G}$ is the set of available technologies |
|$\mathcal{H} \subseteq \mathcal{G}$ | where $\mathcal{H}$ is the subset of thermal resources|
|$\mathcal{VRE} \subseteq \mathcal{G}$ | where $\mathcal{VRE}$ is the subset of curtailable Variable Renewable Energy (VRE) resources|
|$\overline{\mathcal{VRE}}^{y,z}$ | set of VRE resource bins for VRE technology type $y \in \mathcal{VRE}$ in zone $z$ |
|$\mathcal{CE} \subseteq \mathcal{G}$ | where $\mathcal{CE}$ is the subset of resources qualifying for the clean energy standard policy constraint|
|$\mathcal{UC} \subseteq \mathcal{H}$ | where $\mathcal{UC}$ is the subset of thermal resources subject to unit commitment constraints|
|$s \in \mathcal{S}$ | where $s$ denotes a segment and $\mathcal{S}$ is the set of consumers segments for price-responsive demand curtailment|
|$\mathcal{O} \subseteq \mathcal{G}$ | where $\mathcal{O}$ is the subset of storage resources excluding heat storage and hydro storage |
|$o \in \mathcal{O}$ | where $o$ denotes a storage technology in a set $\mathcal{O}$|
|$\mathcal{O}^{sym} \subseteq \mathcal{O}$ | where $\mathcal{O}^{sym}$ corresponds to the set of energy storage technologies with equal (or symmetric) charge and discharge power capacities|
|$\mathcal{O}^{asym} \subseteq \mathcal{O}$ | where $\mathcal{O}^{asym}$ corresponds to the set of energy storage technologies with independently sized (or asymmetric) charge and discharge power capacities|
|$\mathcal{O}^{LDES} \subseteq \mathcal{O}$ | where $\mathcal{O}^{LDES}$ corresponds to the set of long-duration energy storage technologies for which inter-period energy exchange is permitted when using representative periods to model annual grid operations|
|$\mathcal{VS} \subseteq \mathcal{G}$ | where $\mathcal{VS}$ is the subset of co-located VRE and storage resources |
|$\mathcal{VS}^{pv} \subseteq \mathcal{VS}$ | where $\mathcal{VS}^{pv}$ corresponds to the set of co-located VRE and storage resources with a solar PV component |
|$\mathcal{VS}^{wind} \subseteq \mathcal{VS}$ | where $\mathcal{VS}^{wind}$ corresponds to the set of co-located VRE and storage resources with a wind component |
|$\mathcal{VS}^{elec} \subseteq \mathcal{VS}$ | where $\mathcal{VS}^{elec}$ corresponds to the set of co-located VRE and storage resources with an electrolyzer component |
|$\mathcal{VS}^{inv} \subseteq \mathcal{VS}$ | where $\mathcal{VS}^{inv}$ corresponds to the set of co-located VRE and storage resources with an inverter component |
|$\mathcal{VS}^{stor} \subseteq \mathcal{VS}$ | where $\mathcal{VS}^{stor}$ corresponds to the set of co-located VRE and storage resources with a storage component |
|$\mathcal{VS}^{sym, dc} \subseteq \mathcal{VS}$ | where $\mathcal{VS}^{sym, dc}$ corresponds to the set of co-located VRE and storage resources with a storage DC component with equal (or symmetric) charge and discharge power capacities |
|$\mathcal{VS}^{sym, ac} \subseteq \mathcal{VS}$ | where $\mathcal{VS}^{sym, ac}$ corresponds to the set of co-located VRE and storage resources with a storage AC component with equal (or symmetric) charge and discharge power capacities |
|$\mathcal{VS}^{asym, dc, dis} \subseteq \mathcal{VS}$ | where $\mathcal{VS}^{asym, dc, dis}$ corresponds to the set of co-located VRE and storage resources with a storage DC component with independently sized (or asymmetric) discharge power capabilities |
|$\mathcal{VS}^{asym, dc, cha} \subseteq \mathcal{VS}$ | where $\mathcal{VS}^{asym, dc, cha}$ corresponds to the set of co-located VRE and storage resources with a storage DC component with independently sized (or asymmetric) charge power capabilities |
|$\mathcal{VS}^{asym, ac, dis} \subseteq \mathcal{VS}$ | where $\mathcal{VS}^{asym, ac, dis}$ corresponds to the set of co-located VRE and storage with a storage AC component with independently sized (or asymmetric) discharge power capabilities |
|$\mathcal{VS}^{asym, ac, cha} \subseteq \mathcal{VS}$ | where $\mathcal{VS}^{asym, ac, cha}$ corresponds to the set of co-located VRE and storage resources with a storage AC component with independently sized (or asymmetric) charge power capabilities |
|$\mathcal{VS}^{LDES} \subseteq \mathcal{VS}$ | where $\mathcal{VS}^{LDES}$ corresponds to the set of co-located VRE and storage resources with a long-duration energy storage component for which inter-period energy exchange is permitted when using representative periods to model annual grid operations|
$\mathcal{W} \subseteq \mathcal{G}$ | where $\mathcal{W}$ set of hydroelectric generators with water storage reservoirs|
|$\mathcal{W}^{nocap} \subseteq \mathcal{W}$ | where $\mathcal{W}^{nocap}$ is a subset of set of $ \mathcal{W}$ and represents resources with unknown reservoir capacity|
|$\mathcal{W}^{cap} \subseteq \mathcal{W}$ | where $\mathcal{W}^{cap}$ is a subset of set of $ \mathcal{W}$ and represents resources with known reservoir capacity|
|$\mathcal{MR} \subseteq \mathcal{G}$ | where $\mathcal{MR}$ set of must-run resources|
|$\mathcal{DF} \subseteq \mathcal{G}$ | where $\mathcal{DF}$ set of flexible demand resources|
|$\mathcal{ELECTROLYZER} \subseteq \mathcal{G}$ | where $\mathcal{ELECTROLYZER}$ set of electrolyzer resources (optional set)|
|$\mathcal{G}_p^{ESR} \subseteq \mathcal{G}$ | where $\mathcal{G}_p^{ESR}$ is a subset of $\mathcal{G}$ that is eligible for Energy Share Requirement (ESR) policy constraint $p$|
|$p \in \mathcal{P}$ | where $p$ denotes a instance in the policy set $\mathcal{P}$|
|$\mathcal{P}^{ESR} \subseteq \mathcal{P}$ | Energy Share Requirement type policies |
|$\mathcal{P}^{CO_2} \subseteq \mathcal{P}$ | CO$_2$ emission cap policies|
|$\mathcal{P}^{CO_2}_{mass} \subseteq \mathcal{P}^{CO_2}$ | CO$_2$ emissions limit policy constraints, mass-based |
|$\mathcal{P}^{CO_2}_{demand} \subseteq \mathcal{P}^{CO_2}$ | CO$_2$ emissions limit policy constraints, demand and emission-rate based |   
|$\mathcal{P}^{CO_2}_{gen} \subseteq \mathcal{P}^{CO_2}$ | CO$_2$ emissions limit policy constraints, generation emission-rate based |
|$\mathcal{P}^{CRM} \subseteq \mathcal{P}$ | Capacity reserve margin (CRM) type policy constraints |
|$\mathcal{P}^{MinTech} \subseteq \mathcal{P}$ | Minimum Capacity Carve-out type policy constraint |
|$\mathcal{Z}^{ESR}_{p} \subseteq \mathcal{Z}$ | set of zones eligible for ESR policy constraint $p \in \mathcal{P}^{ESR}$ |
|$\mathcal{Z}^{CRM}_{p} \subseteq \mathcal{Z}$ | set of zones that form the locational deliverable area for capacity reserve margin policy constraint $p \in \mathcal{P}^{CRM}$ |
|$\mathcal{Z}^{CO_2}_{p,mass} \subseteq \mathcal{Z}$ | set of zones are under the emission cap mass-based cap-and-trade policy constraint $p \in \mathcal{P}^{CO_2}_{mass}$ |
|$\mathcal{Z}^{CO_2}_{p,demand} \subseteq \mathcal{Z}$ | set of zones are under the emission cap demand-and-emission-rate based cap-and-trade policy constraint $p \in \mathcal{P}^{CO_2}_{demand}$ |
|$\mathcal{Z}^{CO_2}_{p,gen} \subseteq \mathcal{Z}$ | set of zones are under the emission cap generation emission-rate based cap-and-trade policy constraint $p \in \mathcal{P}^{CO2,gen}$ |
|$\mathcal{L}_p^{in} \subseteq \mathcal{L}$ | The subset of transmission lines entering Locational Deliverability Area of capacity reserve margin policy $p \in \mathcal{P}^{CRM}$ |
|$\mathcal{L}_p^{out} \subseteq \mathcal{L}$ | The subset of transmission lines leaving Locational Deliverability Area of capacity reserve margin policy $p \in \mathcal{P}^{CRM}$ |
|$\mathcal{Qualified} \subseteq \mathcal{G}$ | where $\mathcal{Qualified}$ is the subset of generation and storage resources eligible to supply electrolyzers within the same zone (optional set) |
---


## Decision Variables
---
|**Notation** | **Description**|
| :------------ | :-----------|
|$\Omega_{y,z} \in \mathbb{R}_+$ | Installed capacity in terms of the number of units (each unit, being of size $\overline{\Omega}_{y,z}^{size}$) of resource $y$  in zone $z$ \[Dimensionless\] (Note that for co-located VRE and storage resources, this value represents the installed capacity of the grid connection in \[MW AC\])|
|$\Omega^{energy}_{y,z} \in \mathbb{R}_+$ | Installed energy capacity of resource $y$  in zone $z$ - only applicable for storage resources, $y \in \mathcal{O} \cup y \in \mathcal{VS}^{stor}$ \[MWh] (Note that for co-located VRE and storage resources, this value represents the installed capacity of the storage component in MWh)|
|$\Omega^{charge}_{y,z} \in \mathbb{R}_+$ | Installed charging power capacity of resource $y$  in zone $z$ - only applicable for storage resources, $y \in \mathcal{O}^{asym}$ \[MW\]|
|$\Omega^{pv}_{y,z} \in \mathbb{R}_+$ | Installed solar PV capacity of resource $y$  in zone $z$ - only applicable for co-located VRE and storage resources with a solar PV component, $y \in \mathcal{VS}^{pv}$ \[MW DC\]|
|$\Omega^{wind}_{y,z} \in \mathbb{R}_+$ | Installed wind capacity of resource $y$  in zone $z$ - only applicable for co-located VRE and storage resources with a wind component, $y \in \mathcal{VS}^{wind}$ \[MW AC\]|
|$\Omega^{elec}_{y,z} \in \mathbb{R}_+$ | Installed electrolyzer capacity of resource $y$  in zone $z$ - only applicable for co-located VRE and storage resources with an electrolyzer component, $y \in \mathcal{VS}^{elec}$ \[MW AC\]|
|$\Omega^{inv}_{y,z} \in \mathbb{R}_+$ | Installed inverter capacity of resource $y$  in zone $z$ - only applicable for co-located VRE and storage resources with an inverter component, $y \in \mathcal{VS}^{inv}$ \[MW AC\]|
|$\Omega^{dc,dis}_{y,z} \in \mathbb{R}_+$ | Installed storage DC discharge capacity of resource $y$  in zone $z$ - only applicable for co-located VRE and storage resources with an asymmetric storage DC discharge component, $y \in \mathcal{VS}^{asym,dc,dis}$ \[MW DC\]|
|$\Omega^{dc,cha}_{y,z} \in \mathbb{R}_+$ | Installed storage DC charge capacity of resource $y$  in zone $z$ - only applicable for co-located VRE and storage resources with an asymmetric storage DC charge component, $y \in \mathcal{VS}^{asym,dc,cha}$ \[MW DC\]|
|$\Omega^{ac,dis}_{y,z} \in \mathbb{R}_+$ | Installed storage AC discharge capacity of resource $y$  in zone $z$ - only applicable for co-located VRE and storage resources with an asymmetric storage AC discharge component, $y \in \mathcal{VS}^{asym,ac,dis}$ \[MW AC\]|
|$\Omega^{ac,cha}_{y,z} \in \mathbb{R}_+$ | Installed storage AC charge capacity of resource $y$  in zone $z$ - only applicable for co-located VRE and storage resources with an asymmetric storage AC charge component, $y \in \mathcal{VS}^{asym,ac,cha}$ \[MW AC\]|
|$\Delta_{y,z} \in \mathbb{R}_+$ | Retired capacity of technology $y$ from existing capacity in zone $z$ \[MW\] (Note that for co-located VRE and storage resources, this value represents the retired capacity of the grid connection in MW AC)|
|$\Delta^{energy}_{y,z} \in \mathbb{R}_+$ | Retired energy capacity of technology $y$ from existing capacity in zone $z$ - only applicable for storage resources, $y \in \mathcal{O} \cup y \in \mathcal{VS}^{stor}$ \[MWh] (Note that for co-located VRE and storage resources, this value represents the retired capacity of the storage component in MWh)|
|$\Delta^{charge}_{y,z} \in \mathbb{R}_+$ | Retired charging capacity of technology $y$ from existing capacity in zone $z$ - only applicable for storage resources, $y \in \mathcal{O}^{asym}$\[MW\]|
|$\Delta^{pv}_{y,z} \in \mathbb{R}_+$ | Retired solar PV capacity of technology $y$ from existing capacity in zone $z$ - only applicable for co-located VRE and storage resources with a solar PV component, $y \in \mathcal{VS}^{pv}$ \[MW DC\]|
|$\Delta^{wind}_{y,z} \in \mathbb{R}_+$ | Retired wind capacity of technology $y$ from existing capacity in zone $z$ - only applicable for co-located VRE and storage resources with a wind component, $y \in \mathcal{VS}^{wind}$ \[MW AC\]|
|$\Delta^{elec}_{y,z} \in \mathbb{R}_+$ | Retired electrolyzer capacity of technology $y$ from existing capacity in zone $z$ - only applicable for co-located VRE and storage resources with an electrolyzer component, $y \in \mathcal{VS}^{elec}$ \[MW AC\]|
|$\Delta^{inv}_{y,z} \in \mathbb{R}_+$ | Retired inverter capacity of technology $y$ from existing capacity in zone $z$ - only applicable for co-located VRE and storage resources with an inverter component, $y \in \mathcal{VS}^{inv}$ \[MW AC\]|
|$\Delta^{dc,dis}_{y,z} \in \mathbb{R}_+$ | Retired storage DC discharge capacity of technology $y$ from existing capacity in zone $z$ - only applicable for co-located VRE and storage resources with an asymmetric storage DC discharge component, $y \in \mathcal{VS}^{asym,dc,dis}$ \[MW DC\]|
|$\Delta^{dc,cha}_{y,z} \in \mathbb{R}_+$ | Retired storage DC charge capacity of technology $y$ from existing capacity in zone $z$ - only applicable for co-located VRE and storage resources with an asymmetric storage DC charge component, $y \in \mathcal{VS}^{asym,dc,cha}$ \[MW DC\]|
|$\Delta^{ac,dis}_{y,z} \in \mathbb{R}_+$ | Retired storage AC discharge capacity of technology $y$ from existing capacity in zone $z$ - only applicable for co-located VRE and storage resources with an asymmetric storage AC discharge component, $y \in \mathcal{VS}^{asym,ac,dis}$ \[MW AC\]|
|$\Delta^{ac,cha}_{y,z} \in \mathbb{R}_+$ | Retired storage AC charge capacity of technology $y$ from existing capacity in zone $z$ - only applicable for co-located VRE and storage resources with an asymmetric storage AC charge component, $y \in \mathcal{VS}^{asym,ac,cha}$ \[MW AC\]|
|$\Delta_{y,z}^{total} \in \mathbb{R}_+$ | Total installed capacity of technology $y$ in zone $z$ \[MW\] (Note that co-located VRE and storage resources, this value represents the total capacity of the grid connection in MW AC) |
|$\Delta_{y,z}^{total,energy} \in \mathbb{R}_+$ | Total installed energy capacity of technology $y$ in zone $z$  - only applicable for storage resources, $y \in \mathcal{O} \cup y \in \mathcal{VS}^{stor}$ \[MWh] (Note that co-located VRE and storage resources, this value represents the total installed energy capacity of the storage component in MWh) |
|$\Delta_{y,z}^{total,charge} \in \mathbb{R}_+$ | Total installed charging power capacity of technology $y$ in zone $z$ - only applicable for storage resources, $y \in \mathcal{O}^{asym}$ \[MW\]|
|$\Delta_{y,z}^{total,pv} \in \mathbb{R}_+$ | Total installed solar PV capacity of technology $y$ in zone $z$  - only applicable for co-located VRE and storage resources with a solar PV component, $y \in \mathcal{VS}^{pv}$ \[MW DC\]|
|$\Delta_{y,z}^{total,wind} \in \mathbb{R}_+$ | Total installed wind capacity of technology $y$ in zone $z$  - only applicable for co-located VRE and storage resources with a wind component, $y \in \mathcal{VS}^{wind}$ \[MW AC\]|
|$\Delta_{y,z}^{total,elec} \in \mathbb{R}_+$ | Total installed electrolyzer capacity of technology $y$ in zone $z$  - only applicable for co-located VRE and storage resources with an electrolyzer component, $y \in \mathcal{VS}^{elec}$ \[MW AC\]|
|$\Delta_{y,z}^{total,inv} \in \mathbb{R}_+$ | Total installed inverter capacity of technology $y$ in zone $z$  - only applicable for co-located VRE and storage resources with an inverter component, $y \in \mathcal{VS}^{inv}$ \[MW AC\]|
|$\Delta_{y,z}^{total,dc,dis} \in \mathbb{R}_+$ | Total installed storage DC discharge capacity of technology $y$ in zone $z$  - only applicable for co-located VRE and storage resources with an asymmetric storage DC discharge component, $y \in \mathcal{VS}^{asym,dc,dis}$ \[MW DC\]|
|$\Delta_{y,z}^{total,dc,cha} \in \mathbb{R}_+$ | Total installed storage DC charge capacity of technology $y$ in zone $z$  - only applicable for co-located VRE and storage resources with an asymmetric storage DC charge component, $y \in \mathcal{VS}^{asym,dc,cha}$ \[MW DC\]|
|$\Delta_{y,z}^{total,ac,dis} \in \mathbb{R}_+$ | Total installed storage AC discharge capacity of technology $y$ in zone $z$  - only applicable for co-located VRE and storage resources with an asymmetric storage AC discharge component, $y \in \mathcal{VS}^{asym,ac,dis}$ \[MW AC\]|
|$\Delta_{y,z}^{total,ac,cha} \in \mathbb{R}_+$ | Total installed storage AC charge capacity of technology $y$ in zone $z$  - only applicable for co-located VRE and storage resources with an asymmetric storage AC charge component, $y \in \mathcal{VS}^{asym,ac,cha}$ \[MW AC\]|
|$\bigtriangleup\varphi^{max}_{l}$ | Additional transmission capacity added to line $l$ \[MW\] |
|$\Theta_{y,z,t} \in \mathbb{R}_+$ | Energy injected into the grid by technology $y$ at time step $t$ in zone $z$ \[MWh]|
|$\Theta^{pv}_{y,z,t} \in \mathbb{R}_+$ | Energy generated by the solar PV component into the grid by technology $y$ at time step $t$ in zone $z$ - only applicable for co-located VRE and storage resources with a solar PV component, $y \in \mathcal{VS}^{pv}$ \[MWh]|
|$\Theta^{wind}_{y,z,t} \in \mathbb{R}_+$ | Energy generated by the wind component into the grid by technology $y$ at time step $t$ in zone $z$ - only applicable for co-located VRE and storage resources with a wind component, $y \in \mathcal{VS}^{wind}$ \[MWh]|
|$\Theta^{dc}_{y,z,t} \in \mathbb{R}_+$ | Energy discharged by the storage DC component into the grid by technology $y$ at time step $t$ in zone $z$ - only applicable for co-located VRE and storage resources with a discharge DC component, $y \in \mathcal{VS}^{sym,dc} \cup y \in \mathcal{VS}^{asym,dc,dis}$ \[MWh]|
|$\Theta^{ac}_{y,z,t} \in \mathbb{R}_+$ | Energy discharged by the storage AC component into the grid by technology $y$ at time step $t$ in zone $z$ - only applicable for co-located VRE and storage resources with a discharge AC component, $y \in \mathcal{VS}^{sym,ac} \cup y \in \mathcal{VS}^{asym,ac,dis}$ \[MWh]|
|$\Pi_{y,z,t} \in \mathbb{R}_+$ | Energy withdrawn from grid by technology $y$ at time step $t$ in zone $z$ \[MWh]|
|$\Pi^{dc}_{y,z,t} \in \mathbb{R}_+$ | Energy withdrawn from the VRE and grid by technology $y$ at time step $t$ in zone $z$ - only applicable for co-located VRE and storage resources with a charge DC component, $y \in \mathcal{VS}^{sym,dc} \cup y \in \mathcal{VS}^{asym,dc,cha}$ \[MWh]|
|$\Pi^{ac}_{y,z,t} \in \mathbb{R}_+$ | Energy withdrawn from the VRE and grid by technology $y$ at time step $t$ in zone $z$ - only applicable for co-located VRE and storage resources with a charge AC component, $y \in \mathcal{VS}^{sym,ac} \cup y \in \mathcal{VS}^{asym,ac,cha}$ \[MWh]|
|$\Pi^{elec}_{y,z,t} \in \mathbb{R}_+$ | Energy withdrawn from the VRE and grid by technology $y$ at time step $t$ in zone $z$ - only applicable for co-located VRE and storage resources with an electrolyzer component, $y \in \mathcal{VS}^{sym,dc} \cup y \in \mathcal{VS}^{asym,dc,cha}$ \[MWh]|
|$\Gamma_{y,z,t} \in \mathbb{R}_+$ | Stored energy level of technology $y$ at end of time step $t$ in zone $z$ \[MWh]|
|$\Lambda_{s,z,t} \in \mathbb{R}_+$ | Non-served energy/curtailed demand from the price-responsive demand segment $s$ in zone $z$ at time step $t$ \[MWh] |
|$l_{l,t} \in \mathbb{R}_+$ | Losses in line $l$ at time step $t$ \[MWh]|
|$\varrho_{y,z,t}\in \mathbb{R}_+$ | Spillage from a reservoir technology $y$ at end of time step $t$ in zone $z$ \[MWh]|
|$f_{y,z,t}\in \mathbb{R}_+$ | Frequency regulation contribution \[MW\] for up and down reserves from technology $y$ in zone $z$ at time $t$\footnote{Regulation reserve contribution are modeled to be symmetric, consistent with current practice in electricity markets} |
|$r_{y,z,t} \in \mathbb{R}_+$ |  Upward spinning reserves contribution \[MW\] from technology $y$ in zone $z$ at time $t (we are not modeling down spinning reserves since these are usually never binding for high variable renewable energy systems)|
|$f^{charge}_{y,z,t}\in \mathbb{R}_+$ | Frequency regulation contribution \[MW\] for up and down reserves from charging storage technology $y$ in zone $z$ at time $t$ |
|$f^{discharge}_{y,z,t}\in \mathbb{R}_+$ | Frequency regulation contribution \[MW\] for up and down reserves from discharging storage technology $y$ in zone $z$ at time $t$ |
|$r^{charge}_{y,z,t} \in \mathbb{R}_+$ |  Upward spinning reserves contribution \[MW\] from charging storage technology $y$ in zone $z$ at time $t$|
|$r^{discharge}_{y,z,t} \in \mathbb{R}_+$ |  Upward spinning reserves contribution \[MW\] from discharging storage technology $y$ in zone $z$ at time $t$|
|$r^{unmet}_t \in \mathbb{R}_+$ | Shortfall in provision of upward operating spinning reserves during each time period $t \in T$ |
|$f^{pv}_{y,z,t}\in \mathbb{R}_+$ | Frequency regulation contribution \[MW\] for up and down reserves for the solar PV component from technology $y$ in zone $z$ at time $t$ - only applicable for co-located VRE and storage resources with a solar PV component, $y \in \mathcal{VS}^{pv}$ |
|$r^{pv}_{y,z,t} \in \mathbb{R}_+$ |  Upward spinning reserves contribution \[MW\] for the solar PV component from technology $y$ in zone $z$ at time $t$ - only applicable for co-located VRE and storage resources with a solar PV component, $y \in \mathcal{VS}^{pv}$ |
|$f^{wind}_{y,z,t}\in \mathbb{R}_+$ | Frequency regulation contribution \[MW\] for up and down reserves for the wind component from technology $y$ in zone $z$ at time $t$ - only applicable for co-located VRE and storage resources with a wind component, $y \in \mathcal{VS}^{wind}$ |
|$r^{wind}_{y,z,t} \in \mathbb{R}_+$ |  Upward spinning reserves contribution \[MW\] for the wind component from technology $y$ in zone $z$ at time $t$ - only applicable for co-located VRE and storage resources with a wind component, $y \in \mathcal{VS}^{wind}$ |
|$f^{dc,dis}_{y,z,t}\in \mathbb{R}_+$ | Frequency regulation contribution \[MW\] for up and down reserves for the storage DC discharge component from technology $y$ in zone $z$ at time $t$ - only applicable for co-located VRE and storage resources with a storage DC discharge component, $y \in \mathcal{VS}^{sym,dc} \cup y \in \mathcal{VS}^{asym,dc,dis}$ |
|$r^{dc,dis}_{y,z,t} \in \mathbb{R}_+$ |  Upward spinning reserves contribution \[MW\] for the storage DC discharge component from technology $y$ in zone $z$ at time $t$ - only applicable for co-located VRE and storage resources with a storage DC discharge component, $y \in \mathcal{VS}^{sym,dc} \cup y \in \mathcal{VS}^{asym,dc,dis}$ |
|$f^{dc,cha}_{y,z,t}\in \mathbb{R}_+$ | Frequency regulation contribution \[MW\] for up and down reserves for the storage DC charge component from technology $y$ in zone $z$ at time $t$ - only applicable for co-located VRE and storage resources with a storage DC charge component, $y \in \mathcal{VS}^{sym,dc} \cup y \in \mathcal{VS}^{asym,dc,cha}$ |
|$r^{dc,cha}_{y,z,t} \in \mathbb{R}_+$ |  Upward spinning reserves contribution \[MW\] for the storage DC charge component from technology $y$ in zone $z$ at time $t$ - only applicable for co-located VRE and storage resources with a storage DC charge component, $y \in \mathcal{VS}^{sym,dc} \cup y \in \mathcal{VS}^{asym,dc,cha}$ |
|$f^{ac,dis}_{y,z,t}\in \mathbb{R}_+$ | Frequency regulation contribution \[MW\] for up and down reserves for the storage AC discharge component from technology $y$ in zone $z$ at time $t$ - only applicable for co-located VRE and storage resources with a storage AC discharge component, $y \in \mathcal{VS}^{sym,ac} \cup y \in \mathcal{VS}^{asym,ac,dis}$ |
|$r^{ac,dis}_{y,z,t} \in \mathbb{R}_+$ |  Upward spinning reserves contribution \[MW\] for the storage AC discharge component from technology $y$ in zone $z$ at time $t$ - only applicable for co-located VRE and storage resources with a storage AC discharge component, $y \in \mathcal{VS}^{sym,ac} \cup y \in \mathcal{VS}^{asym,ac,dis}$ |
|$f^{ac,cha}_{y,z,t}\in \mathbb{R}_+$ | Frequency regulation contribution \[MW\] for up and down reserves for the storage AC charge component from technology $y$ in zone $z$ at time $t$ - only applicable for co-located VRE and storage resources with a storage AC charge component, $y \in \mathcal{VS}^{sym,ac} \cup y \in \mathcal{VS}^{asym,ac,cha}$ |
|$r^{ac,cha}_{y,z,t} \in \mathbb{R}_+$ |  Upward spinning reserves contribution \[MW\] for the storage AC charge component from technology $y$ in zone $z$ at time $t$ - only applicable for co-located VRE and storage resources with a storage AC charge component, $y \in \mathcal{VS}^{sym,ac} \cup y \in \mathcal{VS}^{asym,ac,cha}$ |
|$\alpha^{Contingency,Aux}_{y,z} \in \{0,1\}$ | Binary variable that is set to be 1 if the total installed capacity  $\Delta^{\text{total}}_{y,z} > 0$ for any generator $y \in \mathcal{UC}$ and zone $z$, and can be 0 otherwise |
|$\Phi_{l,t} \in \mathbb{R}_+$ | Power flow in line $l$ at time step $t$ \[MWh\]|
|$\theta_{z,t} \in \mathbb{R}$ | Voltage phase angle in zone $z$ at time step $t$ \[radian\]|
|$\nu_{y,z,t}$ | Commitment state of the generation cluster $y$ in zone $z$ at time $t$|
|$\chi_{y,z,t}$ | Number of startup decisions,  of the generation cluster $y$ in zone $z$ at time $t$|
|$\zeta_{y,z,t}$ | Number of shutdown decisions,  of the generation cluster $y$ in zone $z$ at time $t$|
|$\mathcal{Q}_{o,n} \in \mathbb{R}_+$ | Inventory of storage of type $o$ at the beginning of input period $n$ \[MWh]|
|$\Delta\mathcal{Q}_{o,m} \in \mathbb{R}$ | Excess storage inventory built up during representative period $m$ \[MWh]|
|$ON^{+}_{l,t} \in {0,1}$ | Binary variable to activate positive flows on line $l$ in time $t$|
|$TransON^{+}_{l,t} \in \mathbb{R}_+$ | Variable defining maximum positive flow in line $l$ in time $t$ \[MW\]|
|$\Theta^{CRM}_{y,z,t} \in \mathbb{R}_+$ | "Virtual" energy discharged by a storage resource that contributes to the capacity reserve margin for technology $y$ at time step $t$ in zone $z$ - only applicable for storage resources with activated capacity reserve margin policies, $y \in \mathcal{O}$ \[MWh]|
|$\Pi^{CRM}_{y,z,t} \in \mathbb{R}_+$ | "Virtual" energy withdrawn by a storage resource from the grid by technology $y$ at time step $t$ in zone $z$ - only applicable for storage resources with activated capacity reserve margin policies, $y \in \mathcal{O}$ \[MWh]|
|$\Theta^{CRM,dc}_{y,z,t} \in \mathbb{R}_+$ | "Virtual" energy discharged by a storage DC component that contributes to the capacity reserve margin for technology $y$ at time step $t$ in zone $z$ - only applicable for co-located VRE and storage resources with activated capacity reserve margin policies, $y \in \mathcal{VS}^{stor}$ \[MWh]|
|$\Pi^{CRM,dc}_{y,z,t} \in \mathbb{R}_+$ | "Virtual" energy withdrawn by a storage DC component from the grid by technology $y$ at time step $t$ in zone $z$ - only applicable for co-located VRE and storage resources with activated capacity reserve margin policies, $y \in \mathcal{VS}^{stor}$ \[MWh]|
|$\Theta^{CRM,ac}_{y,z,t} \in \mathbb{R}_+$ | "Virtual" energy discharged by a storage AC component that contributes to the capacity reserve margin for technology $y$ at time step $t$ in zone $z$ - only applicable for co-located VRE and storage resources with activated capacity reserve margin policies, $y \in \mathcal{VS}^{stor}$ \[MWh]|
|$\Pi^{CRM,ac}_{y,z,t} \in \mathbb{R}_+$ | "Virtual" energy withdrawn by a storage AC component from the grid by technology $y$ at time step $t$ in zone $z$ - only applicable for co-located VRE and storage resources with activated capacity reserve margin policies, $y \in \mathcal{VS}^{stor}$ \[MWh]|
|$\Gamma^{CRM}_{y,z,t} \in \mathbb{R}_+$ | Total "virtual" state of charge being held in reserves for technology $y$ at time step $t$ in zone $z$ - only applicable for standalone storage and co-located VRE and storage resources with activated capacity reserve margin policies, $y \in \mathcal{O} \cup y \in \mathcal{VS}^{stor}$ \[MWh]|
---


## Parameters
---
|**Notation** | **Description**|
| :------------ | :-----------|
|$D_{z,t}$ | Electricity demand in zone $z$ and at time step $t$ \[MWh\]|
|$\tau^{period}$ | number of time steps in each representative period $w \in \mathcal{W}^{rep}$ and each input period $w \in \mathcal{W}^{input}$|
|$\omega_{t}$ | weight of each model time step $\omega_t =1 \forall t \in T$ when modeling each time step of the year at an hourly resolution \[1/year\]|
|$n_s^{slope}$ | Cost of non-served energy/demand curtailment for price-responsive demand segment $s$ \[\$/MWh\]|
|$n_s^{size}$ | Size of price-responsive demand segment $s$ as a fraction of the hourly zonal demand \[%\]|
|$\overline{\Omega}_{y,z}$ | Maximum capacity of technology $y$ in zone $z$ \[MW\] (Note that for co-located VRE and storage resources, this value represents the maximum grid connection capacity in MW AC)|
|$\underline{\Omega}_{y,z}$ | Minimum capacity of technology $y$ in zone $z$ \[MW\] (Note that for co-located VRE and storage resources, this value represents the minimum grid connection capacity in MW AC)|
|$\overline{\Omega}^{energy}_{y,z}$ | Maximum energy capacity of technology $y$ in zone $z$ - only applicable for storage resources, $y \in \mathcal{O} \cup y \in \mathcal{VS}^{stor}$ \[MWh\] (Note that for co-located VRE and storage resources, this value represents the maximum storage component in MWh)|
|$\underline{\Omega}^{energy}_{y,z}$ | Minimum energy capacity of technology $y$ in zone $z$ - only applicable for storage resources, $y \in \mathcal{O} \cup y \in \mathcal{VS}^{stor}$ \[MWh\] (Note that for co-located VRE and storage resources, this value represents the minimum storage component in MWh)|
|$\overline{\Omega}^{charge}_{y,z}$ | Maximum charging power capacity of technology $y$ in zone $z$  - only applicable for storage resources, $y \in \mathcal{O}^{asym}$ \[MW\]|
|$\underline{\Omega}^{charge}_{y,z}$ | Minimum charging capacity of technology $y$ in zone $z$- only applicable for storage resources, $y \in \mathcal{O}^{asym}$ \[MW\]|
|$\overline{\Omega}^{pv}_{y,z}$ | Maximum solar PV capacity of technology $y$ in zone $z$ - only applicable for co-located VRE and storage resources with a solar PV component, $y \in \mathcal{VS}^{pv}$ \[MW DC\]|
|$\underline{\Omega}^{pv}_{y,z}$ | Minimum solar PV capacity of technology $y$ in zone $z$ - only applicable for co-located VRE and storage resources with a solar PV component, $y \in \mathcal{VS}^{pv}$ \[MW DC\]|
|$\overline{\Omega}^{wind}_{y,z}$ | Maximum wind capacity of technology $y$ in zone $z$ - only applicable for co-located VRE and storage resources with a wind component, $y \in \mathcal{VS}^{wind}$ \[MW AC\]|
|$\underline{\Omega}^{wind}_{y,z}$ | Minimum wind capacity of technology $y$ in zone $z$ - only applicable for co-located VRE and storage resources with a wind component, $y \in \mathcal{VS}^{wind}$ \[MW AC\]|
|$\overline{\Omega}^{elec}_{y,z}$ | Maximum electrolyzer capacity of technology $y$ in zone $z$ - only applicable for co-located VRE and storage resources with an electrolzyer component, $y \in \mathcal{VS}^{elec}$ \[MW AC\]|
|$\underline{\Omega}^{elec}_{y,z}$ | Minimum electrolyzer capacity of technology $y$ in zone $z$ - only applicable for co-located VRE and storage resources with an electrolyzer component, $y \in \mathcal{VS}^{elec}$ \[MW AC\]|
|$\overline{\Omega}^{inv}_{y,z}$ | Maximum inverter capacity of technology $y$ in zone $z$ - only applicable for co-located VRE and storage resources with an inverter component, $y \in \mathcal{VS}^{inv}$ \[MW AC\]|
|$\underline{\Omega}^{inv}_{y,z}$ | Minimum inverter capacity of technology $y$ in zone $z$ - only applicable for co-located VRE and storage resources with an inverter component, $y \in \mathcal{VS}^{inv}$ \[MW AC\]|
|$\overline{\Omega}^{dc,dis}_{y,z}$ | Maximum storage DC discharge capacity of technology $y$ in zone $z$ - only applicable for co-located VRE and storage resources with an asymmetric storage DC discharge component, $y \in \mathcal{VS}^{asym,dc,dis}$ \[MW DC\]|
|$\underline{\Omega}^{dc,dis}_{y,z}$ | Minimum storage DC discharge capacity of technology $y$ in zone $z$ - only applicable for co-located VRE and storage resources with an asymmetric storage DC discharge component, $y \in \mathcal{VS}^{asym,dc,dis}$ \[MW DC\]|
|$\overline{\Omega}^{dc,cha}_{y,z}$ | Maximum storage DC charge capacity of technology $y$ in zone $z$ - only applicable for co-located VRE and storage resources with an asymmetric storage DC charge component, $y \in \mathcal{VS}^{asym,dc,cha}$ \[MW DC\]|
|$\underline{\Omega}^{dc,cha}_{y,z}$ | Minimum storage DC charge capacity of technology $y$ in zone $z$ - only applicable for co-located VRE and storage resources with an asymmetric storage DC charge component, $y \in \mathcal{VS}^{asym,dc,cha}$ \[MW DC\]|
|$\overline{\Omega}^{ac,dis}_{y,z}$ | Maximum storage AC discharge capacity of technology $y$ in zone $z$ - only applicable for co-located VRE and storage resources with an asymmetric storage AC discharge component, $y \in \mathcal{VS}^{asym,ac,dis}$ \[MW AC\]|
|$\underline{\Omega}^{ac,dis}_{y,z}$ | Minimum storage AC discharge capacity of technology $y$ in zone $z$ - only applicable for co-located VRE and storage resources with an asymmetric storage AC discharge component, $y \in \mathcal{VS}^{asym,ac,dis}$ \[MW AC\]|
|$\overline{\Omega}^{ac,cha}_{y,z}$ | Maximum storage AC charge capacity of technology $y$ in zone $z$ - only applicable for co-located VRE and storage resources with an asymmetric storage AC charge component, $y \in \mathcal{VS}^{asym,ac,cha}$ \[MW AC\]|
|$\underline{\Omega}^{ac,cha}_{y,z}$ | Minimum storage AC charge capacity of technology $y$ in zone $z$ - only applicable for co-located VRE and storage resources with an asymmetric storage AC charge component, $y \in \mathcal{VS}^{asym,ac,cha}$ \[MW AC\]|
|$\overline{\Delta}_{y,z}$ | Existing installed capacity of technology $y$ in zone $z$ \[MW\] (Note that for co-located VRE and storage resources, this value represents the existing installed capacity of the grid connection in \[MW AC\])|
|$\overline{\Delta^{energy}_{y,z}}$ | Existing installed energy capacity of technology $y$ in zone $z$ - only applicable for storage resources, $y \in \mathcal{O} \cup y \in \mathcal{VS}^{stor}$ \[MWh] (Note that for co-located VRE and storage resources, this value represents the existing installed energy capacity of the storage component in MWh)|
|$\overline{\Delta^{charge}_{y,z}}$ | Existing installed charging capacity of technology $y$ in zone $z$ - only applicable for storage resources, $y \in \mathcal{O}$ \[MW\]|
|$\overline{\Delta^{pv}_{y,z}}$ | Existing installed solar PV capacity of technology $y$ in zone $z$ - only applicable for co-located VRE and storage resources with a solar PV component, $y \in \mathcal{VS}^{pv}$ \[MW DC\]|
|$\overline{\Delta^{wind}_{y,z}}$ | Existing installed wind capacity of technology $y$ in zone $z$ - only applicable for co-located VRE and storage resources with a wind component, $y \in \mathcal{VS}^{wind}$ \[MW AC\]|
|$\overline{\Delta^{elec}_{y,z}}$ | Existing installed electrolyzer capacity of technology $y$ in zone $z$ - only applicable for co-located VRE and storage resources with an electrolyzer component, $y \in \mathcal{VS}^{elec}$ \[MW AC\]|
|$\overline{\Delta^{inv}_{y,z}}$ | Existing installed inverter capacity of technology $y$ in zone $z$ - only applicable for co-located VRE and storage resources with an inverter component, $y \in \mathcal{VS}^{inv}$ \[MW AC\]|
|$\overline{\Delta^{dc,dis}_{y,z}}$ | Existing installed storage DC discharge capacity of technology $y$ in zone $z$ - only applicable for co-located VRE and storage resources with an asymmetric storage DC discharge component, $y \in \mathcal{VS}^{asym,dc,dis}$ \[MW DC\]|
|$\overline{\Delta^{dc,cha}_{y,z}}$ | Existing installed storage DC charge capacity of technology $y$ in zone $z$ - only applicable for co-located VRE and storage resources with an asymmetric storage DC charge component, $y \in \mathcal{VS}^{asym,dc,cha}$ \[MW DC\]|
|$\overline{\Delta^{ac,dis}_{y,z}}$ | Existing installed storage AC discharge capacity of technology $y$ in zone $z$ - only applicable for co-located VRE and storage resources with an asymmetric storage AC discharge component, $y \in \mathcal{VS}^{asym,ac,dis}$ \[MW AC\]|
|$\overline{\Delta^{dc,cha}_{y,z}}$ | Existing installed storage AC charge capacity of technology $y$ in zone $z$ - only applicable for co-located VRE and storage resources with an asymmetric storage AC charge component, $y \in \mathcal{VS}^{asym,dc,cha}$ \[MW AC\]|
|$\overline{\Omega}_{y,z}^{size}$ | Unit size of technology $y$ in zone $z$ \[MW\]|
|$\pi_{y,z}^{INVEST}$ | Investment cost (annual amortization of total construction cost) for power capacity of technology $y$ in zone $z$ \[\$/MW-yr\] (Note that for co-located VRE and storage resources, this value represents the investment cost of the grid connection capacity in \$/MW AC-yr)|
|$\pi_{y,z}^{INVEST,energy}$ | Investment cost (annual amortization of total construction cost) for energy capacity of technology $y$ in zone $z$ - only applicable for storage resources, $y \in \mathcal{O} \cup y \in \mathcal{VS}^{pv}$ \[\$/MWh-yr\] (Note that for co-located VRE and storage resources, this value represents the investment cost of the energy capacity of the storage component in \$/MWh-yr)|
|$\pi_{y,z}^{INVEST,charge}$ | Investment cost (annual amortization of total construction cost) for charging power capacity of technology $y$ in zone $z$ - only applicable for storage resources, $y \in \mathcal{O}$ \[\$/MW-yr\]|
|$\pi_{y,z}^{INVEST,pv}$ | Investment cost (annual amortization of total construction cost) for solar PV capacity of technology $y$ in zone $z$ - only applicable for co-located VRE and storage resources with a solar PV component, $y \in \mathcal{VS}^{pv}$ \[\$/MW DC-yr\]|
|$\pi_{y,z}^{INVEST,wind}$ | Investment cost (annual amortization of total construction cost) for wind capacity of technology $y$ in zone $z$ - only applicable for co-located VRE and storage resources with a wind component, $y \in \mathcal{VS}^{wind}$ \[\$/MW AC-yr\]|
|$\pi_{y,z}^{INVEST,elec}$ | Investment cost (annual amortization of total construction cost) for electrolyzer capacity of technology $y$ in zone $z$ - only applicable for co-located VRE and storage resources with an electrolyzer component, $y \in \mathcal{VS}^{elec}$ \[\$/MW AC-yr\]|
|$\pi_{y,z}^{INVEST,inv}$ | Investment cost (annual amortization of total construction cost) for inverter capacity of technology $y$ in zone $z$ - only applicable for co-located VRE and storage resources with an inverter component, $y \in \mathcal{VS}^{inv}$ \[\$/MW AC-yr\]|
|$\pi_{y,z}^{INVEST,dc,dis}$ | Investment cost (annual amortization of total construction cost) for storage DC discharge capacity of technology $y$ in zone $z$ - only applicable for co-located VRE and storage resources with a storage DC discharge component, $y \in \mathcal{VS}^{asym,dc,dis}$ [\$/MW DC-yr]|
|$\pi_{y,z}^{INVEST,dc,cha}$ | Investment cost (annual amortization of total construction cost) for storage DC charge capacity of technology $y$ in zone $z$ - only applicable for co-located VRE and storage resources with a storage DC charge component, $y \in \mathcal{VS}^{asym,dc,cha}$ [\$/MW DC-yr]|
|$\pi_{y,z}^{INVEST,ac,dis}$ | Investment cost (annual amortization of total construction cost) for storage AC discharge capacity of technology $y$ in zone $z$ - only applicable for co-located VRE and storage resources with a storage AC discharge component, $y \in \mathcal{VS}^{asym,ac,dis}$ [\$/MW AC-yr]|
|$\pi_{y,z}^{INVEST,ac,cha}$ | Investment cost (annual amortization of total construction cost) for storage AC charge capacity of technology $y$ in zone $z$ - only applicable for co-located VRE and storage resources with a storage AC charge component, $y \in \mathcal{VS}^{asym,ac,cha}$ [\$/MW AC-yr]|
|$\pi_{y,z}^{FOM}$ | Fixed O&M cost of technology $y$ in zone $z$ \[\$/MW-yr\] (Note that for co-located VRE and storage resources, this value represents the fixed O&M cost of the grid connection capacity in \$/MW AC-yr) |
|$\pi_{y,z}^{FOM,energy}$ | Fixed O&M cost of energy component of technology $y$ in zone $z$ - only applicable for storage resources, $y \in \mathcal{O} \cup y \in \mathcal{VS}^{stor}$ \[\$/MWh-yr\] (Note that for co-located VRE and storage resources, this value represents the fixed O&M cost of the storage energy capacity in \$/MWh-yr)|
|$\pi_{y,z}^{FOM,charge}$ | Fixed O&M cost of charging power component of technology $y$ in zone $z$ - only applicable for storage resources, $y \in \mathcal{O}$ \[\$/MW-yr\]|
|$\pi_{y,z}^{FOM,pv}$ | Fixed O&M cost of the solar PV component of technology $y$ in zone $z$ - only applicable for co-located VRE and storage resources with a solar PV component, $y \in \mathcal{VS}^{pv}$ [\$/MW DC-yr]|
|$\pi_{y,z}^{FOM,wind}$ | Fixed O&M cost of the wind component of technology $y$ in zone $z$ - only applicable for co-located VRE and storage resources with a wind component, $y \in \mathcal{VS}^{wind}$ [\$/MW AC-yr]|
|$\pi_{y,z}^{FOM,elec}$ | Fixed O&M cost of the electrolyzer component of technology $y$ in zone $z$ - only applicable for co-located VRE and storage resources with an electrolyzer component, $y \in \mathcal{VS}^{elec}$ [\$/MW AC-yr]|
|$\pi_{y,z}^{FOM,inv}$ | Fixed O&M cost of the inverter component of technology $y$ in zone $z$ - only applicable for co-located VRE and storage resources with an inverter component, $y \in \mathcal{VS}^{inv}$ [\$/MW AC-yr]|
|$\pi_{y,z}^{FOM,dc,dis}$ | Fixed O&M cost of the storage DC discharge component of technology $y$ in zone $z$ - only applicable for co-located VRE and storage resources with an asymmetric storage DC discharge component, $y \in \mathcal{VS}^{asym,dc,dis}$ [\$/MW DC-yr]|
|$\pi_{y,z}^{FOM,dc,cha}$ | Fixed O&M cost of the storage DC charge component of technology $y$ in zone $z$ - only applicable for co-located VRE and storage resources with an asymmetric storage DC charge component, $y \in \mathcal{VS}^{asym,dc,cha}$ [\$/MW DC-yr]|
|$\pi_{y,z}^{FOM,ac,dis}$ | Fixed O&M cost of the storage AC discharge component of technology $y$ in zone $z$ - only applicable for co-located VRE and storage resources with an asymmetric storage AC discharge component, $y \in \mathcal{VS}^{asym,ac,dis}$ [\$/MW AC-yr]|
|$\pi_{y,z}^{FOM,ac,cha}$ | Fixed O&M cost of the storage AC charge component of technology $y$ in zone $z$ - only applicable for co-located VRE and storage resources with an asymmetric storage AC charge component, $y \in \mathcal{VS}^{asym,ac,cha}$ [\$/MW AC-yr]|
|$\pi_{y,z}^{VOM}$ | Variable O&M cost of technology $y$ in zone $z$ [\$/MWh]|
|$\pi_{y,z}^{VOM,charge}$ | Variable O&M cost of charging technology $y$ in zone $z$ - only applicable for storage and demand flexibility resources, $y \in \mathcal{O} \cup \mathcal{DF}$ [\$/MWh]|
|$\pi_{y,z}^{VOM,pv}$ | Variable O&M cost of the solar PV component of technology $y$ in zone $z$ - only applicable to co-located VRE and storage resources with a solar PV component, $y \in \mathcal{VS}^{pv}$ [\$/MWh]|
|$\pi_{y,z}^{VOM,wind}$ | Variable O&M cost of the wind component of technology $y$ in zone $z$ - only applicable to co-located VRE and storage resources with a wind component, $y \in \mathcal{VS}^{wind}$ [\$/MWh]|
|$\pi_{y,z}^{VOM,dc,dis}$ | Variable O&M cost of the storage DC discharge component of technology $y$ in zone $z$ - only applicable to co-located VRE and storage resources with a storage DC discharge component, $y \in \mathcal{VS}^{sym,dc} \cup y \in \mathcal{VS}^{asym,dc,dis}$ [\$/MWh]|
|$\pi_{y,z}^{VOM,dc,cha}$ | Variable O&M cost of the storage DC charge component of technology $y$ in zone $z$ - only applicable to co-located VRE and storage resources with a storage DC charge component, $y \in \mathcal{VS}^{sym,dc} \cup y \in \mathcal{VS}^{asym,dc,cha}$ [\$/MWh]|
|$\pi_{y,z}^{VOM,ac,dis}$ | Variable O&M cost of the storage AC discharge component of technology $y$ in zone $z$ - only applicable to co-located VRE and storage resources with a storage AC discharge component, $y \in \mathcal{VS}^{sym,ac} \cup y \in \mathcal{VS}^{asym,ac,dis}$ [\$/MWh]|
|$\pi_{y,z}^{VOM,ac,cha}$ | Variable O&M cost of the storage AC charge component of technology $y$ in zone $z$ - only applicable to co-located VRE and storage resources with a storage AC charge component, $y \in \mathcal{VS}^{sym,ac} \cup y \in \mathcal{VS}^{asym,ac,cha}$ [\$/MWh]|
|$\pi_{y,z}^{FUEL}$ | Fuel cost of technology $y$ in zone $z$ [\$/MWh]|
|$\pi_{y,z}^{START}$ | Startup cost of technology $y$ in zone $z$ [\$/startup]|
|$\pi^{TCAP}_{l}$ | Transmission line reinforcement or construction cost for line $l$|
|$\upsilon^{reg}_{y,z}$ | Maximum fraction of capacity that a resource $y$ in zone $z$ can contribute to frequency regulation reserve requirements|
|$\upsilon^{rsv}_{y,z}$ | Maximum fraction of capacity that a resource $y$ in zone $z$ can contribute to upward operating (spinning) reserve requirements|
|$\pi^{Unmet}_{rsv}$ | Cost of unmet spinning reserves in [\$/MW\]|
|$\epsilon^{demand}_{reg}$ | Frequency regulation reserve requirement as a fraction of forecasted demand in each time step |
|$\epsilon^{vre}_{reg}$ | Frequency regulation reserve requirement as a fraction of variable renewable energy generation in each time step |
|$\epsilon^{demand}_{rsv}$ | Operating (spinning) reserve requirement as a fraction of forecasted demand in each time step |
|$\epsilon^{vre}_{rsv}$ | Operating (spinning) reserve requirement as a fraction of forecasted variable renewable energy generation in each time step |
|$\epsilon_{y,z}^{CO_2}$ | CO$_2$ emissions per unit energy produced by technology $y$ in zone $z$ [metric tons/MWh]|
|$\epsilon_{y,z,p}^{MinTech}$ | Equals to 1 if a generator of technology $y$ in zone $z$ is eligible for minimum capacity carveout policy $p \in \mathcal{P}^{MinTech}$, otherwise 0|
|$REQ_p^{MinTech}$ | The minimum capacity requirement of minimum capacity carveout policy $p \in \mathcal{P}^{MinTech}$ [MW\]|
|$REQ_p^{MaxTech}$ | The maximum capacity requirement of minimum capacity carveout policy $p \in \mathcal{P}^{MinTech}$ [MW\]|
|$\epsilon_{y,z,p}^{CRM}$ | Capacity derating factor of technology $y$ in zone $z$ for capacity reserve margin policy $p \in \mathcal{P}^{CRM}$ [fraction]|
|$RM_{z,p}^{CRM}$ | Reserve margin of zone $z$ of capacity reserve margin policy $p \in \mathcal{P}^{CRM}$ [fraction]|
|$\epsilon_{z,p,mass}^{CO_2}$ | Emission budget of zone $z$ under the emission cap $p \in \mathcal{P}^{CO_2}_{mass}$ [ million of metric tonnes]|
|$\epsilon_{z,p,demand}^{CO_2}$ | Maximum carbon intensity of the demand of zone $z$ under the emission cap $p \in \mathcal{P}^{CO_2}_{demand}$ [metric tonnes/MWh]|
|$\epsilon_{z,p,gen}^{CO_2}$ | Maximum emission rate of the generation of zone $z$ under the emission cap $p \in \mathcal{P}^{CO_2}_{gen}$ [metric tonnes/MWh]|
|$\rho_{y,z}^{min}$ | Minimum stable power output per unit of installed capacity for technology $y$ in zone $z$ [%]|
|$\rho_{y,z,t}^{max}$ | Maximum available generation per unit of installed capacity during time step t for technology y in zone z [%]|
|$\rho_{y,z,t}^{max,pv}$ | Maximum available generation per unit of installed capacity for the solar PV component of a co-located VRE and storage resource during time step t for technology y in zone z [%]|
|$\rho_{y,z,t}^{max,wind}$ | Maximum available generation per unit of installed capacity for the wind component of a co-located VRE and storage resource during time step t for technology y in zone z [%]|
|$VREIndex_{y,z}$ | Resource bin index for VRE technology $y$ in zone $z$. $VREIndex_{y,z}=1$ for the first bin, and $VREIndex_{y,z}=0$ for remaining bins. Only defined for $y\in \mathcal{VRE}$ |
|$\varphi^{map}_{l,z}$ | Topology of the network, for line l: $\varphi^{map}_{l,z}=1$ for start zone $z$, - 1 for end zone $z$, 0 otherwise. |
|$\mathcal{B}_{l}$| DC-OPF coefficient for line $l$ [MWh]|
|$\Delta \theta^{\max}_{l}$|Maximum voltage phase angle difference for line $l$ [radian]|
|$\eta_{y,z}^{loss}$ | Self discharge rate per time step per unit of installed capacity for storage technology $y$ in zone $z$ [%]|
|$\eta_{y,z}^{charge}$ | Single-trip efficiency of storage charging/demand deferral for technology $y$ in zone $z$ [%]|
|$\eta_{y,z}^{discharge}$ | Single-trip efficiency of storage (and hydro reservoir) discharging/demand satisfaction for technology $y$ in zone $z$ [%]|
|$\eta_{y,z}^{charge,dc}$ | Single-trip efficiency of storage DC charging/demand deferral for technology $y$ in zone $z$ for co-located VRE and storage resources [%]|
|$\eta_{y,z}^{discharge,dc}$ | Single-trip efficiency of storage DC discharging/demand satisfaction for technology $y$ in zone $z$ for co-located VRE and storage resources [%]|
|$\eta_{y,z}^{charge,ac}$ | Single-trip efficiency of storage AC charging/demand deferral for technology $y$ in zone $z$ for co-located VRE and storage resources [%]|
|$\eta_{y,z}^{discharge,ac}$ | Single-trip efficiency of storage AC discharging/demand satisfaction for technology $y$ in zone $z$ for co-located VRE and storage resources [%]|
|$\eta_{y,z}^{inverter}$ | Inverter efficiency representing losses from converting DC to AC power and vice versa for technology $y$ in zone $z$ for co-located VRE and storage resources [%]|
|$\eta_{y,z}^{ILR,pv}$ | Inverter loading ratio (the solar PV capacity sizing to the inverter capacity built) of technology $y$ in zone $z$ for co-located VRE and storage resources with a solar PV component [%]|
|$\eta_{y,z}^{ILR,wind}$ | Inverter loading ratio (the wind PV capacity sizing to the grid connection capacity built) of technology $y$ in zone $z$ for co-located VRE and storage resources with a wind component [%]|
|$\mu_{y,z}^{stor}$ | Ratio of energy capacity to discharge power capacity for storage technology (and hydro reservoir) $y$ in zone $z$ [MWh/MW\]|
|$\mu_{y,z}^{dc,stor}$ | Ratio of discharge power capacity to energy capacity for the storage DC component of co-located VRE and storage technology $y$ in zone $z$ [MW/MWh]|
|$\mu_{y,z}^{ac,stor}$ | Ratio of discharge power capacity to energy capacity for the storage AC component of co-located VRE and storage technology $y$ in zone $z$ [MW/MWh]|
|$\mu_{y,z}^{\mathcal{DF}}$ | Maximum percentage of hourly demand that can be shifted by technology $y$ in zone $z$ [%]|
|$\kappa_{y,z}^{up}$ | Maximum ramp-up rate per time step as percentage of installed capacity of technology y in zone z [%/hr]|
|$\kappa_{y,z}^{down}$ | Maximum ramp-down rate per time step as percentage of installed capacity of technology y in zone z [%/hr]|
|$\tau_{y,z}^{up}$ | Minimum uptime for thermal generator type y in zone z before new shutdown [hours].|
|$\tau_{y,z}^{down}$ | Minimum downtime or thermal generator type y in zone z before new restart [hours].|
|$\tau_{y,z}^{advance}$ | maximum  time  by which flexible demand resource can  be  advanced [hours]  |
|$\tau_{y,z}^{delay}$ | maximum  time  by which flexible demand resource can  be  delayed [hours]  |
|$\eta_{y,z}^{dflex}$ | energy losses associated with shifting the flexible demand [%]|
|$\mu_{p,z}^{\mathcal{ESR}}$ | share of total demand in each model zone $z \in \mathcal{ESR}^{p}$  that must be served by qualifying renewable energy resources $y \in \mathcal{G}^{ESR}_{p}$|
|$f(n)$ | Mapping each modeled period $n \in \mathcal{N}$ to corresponding representative period $w \in \mathcal{W}$|
|$\eta_{y}^{electrolyzer}$ | Efficiency of the electrolyzer $y$ in megawatt-hours (MWh) of electricity per metric tonne of hydrogen produced \[MWh/t\] (optional parameter)|
|$ $^{hydrogen}_y$ | Price of hydrogen per metric tonne for electrolyzer $y$ \[\$/t\] (optional parameter)|
|$\mathcal{Min kt}_y$ | Minimum annual quantity of hydrogen that must be produced by electrolyzer $y$ in kilotonnes \[kt\] (optional parameter)|
---
