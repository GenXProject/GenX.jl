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
    infer_solver(optimizer::Any)
Return the name (`String`) of the solver to be used in the GenX.configure\_solver method according to the solver imported by the user. 
"""
function infer_solver(optimizer::Any)
    return lowercase(string(parentmodule(optimizer)))
end


@doc raw"""
	configure_solver(solver_settings_path::String, optimizer::Any)

This method returns a solver-specific MathOptInterface OptimizerWithAttributes optimizer instance to be used in the GenX.generate\_model() method.

The "solver" argument is a string which specifies the solver to be used. It is not case sensitive.
Currently supported solvers include: "Gurobi", "CPLEX", "Clp", "Cbc", or "SCIP"

The "solver\_settings\_path" argument is a string which specifies the path to the directory that contains the settings YAML file for the specified solver.

"""
function configure_solver(solver_settings_path::String, optimizer::Any)
    solver_name = infer_solver(optimizer)
    path = joinpath(solver_settings_path, solver_name * "_settings.yml")

    configure_functions = Dict(
        "highs" => configure_highs,
        "gurobi" => configure_gurobi,
        "cplex" => configure_cplex,
        "clp" => configure_clp,
        "cbc" => configure_cbc,
        "scip" => configure_scip,
    )
    
    return configure_functions[solver_name](path, optimizer)
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
