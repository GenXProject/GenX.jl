@doc raw"""
	configure_solver(solver::String, solver_settings_path::String)

This method returns a solver-specific MathOptInterface OptimizerWithAttributes optimizer instance to be used in the GenX.generate\_model() method.

The "solver" argument is a string which specifies the solver to be used. It is not case sensitive.
Currently supported solvers include: "Gurobi", "CPLEX", "Clp", "Cbc", or "SCIP"

The "solver\_settings\_path" argument is a string which specifies the path to the directory that contains the settings YAML file for the specified solver.

"""
function configure_solver(solver::String, solver_settings_path::String)

    solver = lowercase(solver)

    path = joinpath(solver_settings_path, solver*"_settings.yml")

    configure_functions = Dict(
                               "highs" => configure_highs,
                               "gurobi" => configure_gurobi,
                               "cplex" => configure_cplex,
                               "clp" => configure_clp,
                               "cbc" => configure_cbc,
                               "scip" => configure_scip,
                              )

    return configure_functions[solver](path)
end

@doc raw"""
    rename_keys(attributes:Dict, new_key_names::Dict)

Renames the keys of the `attributes` dictionary based on old->new pairs in the new_key_names dictionary.

"""
function rename_keys(attributes::Dict, new_key_names::Dict)
    updated_attributes = typeof(attributes)()
    for (old_key, value) in attributes
        if ~haskey(new_key_names, old_key)
            new_key = old_key
        else
            new_key = new_key_names[old_key]
            if haskey(attributes, new_key)
                @error "Colliding keys: '$old_key' needs to be renamed to '$new_key' but '$new_key' already exists in", attributes
            end
        end
        updated_attributes[new_key] = value
    end
    return updated_attributes
end
