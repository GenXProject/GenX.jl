@doc raw"""
	cap_reserve_margin!(EP::Model, inputs::Dict, setup::Dict)
Instead of modeling capacity reserve margin requirement (a.k.a. capacity market or resource adequacy requirement) using an annual constraint, 
we model each requirement with hourly constraint by simulating the activation of the capacity obligation. 
We define capacity reserve margin constraint for subsets of zones, $z  \in \mathcal{Z}^{CRM}_{p}$, and each subset stands 
	for a locational deliverability area (LDA) or a reserve sharing group.  
For thermal resources, the available capacity is the total capacity in the LDA 
	derated by the outage rate, $\epsilon_{y,z,p}^{CRM}$. 
For storage ($y \in \mathcal{O}$), the available capacity is the minimum of the 
	state of the charge (SoC) at the begining of the time-step or the maximum 
	discharge capacity, derated by the derating factor.
For variable renewable energy ($y \in \mathcal{VRE}$), the available capacity is 
	the capacity mutiplied by the hourly cacity factor at time-step $t$ and further 
	derated by the derating factor. 
For hydro and flexibile demand resources ($y \in \mathcal{DF}$), the available capacity is 
	the net injection into the transmission network in time step $t$ derated by 
	the derating factor, also stored in the parameter, $\epsilon_{y,z,p}^{CRM}$. 
If the imported capacity is eligible to provide capacity to the CRM constraint, 
	the inbound powerflow on all lines $\mathcal{L}_{p}^{in}$ in time step $t$ 
	will be derated to form the available capacity from outside of the LDA. 
	The reverse is true as well: the outbound derated powerflow on all lines 
	$\mathcal{L}_{p}^{out}$ in time step $t$ is taken out from the total available capacity. 
The derating factor should be equal to the expected availability of the resource 
	during periods when the capacity reserve constraint is binding (e.g. accounting 
	for forced outages during supply constrained periods) and is similar to derating 
	factors used in the capacity markets. 
On top of the flexible demand resources, load curtailment can also provide capacity 
	(i.e., demand response or load management). We allow all segments of voluntary 
	load curtailment, $s \geq 2 \in S$, to contribute to capacity requirements. 
	The first segment $s = 1 \in S$ corresponds to involuntary demand curtailment 
	or emergency load shedding at the price cap or value of lost load, and thus 
	does not contribute to reserve requirements.  
Note that the time step-weighted sum of the shadow prices of this constraint 
	corresponds to the capacity market payments reported by ISOs with mandate 
	capacity market mechanism.
```math
\begin{aligned}
   & \sum_{z  \in \mathcal{Z}^{CRM}_{p}} \Big( \sum_{y \in \mathcal{H}} \epsilon_{y,z,p}^{CRM} \times \Delta^{\text{total}}_{y,z} + \sum_{y \in \mathcal{VRE}} \epsilon_{y,z,p}^{CRM} \times \Theta_{y,z,t} \\
   + & \sum_{y \in \mathcal{O}} \epsilon_{y,z,p}^{CRM} \times \left(\Theta_{y,z,t} - \Pi_{y,z,t} \right) + \sum_{y \in \mathcal{DF}} \epsilon_{y,z,p}^{CRM} \times \left(\Pi_{y,z,t} - \Theta_{y,z,t} \right) \\
   + & \sum_{l \in \mathcal{L}_{p}^{in}} \epsilon_{y,z,p}^{CRM} \times \Phi_{l,t} -  \sum_{l \in \mathcal{L}_{p}^{out}} \epsilon_{y,z,p}^{CRM} \times \Phi_{l,t}
   +  \sum_{s \geq 2} \Lambda_{s,t,z}  \Big) \\
   & \geq \sum_{z  \in \mathcal{Z}^{CRM}_{p}} \left( \left(1 + RM_{z,p}^{CRM} \right) \times D_{z,t} \right)  \hspace{1 cm}  \forall t \in \mathcal{T}, \forall p\in \mathcal{P}^{CRM}
\end{aligned}
```
Note that multiple capacity reserve margin requirements can be specified covering 
different individual zones or aggregations of zones, where the total number of 
constraints will automatically be detected.
"""
function cap_reserve_margin!(EP::Model, inputs::Dict, setup::Dict)
	# capacity reserve margin constraint
	dfGen = inputs["dfGen"]
	G = inputs["G"]
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
	OperationWrapping = setup["OperationWrapping"]
	START_SUBPERIODS = inputs["START_SUBPERIODS"]
	INTERIOR_SUBPERIODS = inputs["INTERIOR_SUBPERIODS"]
	hours_per_subperiod = inputs["hours_per_subperiod"] #total number of hours per subperiod

	println("Capacity Reserve Margin Policies Module")
	@expression(EP, eCapResMarBalance[res=1:NCRM, t=1:T], 1*EP[:vZERO])

	### Variable
	if haskey(inputs, "dfCapRes_slack")
		@variable(EP,vCapResSlack[res=1:NCRM, t=1:T]>=0)
		add_to_expression!.(EP[:eCapResMarBalance],EP[:vCapResSlack])	
		# add penalty to the objective function
		@expression(EP, eCapResSlack_Year[res=1:NCRM], 
			sum(EP[:vCapResSlack][res,t] * inputs["omega"][t] for t in 1:T))
		@expression(EP, eCCapResSlack[res=1:NCRM], 
			inputs["dfCapRes_slack"][res,:PriceCap] * EP[:eCapResSlack_Year][res])
		@expression(EP, eCTotalCapResSlack, sum(EP[:eCCapResSlack][res] for res = 1:NCRM))
		add_to_expression!(EP[:eObj], EP[:eCTotalCapResSlack])
	end	

	@variable(EP, vCapContribution[y = 1:G, t = 1:T])
	if Z > 1
		@variable(EP, vCapContributionTrans[l = 1:L, t = 1:T])
	end
	### Expression
	# Initialize Capacity Reserve Margin Expression
	@expression(EP, eCapContributionGenAll[res=1:NCRM, t = 1:T],
		sum(dfGen[y, Symbol("CapRes_$res")] * EP[:vCapContribution][y, t] for y in 1:G)
	)
	add_to_expression!.(EP[:eCapResMarBalance], EP[:eCapContributionGenAll])
	
	if Z > 1
		@expression(EP, eCapContributionTransAll[res=1:NCRM, t = 1:T],
			sum(inputs["dfCapRes_network"][l, Symbol("DerateCapRes_$res")] * 
				inputs["dfCapRes_network"][l, Symbol("CapRes_Excl_$res")] * 
				vCapContributionTrans[l, t] for l in 1:L)
		)
		add_to_expression!.(EP[:eCapResMarBalance], EP[:eCapContributionTransAll])
	end


	# Hydro with Res
	if !isempty(HYDRO_RES)
		@constraint(EP, cCapContriHydro[y in HYDRO_RES, t = 1:T], 
			EP[:vCapContribution][y, t] == EP[:vP][y,t])
	end

	# Variable generations
	if !isempty(VRE)
		@constraint(EP, cCapContriVRE[y in VRE, t = 1:T], 
			EP[:vCapContribution][y, t] == (inputs["pP_Max"][y,t] * EP[:eTotalCap][y]))
	end

	# Must run generations
	if !isempty(MUST_RUN)
		@constraint(EP, cCapContriMUSTRUN[y in MUST_RUN, t = 1:T], 
			EP[:vCapContribution][y, t] == (inputs["pP_Max"][y,t] * EP[:eTotalCap][y]))
	end

	# Thermal units
	if !isempty(THERM_ALL)
		@constraint(EP, cCapContriTHERMAL[y in THERM_ALL, t = 1:T], 
			EP[:vCapContribution][y, t] == (EP[:eTotalCap][y]))
	end

	# Storages
	if !isempty(STOR_ALL)
		@constraint(EP, cCapContriSTORCap[y in STOR_ALL, t = 1:T], 
			EP[:vCapContribution][y, t] <= (EP[:eTotalCap][y]))
		if OperationWrapping ==1
			@constraint(EP, cCapContriSTORSoC_Start[y in STOR_ALL, t in START_SUBPERIODS],
				EP[:vCapContribution][y, t] <= (EP[:vS][y, t + hours_per_subperiod - 1] * 
				dfGen[y, :Eff_Down]/ dfGen[y, :CapRes_duration_requirement])
			)
			@constraint(EP, cCapContriSTORSoC_Interior[y in STOR_ALL, t in INTERIOR_SUBPERIODS],
				EP[:vCapContribution][y, t] <= (EP[:vS][y, t - 1]* 
				dfGen[y, :Eff_Down]/ dfGen[y, :CapRes_duration_requirement])
			)
		else
			@constraint(EP, cCapContriSTORSoC[y in STOR_ALL, t = 2:T], 
			EP[:vCapContribution][y, t] <= (EP[:vS][y, t-1]* 
			dfGen[y, :Eff_Down]/ dfGen[y, :CapRes_duration_requirement])
			)
		end
	end

	# Flexible demand
	if !isempty(FLEX)
		@constraint(EP, cCapContriFLEX[y in FLEX, t = 1:T], 
			EP[:vCapContribution][y, t] == (EP[:vCHARGE_FLEX][y,t] - EP[:vP][y,t])
		)
	end

	# Demand Response (SEG >=2)
	if SEG >= 2
		@expression(EP, eCapResMarBalanceNSE[res=1:NCRM, t=1:T], 
			sum(EP[:eDemandResponse][t, z] 
			for z in findall(x -> x != 0, inputs["dfCapRes"][:, Symbol("CapRes_$res")])))
		add_to_expression!.(EP[:eCapResMarBalance], EP[:eCapResMarBalanceNSE])
	end

	# Transmission's contribution
	if Z > 1
		@constraint(EP, cCapContriTrans[l in 1:L, t = 1:T], 
			EP[:vCapContributionTrans][l, t] == (-1) * EP[:vFLOW][l,t]
		)
	end

	@constraint(EP, cCapacityResMargin[res=1:NCRM, t=1:T], EP[:eCapResMarBalance][res, t]
				>= sum(inputs["pD"][t,z] * (1 + inputs["dfCapRes"][z,Symbol("CapRes_$res")]) 
					for z=findall(x -> x != 0,inputs["dfCapRes"][:,Symbol("CapRes_$res")])))

end
