@doc raw"""
	electrolyzer!(EP::Model, inputs::Dict, setup::Dict)
This function defines the constraints for operation of hydrogen electrolyzers ($y \in EL$) .

	**Ramping limits**

Electrolyzers adhere to the following ramping limits on hourly changes in power output:

```math
\begin{aligned}
	\Theta_{y,z,t-1} - \Theta_{y,z,t} \leq \kappa_{y,z}^{down} \Delta^{\text{total}}_{y,z} \hspace{1cm} \forall y \in \mathcal{EL}, \forall z \in \mathcal{Z}, \forall t \in \mathcal{T}
\end{aligned}
```

```math
\begin{aligned}
	\Theta_{y,z,t} - \Theta_{y,z,t-1} \leq \kappa_{y,z}^{up} \Delta^{\text{total}}_{y,z} \hspace{1cm} \forall y \in \mathcal{EL}, \forall z \in \mathcal{Z}, \forall t \in \mathcal{T}
\end{aligned}
```
(See Constraints 1-2 in the code)

This set of time-coupling constraints wrap around to ensure the power output in the first time step of each year (or each representative period), $t \in \mathcal{T}^{start}$, is within the eligible ramp of the power output in the final time step of the year (or each representative period), $t+\tau^{period}-1$.

**Minimum and maximum power output**

Electrolyzers are bound by the following limits on maximum and minimum power output:

```math
\begin{aligned}
	\Theta_{y,z,t} \geq \rho^{min}_{y,z} \times \Delta^{total}_{y,z}
	\hspace{1cm} \forall y \in \mathcal{EL}, \forall z \in \mathcal{Z}, \forall t \in \mathcal{T}
\end{aligned}
```

```math
\begin{aligned}
	\Theta_{y,z,t} \leq \rho^{max}_{y,z,t} \times \Delta^{total}_{y,z}
	\hspace{1cm} \forall y \in \mathcal{EL}, \forall z \in \mathcal{Z}, \forall t \in \mathcal{T}
\end{aligned}
```
(See Constraints 3-4 in the code)
"""

