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
	function get_retirement_period(cur_period::Int, period_len::Int, lifetime::Int, multi_period_settings::Dict)

This function determines the model period before which all newly built capacity must be retired. Used to enforce endogenous lifetime retirements in multi-period modeling.

inputs:

  * cur\_period – An Int representing the current model period $p$.
  * period\_len – An Int representing the length $L$ of each model period.
  * lifetime – An Int representing the lifetime of a particular resource.
  * multi\_stage\_settings - Dictionary containing settings dictionary configured in the multi-period settings file multi\_period\_settings.yml.

returns: An Int representing the model period in before which the resource must retire due to endogenous lifetime retirements.
"""
function get_retirement_period(cur_period::Int, lifetime::Int, multi_period_settings::Dict)
	period_lens = multi_period_settings["PeriodLengths"]
	### years_from_start = cur_period * period_len # Years from start from the END of the current period # Pre-VSL
	years_from_start = sum(period_lens[1:cur_period])
	ret_years = years_from_start - lifetime # Difference between end of current period and technology lifetime
	### ret_period = floor(ret_years / period_len) # Compute the period before which all newly built capacity must be retired by the end of the current period # Pre-VSL
	ret_period = 0
	while (ret_years - period_lens[ret_period+1] >= 0) & (ret_period < cur_period)
		ret_period += 1
		ret_years -= period_lens[ret_period]
	end
    return Int(ret_period)
end

@doc raw"""
	function investment_discharge_multi_period(EP::Model, inputs::Dict, multi_period_settings::Dict)

This function defines the expressions and constraints keeping track of total available power generation/discharge capacity across all resources as well as constraints on capacity retirements, compatible with multi-period modeling. It includes all of the variables, expressions, and constraints of investmen\_discharge() with additional constraints and variables introduced for compatibility with multi-period modeling, which are described below.

Total Capacity Linking Variables and Constraints:

  * The linking variable vEXISTINGCAP[y] for $y \in \mathcal{G}$ is introduced and replaces occurrences of the parameter Existing\_Cap\_MW ($\bar{\Delta}_{y,z}$) in all expressions and constraints in investment\_discharge().
  * The linking constraint cExistingCap[y] for $y \in \mathcal{G}$  is introduced, which is used to link end discharge capacity from period $p$ to start discharge capacity in period $p+1$. When $p=1$, the constraint sets vEXISTINGCAP[y] = $\bar{\Delta}_{y,z}$.

Scaling Down the Objective Function Contribution:

  * The contribution of eTotalCFix ($\sum_{y \in \mathcal{G}} \sum_{z \in \mathcal{Z}} \left((\pi^{INVEST}_{y,z} \times \overline{\Omega}^{size}_{y,z} \times  \Omega_{y,z}) + (\pi^{FOM}_{y,z} \times \overline{\Omega}^{size}_{y,z} \times  \Delta^{total}_{y,z})\right)$) is scaled down by the factor $\sum_{p=1}^{\mathcal{P}} \frac{1}{(1+WACC)^{p-1}}$, where $\mathcal{P}$ is the length of each period and $WACC$ is the weighted average cost of capital, before it is added to the objective function (these costs will be scaled back to their correct value by the method initialize\_cost\_to\_go()).

Endogenous Retirements Linking Variables and Constraints:
  * The linking variables vCAPTRACK[y,p] and vRETCAPTRACKE[y,p] for $y \in \mathcal{G}, p \in  \mathcal{P}$ are introduced, which represent the cumulative capacity additions and retirements from previous model periods, respectively.
  * Linking constraints which enforce endogenous retirements using the vCAPTRACK and vRETCAPTRACK variables.
  * The constraint enforces that total retirements by period p should atleast equal the sum of the user specified value + new capacity build in prior periods that reach their end of life before end of period p. See Equation 18-21 of  Lara et al, Deterministic electric power infrastructure planning: Mixed-integer programming model and nested decomposition algorithm, EJOR, 271(3), 1037-1054, 2018 for further discussion.

