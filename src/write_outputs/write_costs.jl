"""
    _investment_views(scaled, A, P, myopic) -> (discounted, undiscounted)

Turn one investment cost as the model holds it into the two reported views.

`A` is the annuity factor and `P` the count of payments falling inside the
horizon, both for the item being priced.

Under perfect foresight the model already holds the overnight capital cost, so
dividing by `A` recovers the annual annuity. Under myopic the model holds a
single year's annuity, so no division is needed, and multiplying by `A` *adds
back* the payments the myopic objective never charged.

Used for both resource fixed costs and transmission expansion, which differ only
in what they iterate over.
"""
function _investment_views(scaled, A, P, myopic)
    annual = myopic ? scaled : (A > 0 ? scaled / A : 0.0)
    return annual * A, annual * P
end

"""Accumulate `value(expr[y])` into `acc[y]` for every `y` in `ids`."""
function _accumulate!(acc::Vector{Float64}, expr, ids)
    for y in ids
        acc[y] += value(expr[y])
    end
    return acc
end

"""
Split one fixed-cost component into its investment and fixed O&M parts and
accumulate all four views.

A fixed-cost expression is `investment + fixed O&M`, and the two need different
treatment when reporting a multi-stage run, so they have to be separated. Fixed
O&M is recoverable because it is always `rate * capacity`; investment is then
whatever remains.

Both parts are recovered to *annual* terms first, undoing the scaling
`configure_multi_stage_inputs` applied, and then re-scaled:

  * `fix`        the model's own value, used as-is for single-stage runs
  * `fix_fom`    annual fixed O&M
  * `fix_inv_A`  investment over the annuities falling inside the horizon
  * `fix_inv_P`  investment as an undiscounted cash flow

Under perfect foresight the investment field already holds the overnight capital
cost, so dividing by the annuity factor recovers the annuity. Under myopic it
holds a single year's annuity, so no division is needed and multiplying by the
annuity factor *adds back* the payments the myopic objective never saw. That
add-back is what makes the two modes comparable.
"""
function _accumulate_fixed!(acc, expr, ids, fom_per_unit, cap_expr,
        ann, model_opexmult, myopic)
    for y in ids
        total = value(expr[y])
        acc.fix[y] += total
        ann === nothing && continue

        fom_scaled = fom_per_unit(y) * value(cap_expr[y])
        inv_scaled = total - fom_scaled
        A, P = ann.annuity[y], ann.payment_years[y]

        inv_A, inv_P = _investment_views(inv_scaled, A, P, myopic)
        acc.fix_fom[y] += fom_scaled / model_opexmult
        acc.fix_inv_A[y] += inv_A
        acc.fix_inv_P[y] += inv_P
    end
    return acc
end

"""Accumulate the time-sum of `expr[y, :]` into `acc[y]` for every `y` in `ids`."""
function _accumulate_over_time!(acc::Vector{Float64}, expr, ids)
    for y in ids
        acc[y] += sum(value.(expr[y, :]))
    end
    return acc
end

