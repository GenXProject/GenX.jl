@doc raw"""
	function compute_overnight_capital_cost(settings_d::Dict,inv_costs_yr::Array,crp::Array,tech_wacc::Array)

This function computes overnight capital costs incured within the model horizon, assuming that annualized costs to be paid after the model horizon are fully recoverable, and so are not included in the cost computation.

For each resource $y \in \mathcal{G}$ with annualized investment cost $AIC_{y}$ and capital recovery period $CRP_{y}$, overnight capital costs $OCC_{y}$ are computed as follows:
```math
\begin{aligned}
    & OCC_{y} = \sum^{min(CRP_{y},H)}_{i=1}\frac{AIC_{y}}{(1+WACC_{y})^{i}}
\end{aligned}
```
where $WACC_y$ is the technology-specific weighted average cost of capital (set by the "WACC" field in the Generators\_data.csv or Network.csv files), $H$ is the number of years remaining between the start of the current model stage and the model horizon (the end of the final model stage) and $CRP_y$ is the capital recovery period for technology $y$ (specified in Generators\_data.csv).

inputs:

  * settings\_d - dict object containing settings dictionary configured in the multi-stage settings file multi\_stage\_settings.yml.
  * inv\_costs\_yr - array object containing annualized investment costs.
  * crp - array object of capital recovery period values.
  * tech_wacc - array object containing technology-specific weighted costs of capital.
NOTE: The inv\_costs\_yr and crp arrays must be the same length; values with the same index in each array correspond to the same resource $y \in \mathcal{G}$.

returns: array object containing overnight capital costs, the discounted sum of annual investment costs incured within the model horizon.
"""
function compute_overnight_capital_cost(settings_d::Dict,
        inv_costs_yr::Array,
        crp::Array,
        tech_wacc::Array)

    # Check for resources with non-zero investment costs and a Capital_Recovery_Period value of 0 years
    if any((crp .== 0) .& (inv_costs_yr .> 0))
        msg = "You have some resources with non-zero investment costs and a Capital_Recovery_Period value of 0 years.\n" *
              "These resources will have a calculated overnight capital cost of \$0. Correct your inputs if this is a mistake.\n"
        error(msg)
    end

    cur_stage = settings_d["CurStage"] # Current model
    num_stages = settings_d["NumStages"] # Total number of model stages
    stage_lens = settings_d["StageLengths"]

    # 1) For each resource, find the minimum of the capital recovery period and the end of the model horizon
    # Total time between the end of the final model stage and the start of the current stage
    model_yrs_remaining = sum(stage_lens[cur_stage:end]; init = 0)

    # We will sum annualized costs through the full capital recovery period or the end of planning horizon, whichever comes first
    payment_yrs_remaining = min.(crp, model_yrs_remaining)

    # KEY ASSUMPTION: Investment costs after the planning horizon are fully recoverable, so we don't need to include these costs
    # 2) Compute the present value of investment associated with capital recovery period within the model horizon - discounting to year 1 and not year 0
    #    (Factor to adjust discounting to year 0 for capital cost is included in the discounting coefficient applied to all terms in the objective function value.)
    occ = zeros(length(inv_costs_yr))
    for i in 1:length(occ)
        occ[i] = sum(
            inv_costs_yr[i] / (1 + tech_wacc[i]) .^ (p)
            for p in 1:payment_yrs_remaining[i];
            init = 0)
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

4) When NetworkExpansion is active and there are multiple model zones, parameters related to transmission and network expansion are updated. First, annualized transmission reinforcement costs are converted into overnight capital costs. Next, the maximum allowable transmission line reinforcement parameter is overwritten by the model stage-specific value specified in the "Line\_Max\_Flow\_Possible\_MW" fields in the network\_multi\_stage.csv file. Finally, internal representations of lines eligible or not eligible for transmission expansion are overwritten based on the updated maximum allowable transmission line reinforcement parameters.