inputs:

  * EP – JuMP model.
  * inputs – Dictionary object containing model inputs dictionary generated by load\_inputs().
  * multi\_period\_settings - Dictionary containing settings dictionary configured in the multi-period settings file multi\_period\_settings.yml.

returns: JuMP model with updated variables, expressions, and constraints.
"""
function investment_discharge_multi_period(EP::Model, inputs::Dict, multi_period_settings::Dict)

	println("Investment Discharge Multi-Period Module")

	dfGen = inputs["dfGen"]
	dfGenMultiPeriod = inputs["dfGenMultiPeriod"]

	G = inputs["G"] # Number of resources (generators, storage, DR, and DERs)

	NEW_CAP = inputs["NEW_CAP"] # Set of all resources eligible for new capacity
	RET_CAP = inputs["RET_CAP"] # Set of all resources eligible for capacity retirements
	COMMIT = inputs["COMMIT"] # Set of all resources eligible for unit commitment

	# Multi-period parameters
	num_periods = multi_period_settings["NumPeriods"]
	###period_len = multi_period_settings["PeriodLength"] #Pre-VSL
	cur_period = multi_period_settings["CurPeriod"]
	period_len = multi_period_settings["PeriodLengths"][cur_period]
	wacc = multi_period_settings["WACC"]

	### Variables ###

	# Retired capacity of resource "y" from existing capacity
	@variable(EP, vRETCAP[y in RET_CAP] >= 0);
    # New installed capacity of resource "y"
	@variable(EP, vCAP[y in NEW_CAP] >= 0);

    # DDP Variable – Existing capacity of resource "y"
	@variable(EP, vEXISTINGCAP[y=1:G] >= 0);

	# DDP - Endogenous Retirement Variables #
	# Keep track of all new and retired capacity from all periods
	@variable(EP, vCAPTRACK[y=1:G,p=1:num_periods] >= 0 )
	@variable(EP, vRETCAPTRACK[y=1:G,p=1:num_periods] >= 0 )

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
			EP[:vEXISTINGCAP][y]
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
	OPEXMULT = sum([1/(1+wacc)^(i-1) for i in range(1,stop=period_len)])

	# We divide by OPEXMULT since we are going to multiply the entire objective function by this term later,
	# and we have already accounted for multiple years between time periods for fixed costs.
	EP[:eObj] += (1/OPEXMULT)*eTotalCFix

	## DDP - Endogenous Retirements ##

	@expression(EP, eNewCap[y in 1:G],
		if y in NEW_CAP
			vCAP[y]
		else
			EP[:vZERO]
		end
	)

	@expression(EP, eRetCap[y in 1:G],
		if y in RET_CAP
			vRETCAP[y]
		else
			EP[:vZERO]
		end
	)

	# Construct and add the endogenous retirement constraint expressions
	@expression(EP, eRetCapTrack[y=1:G], sum(EP[:vRETCAPTRACK][y,p] for p=1:cur_period))
	@expression(EP, eNewCapTrack[y=1:G], sum(EP[:vCAPTRACK][y,p] for p=1:get_retirement_period(cur_period, dfGenMultiPeriod[!,:Lifetime][y], multi_period_settings)))
	@expression(EP, eMinRetCapTrack[y=1:G],
		if y in COMMIT
			sum((dfGenMultiPeriod[!,Symbol("Min_Retired_Cap_MW_p$p")][y]/dfGen[!,:Cap_Size][y]) for p=1:cur_period)
		else
			sum((dfGenMultiPeriod[!,Symbol("Min_Retired_Cap_MW_p$p")][y]) for p=1:cur_period)
		end
	)

	### Constraints ###

    # DDP Constraint – Existing capacity variable is equal to existing capacity specified in the input file
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

	## DDP - Endogenous Retirements ##

	# Keep track of newly built capacity from previous time periods
	@constraint(EP, cCapTrackNew[y=1:G], eNewCap[y] == vCAPTRACK[y,cur_period])
	# The RHS of this constraint will be updated in the forward pass
	@constraint(EP, cCapTrack[y=1:G,p=1:(cur_period-1)], vCAPTRACK[y,p] == 0)

	# Keep track of retired capacity from previous time periods
	@constraint(EP, cRetCapTrackNew[y=1:G], eRetCap[y] == vRETCAPTRACK[y,cur_period])
	# The RHS of this constraint will be updated in the forward pass
	@constraint(EP, cRetCapTrack[y=1:G,p=1:(cur_period-1)], vRETCAPTRACK[y,p] == 0)

	@constraint(EP, cLifetimeRet[y=1:G], eNewCapTrack[y] + eMinRetCapTrack[y]  <= eRetCapTrack[y])

	return EP
end

@doc raw"""
	function investment_charge_multi_period(EP::Model, inputs::Dict, multi_period_settings::Dict)

