function investment_discharge_multi_period(EP::Model, inputs::Dict, period_length::Int, wacc::Float64)

	println("Investment Discharge DDP Module")

	dfGen = inputs["dfGen"]

	G = inputs["G"] # Number of resources (generators, storage, DR, and DERs)

	NEW_CAP = inputs["NEW_CAP"] # Set of all resources eligible for new capacity
	RET_CAP = inputs["RET_CAP"] # Set of all resources eligible for capacity retirements
	COMMIT = inputs["COMMIT"] # Set of all resources eligible for unit commitment

	### Variables ###

	# Retired capacity of resource "y" from existing capacity
	@variable(EP, vRETCAP[y in RET_CAP] >= 0);
    # New installed capacity of resource "y"
	@variable(EP, vCAP[y in NEW_CAP] >= 0);

    # DDP Variable – Existing capacity of resource "y"
	@variable(EP, vEXISTINGCAP[y=1:G] >= 0);

	### Expressions ###

	# Cap_Size is set to 1 for all variables when unit UCommit == 0
	# When UCommit > 0, Cap_Size is set to 1 for all variables except those where THERM == 1
	@expression(EP, eTotalCap[y in 1:G],
		if y in intersect(NEW_CAP, RET_CAP) # Resources eligible for new capacity and retirements
			if y in COMMIT
				EP[:vEXISTINGCAP][y] + dfGen[!,:Cap_Size][y]*(EP[:vCAP][y] - EP[:vRETCAP][y])
			else
				EP[:vEXISTINGCAP][y] + EP[:vCAP][y] - EP[:vRETCAP][y]
			end
		elseif y in setdiff(NEW_CAP, RET_CAP) # Resources eligible for only new capacity
			if y in COMMIT
				EP[:vEXISTINGCAP][y] + dfGen[!,:Cap_Size][y]*EP[:vCAP][y]
			else
				EP[:vEXISTINGCAP][y] + EP[:vCAP][y]
			end
		elseif y in setdiff(RET_CAP, NEW_CAP) # Resources eligible for only capacity retirements
			if y in COMMIT
				EP[:vEXISTINGCAP][y] - dfGen[!,:Cap_Size][y]*EP[:vRETCAP][y]
			else
				EP[:vEXISTINGCAP][y] - EP[:vRETCAP][y]
			end
		else # Resources not eligible for new capacity or retirements
			EP[:vEXISTINGCAP][y] + EP[:vZERO]
		end
	)

	## Objective Function Expressions ##

	# Fixed costs for resource "y" = annuitized investment cost plus fixed O&M costs
	# If resource is not eligible for new capacity, fixed costs are only O&M costs
	@expression(EP, eCFix[y in 1:G],
		if y in NEW_CAP # Resources eligible for new capacity
			if y in COMMIT
				dfGen[!,:Inv_Cost_per_MWyr][y]*dfGen[!,:Cap_Size][y]*vCAP[y] + dfGen[!,:Fixed_OM_Cost_per_MWyr][y]*eTotalCap[y]
			else
				dfGen[!,:Inv_Cost_per_MWyr][y]*vCAP[y] + dfGen[!,:Fixed_OM_Cost_per_MWyr][y]*eTotalCap[y]
			end
		else
			dfGen[!,:Fixed_OM_Cost_per_MWyr][y]*eTotalCap[y]
		end
	)

	# Sum individual resource contributions to fixed costs to get total fixed costs
	@expression(EP, eTotalCFix, sum(EP[:eCFix][y] for y in 1:G))

	# Add term to objective function expression
	# DDP - OPEX multiplier to count multiple years between two model time periods
	OPEXMULT = sum([1/(1+wacc)^(i-1) for i in range(1,stop=period_length)])
	# We divide by OPEXMULT since we are going to multiply the entire objective function by this term later, 
	# and we have already accounted for multiple years between time periods for fixed costs.
	EP[:eObj] += (1/OPEXMULT)*eTotalCFix

	### Constratints ###

    # DDP Constraint – Existing capacity variable is equal to existin capacity specified in the input file
    @constraint(EP, cExistingCap[y in 1:G], EP[:vEXISTINGCAP][y] == dfGen[!,:Existing_Cap_MW][y])

	## Constraints on retirements and capacity additions
	# Cannot retire more capacity than existing capacity
	@constraint(EP, cMaxRetNoCommit[y in setdiff(RET_CAP,COMMIT)], vRETCAP[y] <= EP[:vEXISTINGCAP][y])
	@constraint(EP, cMaxRetCommit[y in intersect(RET_CAP,COMMIT)], dfGen[!,:Cap_Size][y]*vRETCAP[y] <= EP[:vEXISTINGCAP][y])

	## Constraints on new built capacity
	# Constraint on maximum capacity (if applicable) [set input to -1 if no constraint on maximum capacity]
	# DEV NOTE: This constraint may be violated in some cases where Existing_Cap_MW is >= Max_Cap_MW and lead to infeasabilty
	@constraint(EP, cMaxCap[y in intersect(dfGen[dfGen.Max_Cap_MW.>0,:R_ID], 1:G)], eTotalCap[y] <= dfGen[!,:Max_Cap_MW][y])

	# Constraint on minimum capacity (if applicable) [set input to -1 if no constraint on minimum capacity]
	# DEV NOTE: This constraint may be violated in some cases where Existing_Cap_MW is <= Min_Cap_MW and lead to infeasabilty
	@constraint(EP, cMinCap[y in intersect(dfGen[dfGen.Min_Cap_MW.>0,:R_ID], 1:G)], eTotalCap[y] >= dfGen[!,:Min_Cap_MW][y])

	return EP
