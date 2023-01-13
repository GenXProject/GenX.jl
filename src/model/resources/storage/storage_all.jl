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
	storage_all!(EP::Model, inputs::Dict, setup::Dict)

Sets up variables and constraints common to all storage resources. See ```storage()``` in ```storage.jl``` for description of constraints.
"""
function storage_all!(EP::Model, inputs::Dict, setup::Dict)
	# Setup variables, constraints, and expressions common to all storage resources
	println("Storage Core Resources Module")

	dfGen = inputs["dfGen"]
	Reserves = setup["Reserves"]
	OperationWrapping = setup["OperationWrapping"]

	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
	Z = inputs["Z"]     # Number of zones

	STOR_ALL = inputs["STOR_ALL"]
	STOR_SHORT_DURATION = inputs["STOR_SHORT_DURATION"]

	START_SUBPERIODS = inputs["START_SUBPERIODS"]
	INTERIOR_SUBPERIODS = inputs["INTERIOR_SUBPERIODS"]

	hours_per_subperiod = inputs["hours_per_subperiod"] #total number of hours per subperiod

	### Variables ###

	# Storage level of resource "y" at hour "t" [MWh] on zone "z" - unbounded
	@variable(EP, vS[y in STOR_ALL, t=1:T] >= 0);

	# Energy withdrawn from grid by resource "y" at hour "t" [MWh] on zone "z"
	@variable(EP, vCHARGE[y in STOR_ALL, t=1:T] >= 0);

	### Expressions ###

	# Energy losses related to technologies (increase in effective demand)
	@expression(EP, eELOSS[y in STOR_ALL], sum(inputs["omega"][t]*EP[:vCHARGE][y,t] for t in 1:T) - sum(inputs["omega"][t]*EP[:vP][y,t] for t in 1:T))

	## Objective Function Expressions ##

	#Variable costs of "charging" for technologies "y" during hour "t" in zone "z"
	@expression(EP, eCVar_in[y in STOR_ALL, t = 1:T], inputs["omega"][t]*dfGen[y, :Var_OM_Cost_per_MWh_In]*vCHARGE[y, t])

    # Sum individual resource contributions to variable charging costs to get total variable charging costs

    # Sum to the plant level
    @expression(EP, ePlantCVarIn[y in STOR_ALL], sum(EP[:eCVar_in][y, t] for t in 1:T))
    
	# Sum to the zonal level
    @expression(EP, eZonalCVarIn[z = 1:Z], EP[:vZERO] + sum(EP[:ePlantCVarIn][y] for y in intersect(STOR_ALL, dfGen[dfGen[!, :Zone].==z, :R_ID])))
    
	# Sum to the system level
    @expression(EP, eTotalCVarIn, sum(EP[:eZonalCVarIn][z] for z in 1:Z))

	# Add to objective function
	add_to_expression!(EP[:eObj], EP[:eTotalCVarIn])

	## Power Balance Expressions ##

	# Term to represent net dispatch from storage in any period
	@expression(EP, ePowerBalanceStor[t=1:T, z=1:Z],
		sum(EP[:vP][y,t]-EP[:vCHARGE][y,t] for y in intersect(dfGen[dfGen.Zone.==z,:R_ID],STOR_ALL)))

	add_to_expression!.(EP[:ePowerBalance], EP[:ePowerBalanceStor])

	### Constraints ###

	## Storage energy capacity and state of charge related constraints:

	# Links state of charge in first time step with decisions in last time step of each subperiod
	# We use a modified formulation of this constraint (cSoCBalLongDurationStorageStart) when operations wrapping and long duration storage are being modeled
	if OperationWrapping ==1 && !isempty(inputs["STOR_LONG_DURATION"])
		CONSTRAINTSET = STOR_SHORT_DURATION
	else
		CONSTRAINTSET = STOR_ALL
	end
	@constraint(EP, cSoCBalStart[t in START_SUBPERIODS, y in CONSTRAINTSET], EP[:vS][y,t] ==
		EP[:vS][y,t+hours_per_subperiod-1] - (1/dfGen[y,:Eff_Down] * EP[:vP][y,t])
		+ (dfGen[y,:Eff_Up]*EP[:vCHARGE][y,t]) - (dfGen[y,:Self_Disch] * EP[:vS][y,t+hours_per_subperiod-1]))

	@constraints(EP, begin

		# Max and min constraints on energy storage capacity built (as proportion to discharge power capacity)
		[y in STOR_ALL], EP[:eTotalCapEnergy][y] >= dfGen[y,:Min_Duration] * EP[:eTotalCap][y]
		[y in STOR_ALL], EP[:eTotalCapEnergy][y] <= dfGen[y,:Max_Duration] * EP[:eTotalCap][y]

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
			[y in STOR_ALL, t=1:T], EP[:vP][y,t] <= EP[:eTotalCap][y]
			[y in STOR_ALL, t=1:T], EP[:vP][y,t] <= EP[:vS][y, hoursbefore(hours_per_subperiod,t,1)]*dfGen[y,:Eff_Down]
		end)
	end

	#From co2 Policy module
	@expression(EP, eELOSSByZone[z=1:Z],
		sum(EP[:eELOSS][y] for y in intersect(STOR_ALL, dfGen[dfGen[!,:Zone].==z,:R_ID]))
	)
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