This function defines the expressions and constraints keeping track of total available power charge capacity across all storage resources with asymmetric charge/discharge as well as constraints on charge capacity retirements, compatible with multi-period modeling. It includes all of the variables, expressions, and constraints of investmen\_discharge() with additional constraints and variables introduced for compatibility with multi-period modeling, all analogous to those described in investment_discharge_multi_period().

inputs:

  * EP – JuMP model.
  * inputs – Dictionary object containing model inputs dictionary generated by load\_inputs().
  * multi\_period\_settings - Dictionary containing settings dictionary configured in the multi-period settings file multi\_period\_settings.yml.

returns: JuMP model with updated variables, expressions, and constraints.
"""
function investment_charge_multi_period(EP::Model, inputs::Dict, multi_period_settings::Dict)

	println("Storage Investment Charge Multi-Period Module")

	dfGen = inputs["dfGen"]
	dfGenMultiPeriod = inputs["dfGenMultiPeriod"]

	STOR_ASYMMETRIC = inputs["STOR_ASYMMETRIC"] # Set of storage resources with asymmetric (separte) charge/discharge capacity components

	NEW_CAP_CHARGE = inputs["NEW_CAP_CHARGE"] # Set of asymmetric charge/discharge storage resources eligible for new charge capacity
	RET_CAP_CHARGE = inputs["RET_CAP_CHARGE"] # Set of asymmetric charge/discharge storage resources eligible for charge capacity retirements

	# Multi-period parameters
	num_periods = multi_period_settings["NumPeriods"]
	### period_len = multi_period_settings["PeriodLength"] # Pre-VSL
	cur_period = multi_period_settings["CurPeriod"]
	period_len = multi_period_settings["PeriodLengths"][cur_period]
	wacc = multi_period_settings["WACC"]

	### Variables ###

	## Storage capacity built and retired for storage resources with independent charge and discharge power capacities (STOR=2)

	# New installed charge capacity of resource "y"
	@variable(EP, vCAPCHARGE[y in NEW_CAP_CHARGE] >= 0)

	# Retired charge capacity of resource "y" from existing capacity
	@variable(EP, vRETCAPCHARGE[y in RET_CAP_CHARGE] >= 0)

	# DDP Variable – Existing charge capacity of resource "y"
	@variable(EP, vEXISTINGCAPCHARGE[y in STOR_ASYMMETRIC] >= 0);

	# DDP - Endogenous Retirement Variables #
	# Keep track of all new and retired capacity from all periods
	@variable(EP, vCAPTRACKCHARGE[y in STOR_ASYMMETRIC,p=1:num_periods] >= 0 )
	@variable(EP, vRETCAPTRACKCHARGE[y in STOR_ASYMMETRIC,p=1:num_periods] >= 0 )

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
	OPEXMULT = sum([1/(1+wacc)^(i-1) for i in range(1,stop=period_len)])
	# We divide by OPEXMULT since we are going to multiply the entire objective function by this term later,
	# and we have already accounted for multiple years between time periods for fixed costs.
	EP[:eObj] += (1/OPEXMULT)*eTotalCFixCharge

	## DDP - Endogenous Retirements ##

		@expression(EP, eNewCapCharge[y in STOR_ASYMMETRIC],
		if y in NEW_CAP_CHARGE
			vCAPCHARGE[y]
		else
			EP[:vZERO]
		end
	)

	@expression(EP, eRetCapCharge[y in STOR_ASYMMETRIC],
		if y in RET_CAP_CHARGE
			vRETCAPCHARGE[y]
		else
			EP[:vZERO]
		end
	)

	# Construct and add the endogenous retirement constraint expressions
	@expression(EP, eRetCapTrackCharge[y in STOR_ASYMMETRIC], sum(EP[:vRETCAPTRACKCHARGE][y,p] for p=1:cur_period))
	@expression(EP, eNewCapTrackCharge[y in STOR_ASYMMETRIC], sum(EP[:vCAPTRACKCHARGE][y,p] for p=1:get_retirement_period(cur_period, dfGenMultiPeriod[!,:Lifetime][y], multi_period_settings)))
	@expression(EP, eMinRetCapTrackCharge[y in STOR_ASYMMETRIC], sum((dfGenMultiPeriod[!,Symbol("Min_Retired_Charge_Cap_MW_p$p")][y]) for p=1:cur_period))

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

	## DDP - Endogenous Retirements ##

	# Keep track of newly built capacity from previous time periods
	@constraint(EP, cCapTrackChargeNew[y in STOR_ASYMMETRIC], eNewCapCharge[y] == vCAPTRACKCHARGE[y,cur_period])
	# The RHS of this constraint will be updated in the forward pass
	@constraint(EP, cCapTrackCharge[y in STOR_ASYMMETRIC,p=1:(cur_period-1)], vCAPTRACKCHARGE[y,p] == 0)

	# Keep track of retired capacity from previous time periods
	@constraint(EP, cRetCapTrackChargeNew[y in STOR_ASYMMETRIC], eRetCapCharge[y] == vRETCAPTRACKCHARGE[y,cur_period])
	# The RHS of this constraint will be updated in the forward pass
	@constraint(EP, cRetCapTrackCharge[y in STOR_ASYMMETRIC,p=1:(cur_period-1)], vRETCAPTRACKCHARGE[y,p] == 0)

	@constraint(EP, cLifetimeRetCharge[y in STOR_ASYMMETRIC], eNewCapTrackCharge[y] + eMinRetCapTrackCharge[y]  <= eRetCapTrackCharge[y])

	return EP
end

@doc raw"""
	function investment_energy_multi_period(EP::Model, inputs::Dict, multi_period_settings::Dict)