end

function investment_charge_multi_period(EP::Model, inputs::Dict, period_length::Int, wacc::Float64)

	println("Charge Investment DDP Module")

	dfGen = inputs["dfGen"]

	STOR_ASYMMETRIC = inputs["STOR_ASYMMETRIC"] # Set of storage resources with asymmetric (separte) charge/discharge capacity components

	NEW_CAP_CHARGE = inputs["NEW_CAP_CHARGE"] # Set of asymmetric charge/discharge storage resources eligible for new charge capacity
	RET_CAP_CHARGE = inputs["RET_CAP_CHARGE"] # Set of asymmetric charge/discharge storage resources eligible for charge capacity retirements

	### Variables ###

	## Storage capacity built and retired for storage resources with independent charge and discharge power capacities (STOR=2)

	# New installed charge capacity of resource "y"
	@variable(EP, vCAPCHARGE[y in NEW_CAP_CHARGE] >= 0)

	# Retired charge capacity of resource "y" from existing capacity
	@variable(EP, vRETCAPCHARGE[y in RET_CAP_CHARGE] >= 0)

	# DDP Variable – Existing charge capacity of resource "y"
	@variable(EP, vEXISTINGCAPCHARGE[y in STOR_ASYMMETRIC] >= 0);

	### Expressions ###

	@expression(EP, eTotalCapCharge[y in STOR_ASYMMETRIC],
		if (y in intersect(NEW_CAP_CHARGE, RET_CAP_CHARGE))
			EP[:vEXISTINGCAPCHARGE][y] + EP[:vCAPCHARGE][y] - EP[:vRETCAPCHARGE][y]
		elseif (y in setdiff(NEW_CAP_CHARGE, RET_CAP_CHARGE))
			EP[:vEXISTINGCAPCHARGE][y] + EP[:vCAPCHARGE][y]
		elseif (y in setdiff(RET_CAP_CHARGE, NEW_CAP_CHARGE))
			EP[:vEXISTINGCAPCHARGE][y] - EP[:vRETCAPCHARGE][y]
		else
			EP[:vEXISTINGCAPCHARGE][y]
		end
	)

	## Objective Function Expressions ##

	# Fixed costs for resource "y" = annuitized investment cost plus fixed O&M costs
	# If resource is not eligible for new charge capacity, fixed costs are only O&M costs
	@expression(EP, eCFixCharge[y in STOR_ASYMMETRIC],
		if y in NEW_CAP_CHARGE # Resources eligible for new charge capacity
			dfGen[!,:Inv_Cost_Charge_per_MWyr][y]*vCAPCHARGE[y] + dfGen[!,:Fixed_OM_Cost_Charge_per_MWyr][y]*eTotalCapCharge[y]
		else
			dfGen[!,:Fixed_OM_Cost_Charge_per_MWyr][y]*eTotalCapCharge[y]
		end
	)

	# Sum individual resource contributions to fixed costs to get total fixed costs
	@expression(EP, eTotalCFixCharge, sum(EP[:eCFixCharge][y] for y in STOR_ASYMMETRIC))

	# Add term to objective function expression
	# DDP - OPEX multiplier to count multiple years between two model time periods
	OPEXMULT = sum([1/(1+wacc)^(i-1) for i in range(1,stop=period_length)])
	# We divide by OPEXMULT since we are going to multiply the entire objective function by this term later, 
	# and we have already accounted for multiple years between time periods for fixed costs.
	EP[:eObj] += (1/OPEXMULT)*eTotalCFixCharge

	### Constratints ###

	# DDP Constraint – Existing capacity variable is equal to existin capacity specified in the input file
	@constraint(EP, cExistingCapCharge[y in STOR_ASYMMETRIC], EP[:vEXISTINGCAPCHARGE][y] == dfGen[!,:Existing_Charge_Cap_MW][y])

	## Constraints on retirements and capacity additions
	#Cannot retire more charge capacity than existing charge capacity
 	@constraint(EP, cMaxRetCharge[y in RET_CAP_CHARGE], vRETCAPCHARGE[y] <= EP[:vEXISTINGCAPCHARGE][y])

  	#Constraints on new built capacity

	# Constraint on maximum charge capacity (if applicable) [set input to -1 if no constraint on maximum charge capacity]
	# DEV NOTE: This constraint may be violated in some cases where Existing_Charge_Cap_MW is >= Max_Charge_Cap_MWh and lead to infeasabilty
	@constraint(EP, cMaxCapCharge[y in intersect(dfGen[!,:Max_Charge_Cap_MW].>0, STOR_ASYMMETRIC)], eTotalCapCharge[y] <= dfGen[!,:Max_Charge_Cap_MW][y])

	# Constraint on minimum charge capacity (if applicable) [set input to -1 if no constraint on minimum charge capacity]
	# DEV NOTE: This constraint may be violated in some cases where Existing_Charge_Cap_MW is <= Min_Charge_Cap_MWh and lead to infeasabilty
	@constraint(EP, cMinCapCharge[y in intersect(dfGen[!,:Min_Charge_Cap_MW].>0, STOR_ASYMMETRIC)], eTotalCapCharge[y] >= dfGen[!,:Min_Charge_Cap_MW][y])

	return EP
