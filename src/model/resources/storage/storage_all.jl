@doc raw"""
	storage_all!(EP::Model, inputs::Dict, setup::Dict)

Sets up variables and constraints common to all storage resources. See ```storage()``` in ```storage.jl``` for description of constraints.
"""
function storage_all!(EP::Model, inputs::Dict, setup::Dict)
	# Setup variables, constraints, and expressions common to all storage resources
	println("Storage Core Resources Module")

	dfGen = inputs["dfGen"]
	Reserves = setup["Reserves"]
	CapacityReserveMargin = setup["CapacityReserveMargin"]

	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
	Z = inputs["Z"]     # Number of zones

	STOR_ALL = inputs["STOR_ALL"]
	STOR_SHORT_DURATION = inputs["STOR_SHORT_DURATION"]
	representative_periods = inputs["REP_PERIOD"]

	START_SUBPERIODS = inputs["START_SUBPERIODS"]
	INTERIOR_SUBPERIODS = inputs["INTERIOR_SUBPERIODS"]

	hours_per_subperiod = inputs["hours_per_subperiod"] #total number of hours per subperiod

	### Variables ###

	# Storage level of resource "y" at hour "t" [MWh] on zone "z" - unbounded
	@variable(EP, vS[y in STOR_ALL, t=1:T] >= 0);

	# Energy withdrawn from grid by resource "y" at hour "t" [MWh] on zone "z"
	@variable(EP, vCHARGE[y in STOR_ALL, t=1:T] >= 0);

	# Virtual discharge contributing to capacity reserves at timestep t for storage cluster y
	@variable(EP, vCAPCONTRSTOR_VP[y in STOR_ALL, t=1:T] >= 0)

	# Virtual charge contributing to capacity reserves at timestep t for storage cluster y
	@variable(EP, vCAPCONTRSTOR_VCHARGE[y in STOR_ALL, t=1:T] >= 0)

	# Total state of charge being held in reserve at timestep t for storage cluster y
	@variable(EP, vCAPCONTRSTOR_VS[y in STOR_ALL, t=1:T] >= 0)

	### Expressions ###

	# Energy losses related to technologies (increase in effective demand)
	@expression(EP, eELOSS[y in STOR_ALL], sum(inputs["omega"][t]*EP[:vCHARGE][y,t] for t in 1:T) - sum(inputs["omega"][t]*EP[:vP][y,t] for t in 1:T))

	## Objective Function Expressions ##

	#Variable costs of "charging" for technologies "y" during hour "t" in zone "z"
	@expression(EP, eCVar_in[y in STOR_ALL,t=1:T], inputs["omega"][t]*dfGen[y,:Var_OM_Cost_per_MWh_In]*vCHARGE[y,t])

	# Sum individual resource contributions to variable charging costs to get total variable charging costs
	@expression(EP, eTotalCVarInT[t=1:T], sum(eCVar_in[y,t] for y in STOR_ALL))
	@expression(EP, eTotalCVarIn, sum(eTotalCVarInT[t] for t in 1:T))
	EP[:eObj] += eTotalCVarIn

	## Power Balance Expressions ##

	# Term to represent net dispatch from storage in any period
	@expression(EP, ePowerBalanceStor[t=1:T, z=1:Z],
		sum(EP[:vP][y,t]-EP[:vCHARGE][y,t] for y in intersect(dfGen[dfGen.Zone.==z,:R_ID],STOR_ALL)))

	EP[:ePowerBalance] += ePowerBalanceStor

	### Constraints ###

	## Storage energy capacity and state of charge related constraints:

	# Links state of charge in first time step with decisions in last time step of each subperiod
	# We use a modified formulation of this constraint (cSoCBalLongDurationStorageStart) when operations wrapping and long duration storage are being modeled
	if representative_periods > 1 && !isempty(inputs["STOR_LONG_DURATION"])
		CONSTRAINTSET = STOR_SHORT_DURATION
	else
		CONSTRAINTSET = STOR_ALL
	end
	@constraint(EP, cSoCBalStart[t in START_SUBPERIODS, y in CONSTRAINTSET], EP[:vS][y,t] ==
		EP[:vS][y,t+hours_per_subperiod-1] - (1/dfGen[y,:Eff_Down] * EP[:vP][y,t])
		+ (dfGen[y,:Eff_Up]*EP[:vCHARGE][y,t]) - (dfGen[y,:Self_Disch] * EP[:vS][y,t+hours_per_subperiod-1]))

	@constraints(EP, begin

		# Maximum energy stored must be less than energy capacity
		[y in STOR_ALL, t in 1:T], EP[:vS][y,t] <= EP[:eTotalCapEnergy][y]

		# energy stored for the next hour
		cSoCBalInterior[t in INTERIOR_SUBPERIODS, y in STOR_ALL], EP[:vS][y,t] ==
			EP[:vS][y,t-1]-(1/dfGen[y,:Eff_Down]*EP[:vP][y,t])+(dfGen[y,:Eff_Up]*EP[:vCHARGE][y,t])-(dfGen[y,:Self_Disch]*EP[:vS][y,t-1])
	end)

	# Storage discharge and charge power (and reserve contribution) related constraints:
	if Reserves == 1
		storage_all_reserves!(EP, inputs)
	else
		# Note: maximum charge rate is also constrained by maximum charge power capacity, but as this differs by storage type,
		# this constraint is set in functions below for each storage type

		# Maximum discharging rate must be less than power rating OR available stored energy in the prior period, whichever is less
		# wrapping from end of sample period to start of sample period for energy capacity constraint
		@constraints(EP, begin
			[y in STOR_ALL, t=1:T], EP[:vP][y,t] + EP[:vCAPCONTRSTOR_VP][y,t] <= EP[:eTotalCap][y]
			[y in STOR_ALL, t=1:T], EP[:vP][y,t] + EP[:vCAPCONTRSTOR_VP][y,t] <= EP[:vS][y, hoursbefore(hours_per_subperiod,t,1)]*dfGen[y,:Eff_Down]
		end)
	end
	#From co2 Policy module
	@expression(EP, eELOSSByZone[z=1:Z],
		sum(EP[:eELOSS][y] for y in intersect(STOR_ALL, dfGen[dfGen[!,:Zone].==z,:R_ID]))
	)

	# Capacity Reserve Margin policy
	if CapacityReserveMargin == 1
		# Constraints governing energy held in reserve when storage makes virtual capacity reserve margin contributions:

		# Links energy held in reserve in first time step with decisions in last time step of each subperiod
		# We use a modified formulation of this constraint (cVSoCBalLongDurationStorageStart) when operations wrapping and long duration storage are being modeled
		@constraint(EP, cVSoCBalStart[t in START_SUBPERIODS, y in CONSTRAINTSET], EP[:vCAPCONTRSTOR_VS][y,t] ==
			EP[:vCAPCONTRSTOR_VS][y,t+hours_per_subperiod-1] + (1/dfGen[y,:Eff_Down] * EP[:vCAPCONTRSTOR_VP][y,t])
			- (dfGen[y,:Eff_Up]*EP[:vCAPCONTRSTOR_VCHARGE][y,t]) - (dfGen[y,:Self_Disch] * EP[:vCAPCONTRSTOR_VS][y,t+hours_per_subperiod-1]))

		# energy held in reserve for the next hour
		@constraint(EP, cVSoCBalInterior[t in INTERIOR_SUBPERIODS, y in STOR_ALL], EP[:vCAPCONTRSTOR_VS][y,t] ==
			EP[:vCAPCONTRSTOR_VS][y,t-1]+(1/dfGen[y,:Eff_Down]*EP[:vCAPCONTRSTOR_VP][y,t])-(dfGen[y,:Eff_Up]*EP[:vCAPCONTRSTOR_VCHARGE][y,t])-(dfGen[y,:Self_Disch]*EP[:vCAPCONTRSTOR_VS][y,t-1]))
		
		# energy held in reserve acts as a lower bound on the total energy held in storage
		@constraint(EP, cSOCMinCapRes[t in 1:T, y in STOR_ALL], EP[:vS][y,t] >= EP[:vCAPCONTRSTOR_VS][y,t])
	else
		# Set values for all capacity reserve margin variables to 0
		@constraints(EP, begin
			[y in STOR_ALL, t in 1:T], EP[:vCAPCONTRSTOR_VS][y,t] == 0
			[y in STOR_ALL, t in 1:T], EP[:vCAPCONTRSTOR_VP][y,t] == 0
			[y in STOR_ALL, t in 1:T], EP[:vCAPCONTRSTOR_VCHARGE][y,t] == 0
		end)
	end
