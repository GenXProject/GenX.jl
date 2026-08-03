@doc raw"""
	write_planning_problem_costs(path, inputs, setup, benders_results, planning_problem, benders_bundle=nothing)

Write the Benders cost breakdown to `planning_problem_costs.csv`.

First-stage (planning) costs — total fixed cost (`cFix`), network expansion cost
(`cNetworkExp`), and unmet planning policy penalty (`cUnmetPlanningPolicyPenalty`) — are
evaluated against the best Benders planning solution stored in `benders_results.planning_sol`
(no re-solve required, so they are valid even when the master model holds no solver values).

When `benders_bundle` is supplied, the operational (second-stage) costs aggregated from the
solved subproblems are added as additional rows, mirroring the monolithic `write_costs`:
variable O&M (`cVar`), fuel (`cFuel`), non-served energy (`cNSE`), and startup (`cStart`,
non-fuel startup O&M plus startup fuel). In that case `cTotal` is the actual cost of the
incumbent design (fixed + network + operational), which equals the Benders upper bound. When
`benders_bundle` is `nothing` (e.g. the no-values early-return path) only the first-stage rows
are written and `cTotal` is taken from the master objective `value(eObj)`.

Per-zone columns (`Zone1 … ZoneZ`) are appended when multiple zones exist. Fixed costs are
always broken out by zone; with a bundle the operational costs are too (matching the monolithic
per-zone layout). System-wide rows without a per-resource attribution — `cNetworkExp` and
`cUnmetPlanningPolicyPenalty` — are written as `"-"` in each zone column.
"""
function write_planning_problem_costs(path::AbstractString, inputs::Dict, setup::Dict, benders_results::NamedTuple, planning_problem::Model, benders_bundle=nothing)
    gen = inputs["RESOURCES"]
    Z = inputs["Z"]

    # Build a value-lookup function from the best Benders planning solution.
    # JuMP's value(f, expr) evaluates a linear expression by calling f on each
    # variable — no re-solve of the model is needed.
    planning_sol = benders_results.planning_sol
    var_vals = planning_sol.values  # Dict{String, Float64}
    val_fn = var -> get(var_vals, name(var), 0.0)
    EP = planning_problem

    scale2 = setup["ParameterScale"] == 1 ? ModelScalingFactor^2 : 1.0

    # ---- First-stage (planning) costs, evaluated at the incumbent planning solution ----
    cFix = value(val_fn, EP[:eTotalCFix]) +
           (!isempty(inputs["STOR_ALL"]) && haskey(EP.obj_dict, :eTotalCFixEnergy) ? value(val_fn, EP[:eTotalCFixEnergy]) : 0.0) +
           (!isempty(inputs["STOR_ASYMMETRIC"]) && haskey(EP.obj_dict, :eTotalCFixCharge) ? value(val_fn, EP[:eTotalCFixCharge]) : 0.0)

    cNetworkExp = (setup["NetworkExpansion"] == 1 && Z > 1 && haskey(EP.obj_dict, :eTotalCNetworkExp)) ?
                  value(val_fn, EP[:eTotalCNetworkExp]) : 0.0

    cUnmetPolicy = 0.0
    if haskey(inputs, "MinCapPriceCap") && haskey(EP.obj_dict, :eTotalCMinCapSlack)
        cUnmetPolicy += value(val_fn, EP[:eTotalCMinCapSlack])
    end
    if haskey(inputs, "MaxCapPriceCap") && haskey(EP.obj_dict, :eTotalCMaxCapSlack)
        cUnmetPolicy += value(val_fn, EP[:eTotalCMaxCapSlack])
    end

    # Per-zone fixed cost from the incumbent planning solution (raw model units).
    cfix_zone = zeros(Z)
    for z in 1:Z
        Y_ZONE = resources_in_zone_by_rid(gen, z)
        STOR_ALL_ZONE = intersect(inputs["STOR_ALL"], Y_ZONE)
        STOR_ASYMMETRIC_ZONE = intersect(inputs["STOR_ASYMMETRIC"], Y_ZONE)

        c = sum(value.(val_fn, EP[:eCFix][y]) for y in Y_ZONE; init = 0.0)
        if !isempty(STOR_ALL_ZONE) && haskey(EP.obj_dict, :eCFixEnergy)
            c += sum(value.(val_fn, EP[:eCFixEnergy][y]) for y in STOR_ALL_ZONE; init = 0.0)
        end
        if !isempty(STOR_ASYMMETRIC_ZONE) && haskey(EP.obj_dict, :eCFixCharge)
            c += sum(value.(val_fn, EP[:eCFixCharge][y]) for y in STOR_ASYMMETRIC_ZONE; init = 0.0)
        end
        cfix_zone[z] = c
    end

    if benders_bundle === nothing
        # No operational bundle available (e.g. master has no solver values): first-stage costs
        # only. cTotal comes from the master objective, which folds operational cost into vTHETA.
        cost_list = ["cTotal", "cFix", "cNetworkExp", "cUnmetPlanningPolicyPenalty"]
        cTotal = value(val_fn, EP[:eObj])
        total_cost = [cTotal, cFix, cNetworkExp, cUnmetPolicy] .* scale2
        dfCost = DataFrame(Costs = cost_list, Total = total_cost)
        for z in 1:Z
            dfCost[!, Symbol("Zone$z")] = ["-", cfix_zone[z] * scale2, "-", "-"]
        end
        CSV.write(joinpath(path, "planning_problem_costs.csv"), dfCost)
        return nothing
    end

    # ---- Operational (second-stage) costs, aggregated per zone from the subproblems ----
    # Fuel is aggregated to zones here from the per-plant vectors; startup fuel is folded into
    # cStart (matching the monolithic decomposition). Non-fuel startup O&M is in start_om_cost_zone.
    cvar_zone = collect(benders_bundle.var_om_cost_zone)
    cnse_zone = collect(benders_bundle.nse_cost_zone)
    cfuel_zone = zeros(Z)
    cstart_zone = zeros(Z)
    for z in 1:Z
        Y_ZONE = resources_in_zone_by_rid(gen, z)
        cfuel_zone[z] = sum(benders_bundle.fuel_cost_out[Y_ZONE]; init = 0.0)
        cstart_zone[z] = benders_bundle.start_om_cost_zone[z] + sum(benders_bundle.fuel_cost_start[Y_ZONE]; init = 0.0)
    end
    ctotal_zone = cfix_zone .+ cvar_zone .+ cfuel_zone .+ cnse_zone .+ cstart_zone

    # System-wide operational totals (sum over zones so the columns reconcile with Total).
    cVar = sum(cvar_zone)
    cFuel = sum(cfuel_zone)
    cNSE = sum(cnse_zone)
    cStart = sum(cstart_zone)

    # Actual total cost of the incumbent design = fixed + network + operational. This equals the
    # Benders upper bound; it differs from the master objective value(eObj), which uses the
    # vTHETA lower-bound approximation of operational cost.
    cTotal = cFix + cVar + cFuel + cNSE + cStart + cNetworkExp + cUnmetPolicy

    cost_list = ["cTotal", "cFix", "cVar", "cFuel", "cNSE", "cStart", "cNetworkExp", "cUnmetPlanningPolicyPenalty"]
    total_cost = [cTotal, cFix, cVar, cFuel, cNSE, cStart, cNetworkExp, cUnmetPolicy] .* scale2
    dfCost = DataFrame(Costs = cost_list, Total = total_cost)

    for z in 1:Z
        dfCost[!, Symbol("Zone$z")] = [
            ctotal_zone[z] * scale2,
            cfix_zone[z] * scale2,
            cvar_zone[z] * scale2,
            cfuel_zone[z] * scale2,
            cnse_zone[z] * scale2,
            cstart_zone[z] * scale2,
            "-",
            "-",
        ]
    end

    CSV.write(joinpath(path, "planning_problem_costs.csv"), dfCost)
    return nothing
end
