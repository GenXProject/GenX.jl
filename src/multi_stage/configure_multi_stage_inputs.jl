@doc raw"""
    stage_opex_multiplier(discount_rate::Real, stage_len::Int)

Multiplier converting an annual operating cost into a stage-level cost, since a
stage may span several years.

```math
\text{OPEXMULT} = \sum_{j=1}^{L}\frac{1}{(1+DR)^{j}}
```

where $L$ is the stage length in years and $DR$ the general discount rate.

Costs are treated as incurred at the *end* of each year, hence the exponent $j$.
This matches how investment annuities are discounted in
[`overnight_capital_cost_factor`](@ref), which also starts at year 1. Weighting
an operating dollar and an annuity dollar the same way is what makes the two
comparable within a stage.
"""
function stage_opex_multiplier(discount_rate::Real, stage_len::Int)
    return sum(1 / (1 + discount_rate)^j for j in 1:stage_len; init = 0.0)
end

@doc raw"""
    stage_discount_factor(discount_rate::Real, stage_lens, cur_stage::Int)

Factor discounting a cost incurred in `cur_stage` back to the start of the
modeling horizon.

```math
DF_i = \frac{1}{(1+DR)^{N_i}}, \qquad N_i = \sum_{s<i} L_s
```
"""
function stage_discount_factor(discount_rate::Real, stage_lens, cur_stage::Int)
    cum_years = sum(stage_lens[1:(cur_stage - 1)]; init = 0)
    return 1 / (1 + discount_rate)^cum_years
end

@doc raw"""
    payment_years_remaining(settings_d::Dict, crp)

Per-resource count of investment annuity payments falling inside the modeling
horizon:

```math
P_y = \min(CRP_y, \sum_{s \geq i} L_s)
```

Annuities due after the horizon are assumed fully recoverable and excluded.
"""
function payment_years_remaining(settings_d::Dict, crp)
    cur_stage = settings_d["CurStage"]
    stage_lens = settings_d["StageLengths"]

    # Total time between the end of the final model stage and the start of the current stage
    model_yrs_remaining = sum(stage_lens[cur_stage:end]; init = 0)

    # For each resource, take the minimum of the capital recovery period and the end of the
    # model horizon: annualized costs are summed through the full capital recovery period or
    # the end of the planning horizon, whichever comes first
    return min.(crp, model_yrs_remaining)
end

@doc raw"""
    overnight_capital_cost_factor(settings_d::Dict, crp)

Per-resource factor converting an annualized investment cost into an overnight
capital cost, over the payments falling inside the horizon:

```math
A_y = \sum_{p=1}^{P_y}\frac{1}{(1+DR)^{p}}
```

where $DR$ is the general discount rate (the `WACC` field of
`multi_stage_settings.yml`). Every annuity is discounted at this one rate, which
represents the planner's time value of money, so two resources with the same
annualized cost and recovery period are weighted identically whatever their
financing. A technology-specific cost of capital belongs in the annualized
investment cost itself, not in how its annuities are discounted.

Discounting starts at year 1, not year 0; the adjustment to year 0 is carried by
the stage discount factor applied to the whole objective.
"""
function overnight_capital_cost_factor(settings_d::Dict, crp)
    payment_yrs = payment_years_remaining(settings_d, crp)
    dr = settings_d["DiscountRate"]

    # Present value of the investment annuities associated with the capital recovery period
    # within the model horizon - discounting to year 1 and not year 0. (The factor adjusting
    # to year 0 for capital cost is included in the discounting coefficient applied to all
    # terms in the objective function value.)
    return [sum(1 / (1 + dr)^p for p in 1:payment_yrs[i]; init = 0.0)
            for i in eachindex(payment_yrs)]
end

