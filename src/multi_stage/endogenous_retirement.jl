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

function update_cumulative_min_ret!(inputs_d::Dict,t::Int,Resource_Set::String,dfGen_Name::String,RetCap::Symbol)

	CumRetCap = Symbol("Cum_"*String(RetCap));

	if !isempty(inputs_d[1][Resource_Set])
		if t==1
			inputs_d[t][dfGen_Name][!,CumRetCap] = inputs_d[t][dfGen_Name][!,RetCap];
		else
			inputs_d[t][dfGen_Name][!,CumRetCap] = inputs_d[t-1][dfGen_Name][!,CumRetCap] + inputs_d[t][dfGen_Name][!,RetCap];
		end
	end
end

function compute_cumulative_min_retirements!(inputs_d::Dict,t::Int)

	mytab =[("G","dfGen",:Min_Retired_Cap_MW),
	("STOR_ALL","dfGen",:Min_Retired_Energy_Cap_MW),
	("STOR_ASYMMETRIC","dfGen",:Min_Retired_Charge_Cap_MW)];

	for (Resource_Set,dfGen_Name,RetCap) in mytab
		update_cumulative_min_ret!(inputs_d,t,Resource_Set,dfGen_Name,RetCap)
	end


end

function endogenous_retirement!(EP::Model, inputs::Dict, setup::Dict)
	multi_stage_settings = setup["MultiStageSettingsDict"]

	println("Endogenous Retirement Module")

	num_stages = multi_stage_settings["NumStages"]
	cur_stage = multi_stage_settings["CurStage"]
	stage_lens = multi_stage_settings["StageLengths"]

	endogenous_retirement_discharge!(EP, inputs, num_stages, cur_stage, stage_lens)

	if !isempty(inputs["STOR_ALL"])
		endogenous_retirement_energy!(EP, inputs, num_stages, cur_stage, stage_lens)
	end

	if !isempty(inputs["STOR_ASYMMETRIC"])
		endogenous_retirement_charge!(EP, inputs, num_stages, cur_stage, stage_lens)
	end

end

function endogenous_retirement_discharge!(EP::Model, inputs::Dict, num_stages::Int, cur_stage::Int, stage_lens::Array{Int, 1})

	println("Endogenous Retirement (Discharge) Module")
	
	dfGen = inputs["dfGen"]

	G = inputs["G"] # Number of resources (generators, storage, DR, and DERs)

	NEW_CAP = inputs["NEW_CAP"] # Set of all resources eligible for new capacity
	RET_CAP = inputs["RET_CAP"] # Set of all resources eligible for capacity retirements
	COMMIT = inputs["COMMIT"] # Set of all resources eligible for unit commitment

	### Variables ###

	# Keep track of all new and retired capacity from all stages
	@variable(EP, vCAPTRACK[y in RET_CAP,p=1:num_stages] >= 0 )
	@variable(EP, vRETCAPTRACK[y in RET_CAP,p=1:num_stages] >= 0 )

	### Expressions ###

	@expression(EP, eNewCap[y in RET_CAP],
		if y in NEW_CAP
			EP[:vCAP][y]
		else
			EP[:vZERO]
		end
	)

	@expression(EP, eRetCap[y in RET_CAP], EP[:vRETCAP][y])

	# Construct and add the endogenous retirement constraint expressions
	@expression(EP, eRetCapTrack[y in RET_CAP], sum(EP[:vRETCAPTRACK][y,p] for p=1:cur_stage))
	@expression(EP, eNewCapTrack[y in RET_CAP], sum(EP[:vCAPTRACK][y,p] for p=1:get_retirement_stage(cur_stage, dfGen[!,:Lifetime][y], stage_lens)))
	@expression(EP, eMinRetCapTrack[y in RET_CAP],
		if y in COMMIT
			dfGen[y,:Cum_Min_Retired_Cap_MW]/dfGen[y,:Cap_Size]
		else
			dfGen[y,:Cum_Min_Retired_Cap_MW]
		end
	)

	### Constraints ###

	# Keep track of newly built capacity from previous stages
	@constraint(EP, cCapTrackNew[y in RET_CAP], eNewCap[y] == vCAPTRACK[y,cur_stage])
	# The RHS of this constraint will be updated in the forward pass
	@constraint(EP, cCapTrack[y in RET_CAP,p=1:(cur_stage-1)], vCAPTRACK[y,p] == 0)

	# Keep track of retired capacity from previous stages
	@constraint(EP, cRetCapTrackNew[y in RET_CAP], eRetCap[y] == vRETCAPTRACK[y,cur_stage])
	# The RHS of this constraint will be updated in the forward pass
	@constraint(EP, cRetCapTrack[y in RET_CAP,p=1:(cur_stage-1)], vRETCAPTRACK[y,p] == 0)

	@constraint(EP, cLifetimeRet[y in RET_CAP], eNewCapTrack[y] + eMinRetCapTrack[y]  <= eRetCapTrack[y])

end

