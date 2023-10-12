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

	if CapacityReserveMargin > 0
		# Virtual discharge contributing to capacity reserves at timestep t for storage cluster y
		@variable(EP, vCAPRES_discharge[y in STOR_ALL, t=1:T] >= 0)

		# Virtual charge contributing to capacity reserves at timestep t for storage cluster y
		@variable(EP, vCAPRES_charge[y in STOR_ALL, t=1:T] >= 0)

		# Total state of charge being held in reserve at timestep t for storage cluster y
		@variable(EP, vCAPRES_socinreserve[y in STOR_ALL, t=1:T] >= 0)
	end

	### Expressions ###

	# Energy losses related to technologies (increase in effective demand)
	@expression(EP, eELOSS[y in STOR_ALL], sum(inputs["omega"][t]*EP[:vCHARGE][y,t] for t in 1:T) - sum(inputs["omega"][t]*EP[:vP][y,t] for t in 1:T))

	## Objective Function Expressions ##

	#Variable costs of "charging" for technologies "y" during hour "t" in zone "z"
	@expression(EP, eCVar_in[y in STOR_ALL,t=1:T], inputs["omega"][t]*dfGen[y,:Var_OM_Cost_per_MWh_In]*vCHARGE[y,t])

	# Sum individual resource contributions to variable charging costs to get total variable charging costs
	@expression(EP, eTotalCVarInT[t=1:T], sum(eCVar_in[y,t] for y in STOR_ALL))
	@expression(EP, eTotalCVarIn, sum(eTotalCVarInT[t] for t in 1:T))
	add_to_expression!(EP[:eObj], eTotalCVarIn)


	if CapacityReserveMargin > 0
		#Variable costs of "virtual charging" for technologies "y" during hour "t" in zone "z"
		@expression(EP, eCVar_in_virtual[y in STOR_ALL,t=1:T], inputs["omega"][t]*dfGen[y,:Var_OM_Cost_per_MWh_In]*vCAPRES_charge[y,t])
		@expression(EP, eTotalCVarInT_virtual[t=1:T], sum(eCVar_in_virtual[y,t] for y in STOR_ALL))
		@expression(EP, eTotalCVarIn_virtual, sum(eTotalCVarInT_virtual[t] for t in 1:T))
		EP[:eObj] += eTotalCVarIn_virtual

		#Variable costs of "virtual discharging" for technologies "y" during hour "t" in zone "z"
		@expression(EP, eCVar_out_virtual[y in STOR_ALL,t=1:T], inputs["omega"][t]*dfGen[y,:Var_OM_Cost_per_MWh]*vCAPRES_discharge[y,t])
		@expression(EP, eTotalCVarOutT_virtual[t=1:T], sum(eCVar_out_virtual[y,t] for y in STOR_ALL))
		@expression(EP, eTotalCVarOut_virtual, sum(eTotalCVarOutT_virtual[t] for t in 1:T))
		EP[:eObj] += eTotalCVarOut_virtual
	end

	## Power Balance Expressions ##

	# Term to represent net dispatch from storage in any period
	@expression(EP, ePowerBalanceStor[t=1:T, z=1:Z],
		sum(EP[:vP][y,t]-EP[:vCHARGE][y,t] for y in intersect(dfGen[dfGen.Zone.==z,:R_ID],STOR_ALL))
	)
	add_similar_to_expression!(EP[:ePowerBalance], ePowerBalanceStor)

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
		storage_all_reserves!(EP, inputs, setup)
	else
		if CapacityReserveMargin > 0
			# Note: maximum charge rate is also constrained by maximum charge power capacity, but as this differs by storage type,
			# this constraint is set in functions below for each storage type

			# Maximum discharging rate must be less than power rating OR available stored energy in the prior period, whichever is less
			# wrapping from end of sample period to start of sample period for energy capacity constraint
			@constraints(EP, begin
				[y in STOR_ALL, t=1:T], EP[:vP][y,t] + EP[:vCAPRES_discharge][y,t] <= EP[:eTotalCap][y]
				[y in STOR_ALL, t=1:T], EP[:vP][y,t] + EP[:vCAPRES_discharge][y,t] <= EP[:vS][y, hoursbefore(hours_per_subperiod,t,1)]*dfGen[y,:Eff_Down]
			end)
		else
			@constraints(EP, begin
				[y in STOR_ALL, t=1:T], EP[:vP][y,t] <= EP[:eTotalCap][y]
				[y in STOR_ALL, t=1:T], EP[:vP][y,t] <= EP[:vS][y, hoursbefore(hours_per_subperiod,t,1)]*dfGen[y,:Eff_Down]
			end)
		end
	end

	# From CO2 Policy module
	expr = @expression(EP, [z=1:Z], sum(EP[:eELOSS][y] for y in intersect(STOR_ALL, dfGen[dfGen[!,:Zone].==z,:R_ID])))
	add_similar_to_expression!(EP[:eELOSSByZone], expr)

	# Capacity Reserve Margin policy
	if CapacityReserveMargin > 0
		# Constraints governing energy held in reserve when storage makes virtual capacity reserve margin contributions:

		# Links energy held in reserve in first time step with decisions in last time step of each subperiod
		# We use a modified formulation of this constraint (cVSoCBalLongDurationStorageStart) when operations wrapping and long duration storage are being modeled
		@constraint(EP, cVSoCBalStart[t in START_SUBPERIODS, y in CONSTRAINTSET], EP[:vCAPRES_socinreserve][y,t] ==
			EP[:vCAPRES_socinreserve][y,t+hours_per_subperiod-1] + (1/dfGen[y,:Eff_Down] * EP[:vCAPRES_discharge][y,t])
			- (dfGen[y,:Eff_Up]*EP[:vCAPRES_charge][y,t]) - (dfGen[y,:Self_Disch] * EP[:vCAPRES_socinreserve][y,t+hours_per_subperiod-1]))

		# energy held in reserve for the next hour
		@constraint(EP, cVSoCBalInterior[t in INTERIOR_SUBPERIODS, y in STOR_ALL], EP[:vCAPRES_socinreserve][y,t] ==
			EP[:vCAPRES_socinreserve][y,t-1]+(1/dfGen[y,:Eff_Down]*EP[:vCAPRES_discharge][y,t])-(dfGen[y,:Eff_Up]*EP[:vCAPRES_charge][y,t])-(dfGen[y,:Self_Disch]*EP[:vCAPRES_socinreserve][y,t-1]))
		
		# energy held in reserve acts as a lower bound on the total energy held in storage
		@constraint(EP, cSOCMinCapRes[t in 1:T, y in STOR_ALL], EP[:vS][y,t] >= EP[:vCAPRES_socinreserve][y,t])
	end