@doc raw"""
	function compute_overnight_capital_cost(settings_d::Dict,inv_costs_yr::Array,crp::Array)

This function computes overnight capital costs incured within the model horizon, assuming that annualized costs to be paid after the model horizon are fully recoverable, and so are not included in the cost computation.

For each resource $y \in \mathcal{G}$ with annualized investment cost $AIC_{y}$ and capital recovery period $CRP_{y}$, overnight capital costs $OCC_{y}$ are computed as follows:
```math
\begin{aligned}
    & OCC_{y} = \sum^{min(CRP_{y},H)}_{i=1}\frac{AIC_{y}}{(1+DR)^{i}}
\end{aligned}
```
where $DR$ is the general discount rate (the "WACC" field in multi\_stage\_settings.yml), $H$ is the number of years remaining between the start of the current model stage and the model horizon (the end of the final model stage) and $CRP_y$ is the capital recovery period for technology $y$ (specified in Resource\_multistage\_data.csv, or Network.csv for transmission lines). A technology-specific cost of capital is not used here; it is assumed to be reflected in $AIC_y$ already. See [`overnight_capital_cost_factor`](@ref).

inputs:

  * settings\_d - dict object containing settings dictionary configured in the multi-stage settings file multi\_stage\_settings.yml.
  * inv\_costs\_yr - array object containing annualized investment costs.
  * crp - array object of capital recovery period values.
NOTE: The inv\_costs\_yr and crp arrays must be the same length; values with the same index in each array correspond to the same resource $y \in \mathcal{G}$.

returns: array object containing overnight capital costs, the discounted sum of annual investment costs incured within the model horizon.
"""
function compute_overnight_capital_cost(settings_d::Dict,
        inv_costs_yr::Array,
        crp::Array)

    validate_capital_recovery_period(inv_costs_yr, crp)

    # KEY ASSUMPTION: Investment costs after the planning horizon are fully recoverable, so we
    # don't need to include these costs. Which annuities fall inside the horizon, and how they
    # are discounted, is handled by `overnight_capital_cost_factor`.
    #
    # Returns the overnight capital cost: the discounted sum of annual investment costs
    # incurred within the model horizon.
    return inv_costs_yr .* overnight_capital_cost_factor(settings_d, crp)
end

"""
    validate_capital_recovery_period(inv_costs_yr, crp)

Error if any resource has a positive investment cost and a capital recovery
period of zero years.

Such a resource has no years over which to spread its annuity, so its annuity
factor is zero and the investment silently disappears from both the model's
overnight capital cost and the reported figures. That is almost always an input
mistake, so it is rejected rather than absorbed.
"""
function validate_capital_recovery_period(inv_costs_yr, crp)
    if any((crp .== 0) .& (inv_costs_yr .> 0))
        msg = "You have some resources with non-zero investment costs and a Capital_Recovery_Period value of 0 years.\n" *
              "These resources will have a calculated overnight capital cost of \$0. Correct your inputs if this is a mistake.\n"
        error(msg)
    end
    return nothing
end

"""
Per-resource investment annuity data for one fixed-cost component.

  * `annuity` - the factor converting an annualized investment cost into an
    overnight capital cost, from `overnight_capital_cost_factor`. Gives the
    discounted view.
  * `payment_years` - the count of annuity payments falling inside the horizon,
    from `payment_years_remaining`. Gives the undiscounted cash flow.
"""
struct ComponentAnnuity
    annuity::Vector{Float64}
    payment_years::Vector{Float64}
end

"""
Per-stage factors that multi-stage cost reporting needs, all for the stage this
was built for.

  * `discount_factor` - discounts stage costs to the start of the horizon
  * `opex_multiplier` - annual to stage-level operating costs. Always the
    perfect-foresight value, since reporting discounts myopic runs too even
    though the myopic objective does not.
  * `stage_length` - years in this stage, for undiscounted cash flows
  * `components` - a `ComponentAnnuity` per fixed-cost component
"""
struct MultiStageCostFactors
    discount_factor::Float64
    opex_multiplier::Float64
    stage_length::Int
    components::Dict{Symbol, ComponentAnnuity}
end

