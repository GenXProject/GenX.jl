"""
GenX: An Configurable Capacity Expansion Model
Copyright (C) 2021,  Massachusetts Institute of Technology
This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
A complete copy of the GNU General Public License v2 (GPLv2) is available
in LICENSE.txt.  Users uncompressing this from an archive may not have
received this license file.  If not, see <http://www.gnu.org/licenses/>.
"""

@doc raw"""
	cap_reserve_margin!(EP::Model, inputs::Dict, setup::Dict)
Instead of modeling capacity reserve margin requirement (a.k.a. capacity market or resource adequacy requirement) using an annual constraint, we model each requirement with hourly constraint by simulating the activation of the capacity obligation. We define capacity reserve margin constraint for subsets of zones,$z  \in \mathcal{Z}^{CRM}_{p}$, and each subset stands for a locational deliverability area (LDA) or a reserve sharing group.  For thermal resources, the available capacity is the total capacity in the LDA derated by the outage rate, $\epsilon_{y,z,p}^{CRM}$. For storage ($y \in \mathcal{O}$), variable renewable energy ($y \in \mathcal{VRE}$), and  flexibile demand resources ($y \in \mathcal{DF}$), the available capacity is the net injection into the transmission network in time step $t$ derated by the derating factor, also stored in the parameter, $\epsilon_{y,z,p}^{CRM}$. If the imported capacity is eligible to provide capacity to the CRM constraint, the inbound powerflow on all lines $\mathcal{L}_{p}^{in}$ in time step $t$ will be derated to form the available capacity from outside of the LDA. The reverse is true as well: the outbound derated powerflow on all lines $\mathcal{L}_{p}^{out}$ in time step $t$ is taken out from the total available capacity. The derating factor should be equal to the expected availability of the resource during periods when the capacity reserve constraint is binding (e.g. accounting for forced outages during supply constrained periods) and is similar to derating factors used in the capacity markets. On top of the flexible demand resources, load curtailment can also provide capacity (i.e., demand response or load management). We allow all segments of voluntary load curtailment, $s \geq 2 \in S$, to contribute to capacity requirements. The first segment $s = 1 \in S$ corresponds to involuntary demand curtailment or emergency load shedding at the price cap or value of lost load, and thus does not contribute to reserve requirements.  Note that the time step-weighted sum of the shadow prices of this constraint corresponds to the capacity market payments reported by ISOs with mandate capacity market mechanism.
```math
\begin{aligned}
   & \sum_{z  \in \mathcal{Z}^{CRM}_{p}} \Big( \sum_{y \in \mathcal{H}} \epsilon_{y,z,p}^{CRM} \times \Delta^{\text{total}}_{y,z} + \sum_{y \in \mathcal{VRE}} \epsilon_{y,z,p}^{CRM} \times \Theta_{y,z,t} \\
   + & \sum_{y \in \mathcal{O}} \epsilon_{y,z,p}^{CRM} \times \left(\Theta_{y,z,t} - \Pi_{y,z,t} \right) + \sum_{y \in \mathcal{DF}} \epsilon_{y,z,p}^{CRM} \times \left(\Pi_{y,z,t} - \Theta_{y,z,t} \right) \\
   + & \sum_{l \in \mathcal{L}_{p}^{in}} \epsilon_{y,z,p}^{CRM} \times \Phi_{l,t} -  \sum_{l \in \mathcal{L}_{p}^{out}} \epsilon_{y,z,p}^{CRM} \times \Phi_{l,t}
   +  \sum_{s \geq 2} \Lambda_{s,t,z}  \Big) \\
   & \geq \sum_{z  \in \mathcal{Z}^{CRM}_{p}} \left( \left(1 + RM_{z,p}^{CRM} \right) \times D_{z,t} \right)  \hspace{1 cm}  \forall t \in \mathcal{T}, \forall p\in \mathcal{P}^{CRM}
\end{aligned}
```
Note that multiple capacity reserve margin requirements can be specified covering different individual zones or aggregations of zones, where the total number of constraints is specified by the GenX settings parameter ```CapacityReserveMargin``` (where this parameter should be an integer value > 0).
"""
function cap_reserve_margin!(EP::Model, inputs::Dict, setup::Dict)
	# capacity reserve margin constraint
	dfGen = inputs["dfGen"]
	T = inputs["T"]
	NCRM = inputs["NCapacityReserveMargin"]
	HYDRO_RES = inputs["HYDRO_RES"]
	VRE = inputs["VRE"]
	MUST_RUN = inputs["MUST_RUN"]
	FLEX = inputs["FLEX"]
	THERM_ALL = inputs["THERM_ALL"]
	STOR_ALL = inputs["STOR_ALL"]
	SEG = inputs["SEG"]
	Z = inputs["Z"]
	L = inputs["L"]
	println("Capacity Reserve Margin Policies Module")
	### Variable
	@variable(EP,vCapResSlack[res=1:NCRM, t=1:T]>=0)

	### Expression
	# Initialize Capacity Reserve Margin Expression
	@expression(EP, eCapResMarBalance[res=1:NCRM, t=1:T], 1*EP[:vCapResSlack][res,t])

	# add penalty to the objective function
	@expression(EP, eCapResSlack_Year[res=1:NCRM], sum(EP[:vCapResSlack][res,t] * inputs["omega"][t] for t in 1:T))
	@expression(EP, eCCapResSlack[res=1:NCRM], inputs["dfCapRes_slack"][res,:PriceCap] * EP[:eCapResSlack_Year][res])
	@expression(EP, eCTotalCapResSlack, sum(EP[:eCCapResSlack][res] for res = 1:NCRM))
	add_to_expression!(EP[:eObj], EP[:eCTotalCapResSlack])

	# Hydro with Res
	if !isempty(HYDRO_RES)
		@expression(EP, eCapResMarBalanceHydro[res=1:NCRM, t=1:T], sum(dfGen[y,Symbol("CapRes_$res")] * EP[:vP][y,t] for y in HYDRO_RES))
		add_to_expression!.(EP[:eCapResMarBalance], EP[:eCapResMarBalanceHydro])
	end

	# Variable generations
	if !isempty(VRE)
		@expression(EP, eCapResMarBalanceVRE[res=1:NCRM, t=1:T], sum(dfGen[y,Symbol("CapRes_$res")] * EP[:eTotalCap][y] * inputs["pP_Max"][y,t]  for y in VRE))
		add_to_expression!.(EP[:eCapResMarBalance], EP[:eCapResMarBalanceVRE])
	end

	# Must run generations
	if !isempty(MUST_RUN)
		@expression(EP, eCapResMarBalanceMustRun[res=1:NCRM, t=1:T], sum(dfGen[y,Symbol("CapRes_$res")] * EP[:eTotalCap][y] * inputs["pP_Max"][y,t]  for y in MUST_RUN))
		add_to_expression!.(EP[:eCapResMarBalance], EP[:eCapResMarBalanceMustRun])
	end

	# Thermal units
	if !isempty(THERM_ALL)
		@expression(EP, eCapResMarBalanceThermal[res=1:NCRM, t=1:T], sum(dfGen[y,Symbol("CapRes_$res")] * EP[:eTotalCap][y] for y in THERM_ALL))
		add_to_expression!.(EP[:eCapResMarBalance], EP[:eCapResMarBalanceThermal])
	end

	# Storages
	if !isempty(STOR_ALL)
		@expression(EP, eCapResMarBalanceStor[res=1:NCRM, t=1:T], sum(dfGen[y,Symbol("CapRes_$res")] * (EP[:vP][y,t] - EP[:vCHARGE][y,t])  for y in STOR_ALL))
		add_to_expression!.(EP[:eCapResMarBalance], EP[:eCapResMarBalanceStor])
	end

	# Flexible demand
	if !isempty(FLEX)
		@expression(EP, eCapResMarBalanceFlex[res=1:NCRM, t=1:T], sum(dfGen[y,Symbol("CapRes_$res")] * (EP[:vCHARGE_FLEX][y,t] - EP[:vP][y,t]) for y in FLEX))
		add_to_expression!.(EP[:eCapResMarBalance], EP[:eCapResMarBalanceFlex])
	end

	# Demand Response (SEG >=2)
	if SEG >= 2
		@expression(EP, eCapResMarBalanceNSE[res=1:NCRM, t=1:T], sum(EP[:eDemandResponse][t, z] for z in findall(x -> x > 0, inputs["dfCapRes"][:, Symbol("CapRes_$res")])))
		add_to_expression!.(EP[:eCapResMarBalance], EP[:eCapResMarBalanceNSE])
	end

	# VRE-STOR 
	if (setup["VreStor"] == 1)
		dfGen_VRE_STOR = inputs["dfGen_VRE_STOR"]
		@expression(EP, eMinCapResVREStor[res = 1:NCRM], sum(EP[:eTotalCap_VRE] for y in dfGen_VRE_STOR[(dfGen_VRE_STOR[!,Symbol("MinCapTag_$mincap")].== 1) ,:][!,:R_ID]))
		add_to_expression!.(EP[:eCapResMarBalance], EP[:eMinCapResVREStor])
	end

	# Transmission's contribution
	if Z > 1 
		@expression(EP, eCapResMarBalanceTrans[res=1:NCRM, t=1:T], sum(inputs["dfCapRes_network"][l, Symbol("DerateCapRes_$res")] * inputs["dfCapRes_network"][l, Symbol("CapRes_Excl_$res")] * EP[:vFLOW][l,t] for l in 1:L))
		add_to_expression!.(EP[:eCapResMarBalance], -1, EP[:eCapResMarBalanceTrans])
	end

	@constraint(EP, cCapacityResMargin[res=1:NCRM, t=1:T], EP[:eCapResMarBalance][res, t]
				>= sum(inputs["pD"][t,z] * (1 + inputs["dfCapRes"][z,Symbol("CapRes_$res")]) for z=findall(x->x>0,inputs["dfCapRes"][:,Symbol("CapRes_$res")])))

end