end

function storage_all_reserves!(EP::Model, inputs::Dict)

	dfGen = inputs["dfGen"]
	T = inputs["T"]

	START_SUBPERIODS = inputs["START_SUBPERIODS"]
	INTERIOR_SUBPERIODS = inputs["INTERIOR_SUBPERIODS"]
	p = inputs["hours_per_subperiod"]

	STOR_ALL = inputs["STOR_ALL"]

	STOR_REG_RSV = intersect(STOR_ALL, inputs["REG"], inputs["RSV"]) # Set of storage resources with both REG and RSV reserves

	STOR_REG = intersect(STOR_ALL, inputs["REG"]) # Set of storage resources with REG reserves
	STOR_RSV = intersect(STOR_ALL, inputs["RSV"]) # Set of storage resources with RSV reserves

	STOR_NO_RES = setdiff(STOR_ALL, STOR_REG, STOR_RSV) # Set of storage resources with no reserves

	STOR_REG_ONLY = setdiff(STOR_REG, STOR_RSV) # Set of storage resources only with REG reserves
	STOR_RSV_ONLY = setdiff(STOR_RSV, STOR_REG) # Set of storage resources only with RSV reserves

	if !isempty(STOR_REG_RSV)
		# Storage units charging can charge faster to provide reserves down and charge slower to provide reserves up
		@constraints(EP, begin
			# Maximum storage contribution to reserves is a specified fraction of installed discharge power capacity
			[y in STOR_REG_RSV, t=1:T], EP[:vREG][y,t] <= dfGen[y,:Reg_Max]*EP[:eTotalCap][y]
			[y in STOR_REG_RSV, t=1:T], EP[:vRSV][y,t] <= dfGen[y,:Rsv_Max]*EP[:eTotalCap][y]

			# Actual contribution to regulation and reserves is sum of auxilary variables for portions contributed during charging and discharging
			[y in STOR_REG_RSV, t=1:T], EP[:vREG][y,t] == EP[:vREG_charge][y,t]+EP[:vREG_discharge][y,t]
			[y in STOR_REG_RSV, t=1:T], EP[:vRSV][y,t] == EP[:vRSV_charge][y,t]+EP[:vRSV_discharge][y,t]

			# Maximum charging rate plus contribution to reserves up must be greater than zero
			# Note: when charging, reducing charge rate is contributing to upwards reserve & regulation as it drops net demand
			[y in STOR_REG_RSV, t=1:T], EP[:vCHARGE][y,t]-EP[:vREG_charge][y,t]-EP[:vRSV_charge][y,t] >= 0

			# Maximum discharging rate and contribution to reserves down must be greater than zero
			# Note: when discharging, reducing discharge rate is contributing to downwards regulation as it drops net supply
			[y in STOR_REG_RSV, t=1:T], EP[:vP][y,t]-EP[:vREG_discharge][y,t] >= 0

			# Maximum charging rate plus contribution to regulation down must be less than available storage capacity
			[y in STOR_REG_RSV, t=1:T], dfGen[y,:Eff_Up]*(EP[:vCHARGE][y,t]+EP[:vREG_charge][y,t]) <= EP[:eTotalCapEnergy][y]-EP[:vS][y, hoursbefore(p,t,1)]
			# Note: maximum charge rate is also constrained by maximum charge power capacity, but as this differs by storage type,
			# this constraint is set in functions below for each storage type

			# Maximum discharging rate and contribution to reserves up must be less than power rating OR available stored energy in prior period, whichever is less
			# wrapping from end of sample period to start of sample period for energy capacity constraint
			[y in STOR_REG_RSV, t=1:T], EP[:vP][y,t]+EP[:vREG_discharge][y,t]+EP[:vRSV_discharge][y,t] <= EP[:eTotalCap][y]
			[y in STOR_REG_RSV, t=1:T], (EP[:vP][y,t]+EP[:vREG_discharge][y,t]+EP[:vRSV_discharge][y,t])/dfGen[y,:Eff_Down] <= EP[:vS][y, hoursbefore(p,t,1)]
		end)
	end
	if !isempty(STOR_REG_ONLY)
		# Storage units charging can charge faster to provide reserves down and charge slower to provide reserves up
		@constraints(EP, begin
			# Maximum storage contribution to reserves is a specified fraction of installed capacity
			[y in STOR_REG_ONLY, t=1:T], EP[:vREG][y,t] <= dfGen[y,:Reg_Max]*EP[:eTotalCap][y]

			# Actual contribution to regulation and reserves is sum of auxilary variables for portions contributed during charging and discharging
			[y in STOR_REG_ONLY, t=1:T], EP[:vREG][y,t] == EP[:vREG_charge][y,t]+EP[:vREG_discharge][y,t]

			# Maximum charging rate plus contribution to reserves up must be greater than zero
			# Note: when charging, reducing charge rate is contributing to upwards reserve & regulation as it drops net demand
			[y in STOR_REG_ONLY, t=1:T], EP[:vCHARGE][y,t]-EP[:vREG_charge][y,t] >= 0

			# Maximum discharging rate and contribution to reserves down must be greater than zero
			# Note: when discharging, reducing discharge rate is contributing to downwards regulation as it drops net supply
			[y in STOR_REG_ONLY, t=1:T], EP[:vP][y,t] - EP[:vREG_discharge][y,t] >= 0

			# Maximum charging rate plus contribution to regulation down must be less than available storage capacity
			[y in STOR_REG_ONLY, t=1:T], dfGen[y,:Eff_Up]*(EP[:vCHARGE][y,t]+EP[:vREG_charge][y,t]) <= EP[:eTotalCapEnergy][y]-EP[:vS][y, hoursbefore(p,t,1)]
			# Note: maximum charge rate is also constrained by maximum charge power capacity, but as this differs by storage type,
			# this constraint is set in functions below for each storage type

			# Maximum discharging rate and contribution to reserves up must be less than power rating OR available stored energy in prior period, whichever is less
			# wrapping from end of sample period to start of sample period for energy capacity constraint
			[y in STOR_REG_ONLY, t=1:T], EP[:vP][y,t] + EP[:vREG_discharge][y,t] <= EP[:eTotalCap][y]
			[y in STOR_REG_ONLY, t=1:T], (EP[:vP][y,t]+EP[:vREG_discharge][y,t])/dfGen[y,:Eff_Down] <= EP[:vS][y, hoursbefore(p,t,1)]
		end)
	end
	if !isempty(STOR_RSV_ONLY)
		# Storage units charging can charge faster to provide reserves down and charge slower to provide reserves up
		@constraints(EP, begin
			# Maximum storage contribution to reserves is a specified fraction of installed capacity
			[y in STOR_RSV_ONLY, t=1:T], EP[:vRSV][y,t] <= dfGen[y,:Rsv_Max]*EP[:eTotalCap][y]

			# Actual contribution to regulation and reserves is sum of auxilary variables for portions contributed during charging and discharging
			[y in STOR_RSV_ONLY, t=1:T], EP[:vRSV][y,t] == EP[:vRSV_charge][y,t]+EP[:vRSV_discharge][y,t]

			# Maximum charging rate plus contribution to reserves up must be greater than zero
			# Note: when charging, reducing charge rate is contributing to upwards reserve & regulation as it drops net demand
			[y in STOR_RSV_ONLY, t=1:T], EP[:vCHARGE][y,t]-EP[:vRSV_charge][y,t] >= 0

			# Note: maximum charge rate is also constrained by maximum charge power capacity, but as this differs by storage type,
			# this constraint is set in functions below for each storage type

			# Maximum discharging rate and contribution to reserves up must be less than power rating OR available stored energy in prior period, whichever is less
			# wrapping from end of sample period to start of sample period for energy capacity constraint
			[y in STOR_RSV_ONLY, t=1:T], EP[:vP][y,t]+EP[:vRSV_discharge][y,t] <= EP[:eTotalCap][y]
			[y in STOR_RSV_ONLY, t=1:T], (EP[:vP][y,t]+EP[:vRSV_discharge][y,t])/dfGen[y,:Eff_Down] <= EP[:vS][y, hoursbefore(p,t,1)]
		end)
	end
	if !isempty(STOR_NO_RES)
		# Maximum discharging rate must be less than power rating OR available stored energy in prior period, whichever is less
		# wrapping from end of sample period to start of sample period for energy capacity constraint
		@constraints(EP, begin
			[y in STOR_NO_RES, t=1:T], EP[:vP][y,t] <= EP[:eTotalCap][y]
			[y in STOR_NO_RES, t=1:T], EP[:vP][y,t]/dfGen[y,:Eff_Down] <= EP[:vS][y, hoursbefore(p,t,1)]
		end)
	end
end
