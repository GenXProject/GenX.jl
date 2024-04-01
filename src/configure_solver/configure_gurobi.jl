@doc raw"""
	configure_gurobi(solver_settings_path::String)

Reads user-specified solver settings from gurobi\_settings.yml in the directory specified by the string solver\_settings\_path.

Returns a `MathOptInterface.OptimizerWithAttributes` Gurobi optimizer instance to be used in the `GenX.generate_model()` method.

The Gurobi optimizer instance is configured with the following default parameters if a user-specified parameter for each respective field is not provided:

 - FeasibilityTol = 1e-6 (Constraint (primal) feasibility tolerances. See https://www.gurobi.com/documentation/8.1/refman/feasibilitytol.html)
 - OptimalityTol = 1e-4 (Dual feasibility tolerances. See https://www.gurobi.com/documentation/8.1/refman/optimalitytol.html#parameter:OptimalityTol)
 - Presolve = -1 (Controls presolve level. See https://www.gurobi.com/documentation/8.1/refman/presolve.html)
 - AggFill = -1 (Allowed fill during presolve aggregation. See https://www.gurobi.com/documentation/8.1/refman/aggfill.html#parameter:AggFill)
 - PreDual = -1 (Presolve dualization. See https://www.gurobi.com/documentation/8.1/refman/predual.html#parameter:PreDual)
 - TimeLimit = Inf	(Limits total time solver. See https://www.gurobi.com/documentation/8.1/refman/timelimit.html)
 - MIPGap = 1e-4 (Relative (p.u. of optimal) mixed integer optimality tolerance for MIP problems (ignored otherwise). See https://www.gurobi.com/documentation/8.1/refman/mipgap2.html)
 - Crossover = -1 (Barrier crossver strategy. See https://www.gurobi.com/documentation/8.1/refman/crossover.html#parameter:Crossover)
 - Method = -1	(Algorithm used to solve continuous models (including MIP root relaxation). See https://www.gurobi.com/documentation/8.1/refman/method.html)
 - BarConvTol = 1e-8 (Barrier convergence tolerance (determines when barrier terminates). See https://www.gurobi.com/documentation/8.1/refman/barconvtol.html)
 - NumericFocus = 0 (Numerical precision emphasis. See https://www.gurobi.com/documentation/8.1/refman/numericfocus.html)

"""
function configure_gurobi(solver_settings_path::String, optimizer::Any)
    solver_settings = YAML.load(open(solver_settings_path))
    solver_settings = convert(Dict{String, Any}, solver_settings)

    default_settings = Dict("Feasib_Tol" => 1e-6,
        "Optimal_Tol" => 1e-4,
        "Pre_Solve" => -1,
        "AggFill" => -1,
        "PreDual" => -1,
        "TimeLimit" => Inf,
        "MIPGap" => 1e-3,
        "Crossover" => -1,
        "Method" => -1,
        "BarConvTol" => 1e-8,
        "NumericFocus" => 0,
        "OutputFlag" => 1)

    attributes = merge(default_settings, solver_settings)

    key_replacement = Dict("Feasib_Tol" => "FeasibilityTol",
        "Optimal_Tol" => "OptimalityTol",
        "Pre_Solve" => "Presolve")

    attributes = rename_keys(attributes, key_replacement)

    attributes::Dict{String, Any}
    return optimizer_with_attributes(optimizer, attributes...)
end
