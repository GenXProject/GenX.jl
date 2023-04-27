@doc raw"""
	curtailable_variable_renewable!(EP::Model, inputs::Dict, setup::Dict)
This function defines the constraints for operation of variable renewable energy (VRE) resources whose output can be curtailed ($y \in \mathcal{VRE}$), such as utility-scale solar PV or wind power resources or run-of-river hydro resources that can spill water.
The operational constraints for VRE resources are a function of each technology's time-dependent hourly capacity factor (or availability factor, $\rho^{max}_{y,z,t}$), in per unit terms, and the total available capacity ($\Delta^{total}_{y,z}$).
**Power output in each time step**
For each VRE technology type $y$ and model zone $z$, the model allows for incorporating multiple bins with different parameters for resource quality ($\rho^{max}_{y,z,t}$), maximum availability ($\overline{\Omega_{y,z}}$) and investment cost ($\Pi^{INVEST}_{y,z}$, for example, due to interconnection cost differences). We define variables related to installed capacity ($\Delta_{y,z}$) and retired capacity ($\Delta_{y,z}$) for all resource bins for a particular VRE resource type $y$ and zone $z$ ($\overline{\mathcal{VRE}}^{y,z}$). However, the variable corresponding to power output in each timestep is only defined for the first bin. Parameter $VREIndex_{y,z}$, is used to keep track of the first bin, where $VREIndex_{y,z}=1$ for the first bin and $VREIndex_{y,z}=0$ for the remaining bins. This approach allows for modeling many different bins per VRE technology type and zone while significantly reducing the number of operational variable (related to power output for each time step from each bin) added to the model with every additional bin. Thus, the maximum power output for each VRE resource type in each zone is given by the following equation:
```math
\begin{aligned}
	\Theta_{y,z,t} \leq \sum_{(x,z)\in \overline{\mathcal{VRE}}^{x,z}}{\rho^{max}_{x,z,t} \times \Delta^{total}_{x,z}}  \hspace{2 cm}  \forall y,z \in \{(y,z)|VREIndex_{y,z}=1, z \in \mathcal{Z}\},t \in \mathcal{T}
\end{aligned}
```
The above constraint is defined as an inequality instead of an equality to allow for VRE power output to be curtailed if desired. This adds the possibility of introducing VRE curtailment as an extra degree of freedom to guarantee that generation exactly meets demand in each time step.
Note that if ```Reserves=1``` indicating that frequency regulation and operating reserves are modeled, then this function calls ```curtailable_variable_renewable_reserves!()```, which replaces the above constraints with a formulation inclusive of reserve provision.
"""
function curtailable_variable_renewable!(EP::Model, inputs::Dict, setup::Dict)
	## Controllable variable renewable generators
	### Option of modeling VRE generators with multiple availability profiles and capacity limits -  Num_VRE_Bins in Generators_data.csv  >1
	## Default value of Num_VRE_Bins ==1
	println("Dispatchable Resources Module")

	dfGen = inputs["dfGen"]

	Reserves = setup["Reserves"]
	CapacityReserveMargin = setup["CapacityReserveMargin"]

	T = inputs["T"]     # Number of time steps (hours)
	Z = inputs["Z"]     # Number of zones
	G = inputs["G"] 	# Number of generators

	VRE = inputs["VRE"]

	VRE_POWER_OUT = intersect(dfGen[dfGen.Num_VRE_Bins.>=1,:R_ID], VRE)
	VRE_NO_POWER_OUT = setdiff(VRE, VRE_POWER_OUT)

	### Expressions ###

	## Power Balance Expressions ##

	@expression(EP, ePowerBalanceDisp[t=1:T, z=1:Z],
	sum(EP[:vP][y,t] for y in intersect(VRE, dfGen[dfGen[!,:Zone].==z,:R_ID])))

	EP[:ePowerBalance] += ePowerBalanceDisp

	# Capacity Reserves Margin policy
	if CapacityReserveMargin > 0
		@expression(EP, eCapResMarBalanceVRE[res=1:inputs["NCapacityReserveMargin"], t=1:T], sum(dfGen[y,Symbol("CapRes_$res")] * EP[:eTotalCap][y] * inputs["pP_Max"][y,t]  for y in VRE))
		EP[:eCapResMarBalance] += eCapResMarBalanceVRE
	end

	### Constratints ###
	# For resource for which we are modeling hourly power output
	for y in VRE_POWER_OUT
		# Define the set of generator indices corresponding to the different sites (or bins) of a particular VRE technology (E.g. wind or solar) in a particular zone.
		# For example the wind resource in a particular region could be include three types of bins corresponding to different sites with unique interconnection, hourly capacity factor and maximim available capacity limits.
		VRE_BINS = intersect(dfGen[dfGen[!,:R_ID].>=y,:R_ID], dfGen[dfGen[!,:R_ID].<=y+dfGen[y,:Num_VRE_Bins]-1,:R_ID])

		# Constraints on contribution to regulation and reserves
		if Reserves == 1
			curtailable_variable_renewable_reserves!(EP, inputs)
		else
			# Maximum power generated per hour by renewable generators must be less than
			# sum of product of hourly capacity factor for each bin times its the bin installed capacity
			# Note: inequality constraint allows curtailment of output below maximum level.
			@constraint(EP, [t=1:T], EP[:vP][y,t] <= sum(inputs["pP_Max"][yy,t]*EP[:eTotalCap][yy] for yy in VRE_BINS))
		end

	end

	# Set power variables for all bins that are not being modeled for hourly output to be zero
	for y in VRE_NO_POWER_OUT
		fix.(EP[:vP][y,:], 0.0, force=true)
	end
	##CO2 Polcy Module VRE Generation by zone
	@expression(EP, eGenerationByVRE[z=1:Z, t=1:T], # the unit is GW
		sum(EP[:vP][y,t] for y in intersect(inputs["VRE"], dfGen[dfGen[!,:Zone].==z,:R_ID]))
	)
	EP[:eGenerationByZone] += eGenerationByVRE

