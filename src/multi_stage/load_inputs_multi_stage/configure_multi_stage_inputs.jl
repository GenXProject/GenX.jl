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
	function compute_overnight_capital_cost(settings_d::Dict,inv_costs_yr::Array,crp::Array,tech_wacc::Array)

This function computes overnight capital costs incured within the model horizon, assuming that annualized costs to be paid after the model horizon are fully recoverable, and so are not included in the cost computation.

For each resource $y \in \mathcal{G}$ with annualized investment cost $AIC_{y}$ and capital recovery period $CRP_{y}$, overnight capital costs $OCC_{y}$ are computed as follows:
```math
\begin{aligned}
    & OCC_{y} = \sum^{min(CRP_{y},H)}_{i=1}\frac{AIC_{y}}{(1+WACC_{y})^{i}}
\end{aligned}
```
where $WACC_y$ is the technology-specific weighted average cost of capital (set by the "WACC" field in the Generators_data.csv or Network.csv files), $H$ is the number of years remaining between the start of the current model stage and the model horizon (the end of the final model stage) and $CRP_y$ is the capital recovery period for technology $y$ (specified in Generators_data.csv)

inputs:

  * settings\_d - dict object containing settings dictionary configured in the multi-stage settings file multi\_stage\_settings.yml.
  * inv\_costs\_yr - array object containing annualized investment costs.
  * crp - array object of capital recovery period values.
  * tech_wacc - array object containing technology-specific weighted costs of capital.
NOTE: The inv\_costs\_yr and crp arrays must be the same length; values with the same index in each array correspond to the same resource $y \in \mathcal{G}$.

returns: array object containing overnight capital costs, the discounted sum of annual investment costs incured within the model horizon.
"""
function compute_overnight_capital_cost(settings_d::Dict,inv_costs_yr::Array,crp::Array, tech_wacc::Array)

	cur_stage = settings_d["CurStage"] # Current model
	num_stages = settings_d["NumStages"] # Total number of model stages
	stage_lens = settings_d["StageLengths"]

	# 1) For each resource, find the minimum of the capital recovery period and the end of the model horizon
	# Total time between the end of the final model stage and the start of the current stage
	model_yrs_remaining = sum(stage_lens[cur_stage:end])

	# We will sum annualized costs through the full capital recovery period or the end of planning horizon, whichever comes first
	payment_yrs_remaining = min.(crp, model_yrs_remaining)

	# KEY ASSUMPTION: Investment costs after the planning horizon are fully recoverable, so we don't need to include these costs
	# 2) Compute the present value of investment associated with capital recovery period within the model horizon - discounting to year 1 and not year 0
	#    (Factor to adjust discounting to year 0 for capital cost is included in the discounting coefficient applied to all terms in the objective function value.)
	occ = zeros(length(inv_costs_yr))
	for i in 1:length(occ)
		occ[i] = sum(inv_costs_yr[i]/(1+tech_wacc[i]) .^ (p) for p=1:payment_yrs_remaining[i])
	end

	# 3) Return the overnight capital cost (discounted sum of annual investment costs incured within the model horizon)
	return occ
end

@doc raw"""
	function configure_multi_stage_inputs(inputs_d::Dict, settings_d::Dict, NetworkExpansion::Int64)

This function overwrites input parameters read in via the load\_inputs() method for proper configuration of multi-stage modeling:

1) Overnight capital costs are computed via the compute\_overnight\_capital\_cost() method and overwrite internal model representations of annualized investment costs.

2) Annualized fixed O&M costs are scaled up to represent total fixed O&M incured over the length of each model stage (specified by "StageLength" field in multi\_stage\_settings.yml).

3) Internal set representations of resources eligible for capacity retirements are overwritten to ensure compatability with multi-stage modeling.

4) When NetworkExpansion is active and there are multiple model zones, parameters related to transmission and network expansion are updated. First, annualized transmission reinforcement costs are converted into overnight capital costs. Next, the maximum allowable transmission line reinforcement parameter is overwritten by the model stage-specific value specified in the "Line\_Max\_Flow\_Possible\_MW" fields in the network_multi_stage.csv file. Finally, internal representations of lines eligible or not eligible for transmission expansion are overwritten based on the updated maximum allowable transmission line reinforcement parameters.

inputs:

  * inputs\_d - dict object containing model inputs dictionary generated by load\_inputs().
  * settings\_d - dict object containing settings dictionary configured in the multi-stage settings file multi\_stage\_settings.yml.
  * NetworkExpansion - integer flag (0/1) indicating whether network expansion is on, set via the "NetworkExpansion" field in genx\_settings.yml.