@doc raw"""
    cost_breakdown(EP::Model, inputs::Dict, setup::Dict)

Collect the solved cost terms that make up `costs.csv`, in model units and
before any scaling.

Costs that can be attributed to a resource are returned as vectors indexed by
resource id, so that the system total is the sum of the vector and a zone's
value is the sum over the resources in that zone. This is what makes the zone
columns add up to the `Total` column by construction, rather than by two
independent accumulations that can drift apart.

Costs with no per-resource attribution are returned as scalars
(`unmet_rsv`, `netexp`, `policy_penalty`) or per-zone vectors (`nse`).

Returns a `NamedTuple`; see [`assemble_costs`](@ref) for how it becomes a table.
"""
function cost_breakdown(EP::Model, inputs::Dict, setup::Dict)
    gen = inputs["RESOURCES"]
    G = length(gen)
    Z = inputs["Z"]

    VRE_STOR = inputs["VRE_STOR"]
    ALLAM_CYCLE_LOX = inputs["ALLAM_CYCLE_LOX"]
    STOR_ALL = inputs["STOR_ALL"]
    STOR_ASYMMETRIC = inputs["STOR_ASYMMETRIC"]
    FLEX = inputs["FLEX"]
    COMMIT = inputs["COMMIT"]
    CCS = inputs["CCS"]

    zeros_G() = zeros(Float64, G)
    fix, var, fuel, start = zeros_G(), zeros_G(), zeros_G(), zeros_G()
    co2, h2, grid = zeros_G(), zeros_G(), zeros_G()
    acc = (fix = fix, fix_fom = zeros_G(),
        fix_inv_A = zeros_G(), fix_inv_P = zeros_G())
    grid_acc = (fix = grid, fix_fom = zeros_G(),
        fix_inv_A = zeros_G(), fix_inv_P = zeros_G())

    # Multi-stage reporting needs the investment/O&M split; single-stage does
    # not, and passing `nothing` for the annuity skips it.
    multistage = setup["MultiStage"] == 1 && haskey(inputs, "MULTISTAGE_COST_FACTORS")
    if setup["MultiStage"] == 1 && !multistage
        # Falling back here would quietly emit single-stage-shaped costs for a
        # multi-stage run, with no undiscounted companion, so say so loudly.
        @warn "Multi-stage cost factors are missing from inputs; costs will be " *
              "reported on the model's own basis rather than discounted. This " *
              "means configure_multi_stage_inputs did not run for this stage."
    end
    if multistage && !isempty(ALLAM_CYCLE_LOX)
        # Allam fixed costs are accumulated whole, without the investment/O&M
        # split, because the loader refuses Allam in multi-stage mode. If that
        # restriction is ever lifted, they would silently vanish from the
        # discounted and undiscounted views rather than be mis-stated.
        error("Allam Cycle LOX resources are not supported in multi-stage cost " *
              "reporting: their fixed costs are not split into investment and " *
              "fixed O&M, so they cannot be rescaled per stage.")
    end
    factors = multistage ? inputs["MULTISTAGE_COST_FACTORS"] : nothing
    myopic = multistage && setup["MultiStageSettingsDict"]["Myopic"] == 1
    model_opexmult = multistage ? inputs["OPEXMULT"] : 1.0
    # Returns nothing for single-stage runs, which is how _accumulate_fixed!
    # knows to skip the investment/O&M split. In a multi-stage run a missing
    # component is not a reason to skip: it would drop that component from the
    # discounted and undiscounted views while leaving it in the model view, so
    # the file would look self-consistent and understate costs.
    function ann(key)
        multistage || return nothing
        haskey(factors.components, key) && return factors.components[key]
        error("Multi-stage cost factors have no '$key' component, so its " *
              "investment cannot be rescaled per stage. This means " *
              "stash_cost_reporting_factors! and the cost writer disagree " *
              "about which components exist.")
    end

    # --- Fixed costs -------------------------------------------------------
    # eTotalCFix is the sum of eCFix over all resources plus the Allam plant
    # term, so both are needed here to reproduce it.
    _accumulate_fixed!(acc, EP[:eCFix], 1:G,
        y -> fixed_om_cost_per_mwyr(gen[y]), EP[:eTotalCap],
        ann(:discharge), model_opexmult, myopic)
    !isempty(STOR_ALL) && _accumulate_fixed!(acc, EP[:eCFixEnergy], STOR_ALL,
        y -> fixed_om_cost_per_mwhyr(gen[y]), EP[:eTotalCapEnergy],
        ann(:energy), model_opexmult, myopic)
    !isempty(STOR_ASYMMETRIC) && _accumulate_fixed!(acc, EP[:eCFixCharge],
        STOR_ASYMMETRIC, y -> fixed_om_cost_charge_per_mwyr(gen[y]),
        EP[:eTotalCapCharge], ann(:charge), model_opexmult, myopic)
    if !isempty(ALLAM_CYCLE_LOX)
        # Allam is refused in multi-stage, so it never needs the split.
        _accumulate!(fix, EP[:eCFix_Allam_Plant], ALLAM_CYCLE_LOX)
    end

    # --- Variable costs ----------------------------------------------------
    _accumulate_over_time!(var, EP[:eCVar_out], 1:G)
    !isempty(STOR_ALL) && _accumulate_over_time!(var, EP[:eCVar_in], STOR_ALL)
    !isempty(FLEX) && _accumulate_over_time!(var, EP[:eCVarFlex_in], FLEX)
    if !isempty(ALLAM_CYCLE_LOX)
        _accumulate!(var, EP[:eCVar_Allam], ALLAM_CYCLE_LOX)
    end

    # Virtual charge/discharge penalties, present only when the capacity
    # reserve margin is active. These are in the objective but had no row of
    # their own, so they were missing from the reported breakdown entirely.
    for (sym, ids) in [(:eCVar_in_virtual, STOR_ALL), (:eCVar_out_virtual, STOR_ALL)]
        haskey(EP.obj_dict, sym) && !isempty(ids) &&
            _accumulate_over_time!(var, EP[sym], ids)
    end

    # --- Fuel --------------------------------------------------------------
    _accumulate_over_time!(fuel, EP[:ePlantCFuelOut], 1:G)

    # --- Start-up ----------------------------------------------------------
    # Start-up O&M is only defined for committed resources, but start-up *fuel*
    # (ePlantCFuelStart) is defined over all resources and that is what
    # eTotalCFuelStart sums. Accumulating it over 1:G rather than over the
    # commitment sets keeps this row equal to the objective's contribution even
    # if a resource outside those sets ever carries start fuel.
    if setup["UCommit"] >= 1
        !isempty(COMMIT) && _accumulate_over_time!(start, EP[:eCStart], COMMIT)
        if !isempty(ALLAM_CYCLE_LOX)
            _accumulate_over_time!(start, EP[:eCStart_Allam], ALLAM_CYCLE_LOX)
        end
        _accumulate_over_time!(start, EP[:ePlantCFuelStart], 1:G)
    end

    # --- CO2 sequestration -------------------------------------------------
    !isempty(CCS) && _accumulate!(co2, EP[:ePlantCCO2Sequestration], CCS)

    # --- Co-located VRE+storage -------------------------------------------
    # Each component carries its own fixed-cost and (where applicable) variable
    # O&M expression, indexed in the same resource-id space as everything else.
    if !isempty(VRE_STOR)
        vs = gen.VreStorage
        by_rid(y, sym) = by_rid_res(y, sym, vs)
        # (expression, id set, per-unit O&M field, capacity expression,
        #  annuity component). The O&M field and the annuity component differ
        #  per component, which is why this cannot be a single lookup.
        fix_components = [
            (:eCFixDC, "VS_DC", :fixed_om_inverter_cost_per_mwyr, :eTotalCap_DC, :dc),
            (:eCFixSolar, "VS_SOLAR", :fixed_om_solar_cost_per_mwyr,
                :eTotalCap_SOLAR, :solar),
            (:eCFixWind, "VS_WIND", :fixed_om_wind_cost_per_mwyr,
                :eTotalCap_WIND, :wind),
            (:eCFixElec, "VS_ELEC", :fixed_om_elec_cost_per_mwyr,
                :eTotalCap_ELEC, :elec),
            (:eCFixEnergy_VS, "VS_STOR", :fixed_om_cost_per_mwhyr,
                :eTotalCap_STOR, :stor_vs),
            (:eCFixCharge_DC, "VS_ASYM_DC_CHARGE", :fixed_om_cost_charge_dc_per_mwyr,
                :eTotalCapCharge_DC, :charge_dc),
            (:eCFixDischarge_DC, "VS_ASYM_DC_DISCHARGE",
                :fixed_om_cost_discharge_dc_per_mwyr, :eTotalCapDischarge_DC,
                :discharge_dc),
            (:eCFixCharge_AC, "VS_ASYM_AC_CHARGE", :fixed_om_cost_charge_ac_per_mwyr,
                :eTotalCapCharge_AC, :charge_ac),
            (:eCFixDischarge_AC, "VS_ASYM_AC_DISCHARGE",
                :fixed_om_cost_discharge_ac_per_mwyr, :eTotalCapDischarge_AC,
                :discharge_ac)
        ]
        for (sym, key, fom_field, cap_sym, ann_key) in fix_components
            ids = inputs[key]
            isempty(ids) || _accumulate_fixed!(acc, EP[sym], ids,
                y -> by_rid(y, fom_field), EP[cap_sym],
                ann(ann_key), model_opexmult, myopic)
        end

        # Note the set families differ, and mixing them up silently drops costs.
        # Fixed costs above are declared over VS_ASYM_*, since only asymmetric
        # resources have a separately sized charge or discharge capacity to pay
        # for. Variable O&M below is declared over the broader VS_STOR_* sets,
        # because every storage resource incurs it whether symmetric or not.
        var_components = [
            (:eCVarOutSolar, "VS_SOLAR"),
            (:eCVarOutWind, "VS_WIND"),
            (:eCVar_Charge_DC, "VS_STOR_DC_CHARGE"),
            (:eCVar_Discharge_DC, "VS_STOR_DC_DISCHARGE"),
            (:eCVar_Charge_AC, "VS_STOR_AC_CHARGE"),
            (:eCVar_Discharge_AC, "VS_STOR_AC_DISCHARGE")
        ]
        for (sym, key) in var_components
            ids = inputs[key]
            isempty(ids) || _accumulate_over_time!(var, EP[sym], ids)
        end

        # Co-located virtual charge/discharge, again only under a capacity
        # reserve margin. Declared over the same broad VS_STOR_* sets.
        virtual_components = [
            (:eCVar_Charge_DC_virtual, "VS_STOR_DC_CHARGE"),
            (:eCVar_Discharge_DC_virtual, "VS_STOR_DC_DISCHARGE"),
            (:eCVar_Charge_AC_virtual, "VS_STOR_AC_CHARGE"),
            (:eCVar_Discharge_AC_virtual, "VS_STOR_AC_DISCHARGE")
        ]
        for (sym, key) in virtual_components
            ids = inputs[key]
            haskey(EP.obj_dict, sym) && !isempty(ids) &&
                _accumulate_over_time!(var, EP[sym], ids)
        end

        # Grid connection is a memo row. For a co-located resource eCFix is
        # entirely the grid-connection cost, since every other component has its
        # own expression above, so the memo reads eCFix over VRE_STOR rather
        # than eCGrid. The two are the same wherever both are defined, except
        # that eCFix scales the investment term by Cap_Size for a resource in
        # CAP_SIZE_SCALED and eCGrid does not. Reading eCFix keeps the memo
        # equal to the cFix it is quoting in every configuration.
        _accumulate_fixed!(grid_acc, EP[:eCFix], VRE_STOR,
            y -> fixed_om_cost_per_mwyr(gen[y]), EP[:eTotalCap],
            ann(:discharge), model_opexmult, myopic)
    end

    # --- Hydrogen revenue (negative cost) ----------------------------------
    VS_ELEC = !isempty(VRE_STOR) ? inputs["VS_ELEC"] : Int[]
    ELECTROLYZER_ALL = !isempty(VS_ELEC) ? union(VS_ELEC, inputs["ELECTROLYZER"]) :
                       inputs["ELECTROLYZER"]
    if !isempty(ELECTROLYZER_ALL)
        for y in inputs["ELECTROLYZER"]
            h2[y] -= sum(value.(EP[:eHydrogenValue][y, :]))
        end
        for y in VS_ELEC
            h2[y] -= sum(value.(EP[:eHydrogenValue_vs][y, :]))
        end
    end

    # --- Non-served energy, by zone ---------------------------------------
    nse = [sum(value.(EP[:eCNSE][:, :, z])) for z in 1:Z]

    # --- System-wide terms with no resource attribution -------------------
    unmet_rsv = setup["OperationalReserves"] == 1 ? value(EP[:eTotalCRsvPen]) : 0.0

    # Network expansion is a pure investment cost, so it gets the same treatment
    # as the fixed-cost investment terms but per line rather than per resource.
    # Unlike those, this component is genuinely absent when network expansion is
    # off, so it is only looked up when the model has it; asking unconditionally
    # would trip the missing-component guard on every single-zone case.
    has_netexp = setup["NetworkExpansion"] == 1 && Z > 1
    netexp = has_netexp ? value(EP[:eTotalCNetworkExp]) : 0.0
    netexp_A, netexp_P = netexp, 0.0
    trans_ann = (multistage && has_netexp) ? ann(:transmission) : nothing
    if trans_ann !== nothing && netexp != 0.0
        # Rebuild eTotalCNetworkExp line by line, because each line carries its
        # own recovery period and cost of capital. EXPANSION_LINES (continuous
        # reinforcement) and DISCRETE_BUILD_LINES (whole new circuits) are
        # disjoint by construction, so both have to be walked.
        acc_A, acc_P = 0.0, 0.0
        pC = inputs["pC_Line_Reinforcement"]
        add_line! = function (l, cost)
            a, p = _investment_views(cost, trans_ann.annuity[l],
                trans_ann.payment_years[l], myopic)
            acc_A += a
            acc_P += p
        end
        for l in inputs["EXPANSION_LINES"]
            add_line!(l, value(EP[:vNEW_TRANS_CAP][l]) * pC[l])
        end
        if haskey(EP.obj_dict, :vNEW_TRANS_LINES)
            for l in get(inputs, "DISCRETE_BUILD_LINES", Int[])
                add_line!(l, value(EP[:vNEW_TRANS_LINES][l]) *
                             inputs["Line_Reinforcement_Cap_Size"][l] * pC[l])
            end
        end
        netexp_A, netexp_P = acc_A, acc_P
    end

    policy_penalty = 0.0
    for (key, sym) in [("dfCapRes_slack", :eCTotalCapResSlack),
        ("dfESR_slack", :eCTotalESRSlack),
        ("dfCO2Cap_slack", :eCTotalCO2CapSlack),
        ("MinCapPriceCap", :eTotalCMinCapSlack),
        ("MaxCapPriceCap", :eTotalCMaxCapSlack),
        ("H2DemandPriceCap", :eTotalCH2DemandSlack),
        ("dfHM_slack", :eCTotalHMSlack)]
        haskey(inputs, key) && (policy_penalty += value(EP[sym]))
    end
    # Three further penalties are gated on the model rather than on an inputs
    # key. vslack_term exists only when a retrofit cluster opts out of
    # contributing to the minimum retirement requirement. eObjSlack and
    # eObjSlackVreStor penalise long-duration storage slack; note these two
    # reach the objective via `EP[:eObj] += ...` rather than
    # `add_to_expression!`, so they do not show up when grepping for the latter.
    for sym in (:vslack_term, :eObjSlack, :eObjSlackVreStor)
        haskey(EP.obj_dict, sym) && (policy_penalty += value(EP[sym]))
    end

    return (fix = fix, var = var, fuel = fuel, start = start, co2 = co2, h2 = h2,
        grid = grid, nse = nse, unmet_rsv = unmet_rsv, netexp = netexp,
        policy_penalty = policy_penalty, obj = value(EP[:eObj]),
        electrolyzer_all = ELECTROLYZER_ALL,
        # Multi-stage views; zero-filled and unused for single-stage runs.
        fix_fom = acc.fix_fom, 
        fix_inv_A = acc.fix_inv_A,
        fix_inv_P = acc.fix_inv_P,
        grid_fom = grid_acc.fix_fom, 
        grid_inv_A = grid_acc.fix_inv_A,
        grid_inv_P = grid_acc.fix_inv_P,
        netexp_A = netexp_A, 
        netexp_P = netexp_P,
        multistage = multistage, 
        factors = factors)