inputs:

  * inputs\_d - dict object containing model inputs dictionary generated by load\_inputs().
  * settings\_d - dict object containing settings dictionary configured in the multi-stage settings file multi\_stage\_settings.yml.
  * NetworkExpansion - integer flag (0/1) indicating whether network expansion is on, set via the "NetworkExpansion" field in genx\_settings.yml.

returns: dictionary containing updated model inputs, to be used in the generate\_model() method.
"""
function configure_multi_stage_inputs(inputs_d::Dict,
        settings_d::Dict,
        NetworkExpansion::Int64)
    gen = inputs_d["RESOURCES"]

    # Parameter inputs when multi-year discounting is activated
    cur_stage = settings_d["CurStage"]
    stage_len = settings_d["StageLengths"][cur_stage]
    wacc = settings_d["WACC"] # Interest Rate and also the discount rate unless specified other wise
    myopic = settings_d["Myopic"] == 1 # 1 if myopic (only one forward pass), 0 if full DDP

    # Define OPEXMULT here, include in inputs_dict[t] for use in dual_dynamic_programming.jl, transmission_multi_stage.jl, and investment_multi_stage.jl
    OPEXMULT = myopic ? 1 :
               sum([1 / (1 + wacc)^(i - 1) for i in range(1, stop = stage_len)])
    inputs_d["OPEXMULT"] = OPEXMULT

    if !myopic ### Leave myopic costs in annualized form and do not scale OPEX costs
        # 1. Convert annualized investment costs incured within the model horizon into overnight capital costs
        # NOTE: Although the "yr" suffix is still in use in these parameter names, they no longer represent annualized costs but rather truncated overnight capital costs
        gen.inv_cost_per_mwyr = compute_overnight_capital_cost(settings_d,
            inv_cost_per_mwyr.(gen),
            capital_recovery_period.(gen),
            tech_wacc.(gen))
        gen.inv_cost_per_mwhyr = compute_overnight_capital_cost(settings_d,
            inv_cost_per_mwhyr.(gen),
            capital_recovery_period.(gen),
            tech_wacc.(gen))
        gen.inv_cost_charge_per_mwyr = compute_overnight_capital_cost(settings_d,
            inv_cost_charge_per_mwyr.(gen),
            capital_recovery_period.(gen),
            tech_wacc.(gen))

        # 2. Update fixed O&M costs to account for the possibility of more than 1 year between two model stages
        # NOTE: Although the "yr" suffix is still in use in these parameter names, they now represent total costs incured in each stage, which may be multiple years
        gen.fixed_om_cost_per_mwyr = fixed_om_cost_per_mwyr.(gen) .* OPEXMULT
        gen.fixed_om_cost_per_mwhyr = fixed_om_cost_per_mwhyr.(gen) .* OPEXMULT
        gen.fixed_om_cost_charge_per_mwyr = fixed_om_cost_charge_per_mwyr.(gen) .* OPEXMULT

        # Conduct 1. and 2. for any co-located VRE-STOR resources
        if !isempty(inputs_d["VRE_STOR"])
            gen_VRE_STOR = gen.VreStorage
            gen_VRE_STOR.inv_cost_inverter_per_mwyr = compute_overnight_capital_cost(
                settings_d,
                inv_cost_inverter_per_mwyr.(gen_VRE_STOR),
                capital_recovery_period_dc.(gen_VRE_STOR),
                tech_wacc_dc.(gen_VRE_STOR))
            gen_VRE_STOR.inv_cost_solar_per_mwyr = compute_overnight_capital_cost(
                settings_d,
                inv_cost_solar_per_mwyr.(gen_VRE_STOR),
                capital_recovery_period_solar.(gen_VRE_STOR),
                tech_wacc_solar.(gen_VRE_STOR))
            gen_VRE_STOR.inv_cost_wind_per_mwyr = compute_overnight_capital_cost(
                settings_d,
                inv_cost_wind_per_mwyr.(gen_VRE_STOR),
                capital_recovery_period_wind.(gen_VRE_STOR),
                tech_wacc_wind.(gen_VRE_STOR))
            gen_VRE_STOR.inv_cost_discharge_dc_per_mwyr = compute_overnight_capital_cost(
                settings_d,
                inv_cost_discharge_dc_per_mwyr.(gen_VRE_STOR),
                capital_recovery_period_discharge_dc.(gen_VRE_STOR),
                tech_wacc_discharge_dc.(gen_VRE_STOR))
            gen_VRE_STOR.inv_cost_charge_dc_per_mwyr = compute_overnight_capital_cost(
                settings_d,
                inv_cost_charge_dc_per_mwyr.(gen_VRE_STOR),
                capital_recovery_period_charge_dc.(gen_VRE_STOR),
                tech_wacc_charge_dc.(gen_VRE_STOR))
            gen_VRE_STOR.inv_cost_discharge_ac_per_mwyr = compute_overnight_capital_cost(
                settings_d,
                inv_cost_discharge_ac_per_mwyr.(gen_VRE_STOR),
                capital_recovery_period_discharge_ac.(gen_VRE_STOR),
                tech_wacc_discharge_ac.(gen_VRE_STOR))
            gen_VRE_STOR.inv_cost_charge_ac_per_mwyr = compute_overnight_capital_cost(
                settings_d,
                inv_cost_charge_ac_per_mwyr.(gen_VRE_STOR),
                capital_recovery_period_charge_ac.(gen_VRE_STOR),
                tech_wacc_charge_ac.(gen_VRE_STOR))

            gen_VRE_STOR.fixed_om_inverter_cost_per_mwyr = fixed_om_inverter_cost_per_mwyr.(gen_VRE_STOR) .*
                                                           OPEXMULT
            gen_VRE_STOR.fixed_om_solar_cost_per_mwyr = fixed_om_solar_cost_per_mwyr.(gen_VRE_STOR) .*
                                                        OPEXMULT
            gen_VRE_STOR.fixed_om_wind_cost_per_mwyr = fixed_om_wind_cost_per_mwyr.(gen_VRE_STOR) .*
                                                       OPEXMULT
            gen_VRE_STOR.fixed_om_cost_discharge_dc_per_mwyr = fixed_om_cost_discharge_dc_per_mwyr.(gen_VRE_STOR) .*
                                                               OPEXMULT
            gen_VRE_STOR.fixed_om_cost_charge_dc_per_mwyr = fixed_om_cost_charge_dc_per_mwyr.(gen_VRE_STOR) .*
                                                            OPEXMULT
            gen_VRE_STOR.fixed_om_cost_discharge_ac_per_mwyr = fixed_om_cost_discharge_ac_per_mwyr.(gen_VRE_STOR) .*
                                                               OPEXMULT
            gen_VRE_STOR.fixed_om_cost_charge_ac_per_mwyr = fixed_om_cost_charge_ac_per_mwyr.(gen_VRE_STOR) .*
                                                            OPEXMULT
        end
    end

    retirable = is_retirable(gen)

    # TODO: ask Sam about this
    # Set of all resources eligible for capacity retirements
    inputs_d["RET_CAP"] = retirable
    # Set of all storage resources eligible for energy capacity retirements
    inputs_d["RET_CAP_ENERGY"] = intersect(retirable, inputs_d["STOR_ALL"])
    # Set of asymmetric charge/discharge storage resources eligible for charge capacity retirements
    inputs_d["RET_CAP_CHARGE"] = intersect(retirable, inputs_d["STOR_ASYMMETRIC"])
    # Set of all co-located resources' components eligible for capacity retirements
    if !isempty(inputs_d["VRE_STOR"])
        inputs_d["RET_CAP_DC"] = intersect(retirable, inputs_d["VS_DC"])
        inputs_d["RET_CAP_SOLAR"] = intersect(retirable, inputs_d["VS_SOLAR"])
        inputs_d["RET_CAP_WIND"] = intersect(retirable, inputs_d["VS_WIND"])
        inputs_d["RET_CAP_STOR"] = intersect(retirable, inputs_d["VS_STOR"])
        inputs_d["RET_CAP_DISCHARGE_DC"] = intersect(retirable,
            inputs_d["VS_ASYM_DC_DISCHARGE"])
        inputs_d["RET_CAP_CHARGE_DC"] = intersect(retirable, inputs_d["VS_ASYM_DC_CHARGE"])
        inputs_d["RET_CAP_DISCHARGE_AC"] = intersect(retirable,
            inputs_d["VS_ASYM_AC_DISCHARGE"])
        inputs_d["RET_CAP_CHARGE_AC"] = intersect(retirable, inputs_d["VS_ASYM_AC_CHARGE"])
    end

    # Transmission
    if NetworkExpansion == 1 && inputs_d["Z"] > 1
        if !myopic ### Leave myopic costs in annualized form
            # 1. Convert annualized tramsmission investment costs incured within the model horizon into overnight capital costs
            inputs_d["pC_Line_Reinforcement"] = compute_overnight_capital_cost(settings_d,
                inputs_d["pC_Line_Reinforcement"],
                inputs_d["Capital_Recovery_Period_Trans"],
                inputs_d["transmission_WACC"])
        end

        # Scale max_allowed_reinforcement to allow for possibility of deploying maximum reinforcement in each investment stage
        inputs_d["pTrans_Max_Possible"] = inputs_d["pLine_Max_Flow_Possible_MW"]

        # Network lines and zones that are expandable have greater maximum possible line flow than the available capacity of the previous stage as well as available line reinforcement
        inputs_d["EXPANSION_LINES"] = findall((inputs_d["pLine_Max_Flow_Possible_MW"] .>
                                               inputs_d["pTrans_Max"]) .&
                                              (inputs_d["pMax_Line_Reinforcement"] .> 0))
        inputs_d["NO_EXPANSION_LINES"] = findall((inputs_d["pLine_Max_Flow_Possible_MW"] .<=
                                                  inputs_d["pTrans_Max"]) .|
                                                 (inputs_d["pMax_Line_Reinforcement"] .<=
                                                  0))
        # To-Do: Error Handling
        # 1.) Enforce that pLine_Max_Flow_Possible_MW for the first model stage be equal to (for transmission expansion to be disalowed) or greater (to allow transmission expansion) than pTrans_Max in inputs/inputs_p1
    end

    return inputs_d
end

@doc raw"""
    validate_can_retire_multistage(inputs_dict::Dict, num_stages::Int)