function electrolyzer!(EP::Model, inputs::Dict, setup::Dict)
	## Electrolyzer resources
	println("Electrolyzer Resources Module")

	dfGen = inputs["dfGen"]

	#Reserves = setup["Reserves"]
	#CapacityReserveMargin = setup["CapacityReserveMargin"]

	T = inputs["T"]     # Number of time steps (hours)
	Z = inputs["Z"]     # Number of zones
	G = inputs["G"] 	# Number of generators

	ELECTROLYZERS = inputs["ELECTROLYZER"]
	STORAGE = inputs["STOR_ALL"]

	p = inputs["hours_per_subperiod"] #total number of hours per subperiod

	### Variables ###

	# Electrical energy consumed by electrolyzer resource "y" at hour "t"
	@variable(EP, vUSE[y=ELECTROLYZERS,t=1:T] >=0);

	### Expressions ###

	## Power Balance Expressions ##

	@expression(EP, ePowerBalanceElectrolyzers[t=1:T, z=1:Z],
	sum(EP[:vUSE][y,t] for y in intersect(ELECTROLYZERS, dfGen[dfGen[!,:Zone].==z,:R_ID])))

	# Electrolyzers consume electricity so their vUSE is subtracted from power balance
	EP[:ePowerBalance] -= ePowerBalanceElectrolyzers

	# Capacity Reserves Margin policy
	## Electrolyzers currently do not contribute to capacity reserve margin. Could allow them to contribute as a curtailable demand in future.

	### Constraints ###

	### Maximum ramp up and down between consecutive hours (Constraints #1-2)
	@constraints(EP, begin
		## Maximum ramp up between consecutive hours
        [y in ELECTROLYZERS, t in 1:T], EP[:vUSE][y,t] - EP[:vUSE][y, hoursbefore(p,t,1)] <= dfGen[y,:Ramp_Up_Percentage]*EP[:eTotalCap][y]

		## Maximum ramp down between consecutive hours
		[y in ELECTROLYZERS, t in 1:T], EP[:vUSE][y, hoursbefore(p,t,1)] - EP[:vUSE][y,t] <= dfGen[y,:Ramp_Dn_Percentage]*EP[:eTotalCap][y]
	end)

	### Minimum and maximum power output constraints (Constraints #3-4)
	if setup["Reserves"] == 1
		## Electrolyzers currently do not contribute to operating reserves. Could allow them to contribute as a curtailable demand in future.
	else
		@constraints(EP, begin
			# Minimum stable power generated per technology "y" at hour "t" Min_Power
			[y in ELECTROLYZERS, t=1:T], EP[:vUSE][y,t] >= dfGen[y,:Min_Power]*EP[:eTotalCap][y]

			# Maximum power generated per technology "y" at hour "t"
			[y in ELECTROLYZERS, t=1:T], EP[:vUSE][y,t] <= inputs["pP_Max"][y,t]*EP[:eTotalCap][y]
		end)

	end

	### Minimum hydrogen production constraint (if any)
	@constraint(EP, 
		cHydrogenMin[y in ELECTROLYZERS], sum(inputs["omega"][t] * EP[:vUSE][y,t] / dfGen[y,:Hydrogen_MWh_Per_Tonne] for t=1:T) >= dfGen[y,:Electrolyzer_Min_kt]*10^3
	)

	### Remove vP (electrolyzers do not produce power so vP = 0 for all periods)
	@constraints(EP, begin
		[y in ELECTROLYZERS, t in 1:T], EP[:vP][y,t] == 0
	end)

	### Hourly Hydrogen Matching Constraint ###
	# Requires generation from qualified resources (indicated by Qualified_Hydrogen_Supply==1 in Generators_data.csv) 
	# from within the same zone as the electrolyzers are located to be >= hourly consumption from electrolyzers (and any charging by 
	# qualified storage within the zone used to help increase electrolyzer utilization)
	HYDROGEN_ZONES = unique(dfGen.Zone[dfGen.ELECTROLYZER.==1])
	QUALIFIED_SUPPLY = dfGen.R_ID[dfGen.Qualified_Hydrogen_Supply.==1]
	@constraint(EP, cHourlyMatching[z in HYDROGEN_ZONES, t=1:T], 
		sum(EP[:vP][y,t] for y=intersect(dfGen.R_ID[dfGen.Zone.==z], QUALIFIED_SUPPLY)) >= sum(EP[:vUSE][y,t] for y=intersect(dfGen.R_ID[dfGen.Zone.==z], ELECTROLYZERS)) + sum(EP[:vCHARGE][y,t] for y=intersect(dfGen.R_ID[dfGen.Zone.==z], QUALIFIED_SUPPLY, STORAGE))
	)


	### ESR Policy ###
	# Since we're using vUSE to denote electrolyzer consumption, we subtract this from the eESR balance to increase demand for clean resources if desired
	# Electrolyzer demand is only accounted for in an ESR that the electrolyzer resources is tagged in in Generates_data.csv (e.g. ESR_N > 0) and 
	# a share of electrolyzer demand equal to dfGen[y,:ESR_N] must be met by resources qualifying for ESR_N for each electrolyzer resource y.
	if setup["EnergyShareRequirement"] >= 1
		@expression(EP, eElectrolyzerESR[ESR=1:inputs["nESR"]], sum(inputs["omega"][t]*EP[:vUSE][y,t] for y=intersect(ELECTROLYZERS, dfGen[findall(x->x>0,dfGen[!,Symbol("ESR_$ESR")]),:R_ID]), t=1:T))
		EP[:eESR] -= eElectrolyzerESR
	end
	
	### Objective Function ###
	# Subtract hydrogen revenue from objective function
	scale_factor = setup["ParameterScale"] == 1 ? 10^6 : 1  # If ParameterScale==1, costs are in millions of $
	@expression(EP, eHydrogenValue[y=ELECTROLYZERS,t=1:T], (inputs["omega"][t] * EP[:vUSE][y,t] / dfGen[y,:Hydrogen_MWh_Per_Tonne] * dfGen[y,:Hydrogen_Price_Per_Tonne] / scale_factor))
	@expression(EP, eTotalHydrogenValueT[t=1:T], sum(eHydrogenValue[y,t] for y in ELECTROLYZERS))
	@expression(EP, eTotalHydrogenValue, sum(eTotalHydrogenValueT[t] for t=1:T))
	EP[:eObj] -= eTotalHydrogenValue

end