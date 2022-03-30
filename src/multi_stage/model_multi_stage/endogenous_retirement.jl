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
	function get_retirement_stage(cur_stage::Int, stage_len::Int, lifetime::Int, stage_lens::Array{Int, 1})

This function determines the model stage before which all newly built capacity must be retired. Used to enforce endogenous lifetime retirements in multi-stage modeling.

inputs:

  * cur\_stage – An Int representing the current model stage $p$.
  * lifetime – An Int representing the lifetime of a particular resource.
  * stage\_lens – An Int array representing the length $L$ of each model stage.

returns: An Int representing the model stage in before which the resource must retire due to endogenous lifetime retirements.
"""
function get_retirement_stage(cur_stage::Int, lifetime::Int, stage_lens::Array{Int, 1})
	years_from_start = sum(stage_lens[1:cur_stage]) # Years from start from the END of the current stage
	ret_years = years_from_start - lifetime # Difference between end of current stage and technology lifetime
	ret_stage = 0 # Compute the stage before which all newly built capacity must be retired by the end of the current stage
	while (ret_years - stage_lens[ret_stage+1] >= 0) & (ret_stage < cur_stage)
		ret_stage += 1
		ret_years -= stage_lens[ret_stage]
	end
    return Int(ret_stage)
end

function endogenous_retirement(EP::Model, inputs::Dict, multi_stage_settings::Dict)

	println("Endogenous Retirement Module")

	num_stages = multi_stage_settings["NumStages"]
	cur_stage = multi_stage_settings["CurStage"]
	stage_lens = multi_stage_settings["StageLengths"]

	EP = endogenous_retirement_discharge(EP, inputs, num_stages, cur_stage, stage_lens)

	if !isempty(inputs["STOR_ALL"])
		EP = endogenous_retirement_energy(EP, inputs, num_stages, cur_stage, stage_lens)
	end

	if !isempty(inputs["STOR_ASYMMETRIC"])
		EP = endogenous_retirement_charge(EP, inputs, num_stages, cur_stage, stage_lens)
	end

	return EP
end

function endogenous_retirement_discharge(EP::Model, inputs::Dict, num_stages::Int, cur_stage::Int, stage_lens::Array{Int, 1})

	println("Endogenous Retirement (Discharge) Module")
	
	dfGen = inputs["dfGen"]
	dfGenMultiStage = inputs["dfGenMultiStage"]

	G = inputs["G"] # Number of resources (generators, storage, DR, and DERs)

	NEW_CAP = inputs["NEW_CAP"] # Set of all resources eligible for new capacity
	RET_CAP = inputs["RET_CAP"] # Set of all resources eligible for capacity retirements
	COMMIT = inputs["COMMIT"] # Set of all resources eligible for unit commitment

	### Variables ###

	# Keep track of all new and retired capacity from all stages
	@variable(EP, vCAPTRACK[y=1:G,p=1:num_stages] >= 0 )
	@variable(EP, vRETCAPTRACK[y=1:G,p=1:num_stages] >= 0 )

	### Expressions ###

	@expression(EP, eNewCap[y in 1:G],
		if y in NEW_CAP
			EP[:vCAP][y]
		else
			EP[:vZERO]
		end
	)

	@expression(EP, eRetCap[y in 1:G],
		if y in RET_CAP
			EP[:vRETCAP][y]
		else
			EP[:vZERO]
		end
	)

	# Construct and add the endogenous retirement constraint expressions
	@expression(EP, eRetCapTrack[y=1:G], sum(EP[:vRETCAPTRACK][y,p] for p=1:cur_stage))
	@expression(EP, eNewCapTrack[y=1:G], sum(EP[:vCAPTRACK][y,p] for p=1:get_retirement_stage(cur_stage, dfGenMultiStage[!,:Lifetime][y], stage_lens)))
	@expression(EP, eMinRetCapTrack[y=1:G],
		if y in COMMIT
			sum((dfGenMultiStage[!,Symbol("Min_Retired_Cap_MW_p$p")][y]/dfGen[!,:Cap_Size][y]) for p=1:cur_stage)
		else
			sum((dfGenMultiStage[!,Symbol("Min_Retired_Cap_MW_p$p")][y]) for p=1:cur_stage)
		end
	)

	### Constraints ###

	# Keep track of newly built capacity from previous stages
	@constraint(EP, cCapTrackNew[y=1:G], eNewCap[y] == vCAPTRACK[y,cur_stage])
	# The RHS of this constraint will be updated in the forward pass
	@constraint(EP, cCapTrack[y=1:G,p=1:(cur_stage-1)], vCAPTRACK[y,p] == 0)

	# Keep track of retired capacity from previous stages
	@constraint(EP, cRetCapTrackNew[y=1:G], eRetCap[y] == vRETCAPTRACK[y,cur_stage])
	# The RHS of this constraint will be updated in the forward pass
	@constraint(EP, cRetCapTrack[y=1:G,p=1:(cur_stage-1)], vRETCAPTRACK[y,p] == 0)

	@constraint(EP, cLifetimeRet[y=1:G], eNewCapTrack[y] + eMinRetCapTrack[y]  <= eRetCapTrack[y])

	return EP
end

function endogenous_retirement_charge(EP::Model, inputs::Dict, num_stages::Int, cur_stage::Int, stage_lens::Array{Int, 1})

	println("Endogenous Retirement (Charge) Module")

	dfGenMultiStage = inputs["dfGenMultiStage"]

	STOR_ASYMMETRIC = inputs["STOR_ASYMMETRIC"] # Set of storage resources with asymmetric (separte) charge/discharge capacity components

	NEW_CAP_CHARGE = inputs["NEW_CAP_CHARGE"] # Set of asymmetric charge/discharge storage resources eligible for new charge capacity
	RET_CAP_CHARGE = inputs["RET_CAP_CHARGE"] # Set of asymmetric charge/discharge storage resources eligible for charge capacity retirements

	### Variables ###

	# Keep track of all new and retired capacity from all stages
	@variable(EP, vCAPTRACKCHARGE[y in STOR_ASYMMETRIC,p=1:num_stages] >= 0)
	@variable(EP, vRETCAPTRACKCHARGE[y in STOR_ASYMMETRIC,p=1:num_stages] >= 0)

	### Expressions ###

	@expression(EP, eNewCapCharge[y in STOR_ASYMMETRIC],
		if y in NEW_CAP_CHARGE
			EP[:vCAPCHARGE][y]
		else
			EP[:vZERO]
		end
	)

	@expression(EP, eRetCapCharge[y in STOR_ASYMMETRIC],
		if y in RET_CAP_CHARGE
			EP[:vRETCAPCHARGE][y]
		else
			EP[:vZERO]
		end
	)

	# Construct and add the endogenous retirement constraint expressions
	@expression(EP, eRetCapTrackCharge[y in STOR_ASYMMETRIC], sum(EP[:vRETCAPTRACKCHARGE][y,p] for p=1:cur_stage))
	@expression(EP, eNewCapTrackCharge[y in STOR_ASYMMETRIC], sum(EP[:vCAPTRACKCHARGE][y,p] for p=1:get_retirement_stage(cur_stage, dfGenMultiStage[!,:Lifetime][y], stage_lens)))
	@expression(EP, eMinRetCapTrackCharge[y in STOR_ASYMMETRIC], sum((dfGenMultiStage[!,Symbol("Min_Retired_Charge_Cap_MW_p$p")][y]) for p=1:cur_stage))

	### Constratints ###

	# Keep track of newly built capacity from previous stages
	@constraint(EP, cCapTrackChargeNew[y in STOR_ASYMMETRIC], eNewCapCharge[y] == vCAPTRACKCHARGE[y,cur_stage])
	# The RHS of this constraint will be updated in the forward pass
	@constraint(EP, cCapTrackCharge[y in STOR_ASYMMETRIC,p=1:(cur_stage-1)], vCAPTRACKCHARGE[y,p] == 0)

	# Keep track of retired capacity from previous stages
	@constraint(EP, cRetCapTrackChargeNew[y in STOR_ASYMMETRIC], eRetCapCharge[y] == vRETCAPTRACKCHARGE[y,cur_stage])
	# The RHS of this constraint will be updated in the forward pass
	@constraint(EP, cRetCapTrackCharge[y in STOR_ASYMMETRIC,p=1:(cur_stage-1)], vRETCAPTRACKCHARGE[y,p] == 0)

	@constraint(EP, cLifetimeRetCharge[y in STOR_ASYMMETRIC], eNewCapTrackCharge[y] + eMinRetCapTrackCharge[y]  <= eRetCapTrackCharge[y])

	return EP
end

function endogenous_retirement_energy(EP::Model, inputs::Dict, num_stages::Int, cur_stage::Int, stage_lens::Array{Int, 1})

	println("Endogenous Retirement (Energy) Module")

	dfGenMultiStage = inputs["dfGenMultiStage"]

	STOR_ALL = inputs["STOR_ALL"] # Set of all storage resources
	NEW_CAP_ENERGY = inputs["NEW_CAP_ENERGY"] # Set of all storage resources eligible for new energy capacity
	RET_CAP_ENERGY = inputs["RET_CAP_ENERGY"] # Set of all storage resources eligible for energy capacity retirements

	### Variables ###

	# Keep track of all new and retired capacity from all stages
	@variable(EP, vCAPTRACKENERGY[y in STOR_ALL,p=1:num_stages] >= 0)
	@variable(EP, vRETCAPTRACKENERGY[y in STOR_ALL,p=1:num_stages] >= 0)

	### Expressions ###

	@expression(EP, eNewCapEnergy[y in STOR_ALL],
		if y in NEW_CAP_ENERGY
			EP[:vCAPENERGY][y]
		else
			EP[:vZERO]
		end
	)

	@expression(EP, eRetCapEnergy[y in STOR_ALL],
		if y in RET_CAP_ENERGY
			EP[:vRETCAPENERGY][y]
		else
			EP[:vZERO]
		end
	)

	# Construct and add the endogenous retirement constraint expressions
	@expression(EP, eRetCapTrackEnergy[y in STOR_ALL], sum(EP[:vRETCAPTRACKENERGY][y,p] for p=1:cur_stage))
	@expression(EP, eNewCapTrackEnergy[y in STOR_ALL], sum(EP[:vCAPTRACKENERGY][y,p] for p=1:get_retirement_stage(cur_stage, dfGenMultiStage[!,:Lifetime][y], stage_lens)))
	@expression(EP, eMinRetCapTrackEnergy[y in STOR_ALL], sum((dfGenMultiStage[!,Symbol("Min_Retired_Energy_Cap_MW_p$p")][y]) for p=1:cur_stage))

	### Constratints ###

	# Keep track of newly built capacity from previous stages
	@constraint(EP, cCapTrackEnergyNew[y in STOR_ALL], eNewCapEnergy[y] == vCAPTRACKENERGY[y,cur_stage])
	# The RHS of this constraint will be updated in the forward pass
	@constraint(EP, cCapTrackEnergy[y in STOR_ALL,p=1:(cur_stage-1)], vCAPTRACKENERGY[y,p] == 0)

	# Keep track of retired capacity from previous stages
	@constraint(EP, cRetCapTrackEnergyNew[y in STOR_ALL], eRetCapEnergy[y] == vRETCAPTRACKENERGY[y,cur_stage])
	# The RHS of this constraint will be updated in the forward pass
	@constraint(EP, cRetCapTrackEnergy[y in STOR_ALL,p=1:(cur_stage-1)], vRETCAPTRACKENERGY[y,p] == 0)

	@constraint(EP, cLifetimeRetEnergy[y in STOR_ALL], eNewCapTrackEnergy[y] + eMinRetCapTrackEnergy[y]  <= eRetCapTrackEnergy[y])

	return EP
end