This function validates that all the resources do not switch from havig `can_retire = 0` to `can_retire = 1` during the multi-stage optimization.

# Arguments
- `inputs_dict::Dict`: A dictionary containing the inputs for each stage.
- `num_stages::Int`: The number of stages in the multi-stage optimization.

# Returns
- Throws an error if a resource switches from `can_retire = 0` to `can_retire = 1` between stages.
"""
function validate_can_retire_multistage(inputs_dict::Dict, num_stages::Int)
    for stage in 2:num_stages   # note: loop starts from 2 because we are comparing stage t with stage t-1
        can_retire_current = can_retire.(inputs_dict[stage]["RESOURCES"])
        can_retire_previous = can_retire.(inputs_dict[stage - 1]["RESOURCES"])

        # Check if any resource switched from can_retire = 0 to can_retire = 1 between stage t-1 and t
        if any(can_retire_current .- can_retire_previous .> 0)
            # Find the resources that switched from can_retire = 0 to can_retire = 1 and throw an error
            retire_switch_ids = findall(can_retire_current .- can_retire_previous .> 0)
            resources_switched = inputs_dict[stage]["RESOURCES"][retire_switch_ids]
            for resource in resources_switched
                @warn "Resource `$(resource_name(resource))` with id = $(resource_id(resource)) switched " *
                      "from can_retire = 0 to can_retire = 1 between stages $(stage - 1) and $stage"
            end
            msg = "Current implementation of multi-stage optimization does not allow resources " *
                  "to switch from can_retire = 0 to can_retire = 1 between stages."
            error(msg)
        end
    end
    return nothing
end