end

@doc raw"""
	curtailable_variable_renewable_reserves!(EP::Model, inputs::Dict)
When modeling operating reserves, this function is called by ```curtailable_variable_renewable()```, which modifies the constraint for maximum power output in each time step from VRE resources to account for procuring some of the available capacity for frequency regulation ($f_{y,z,t}$) and upward operating (spinning) reserves ($r_{y,z,t}$).
```math
\begin{aligned}
	\Theta_{y,z,t} + f_{y,z,t} + r_{y,z,t} \leq \sum_{(x,z)\in \overline{\mathcal{VRE}}^{x,z}}{\rho^{max}_{x,z,t}\times \Delta^{total}_{x,z}}  \hspace{0.1 cm}   \forall y,z \in \{(y,z)|VREIndex_{y,z}=1, z \in \mathcal{Z}\},t \in \mathcal{T}
\end{aligned}
```
The amount of downward frequency regulation reserves also cannot exceed the current power output.
```math
\begin{aligned}
	f_{y,z,t} \leq \Theta_{y,z,t}
	\forall y,z \in \{(y,z)|VREIndex_{y,z}=1, z \in \mathcal{Z}\},t \in \mathcal{T}
\end{aligned}
```
The amount of frequency regulation and operating reserves procured in each time step is bounded by the user-specified fraction ($\upsilon^{reg}_{y,z}$,$\upsilon^{rsv}_{y,z}$) of available capacity in each period for each reserve type, reflecting the maximum ramp rate for the VRE resource in whatever time interval defines the requisite response time for the regulation or reserve products (e.g., 5 mins or 15 mins or 30 mins). These response times differ by system operator and reserve product, and so the user should define these parameters in a self-consistent way for whatever system context they are modeling.
```math
\begin{aligned}
	r_{y,z,t} \leq \upsilon^{rsv}_{y,z} \sum_{(x,z)\in \overline{\mathcal{VRE}}^{x,z}}{\rho^{max}_{x,z,t}\times \Delta^{total}_{x,z}}  \hspace{1 cm}   \forall y,z \in \{(y,z)|VREIndex_{y,z}=1, z \in \mathcal{Z}\},t \in \mathcal{T} \\
	f_{y,z,t} \leq \upsilon^{reg}_{y,z} \sum_{(x,z)\in \overline{\mathcal{VRE}}^{x,z}}{\rho^{max}_{x,z,t}\times \Delta^{total}_{x,z}}  \hspace{1 cm}   \forall y,z \in \{(y,z)|VREIndex_{y,z}=1, z \in \mathcal{Z}\},t \in \mathcal{T}
\end{aligned}
```
"""
function curtailable_variable_renewable_reserves!(EP::Model, inputs::Dict)

	dfGen = inputs["dfGen"]
	T = inputs["T"]

	VRE_POWER_OUT = intersect(dfGen[dfGen.Num_VRE_Bins.>=1,:R_ID], inputs["VRE"])

	for y in VRE_POWER_OUT
		# Define the set of generator indices corresponding to the different sites (or bins) of a particular VRE technology (E.g. wind or solar) in a particular zone.
		# For example the wind resource in a particular region could be include three types of bins corresponding to different sites with unique interconnection, hourly capacity factor and maximim available capacity limits.
		VRE_BINS = intersect(dfGen[dfGen[!,:R_ID].>=y,:R_ID], dfGen[dfGen[!,:R_ID].<=y+dfGen[y,:Num_VRE_Bins]-1,:R_ID])

		if y in inputs["REG"] && y in inputs["RSV"] # Resource eligible for regulation and spinning reserves
			@constraints(EP, begin
				# For VRE, reserve contributions must be less than the specified percentage of the capacity factor for the hour
				[t=1:T], EP[:vREG][y,t] <= dfGen[y,:Reg_Max]*sum(inputs["pP_Max"][yy,t]*EP[:eTotalCap][yy] for yy in VRE_BINS)
				[t=1:T], EP[:vRSV][y,t] <= dfGen[y,:Rsv_Max]*sum(inputs["pP_Max"][yy,t]*EP[:eTotalCap][yy] for yy in VRE_BINS)

				# Power generated and regulation reserve contributions down per hour must be greater than zero
				[t=1:T], EP[:vP][y,t]-EP[:vREG][y,t] >= 0

				# Power generated and reserve contributions up per hour by renewable generators must be less than
				# hourly capacity factor. Note: inequality constraint allows curtailment of output below maximum level.
				[t=1:T], EP[:vP][y,t]+EP[:vREG][y,t]+EP[:vRSV][y,t] <= sum(inputs["pP_Max"][yy,t]*EP[:eTotalCap][yy] for yy in VRE_BINS)
			end)
		elseif y in inputs["REG"] # Resource only eligible for regulation reserves
			@constraints(EP, begin
				# For VRE, reserve contributions must be less than the specified percentage of the capacity factor for the hour
				[t=1:T], EP[:vREG][y,t] <= dfGen[y,:Reg_Max]*sum(inputs["pP_Max"][yy,t]*EP[:eTotalCap][yy] for yy in VRE_BINS)

				# Power generated and regulation reserve contributions down per hour must be greater than zero
				[t=1:T], EP[:vP][y,t]-EP[:vREG][y,t] >= 0

				# Power generated and reserve contributions up per hour by renewable generators must be less than
				# hourly capacity factor. Note: inequality constraint allows curtailment of output below maximum level.
				[t=1:T], EP[:vP][y,t]+EP[:vREG][y,t] <= sum(inputs["pP_Max"][yy,t]*EP[:eTotalCap][yy] for yy in VRE_BINS)
			end)

		elseif y in inputs["RSV"] # Resource only eligible for spinning reserves - only available in up, no down spinning reserves

			@constraints(EP, begin
				# For VRE, reserve contributions must be less than the specified percentage of the capacity factor for the hour
				[t=1:T], EP[:vRSV][y,t] <= dfGen[y,:Rsv_Max]*sum(inputs["pP_Max"][yy,t]*EP[:eTotalCap][yy] for yy in VRE_BINS)

				# Power generated and reserve contributions up per hour by renewable generators must be less than
				# hourly capacity factor. Note: inequality constraint allows curtailment of output below maximum level.
				[t=1:T], EP[:vP][y,t]+EP[:vRSV][y,t] <= sum(inputs["pP_Max"][yy,t]*EP[:eTotalCap][yy] for yy in VRE_BINS)
			end)
		else # Resource not eligible for reserves
			# Maximum power generated per hour by renewable generators must be less than
			# sum of product of hourly capacity factor for each bin times its the bin installed capacity
			# Note: inequality constraint allows curtailment of output below maximum level.
			@constraint(EP, [t=1:T], EP[:vP][y,t] <= sum(inputs["pP_Max"][yy,t]*EP[:eTotalCap][yy] for yy in VRE_BINS))
		end
	end


end