returns: dictionary containing updated model inputs, to be used in the generate\_model() method.
"""
function configure_multi_stage_inputs(inputs_d::Dict, settings_d::Dict, NetworkExpansion::Int64)

    dfGen = inputs_d["dfGen"]
	dfGenMultiStage = inputs_d["dfGenMultiStage"]

	# Parameter inputs when multi-year discounting is activated
	cur_stage = settings_d["CurStage"]
	stage_len = settings_d["StageLengths"][cur_stage]
	wacc = settings_d["WACC"] # Interest Rate  and also the discount rate unless specified other wise
	myopic = settings_d["Myopic"] == 1 # 1 if myopic (only one forward pass), 0 if full DDP

	# 1. Convert annualized investment costs incured within the model horizon into overnight capital costs
	# NOTE: Although the "yr" suffix is still in use in these parameter names, they no longer represent annualized costs but rather truncated overnight capital costs
	inputs_d["dfGen"][!,:Inv_Cost_per_MWyr] = compute_overnight_capital_cost(settings_d,dfGen[!,:Inv_Cost_per_MWyr],dfGenMultiStage[!,:Capital_Recovery_Period],dfGen[!,:WACC])
	inputs_d["dfGen"][!,:Inv_Cost_per_MWhyr] = compute_overnight_capital_cost(settings_d,dfGen[!,:Inv_Cost_per_MWhyr],dfGenMultiStage[!,:Capital_Recovery_Period],dfGen[!,:WACC])
	inputs_d["dfGen"][!,:Inv_Cost_Charge_per_MWyr] = compute_overnight_capital_cost(settings_d,dfGen[!,:Inv_Cost_Charge_per_MWyr],dfGenMultiStage[!,:Capital_Recovery_Period],dfGen[!,:WACC])

	# 2. Update fixed O&M costs to account for the possibility of more than 1 year between two model stages
	OPEXMULT = sum([1/(1+wacc)^(i-1) for i in range(1,stop=stage_len)]) # OPEX multiplier to count multiple years between two model stages

	# Update fixed O&M costs
	# NOTE: Although the "yr" suffix is still in use in these parameter names, they now represent total costs incured in each stage, which may be multiple years
	inputs_d["dfGen"][!,:Fixed_OM_Cost_per_MWyr] = OPEXMULT.*inputs_d["dfGen"][!,:Fixed_OM_Cost_per_MWyr]
	inputs_d["dfGen"][!,:Fixed_OM_Cost_per_MWhyr] = OPEXMULT.*inputs_d["dfGen"][!,:Fixed_OM_Cost_per_MWhyr]
	inputs_d["dfGen"][!,:Fixed_OM_Cost_charge_per_MWyr] = OPEXMULT.*inputs_d["dfGen"][!,:Fixed_OM_Cost_Charge_per_MWyr]

    # Set of all resources eligible for capacity retirements
	inputs_d["RET_CAP"] = intersect(dfGen[dfGen.New_Build.!=-1,:R_ID])
	# Set of all storage resources eligible for energy capacity retirements
	inputs_d["RET_CAP_ENERGY"] = intersect(dfGen[dfGen.New_Build.!=-1,:R_ID], inputs_d["STOR_ALL"])
	# Set of asymmetric charge/discharge storage resources eligible for charge capacity retirements
	inputs_d["RET_CAP_CHARGE"] = intersect(dfGen[dfGen.New_Build.!=-1,:R_ID], inputs_d["STOR_ASYMMETRIC"])

	# Transmission
	if NetworkExpansion == 1 && inputs_d["Z"] > 1

		dfNetworkMultiStage = inputs_d["dfNetworkMultiStage"]

		# 1. Convert annualized tramsmission investment costs incured within the model horizon into overnight capital costs
		inputs_d["pC_Line_Reinforcement"] = compute_overnight_capital_cost(settings_d,inputs_d["pC_Line_Reinforcement"],dfNetworkMultiStage[!,:Capital_Recovery_Period], inputs_d["transmission_WACC"])

		# Scale max_allowed_reinforcement to allow for possibility of deploying maximum reinforcement in each investment stage
		inputs_d["pTrans_Max_Possible"] = inputs_d["pLine_Max_Flow_Possible_MW_p$cur_stage"]

        # Network lines and zones that are expandable have greater maximum possible line flow than that of the previous stage
		if cur_stage > 1
			inputs_d["EXPANSION_LINES"] = findall(inputs_d["pLine_Max_Flow_Possible_MW_p$cur_stage"] .> inputs_d["pLine_Max_Flow_Possible_MW_p$(cur_stage-1)"])
        	inputs_d["NO_EXPANSION_LINES"] = findall(inputs_d["pLine_Max_Flow_Possible_MW_p$cur_stage"] .<= inputs_d["pLine_Max_Flow_Possible_MW_p$(cur_stage-1)"])
		else
			inputs_d["EXPANSION_LINES"] = findall(inputs_d["pLine_Max_Flow_Possible_MW_p$cur_stage"] .> inputs_d["pTrans_Max"])
			inputs_d["NO_EXPANSION_LINES"] = findall(inputs_d["pLine_Max_Flow_Possible_MW_p$cur_stage"] .<= inputs_d["pTrans_Max"])

			# To-Do: Error Handling
			# 1.) Enforce that pLine_Max_Flow_Possible_MW_p1 be equal to (for transmission expansion to be disalowed) or greater (to allow transmission expansion) than pTrans_Max in Inputs/Inputs_p1
		end
    end

    return inputs_d
end