end

function storage_all_reserves!(EP::Model, inputs::Dict, setup::Dict)

	dfGen = inputs["dfGen"]
	T = inputs["T"]
	p = inputs["hours_per_subperiod"]
	CapacityReserveMargin = setup["CapacityReserveMargin"]

	STOR_ALL = inputs["STOR_ALL"]

	STOR_REG_RSV = intersect(STOR_ALL, inputs["REG"], inputs["RSV"]) # Set of storage resources with both REG and RSV reserves

	STOR_REG = intersect(STOR_ALL, inputs["REG"]) # Set of storage resources with REG reserves
	STOR_RSV = intersect(STOR_ALL, inputs["RSV"]) # Set of storage resources with RSV reserves

	STOR_NO_RES = setdiff(STOR_ALL, STOR_REG, STOR_RSV) # Set of storage resources with no reserves

	STOR_REG_ONLY = setdiff(STOR_REG, STOR_RSV) # Set of storage resources only with REG reserves
	STOR_RSV_ONLY = setdiff(STOR_RSV, STOR_REG) # Set of storage resources only with RSV reserves

    vP = EP[:vP]
    vS = EP[:vS]
    vCHARGE = EP[:vCHARGE]
    vREG = EP[:vREG]
    vRSV = EP[:vRSV]
    vREG_charge = EP[:vREG_charge]
    vRSV_charge = EP[:vRSV_charge]
    vREG_discharge = EP[:vREG_discharge]
    vRSV_discharge = EP[:vRSV_discharge]
    vCAPRES_discharge = EP[:vCAPRES_discharge]
    eTotalCap = EP[:eTotalCap]
    eTotalCapEnergy = EP[:eTotalCapEnergy]

    eff_up(y) = dfGen[y, :Eff_Up]
    eff_down(y) = dfGen[y, :Eff_Down]

	# Maximum storage contribution to reserves is a specified fraction of installed capacity
    @constraint(EP, [y in STOR_REG, t in 1:T], vREG[y, t] <= dfGen[y,:Reg_Max] * eTotalCap[y])
    @constraint(EP, [y in STOR_RSV, t in 1:T], vRSV[y, t] <= dfGen[y,:Rsv_Max] * eTotalCap[y])

	# Actual contribution to regulation and reserves is sum of auxilary variables for portions contributed during charging and discharging
    @constraint(EP, [y in STOR_REG, t in 1:T], vREG[y, t] == vREG_charge[y, t] + vREG_discharge[y, t])
    @constraint(EP, [y in STOR_RSV, t in 1:T], vRSV[y, t] == vRSV_charge[y, t] + vRSV_discharge[y, t])

    # Maximum charging rate plus contribution to reserves up must be greater than zero
    # Note: when charging, reducing charge rate is contributing to upwards reserve & regulation as it drops net demand
    expr = @expression(EP, [y in STOR_ALL, t in 1:T], 1 * vCHARGE[y, t]) # NOTE load-bearing "1 *"

    S = STOR_REG
    add_similar_to_expression!(expr[S, :], -vREG_charge[S, :])

    S = STOR_RSV
    add_similar_to_expression!(expr[S, :], -vRSV_charge[S, :])

    @constraint(EP, [y in STOR_ALL, t in 1:T], expr[y, t] >= 0)

    # Maximum discharging rate and contribution to reserves down must be greater than zero
    # Note: when discharging, reducing discharge rate is contributing to downwards regulation as it drops net supply
    @constraint(EP, [y in STOR_REG, t in 1:T], vP[y, t] - vREG_discharge[y, t] >= 0)

    # Maximum charging rate plus contribution to regulation down must be less than available storage capacity
    @constraint(EP, [y in STOR_REG, t in 1:T], eff_up(y)*(vCHARGE[y, t]+vREG_charge[y, t]) <= eTotalCapEnergy[y]-vS[y, hoursbefore(p,t,1)])
    # Note: maximum charge rate is also constrained by maximum charge power capacity, but as this differs by storage type,
    # this constraint is set in functions below for each storage type

	if !isempty(STOR_REG_RSV)
		# Storage units charging can charge faster to provide reserves down and charge slower to provide reserves up

		# Maximum discharging rate and contribution to reserves up must be less than power rating OR available stored energy in prior period, whichever is less
		# wrapping from end of sample period to start of sample period for energy capacity constraint
		if CapacityReserveMargin > 0
			@constraints(EP, begin
				[y in STOR_REG_RSV, t=1:T], EP[:vP][y,t]+EP[:vCAPRES_discharge][y,t]+EP[:vREG_discharge][y,t]+EP[:vRSV_discharge][y,t] <= EP[:eTotalCap][y]
                [y in STOR_REG_RSV, t=1:T], (EP[:vP][y,t]+EP[:vCAPRES_discharge][y,t]+EP[:vREG_discharge][y,t]+EP[:vRSV_discharge][y,t]) <= EP[:vS][y, hoursbefore(p,t,1)] * dfGen[y, :Eff_Down]
			end)
		else
			@constraints(EP, begin
				[y in STOR_REG_RSV, t=1:T], EP[:vP][y,t]+EP[:vREG_discharge][y,t]+EP[:vRSV_discharge][y,t] <= EP[:eTotalCap][y]
                [y in STOR_REG_RSV, t=1:T], (EP[:vP][y,t]+EP[:vREG_discharge][y,t]+EP[:vRSV_discharge][y,t]) <= EP[:vS][y, hoursbefore(p,t,1)] * dfGen[y, :Eff_Down]
			end)
		end

	end
	if !isempty(STOR_REG_ONLY)
		# Storage units charging can charge faster to provide reserves down and charge slower to provide reserves up

		# Maximum discharging rate and contribution to reserves up must be less than power rating OR available stored energy in prior period, whichever is less
		# wrapping from end of sample period to start of sample period for energy capacity constraint
		if CapacityReserveMargin > 0
			@constraints(EP, begin
				[y in STOR_REG_ONLY, t=1:T], EP[:vP][y,t] + EP[:vCAPRES_discharge][y,t] + EP[:vREG_discharge][y,t] <= EP[:eTotalCap][y]
                [y in STOR_REG_ONLY, t=1:T], (EP[:vP][y,t]+EP[:vCAPRES_discharge][y,t]+EP[:vREG_discharge][y,t]) <= EP[:vS][y, hoursbefore(p,t,1)] * dfGen[y, :Eff_Down]
			end)
		else
			@constraints(EP, begin
				[y in STOR_REG_ONLY, t=1:T], EP[:vP][y,t] + EP[:vREG_discharge][y,t] <= EP[:eTotalCap][y]
                [y in STOR_REG_ONLY, t=1:T], (EP[:vP][y,t]+EP[:vREG_discharge][y,t]) <= EP[:vS][y, hoursbefore(p,t,1)] * dfGen[y, :Eff_Down]
			end)
		end

	end
	if !isempty(STOR_RSV_ONLY)
		# Storage units charging can charge faster to provide reserves down and charge slower to provide reserves up
		# Note: maximum charge rate is also constrained by maximum charge power capacity, but as this differs by storage type,
		# this constraint is set in functions below for each storage type

		# Maximum discharging rate and contribution to reserves up must be less than power rating OR available stored energy in prior period, whichever is less
		# wrapping from end of sample period to start of sample period for energy capacity constraint
		if CapacityReserveMargin > 0
			@constraints(EP, begin
				[y in STOR_RSV_ONLY, t=1:T], EP[:vP][y,t]+EP[:vCAPRES_discharge][y,t]+EP[:vRSV_discharge][y,t] <= EP[:eTotalCap][y]
                [y in STOR_RSV_ONLY, t=1:T], (EP[:vP][y,t]+EP[:vCAPRES_discharge][y,t]+EP[:vRSV_discharge][y,t]) <= EP[:vS][y, hoursbefore(p,t,1)] * dfGen[y, :Eff_Down]
			end)
		else
			@constraints(EP, begin
				[y in STOR_RSV_ONLY, t=1:T], EP[:vP][y,t]+EP[:vRSV_discharge][y,t] <= EP[:eTotalCap][y]
                [y in STOR_RSV_ONLY, t=1:T], (EP[:vP][y,t]+EP[:vRSV_discharge][y,t]) <= EP[:vS][y, hoursbefore(p,t,1)] * dfGen[y, :Eff_Down]
			end)
		end
	end
	if !isempty(STOR_NO_RES)
		# Maximum discharging rate must be less than power rating OR available stored energy in prior period, whichever is less
		# wrapping from end of sample period to start of sample period for energy capacity constraint
		if CapacityReserveMargin > 0
			@constraints(EP, begin
				[y in STOR_NO_RES, t=1:T], EP[:vP][y,t]  + EP[:vCAPRES_discharge][y,t] <= EP[:eTotalCap][y]
                [y in STOR_NO_RES, t=1:T], (EP[:vP][y,t]+EP[:vCAPRES_discharge][y,t]) <= EP[:vS][y, hoursbefore(p,t,1)] * dfGen[y, :Eff_Down]
			end)
		else
			@constraints(EP, begin
				[y in STOR_NO_RES, t=1:T], EP[:vP][y,t] <= EP[:eTotalCap][y]
                [y in STOR_NO_RES, t=1:T], EP[:vP][y,t] <= EP[:vS][y, hoursbefore(p,t,1)] * dfGen[y, :Eff_Down]
			end)
		end
	end
