@doc raw"""
	configure_clp(solver_settings_path::String)

Reads user-specified solver settings from clp\_settings.yml in the directory specified by the string solver\_settings\_path.

Returns a `MathOptInterface.OptimizerWithAttributes` Clp optimizer instance to be used in the `GenX.generate_model()` method.

The Clp optimizer instance is configured with the following default parameters if a user-specified parameter for each respective field is not provided:

 - PrimalTolerance = 1e-7 (Primal feasibility tolerance)
 - DualTolerance = 1e-7 (Dual feasibility tolerance)
 - DualObjectiveLimit = 1e308 (When using dual simplex (where the objective is monotonically changing), terminate when the objective exceeds this limit)
 - MaximumIterations = 2147483647 (Terminate after performing this number of simplex iterations)
 - MaximumSeconds = -1.0	(Terminate after this many seconds have passed. A negative value means no time limit)
 - LogLevel = 1 (Set to 1, 2, 3, or 4 for increasing output. Set to 0 to disable output)
 - PresolveType = 0 (Set to 1 to disable presolve)
 - SolveType = 5 (Solution method: dual simplex (0), primal simplex (1), sprint (2), barrier with crossover (3), barrier without crossover (4), automatic (5))
 - InfeasibleReturn = 0 (Set to 1 to return as soon as the problem is found to be infeasible (by default, an infeasibility proof is computed as well))
 - Scaling = 3 (0 0ff, 1 equilibrium, 2 geometric, 3 auto, 4 dynamic (later))
 - Perturbation = 100 (switch on perturbation (50), automatic (100), don't try perturbing (102))

"""
function configure_clp(solver_settings_path::String, optimizer::Any)
    solver_settings = YAML.load(open(solver_settings_path))
    solver_settings = convert(Dict{String, Any}, solver_settings)

    default_settings = Dict{String, Any}("Feasib_Tol" => 1e-7,
        "DualObjectiveLimit" => 1e308,
        "MaximumIterations" => 2147483647,
        "TimeLimit" => -1.0,
        "LogLevel" => 1,
        "Pre_Solve" => 0,
        "Method" => 5,
        "InfeasibleReturn" => 0,
        "Scaling" => 3,
        "Perturbation" => 100)

    attributes = merge(default_settings, solver_settings)

    key_replacement = Dict("Feasib_Tol" => "PrimalTolerance",
        "TimeLimit" => "MaximumSeconds",
        "Pre_Solve" => "PresolveType",
        "Method" => "SolveType")

    attributes = rename_keys(attributes, key_replacement)

    # TODO this is done to preserve the behavior that Feasib_Tol was used to set both Primal and
    # Dual tolerances. It should probably be fixed.
    attributes["DualTolerance"] = attributes["PrimalTolerance"]

    attributes::Dict{String, Any}
    return optimizer_with_attributes(optimizer, attributes...)
end