end

function investment_energy_multi_period(EP::Model, inputs::Dict, period_length::Int, wacc::Float64)

	println("Storage Investment DDP Module")

	dfGen = inputs["dfGen"]


	STOR_ALL = inputs["STOR_ALL"] # Set of all storage resources
	NEW_CAP_ENERGY = inputs["NEW_CAP_ENERGY"] # Set of all storage resources eligible for new energy capacity
	RET_CAP_ENERGY = inputs["RET_CAP_ENERGY"] # Set of all storage resources eligible for energy capacity retirements

	### Variables ###

	## Energy storage reservoir capacity (MWh capacity) built/retired for storage with variable power to energy ratio (STOR=1 or STOR=2)

	# New installed energy capacity of resource "y"
	@variable(EP, vCAPENERGY[y in NEW_CAP_ENERGY] >= 0)

	# Retired energy capacity of resource "y" from existing capacity
	@variable(EP, vRETCAPENERGY[y in RET_CAP_ENERGY] >= 0)

	# DDP Variable – Existing energy capacity of resource "y"
	@variable(EP, vEXISTINGCAPENERGY[y in STOR_ALL] >= 0);

	### Expressions ###

	@expression(EP, eTotalCapEnergy[y in STOR_ALL],
		if (y in intersect(NEW_CAP_ENERGY, RET_CAP_ENERGY))
			EP[:vEXISTINGCAPENERGY][y] + EP[:vCAPENERGY][y] - EP[:vRETCAPENERGY][y]
		elseif (y in setdiff(NEW_CAP_ENERGY, RET_CAP_ENERGY))
			EP[:vEXISTINGCAPENERGY][y] + EP[:vCAPENERGY][y]
		elseif (y in setdiff(RET_CAP_ENERGY, NEW_CAP_ENERGY))
			EP[:vEXISTINGCAPENERGY][y] - EP[:vRETCAPENERGY][y]
		else
			EP[:vEXISTINGCAPENERGY][y] + EP[:vZERO]
		end
	)

	## Objective Function Expressions ##

	# Fixed costs for resource "y" = annuitized investment cost plus fixed O&M costs
	# If resource is not eligible for new energy capacity, fixed costs are only O&M costs
	@expression(EP, eCFixEnergy[y in STOR_ALL],
		if y in NEW_CAP_ENERGY # Resources eligible for new capacity
			dfGen[!,:Inv_Cost_per_MWhyr][y]*vCAPENERGY[y] + dfGen[!,:Fixed_OM_Cost_per_MWhyr][y]*eTotalCapEnergy[y]
		else
			dfGen[!,:Fixed_OM_Cost_per_MWhyr][y]*eTotalCapEnergy[y]
		end
	)

	# Sum individual resource contributions to fixed costs to get total fixed costs
	@expression(EP, eTotalCFixEnergy, sum(EP[:eCFixEnergy][y] for y in STOR_ALL))

	# Add term to objective function expression
	# DDP - OPEX multiplier to count multiple years between two model time periods
	OPEXMULT = sum([1/(1+wacc)^(i-1) for i in range(1,stop=period_length)])
	# We divide by OPEXMULT since we are going to multiply the entire objective function by this term later, 
	# and we have already accounted for multiple years between time periods for fixed costs.
	EP[:eObj] += (1/OPEXMULT)*eTotalCFixEnergy

	### Constratints ###

	# DDP Constraint – Existing capacity variable is equal to existin capacity specified in the input file
	@constraint(EP, cExistingCapEnergy[y in STOR_ALL], EP[:vEXISTINGCAPENERGY][y] == dfGen[!,:Existing_Cap_MWh][y])

	## Constraints on retirements and capacity additions
	# Cannot retire more energy capacity than existing energy capacity
	@constraint(EP, cMaxRetEnergy[y in RET_CAP_ENERGY], vRETCAPENERGY[y] <= EP[:vEXISTINGCAPENERGY][y])

	## Constraints on new built energy capacity
	# Constraint on maximum energy capacity (if applicable) [set input to -1 if no constraint on maximum energy capacity]
	# DEV NOTE: This constraint may be violated in some cases where Existing_Cap_MWh is >= Max_Cap_MWh and lead to infeasabilty
	@constraint(EP, cMaxCapEnergy[y in intersect(dfGen[dfGen.Max_Cap_MWh.>0,:R_ID], STOR_ALL)], eTotalCap[y] <= dfGen[!,:Max_Cap_MWh][y])

	# Constraint on minimum energy capacity (if applicable) [set input to -1 if no constraint on minimum energy apacity]
	# DEV NOTE: This constraint may be violated in some cases where Existing_Cap_MWh is <= Min_Cap_MWh and lead to infeasabilty
	@constraint(EP, cMinCapEnergy[y in intersect(dfGen[dfGen.Min_Cap_MWh.>0,:R_ID], STOR_ALL)], eTotalCap[y] >= dfGen[!,:Min_Cap_MWh][y])

	return EP
end