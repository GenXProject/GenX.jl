@doc raw"""
	cap_reserve_margin!(EP::Model, inputs::Dict, setup::Dict)
Instead of modeling capacity reserve margin requirement (a.k.a. capacity market or resource adequacy requirement) using an annual constraint,
we model each requirement with hourly constraint by simulating the activation of the capacity obligation.
We define capacity reserve margin constraint for subsets of zones,
$z \in \mathcal{Z}^{CRM}_{p}$, and each subset stands for a
locational deliverability area (LDA) or a reserve sharing group.
For thermal resources, the available capacity is the total capacity in the LDA derated by
the outage rate, $\epsilon_{y,z,p}^{CRM}$.
For variable renewable energy ($y \in \mathcal{VRE}$), the available capacity is the
maximum discharge potential in time step $t$ derated by the derating factor.
For standalone storage and co-located VRE and storage resources
($y \in \mathcal{O} \cup \mathcal{VS}$) the available capacity is the net injection
into the transmission network plus the net virtual injection corresponding to charge held
in reserve, derated by the derating factor.
For information on how each component contributes to the capacity reserve margin formulation for co-located VRE and storage resources, see ```vre_stor_capres!()```.
For flexible demand resources ($y \in \mathcal{DF}$), the available capacity is the net
injection into the transmission network in time step $t$ derated by the derating factor,
also stored in the parameter, $\epsilon_{y,z,p}^{CRM}$.
If the imported capacity is eligible to provide capacity to the CRM constraint,
the inbound powerflow on all lines $\mathcal{L}_{p}^{in}$ in time step $t$ will be derated
to form the available capacity from outside of the LDA.
The reverse is true as well: the outbound derated powerflow on all lines
$\mathcal{L}_{p}^{out}$ in time step $t$ is taken out from the total available capacity.
The derating factor should be equal to the expected availability of the resource during
periods when the capacity reserve constraint is binding (e.g. accounting for forced outages
during supply constrained periods) and is similar to derating factors used in the capacity
markets.
On top of the flexible demand resources, demand curtailment can also provide capacity
(i.e., demand response or load management).
We allow all segments of voluntary demand curtailment, $s \geq 2 \in S$,
to contribute to capacity requirements.
The first segment $s = 1 \in S$ corresponds to involuntary demand curtailment or
emergency load shedding at the price cap or value of lost demand, and thus does not contribute to reserve requirements.
Note that the time step-weighted sum of the shadow prices of this constraint corresponds
to the capacity market payments reported by ISOs with mandate capacity market mechanism.
```math
\begin{aligned}
	& \sum_{z  \in \mathcal{Z}^{CRM}_{p}} \Big( \sum_{y \in \mathcal{H}} \epsilon_{y,z,p}^{CRM} \times \Delta^{\text{total}}_{y,z} + \sum_{y \in \mathcal{VRE}} \epsilon_{y,z,p}^{CRM} \times \rho^{max}_{y,z,t} \\
	& + \sum_{y \in \mathcal{O}} \epsilon_{y,z,p}^{CRM} \times \left(\Theta_{y,z,t} + \Theta^{CRM}_{o,z,t} - \Pi^{CRM}_{o,z,t} - \Pi_{y,z,t} \right) + \sum_{y \in \mathcal{DF}} \epsilon_{y,z,p}^{CRM} \times \left(\Pi_{y,z,t} - \Theta_{y,z,t} \right) \\
	& + \sum_{y \in \mathcal{VS}^{pv}} (\epsilon_{y,z,p}^{CRM} \times \eta^{inverter}_{y,z} \times \rho^{max,pv}_{y,z,t} \times \Delta^{total,pv}_{y,z}) \\
	& + \sum_{y \in \mathcal{VS}^{wind}} (\epsilon_{y,z,p}^{CRM} \times \rho^{max,wind}_{y,z,t} \times \Delta^{total,wind}_{y,z}) \\
    & + \sum_{y \in \mathcal{VS}^{sym,dc} \cup \mathcal{VS}^{asym,dc,dis}} (\epsilon_{y,z,p}^{CRM} \times \eta^{inverter}_{y,z} \times (\Theta^{dc}_{y,z,t} + \Theta^{CRM,dc}_{y,z,t})) \\
    & + \sum_{y \in \mathcal{VS}^{sym,ac} \cup \mathcal{VS}^{asym,ac,dis}} (\epsilon_{y,z,p}^{CRM} \times (\Theta^{ac}_{y,z,t} + \Theta^{CRM,ac}_{y,z,t})) \\
    & - \sum_{y \in \mathcal{VS}^{sym,dc} \cup \mathcal{VS}^{asym,dc,cha}} (\epsilon_{y,z,p}^{CRM} \times \frac{\Pi^{dc}_{y,z,t} + \Pi^{CRM,dc}_{y,z,t}}{\eta^{inverter}_{y,z}}) \\
    & - \sum_{y \in \mathcal{VS}^{sym,dc} \cup \mathcal{VS}^{asym,dc,cha}} (\epsilon_{y,z,p}^{CRM} \times (\Pi^{ac}_{y,z,t} + \Pi^{CRM,ac}_{y,z,t})) \\
	& + \sum_{l \in \mathcal{L}_{p}^{in}} \epsilon_{y,z,p}^{CRM} \times \Phi_{l,t} -  \sum_{l \in \mathcal{L}_{p}^{out}} \epsilon_{y,z,p}^{CRM} \times \Phi_{l,t}
   	+  \sum_{s \geq 2} \Lambda_{s,t,z}  \Big) \\
   	& \geq \sum_{z  \in \mathcal{Z}^{CRM}_{p}} \left( \left(1 + RM_{z,p}^{CRM} \right) \times D_{z,t} \right)  \hspace{1 cm}  \forall t \in \mathcal{T}, \forall p\in \mathcal{P}^{CRM}
\end{aligned}
```
Note that multiple capacity reserve margin requirements can be specified covering different
individual zones or aggregations of zones, where the total number of constraints
is specified by the GenX settings parameter ```CapacityReserveMargin```
(where this parameter should be an integer value > 0).
The expressions establishing the capacity reserve margin contributions of each technology
class are included in their respective technology modules.
"""
function cap_reserve_margin!(EP::Model, inputs::Dict, setup::Dict)
    # capacity reserve margin constraint
    T = inputs["T"]
    NCRM = inputs["NCapacityReserveMargin"]
    println("Capacity Reserve Margin Policies Module")

    # if input files are present, add capacity reserve margin slack variables
    if haskey(inputs, "dfCapRes_slack")
        @variable(EP, vCapResSlack[res = 1:NCRM, t = 1:T]>=0)
        add_similar_to_expression!(EP[:eCapResMarBalance], vCapResSlack)

        @expression(EP,
            eCapResSlack_Year[res = 1:NCRM],
            sum(EP[:vCapResSlack][res, t] * inputs["omega"][t] for t in 1:T))
        @expression(EP,
            eCCapResSlack[res = 1:NCRM],
            inputs["dfCapRes_slack"][res, :PriceCap]*EP[:eCapResSlack_Year][res])
        @expression(EP, eCTotalCapResSlack, sum(EP[:eCCapResSlack][res] for res in 1:NCRM))
        add_to_expression!(EP[:eObj], eCTotalCapResSlack)
    end

    @constraint(EP,
        cCapacityResMargin[res = 1:NCRM, t = 1:T],
        EP[:eCapResMarBalance][res,
            t]
        >=sum(inputs["pD"][t, z] * (1 + inputs["dfCapRes"][z, res])
        for z in findall(x -> x != 0, inputs["dfCapRes"][:, res])))
end