function endogenous_retirement_charge!(EP::Model, inputs::Dict, num_stages::Int, cur_stage::Int, stage_lens::Array{Int, 1})

	println("Endogenous Retirement (Charge) Module")

	dfGen = inputs["dfGen"]

	STOR_ASYMMETRIC = inputs["STOR_ASYMMETRIC"] # Set of storage resources with asymmetric (separte) charge/discharge capacity components

	NEW_CAP_CHARGE = inputs["NEW_CAP_CHARGE"] # Set of asymmetric charge/discharge storage resources eligible for new charge capacity
	RET_CAP_CHARGE = inputs["RET_CAP_CHARGE"] # Set of asymmetric charge/discharge storage resources eligible for charge capacity retirements

	### Variables ###

	# Keep track of all new and retired capacity from all stages
	@variable(EP, vCAPTRACKCHARGE[y in RET_CAP_CHARGE,p=1:num_stages] >= 0)
	@variable(EP, vRETCAPTRACKCHARGE[y in RET_CAP_CHARGE,p=1:num_stages] >= 0)

	### Expressions ###

	@expression(EP, eNewCapCharge[y in RET_CAP_CHARGE],
		if y in NEW_CAP_CHARGE
			EP[:vCAPCHARGE][y]
		else
			EP[:vZERO]
		end
	)

	@expression(EP, eRetCapCharge[y in RET_CAP_CHARGE], EP[:vRETCAPCHARGE][y])

	# Construct and add the endogenous retirement constraint expressions
	@expression(EP, eRetCapTrackCharge[y in RET_CAP_CHARGE], sum(EP[:vRETCAPTRACKCHARGE][y,p] for p=1:cur_stage))
	@expression(EP, eNewCapTrackCharge[y in RET_CAP_CHARGE], sum(EP[:vCAPTRACKCHARGE][y,p] for p=1:get_retirement_stage(cur_stage, dfGen[!,:Lifetime][y], stage_lens)))
	@expression(EP, eMinRetCapTrackCharge[y in RET_CAP_CHARGE], dfGen[y,:Cum_Min_Retired_Charge_Cap_MW])

	### Constratints ###

	# Keep track of newly built capacity from previous stages
	@constraint(EP, cCapTrackChargeNew[y in RET_CAP_CHARGE], eNewCapCharge[y] == vCAPTRACKCHARGE[y,cur_stage])
	# The RHS of this constraint will be updated in the forward pass
	@constraint(EP, cCapTrackCharge[y in RET_CAP_CHARGE,p=1:(cur_stage-1)], vCAPTRACKCHARGE[y,p] == 0)

	# Keep track of retired capacity from previous stages
	@constraint(EP, cRetCapTrackChargeNew[y in RET_CAP_CHARGE], eRetCapCharge[y] == vRETCAPTRACKCHARGE[y,cur_stage])
	# The RHS of this constraint will be updated in the forward pass
	@constraint(EP, cRetCapTrackCharge[y in RET_CAP_CHARGE,p=1:(cur_stage-1)], vRETCAPTRACKCHARGE[y,p] == 0)

	@constraint(EP, cLifetimeRetCharge[y in RET_CAP_CHARGE], eNewCapTrackCharge[y] + eMinRetCapTrackCharge[y]  <= eRetCapTrackCharge[y])

end

function endogenous_retirement_energy!(EP::Model, inputs::Dict, num_stages::Int, cur_stage::Int, stage_lens::Array{Int, 1})

	println("Endogenous Retirement (Energy) Module")

	dfGen = inputs["dfGen"]

	STOR_ALL = inputs["STOR_ALL"] # Set of all storage resources
	NEW_CAP_ENERGY = inputs["NEW_CAP_ENERGY"] # Set of all storage resources eligible for new energy capacity
	RET_CAP_ENERGY = inputs["RET_CAP_ENERGY"] # Set of all storage resources eligible for energy capacity retirements

	### Variables ###

	# Keep track of all new and retired capacity from all stages
	@variable(EP, vCAPTRACKENERGY[y in RET_CAP_ENERGY,p=1:num_stages] >= 0)
	@variable(EP, vRETCAPTRACKENERGY[y in RET_CAP_ENERGY,p=1:num_stages] >= 0)

	### Expressions ###

	@expression(EP, eNewCapEnergy[y in RET_CAP_ENERGY],
		if y in NEW_CAP_ENERGY
			EP[:vCAPENERGY][y]
		else
			EP[:vZERO]
		end
	)

	@expression(EP, eRetCapEnergy[y in RET_CAP_ENERGY], EP[:vRETCAPENERGY][y])

	# Construct and add the endogenous retirement constraint expressions
	@expression(EP, eRetCapTrackEnergy[y in RET_CAP_ENERGY], sum(EP[:vRETCAPTRACKENERGY][y,p] for p=1:cur_stage))
	@expression(EP, eNewCapTrackEnergy[y in RET_CAP_ENERGY], sum(EP[:vCAPTRACKENERGY][y,p] for p=1:get_retirement_stage(cur_stage, dfGen[!,:Lifetime][y], stage_lens)))
	@expression(EP, eMinRetCapTrackEnergy[y in RET_CAP_ENERGY], dfGen[y,:Cum_Min_Retired_Energy_Cap_MW])

	### Constratints ###

	# Keep track of newly built capacity from previous stages
	@constraint(EP, cCapTrackEnergyNew[y in RET_CAP_ENERGY], eNewCapEnergy[y] == vCAPTRACKENERGY[y,cur_stage])
	# The RHS of this constraint will be updated in the forward pass
	@constraint(EP, cCapTrackEnergy[y in RET_CAP_ENERGY,p=1:(cur_stage-1)], vCAPTRACKENERGY[y,p] == 0)

	# Keep track of retired capacity from previous stages
	@constraint(EP, cRetCapTrackEnergyNew[y in RET_CAP_ENERGY], eRetCapEnergy[y] == vRETCAPTRACKENERGY[y,cur_stage])
	# The RHS of this constraint will be updated in the forward pass
	@constraint(EP, cRetCapTrackEnergy[y in RET_CAP_ENERGY,p=1:(cur_stage-1)], vRETCAPTRACKENERGY[y,p] == 0)

	@constraint(EP, cLifetimeRetEnergy[y in RET_CAP_ENERGY], eNewCapTrackEnergy[y] + eMinRetCapTrackEnergy[y]  <= eRetCapTrackEnergy[y])

end