end

@doc raw"""
    assemble_costs(bd::NamedTuple, inputs::Dict, setup::Dict; basis::Symbol = :model)

Turn a [`cost_breakdown`](@ref) into the `costs.csv` table: a `Costs` column of
row names, a `Total` column, and one column per zone.

`basis` selects how stage costs are expressed, and only applies to multi-stage
runs:

  * `:model` – the model's own values, used for single-stage runs
  * `:discounted` – present value at the start of the modeling horizon, which
    is what the objective function weighs
  * `:undiscounted` – cash flows over the stage, with no time value

Rows without a per-resource attribution (`cUnmetRsv`, `cNetworkExp`,
`cUnmetPolicyPenalty`) and the `cGridConnection` memo row are written as empty
cells in the zone columns, matching the system-wide nature of those terms.
Empty keeps the column numeric when read back, which a string placeholder
would not.

`ParameterScale` is applied once, to every numeric cell, at the end.
"""
function assemble_costs(bd::NamedTuple, inputs::Dict, setup::Dict;
        basis::Symbol = :model)
    gen = inputs["RESOURCES"]
    Z = inputs["Z"]
    VRE_STOR = inputs["VRE_STOR"]
    ELECTROLYZER_ALL = bd.electrolyzer_all

    # Scaling per view. Three families of cost scale differently:
    #
    #   investment  annuities, already summed over the payment years, need only
    #               discounting back to the start of the horizon
    #   fixed O&M   annual, so it needs the stage multiplier and the discount
    #   operating   annual, same treatment as fixed O&M
    #
    # Investment carries no operating multiplier: the years are already inside
    # the annuity vector (A payments discounted, or P payments undiscounted).
    use_model = basis == :model || !bd.multistage
    if use_model
        inv_vec, grid_inv, netexp_inv = bd.fix, bd.grid, bd.netexp
        inv_mult, fom_mult, opex_mult = 1.0, 0.0, 1.0
    elseif basis == :discounted
        df, om = bd.factors.discount_factor, bd.factors.opex_multiplier
        inv_vec, grid_inv, netexp_inv = bd.fix_inv_A, bd.grid_inv_A, bd.netexp_A
        inv_mult, fom_mult, opex_mult = df, df * om, df * om
    elseif basis == :undiscounted
        L = float(bd.factors.stage_length)
        inv_vec, grid_inv, netexp_inv = bd.fix_inv_P, bd.grid_inv_P, bd.netexp_P
        inv_mult, fom_mult, opex_mult = 1.0, L, L
    else
        error("unknown cost basis $basis")
    end

    # For the model view the fixed-cost vector already holds investment and O&M
    # combined, so the O&M multiplier is zero to avoid adding it twice.
    fix_v = inv_mult .* inv_vec .+ fom_mult .* bd.fix_fom
    grid_v = inv_mult .* grid_inv .+ fom_mult .* bd.grid_fom
    netexp_v = inv_mult * netexp_inv
    var_v, fuel_v = opex_mult .* bd.var, opex_mult .* bd.fuel
    start_v = opex_mult .* bd.start
    co2_v, h2_v = opex_mult .* bd.co2, opex_mult .* bd.h2
    nse_v = opex_mult .* bd.nse
    unmet_rsv_v = opex_mult * bd.unmet_rsv
    policy_v = opex_mult * bd.policy_penalty

    cost_list = ["cTotal", "cFix", "cVar", "cFuel", "cNSE", "cStart",
        "cUnmetRsv", "cNetworkExp", "cUnmetPolicyPenalty", "cCO2"]
    !isempty(VRE_STOR) && push!(cost_list, "cGridConnection")
    !isempty(ELECTROLYZER_ALL) && push!(cost_list, "cHydrogenRevenue")

    # Single-stage quotes the objective. It now equals the row sum, so this
    # keeps cTotal an independent check on the rows rather than a restatement
    # of them, and leaves the output identical to earlier releases. The
    # multi-stage views rescale investment and operating rows by different
    # factors, so eObj is not in their units; their total is the row sum, which
    # comes out equal to objective_value - vALPHA.
    row_sum = sum(fix_v) + sum(var_v) + sum(fuel_v) + sum(nse_v) + sum(start_v) +
              unmet_rsv_v + netexp_v + policy_v + sum(co2_v) + sum(h2_v)
    total = Any[use_model ? bd.obj : row_sum,
        sum(fix_v),
        sum(var_v),
        sum(fuel_v),
        sum(nse_v),
        sum(start_v),
        unmet_rsv_v,
        netexp_v,
        policy_v,
        sum(co2_v)]
    !isempty(VRE_STOR) && push!(total, sum(grid_v))
    !isempty(ELECTROLYZER_ALL) && push!(total, sum(h2_v))

    dfCost = DataFrame(Costs = cost_list, Total = total)

    for z in 1:Z
        ids = resources_in_zone_by_rid(gen, z)
        zsum(v) = isempty(ids) ? 0.0 : sum(v[ids])

        zone_fix = zsum(fix_v)
        zone_var = zsum(var_v)
        zone_fuel = zsum(fuel_v)
        zone_start = zsum(start_v)
        zone_co2 = zsum(co2_v)
        zone_h2 = zsum(h2_v)
        zone_nse = nse_v[z]

        zone_total = zone_fix + zone_var + zone_fuel + zone_start +
                     zone_co2 + zone_h2 + zone_nse

        # cUnmetRsv, cNetworkExp and cUnmetPolicyPenalty are system-wide and have
        # no zonal value, as is the cGridConnection memo. `missing` writes an
        # empty cell, which keeps the column numeric when read back; a string
        # placeholder would turn the whole column into text.
        col = Any[zone_total, zone_fix, zone_var, zone_fuel, zone_nse,
            zone_start, missing, missing, missing, zone_co2]
        !isempty(VRE_STOR) && push!(col, missing)
        !isempty(ELECTROLYZER_ALL) && push!(col, zone_h2)

        dfCost[!, Symbol("Zone$z")] = col
    end

    if setup["ParameterScale"] == 1
        for col in names(dfCost)[2:end]
            dfCost[!, col] = map(dfCost[!, col]) do v
                v isa Real ? v * ModelScalingFactor^2 : v
            end
        end
    end

    return dfCost
end

@doc raw"""
	write_costs(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing the costs pertaining to the objective function (fixed, variable O&M etc.).
"""
function write_costs(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    bd = cost_breakdown(EP, inputs, setup)
    if bd.multistage
        # Two views of the same stage. costs.csv is what the objective weighs;
        # the companion file is the cash flow over the stage, with no time
        # value. See [`assemble_costs`](@ref).
        CSV.write(joinpath(path, "costs.csv"),
            assemble_costs(bd, inputs, setup; basis = :discounted))
        CSV.write(joinpath(path, "costs_undiscounted.csv"),
            assemble_costs(bd, inputs, setup; basis = :undiscounted))
    else
        CSV.write(joinpath(path, "costs.csv"),
            assemble_costs(bd, inputs, setup; basis = :model))
    end
end