This function defines the expressions and constraints keeping track of total available energy capacity across all storage resources as well as constraints on energy capacity retirements, compatible with multi-period modeling. It includes all of the variables, expressions, and constraints of investmen\_discharge() with additional constraints and variables introduced for compatibility with multi-period modeling, all analogous to those described in investment_discharge_multi_period().

inputs:

  * EP – JuMP model.
  * inputs – Dictionary object containing model inputs dictionary generated by load\_inputs().
  * multi\_period\_settings - Dictionary containing settings dictionary configured in the multi-period settings file multi\_period\_settings.yml.

returns: JuMP model with updated variables, expressions, and constraints.
"""
function investment_energy_multi_period(EP::Model, inputs::Dict, multi_period_settings::Dict)

	println("Storage Investment Energy Multi-Period Module")

	dfGen = inputs["dfGen"]
	dfGenMultiPeriod = inputs["dfGenMultiPeriod"]

	STOR_ALL = inputs["STOR_ALL"] # Set of all storage resources
	NEW_CAP_ENERGY = inputs["NEW_CAP_ENERGY"] # Set of all storage resources eligible for new energy capacity
	RET_CAP_ENERGY = inputs["RET_CAP_ENERGY"] # Set of all storage resources eligible for energy capacity retirements

	# Multi-period parameters
	num_periods = multi_period_settings["NumPeriods"]
	### period_len = multi_period_settings["PeriodLength"] # Pre-VSL
	cur_period = multi_period_settings["CurPeriod"]
	period_len = multi_period_settings["PeriodLengths"][cur_period]
	wacc = multi_period_settings["WACC"]

	### Variables ###

	## Energy storage reservoir capacity (MWh capacity) built/retired for storage with variable power to energy ratio (STOR=1 or STOR=2)

	# New installed energy capacity of resource "y"
	@variable(EP, vCAPENERGY[y in NEW_CAP_ENERGY] >= 0)

	# Retired energy capacity of resource "y" from existing capacity
	@variable(EP, vRETCAPENERGY[y in RET_CAP_ENERGY] >= 0)

	# DDP Variable – Existing energy capacity of resource "y"
	@variable(EP, vEXISTINGCAPENERGY[y in STOR_ALL] >= 0);

	# DDP - Endogenous Retirement Variables #
	# Keep track of all new and retired capacity from all periods
	@variable(EP, vCAPTRACKENERGY[y in STOR_ALL,p=1:num_periods] >= 0 )
	@variable(EP, vRETCAPTRACKENERGY[y in STOR_ALL,p=1:num_periods] >= 0 )

	### Expressions ###

	@expression(EP, eTotalCapEnergy[y in STOR_ALL],
		if (y in intersect(NEW_CAP_ENERGY, RET_CAP_ENERGY))
			EP[:vEXISTINGCAPENERGY][y] + EP[:vCAPENERGY][y] - EP[:vRETCAPENERGY][y]
		elseif (y in setdiff(NEW_CAP_ENERGY, RET_CAP_ENERGY))
			EP[:vEXISTINGCAPENERGY][y] + EP[:vCAPENERGY][y]
		elseif (y in setdiff(RET_CAP_ENERGY, NEW_CAP_ENERGY))
			EP[:vEXISTINGCAPENERGY][y] - EP[:vRETCAPENERGY][y]
		else
			EP[:vEXISTINGCAPENERGY][y]
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
	OPEXMULT = sum([1/(1+wacc)^(i-1) for i in range(1,stop=period_len)])
	# We divide by OPEXMULT since we are going to multiply the entire objective function by this term later,
	# and we have already accounted for multiple years between time periods for fixed costs.
	EP[:eObj] += (1/OPEXMULT)*eTotalCFixEnergy

	## DDP - Endogenous Retirements ##

		@expression(EP, eNewCapEnergy[y in STOR_ALL],
		if y in NEW_CAP_ENERGY
			vCAPENERGY[y]
		else
			EP[:vZERO]
		end
	)

	@expression(EP, eRetCapEnergy[y in STOR_ALL],
		if y in RET_CAP_ENERGY
			vRETCAPENERGY[y]
		else
			EP[:vZERO]
		end
	)

	# Construct and add the endogenous retirement constraint expressions
	@expression(EP, eRetCapTrackEnergy[y in STOR_ALL], sum(EP[:vRETCAPTRACKENERGY][y,p] for p=1:cur_period))
	@expression(EP, eNewCapTrackEnergy[y in STOR_ALL], sum(EP[:vCAPTRACKENERGY][y,p] for p=1:get_retirement_period(cur_period, dfGenMultiPeriod[!,:Lifetime][y], multi_period_settings)))
	@expression(EP, eMinRetCapTrackEnergy[y in STOR_ALL], sum((dfGenMultiPeriod[!,Symbol("Min_Retired_Energy_Cap_MW_p$p")][y]) for p=1:cur_period))

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

	## DDP - Endogenous Retirements ##

	# Keep track of newly built capacity from previous time periods
	@constraint(EP, cCapTrackEnergyNew[y in STOR_ALL], eNewCapEnergy[y] == vCAPTRACKENERGY[y,cur_period])
	# The RHS of this constraint will be updated in the forward pass
	@constraint(EP, cCapTrackEnergy[y in STOR_ALL,p=1:(cur_period-1)], vCAPTRACKENERGY[y,p] == 0)

	# Keep track of retired capacity from previous time periods
	@constraint(EP, cRetCapTrackEnergyNew[y in STOR_ALL], eRetCapEnergy[y] == vRETCAPTRACKENERGY[y,cur_period])
	# The RHS of this constraint will be updated in the forward pass
	@constraint(EP, cRetCapTrackEnergy[y in STOR_ALL,p=1:(cur_period-1)], vRETCAPTRACKENERGY[y,p] == 0)

	@constraint(EP, cLifetimeRetEnergy[y in STOR_ALL], eNewCapTrackEnergy[y] + eMinRetCapTrackEnergy[y]  <= eRetCapTrackEnergy[y])

	return EP
end