@doc raw"""
    stash_cost_reporting_factors!(inputs_d::Dict, settings_d::Dict, NetworkExpansion::Int)

Build a [`MultiStageCostFactors`](@ref) for the current stage and store it under
`inputs_d["MULTISTAGE_COST_FACTORS"]`.

Reporting has to undo and redo the scaling the model applies: investment costs
become overnight capital costs and fixed O&M is multiplied by `OPEXMULT` before
the model is built, so the writer needs the same factors to recover annual
figures and re-scale them.

Computing them here rather than at write time matters twice over. They depend on
`CurStage`, a shared mutable setting that may have moved on by the time outputs
are written. And under perfect foresight the resource cost fields are
overwritten immediately below, so the factors must be taken beforehand.
"""
function stash_cost_reporting_factors!(inputs_d::Dict,
        settings_d::Dict,
        NetworkExpansion::Int)
    gen = inputs_d["RESOURCES"]
    cur_stage = settings_d["CurStage"]
    dr = settings_d["DiscountRate"]
    stage_len = settings_d["StageLengths"][cur_stage]

    G = length(gen)
    components = Dict{Symbol, ComponentAnnuity}()

    # Resource components are stored indexed by global resource id, so the cost
    # writer can index them the same way it indexes the model's expressions.
    # `ids` scatters a sub-collection's values into that space; transmission
    # passes `nothing` since it is indexed by line.
    # Perfect foresight validates the recovery period inside
    # compute_overnight_capital_cost, but myopic never takes that path, so the
    # same check runs here. Without it a myopic resource with a zero recovery
    # period and a positive investment cost would report zero investment while
    # the objective charged it in full.
    function add!(key, crp, inv; ids = nothing)
        validate_capital_recovery_period(inv, crp)
        a = collect(Float64, overnight_capital_cost_factor(settings_d, crp))
        p = collect(Float64, payment_years_remaining(settings_d, crp))
        if ids !== nothing
            a_full, p_full = zeros(Float64, G), zeros(Float64, G)
            a_full[ids], p_full[ids] = a, p
            a, p = a_full, p_full
        end
        components[key] = ComponentAnnuity(a, p)
    end

    # Components carried on the generic resource fields, already indexed by
    # resource id. eCFixEnergy_VS and eCGrid use these too, despite belonging
    # to co-located resources.
    # Each component is validated against the investment field it actually
    # prices: :discharge and :grid against the per-MW cost, :energy and
    # :stor_vs against the per-MWh cost, :charge against the charge-capacity
    # cost. These are still the original annual values here, since the
    # overwrite below has not run yet.
    generic_crp = capital_recovery_period.(gen)
    for (key, inv_f) in [(:discharge, inv_cost_per_mwyr), (:grid, inv_cost_per_mwyr),
        (:energy, inv_cost_per_mwhyr), (:stor_vs, inv_cost_per_mwhyr),
        (:charge, inv_cost_charge_per_mwyr)]
        add!(key, generic_crp, inv_f.(gen))
    end

    # Co-located components with their own recovery period. These come from the
    # VreStorage sub-collection, so they need scattering.
    if !isempty(inputs_d["VRE_STOR"])
        vs = gen.VreStorage
        vs_ids = resource_id.(vs)
        for (key, crp_f, inv_f) in [
            (:dc, capital_recovery_period_dc, inv_cost_inverter_per_mwyr),
            (:solar, capital_recovery_period_solar, inv_cost_solar_per_mwyr),
            (:wind, capital_recovery_period_wind, inv_cost_wind_per_mwyr),
            (:elec, capital_recovery_period_elec, inv_cost_elec_per_mwyr),
            (:charge_dc, capital_recovery_period_charge_dc, inv_cost_charge_dc_per_mwyr),
            (:discharge_dc, capital_recovery_period_discharge_dc,
                inv_cost_discharge_dc_per_mwyr),
            (:charge_ac, capital_recovery_period_charge_ac, inv_cost_charge_ac_per_mwyr),
            (:discharge_ac, capital_recovery_period_discharge_ac,
                inv_cost_discharge_ac_per_mwyr)]
            add!(key, crp_f.(vs), inv_f.(vs); ids = vs_ids)
        end
    end

    if NetworkExpansion == 1 && inputs_d["Z"] > 1
        add!(:transmission, inputs_d["Capital_Recovery_Period_Trans"],
            inputs_d["pC_Line_Reinforcement"])
    end

    inputs_d["MULTISTAGE_COST_FACTORS"] = MultiStageCostFactors(
        stage_discount_factor(dr, settings_d["StageLengths"], cur_stage),
        stage_opex_multiplier(dr, stage_len),
        stage_len,
        components)
    return nothing
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
    dr = settings_d["DiscountRate"] # Planner's time value of money; see resolve_discount_rate_setting!
    myopic = settings_d["Myopic"] == 1 # 1 if myopic (only one forward pass), 0 if full DDP

    # Define OPEXMULT here, include in inputs_dict[t] for use in dual_dynamic_programming.jl, transmission_multi_stage.jl, and investment_multi_stage.jl
    OPEXMULT = myopic ? 1 : stage_opex_multiplier(dr, stage_len)
    inputs_d["OPEXMULT"] = OPEXMULT

    stash_cost_reporting_factors!(inputs_d, settings_d, NetworkExpansion)

    if !myopic ### Leave myopic costs in annualized form and do not scale OPEX costs
        # 1. Convert annualized investment costs incured within the model horizon into overnight capital costs
        # NOTE: Although the "yr" suffix is still in use in these parameter names, they no longer represent annualized costs but rather truncated overnight capital costs
        gen.inv_cost_per_mwyr = compute_overnight_capital_cost(settings_d,
            inv_cost_per_mwyr.(gen),
            capital_recovery_period.(gen))
        gen.inv_cost_per_mwhyr = compute_overnight_capital_cost(settings_d,
            inv_cost_per_mwhyr.(gen),
            capital_recovery_period.(gen))
        gen.inv_cost_charge_per_mwyr = compute_overnight_capital_cost(settings_d,
            inv_cost_charge_per_mwyr.(gen),
            capital_recovery_period.(gen))

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
                capital_recovery_period_dc.(gen_VRE_STOR))
            gen_VRE_STOR.inv_cost_solar_per_mwyr = compute_overnight_capital_cost(
                settings_d,
                inv_cost_solar_per_mwyr.(gen_VRE_STOR),
                capital_recovery_period_solar.(gen_VRE_STOR))
            gen_VRE_STOR.inv_cost_wind_per_mwyr = compute_overnight_capital_cost(
                settings_d,
                inv_cost_wind_per_mwyr.(gen_VRE_STOR),
                capital_recovery_period_wind.(gen_VRE_STOR))
            gen_VRE_STOR.inv_cost_elec_per_mwyr = compute_overnight_capital_cost(
                settings_d,
                inv_cost_elec_per_mwyr.(gen_VRE_STOR),
                capital_recovery_period_elec.(gen_VRE_STOR))
            gen_VRE_STOR.inv_cost_discharge_dc_per_mwyr = compute_overnight_capital_cost(
                settings_d,
                inv_cost_discharge_dc_per_mwyr.(gen_VRE_STOR),
                capital_recovery_period_discharge_dc.(gen_VRE_STOR))
            gen_VRE_STOR.inv_cost_charge_dc_per_mwyr = compute_overnight_capital_cost(
                settings_d,
                inv_cost_charge_dc_per_mwyr.(gen_VRE_STOR),
                capital_recovery_period_charge_dc.(gen_VRE_STOR))
            gen_VRE_STOR.inv_cost_discharge_ac_per_mwyr = compute_overnight_capital_cost(
                settings_d,
                inv_cost_discharge_ac_per_mwyr.(gen_VRE_STOR),
                capital_recovery_period_discharge_ac.(gen_VRE_STOR))
            gen_VRE_STOR.inv_cost_charge_ac_per_mwyr = compute_overnight_capital_cost(
                settings_d,
                inv_cost_charge_ac_per_mwyr.(gen_VRE_STOR),
                capital_recovery_period_charge_ac.(gen_VRE_STOR))

            gen_VRE_STOR.fixed_om_inverter_cost_per_mwyr = fixed_om_inverter_cost_per_mwyr.(gen_VRE_STOR) .*
                                                           OPEXMULT
            gen_VRE_STOR.fixed_om_solar_cost_per_mwyr = fixed_om_solar_cost_per_mwyr.(gen_VRE_STOR) .*
                                                        OPEXMULT
            gen_VRE_STOR.fixed_om_wind_cost_per_mwyr = fixed_om_wind_cost_per_mwyr.(gen_VRE_STOR) .*
                                                       OPEXMULT
            gen_VRE_STOR.fixed_om_elec_cost_per_mwyr = fixed_om_elec_cost_per_mwyr.(gen_VRE_STOR) .*
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
        inputs_d["RET_CAP_ELEC"] = intersect(retirable, inputs_d["VS_ELEC"])
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
                inputs_d["Capital_Recovery_Period_Trans"])
        end

        # Scale max_allowed_reinforcement to allow for possibility of deploying maximum reinforcement in each investment stage
        inputs_d["pTrans_Max_Possible"] = inputs_d["pLine_Max_Flow_Possible_MW"]

        # Network lines and zones that are expandable have greater maximum possible line flow than the available capacity of the previous stage as well as available line reinforcement
        inputs_d["EXPANSION_LINES"] = findall((inputs_d["pLine_Max_Flow_Possible_MW"] .>
                                               inputs_d["pTrans_Max"]) .&
                                              (inputs_d["pMax_Line_Reinforcement"] .> 0))
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