end

# function storage_all_reserves!(EP::Model, inputs::Dict, setup::Dict)
# 
# 	dfGen = inputs["dfGen"]
# 	T = inputs["T"]
# 	p = inputs["hours_per_subperiod"]
# 	CapacityReserveMargin = setup["CapacityReserveMargin"]
# 
# 	STOR_ALL = inputs["STOR_ALL"]
#     REG = inputs["REG"]
#     RSV = inputs["RSV"]
# 
# 	STOR_REG = intersect(STOR_ALL, REG) # Set of storage resources with REG reserves
# 	STOR_RSV = intersect(STOR_ALL, RSV) # Set of storage resources with RSV reserves
# 
#     vP = EP[:vP]
#     vS = EP[:vS]
#     vCHARGE = EP[:vCHARGE]
#     vREG = EP[:vREG]
#     vRSV = EP[:vRSV]
#     vREG_charge = EP[:vREG_charge]
#     vRSV_charge = EP[:vRSV_charge]
#     vREG_discharge = EP[:vREG_discharge]
#     vRSV_discharge = EP[:vRSV_discharge]
#     vCAPRES_discharge = EP[:vCAPRES_discharge]
#     eTotalCap = EP[:eTotalCap]
#     eTotalCapEnergy = EP[:eTotalCapEnergy]
# 
#     eff_up(y) = dfGen[y, :Eff_Up]
#     eff_down(y) = dfGen[y, :Eff_Down]
# 
# 	# Maximum storage contribution to reserves is a specified fraction of installed capacity
#     @constraint(EP, [y in STOR_REG, t in 1:T], vREG[y, t] <= dfGen[y,:Reg_Max] * eTotalCap[y])
#     @constraint(EP, [y in STOR_REG, t in 1:T], vREG[y, t] == vREG_charge[y, t] + vREG_discharge[y, t])
# 
# 	# Actual contribution to regulation and reserves is sum of auxilary variables for portions contributed during charging and discharging
#     @constraint(EP, [y in STOR_RSV, t in 1:T], vRSV[y, t] <= dfGen[y,:Rsv_Max] * eTotalCap[y])
#     @constraint(EP, [y in STOR_RSV, t in 1:T], vRSV[y, t] == vRSV_charge[y, t] + vRSV_discharge[y, t])
# 
#     # Maximum charging rate plus contribution to reserves up must be greater than zero
#     # Note: when charging, reducing charge rate is contributing to upwards reserve & regulation as it drops net demand
#     expr = @expression(EP, [y in STOR_ALL, t in 1:T], 1 * vCHARGE[y, t]) # NOTE load-bearing "1 *"
# 
#     S = STOR_REG
#     add_similar_to_expression!(expr[S, :], -vREG_charge[S, :])
# 
#     S = STOR_RSV
#     add_similar_to_expression!(expr[S, :], -vRSV_charge[S, :])
# 
#     @constraint(EP, [y in STOR_ALL, t in 1:T], expr[y, t] >= 0)
# 
#     # Maximum discharging rate and contribution to reserves down must be greater than zero
#     # Note: when discharging, reducing discharge rate is contributing to downwards regulation as it drops net supply
#     @constraint(EP, [y in STOR_REG, t in 1:T], vP[y, t] - vREG_discharge[y, t] >= 0)
# 
#     # Maximum charging rate plus contribution to regulation down must be less than available storage capacity
#     @constraint(EP, [y in STOR_REG, t in 1:T], eff_up(y)*(vCHARGE[y, t]+vREG_charge[y, t]) <= eTotalCapEnergy[y]-vS[y, hoursbefore(p,t,1)])
#     # Note: maximum charge rate is also constrained by maximum charge power capacity, but as this differs by storage type,
#     # this constraint is set in functions below for each storage type
# 
#     # Maximum discharging rate and contribution to reserves up must be less than power rating
#     expr = @expression(EP, [y in STOR_ALL, t in 1:T], 1 * vP[y, t]) # NOTE load-bearing "1 *"
# 
#     S = STOR_REG
#     add_similar_to_expression!(expr[S, :], vREG_discharge[S, :])
#     S = STOR_RSV
#     add_similar_to_expression!(expr[S, :], vRSV_discharge[S, :])
# 
#     S = STOR_ALL
#     if CapacityReserveMargin > 0
#         add_similar_to_expression!(expr[S, :], vCAPRES_discharge[S, :])
#     end
# 
#     @constraint(EP, [y in STOR_ALL, t in 1:T], expr[y, t] <= eTotalCap[y])
# 
#     # Maximum discharging rate and contribution to reserves up must be less than available stored energy in prior period
#     expr = @expression(EP, [y in STOR_ALL, t in 1:T], 1 * vP[y, t]) # NOTE load-bearing "1 *"
#     S = STOR_REG
#     add_similar_to_expression!(expr[S, :], vREG_discharge[S, :])
#     S = STOR_RSV
#     add_similar_to_expression!(expr[S, :], vRSV_discharge[S, :])
#     S = STOR_ALL
#     if CapacityReserveMargin > 0
#         add_similar_to_expression!(expr[S, :], vCAPRES_discharge[S, :])
#     end
# 
#     @constraint(EP, [y in STOR_ALL, t in 1:T], expr[y, t] <= vS[y, hoursbefore(p,t,1)] * eff_down(y))
# end
