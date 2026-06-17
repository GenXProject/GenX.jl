@doc raw"""
	write_planning_problem_costs(path, inputs, setup, benders_results, planning_problem)

Write fixed and network expansion costs from the Benders planning problem to `planning_problem_costs.csv`.

Evaluates all cost expressions against the best Benders planning solution stored in
`benders_results.planning_sol` (no re-solve required) and writes a cost table with rows
for total cost (`cTotal`), total fixed cost (`cFix`), network expansion cost
(`cNetworkExp`), and unmet planning policy penalty (`cUnmetPlanningPolicyPenalty`).
Per-zone fixed costs are appended as additional columns when multiple zones exist.
"""
function write_planning_problem_costs(path::AbstractString, inputs::Dict, setup::Dict, benders_results::NamedTuple, planning_problem::Model)
    gen = inputs["RESOURCES"]
    Z = inputs["Z"]

    # Build a value-lookup function from the best Benders planning solution.
    # JuMP's value(f, expr) evaluates a linear expression by calling f on each
    # variable — no re-solve of the model is needed.
    planning_sol = benders_results.planning_sol
    var_vals = planning_sol.values  # Dict{String, Float64}
    val_fn = var -> get(var_vals, name(var), 0.0)
    EP = planning_problem

    cost_list = [
        "cTotal",
        "cFix",
        "cNetworkExp",
        "cUnmetPlanningPolicyPenalty",
    ]

    dfCost = DataFrame(Costs = cost_list)

    cTotal = value(val_fn, EP[:eObj])

    cFix = value(val_fn, EP[:eTotalCFix]) +
           (!isempty(inputs["STOR_ALL"]) && haskey(EP.obj_dict, :eTotalCFixEnergy) ? value(val_fn, EP[:eTotalCFixEnergy]) : 0.0) +
           (!isempty(inputs["STOR_ASYMMETRIC"]) && haskey(EP.obj_dict, :eTotalCFixCharge) ? value(val_fn, EP[:eTotalCFixCharge]) : 0.0)

    total_cost = [
        cTotal,
        cFix,
        0.0,
        0.0,
    ]

    dfCost[!, :Total] = total_cost

    if setup["ParameterScale"] == 1
        dfCost.Total .*= ModelScalingFactor^2
    end

    if setup["NetworkExpansion"] == 1 && Z > 1 && haskey(EP.obj_dict, :eTotalCNetworkExp)
        network_exp = value(val_fn, EP[:eTotalCNetworkExp])
        dfCost[3, 2] = setup["ParameterScale"] == 1 ? network_exp * ModelScalingFactor^2 : network_exp
    end

    if haskey(inputs, "MinCapPriceCap") && haskey(EP.obj_dict, :eTotalCMinCapSlack)
        slack = value(val_fn, EP[:eTotalCMinCapSlack])
        dfCost[4, 2] += setup["ParameterScale"] == 1 ? slack * ModelScalingFactor^2 : slack
    end

    if haskey(inputs, "MaxCapPriceCap") && haskey(EP.obj_dict, :eTotalCMaxCapSlack)
        slack = value(val_fn, EP[:eTotalCMaxCapSlack])
        dfCost[4, 2] += setup["ParameterScale"] == 1 ? slack * ModelScalingFactor^2 : slack
    end

    for z in 1:Z
        tempCFix = 0.0

        Y_ZONE = resources_in_zone_by_rid(gen, z)
        STOR_ALL_ZONE = intersect(inputs["STOR_ALL"], Y_ZONE)
        STOR_ASYMMETRIC_ZONE = intersect(inputs["STOR_ASYMMETRIC"], Y_ZONE)

        # println("TESTING 0 ")
        # println(Y_ZONE)
        # println(val_fn)
        # println(EP[:eCFix])
        # for y in Y_ZONE
        #     println("TESTING 0.1 ")
        #     println(y)
        #     println(EP[:eCFix][y])
        # end
        tempCFix += sum(value.(val_fn, EP[:eCFix][y]) for y in Y_ZONE; init = 0.0)

        if !isempty(STOR_ALL_ZONE) && haskey(EP.obj_dict, :eCFixEnergy)
            # println("TESTING 1 ")
            # println(sum(value.(val_fn, EP[:eCFixEnergy][y]) for y in STOR_ALL_ZONE))
            tempCFix += sum(value.(val_fn, EP[:eCFixEnergy][y]) for y in STOR_ALL_ZONE; init = 0.0)
        end
        if !isempty(STOR_ASYMMETRIC_ZONE) && haskey(EP.obj_dict, :eCFixCharge)
            # println("TESTING 2 ")
            # println(sum(value.(val_fn, EP[:eCFixCharge][y]) for y in STOR_ASYMMETRIC_ZONE))
            tempCFix += sum(value.(val_fn, EP[:eCFixCharge][y]) for y in STOR_ASYMMETRIC_ZONE; init = 0.0)
        end

        if setup["ParameterScale"] == 1
            tempCFix *= ModelScalingFactor^2
        end

        dfCost[!, Symbol("Zone$z")] = ["-", tempCFix, "-", "-"]
    end

    CSV.write(joinpath(path, "planning_problem_costs.csv"), dfCost)
end