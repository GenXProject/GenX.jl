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
	configure_solver(solver::String, solver_settings_path::String)

This method returns a solver-specific MathOptInterface OptimizerWithAttributes optimizer instance to be used in the GenX.generate_model() method.

The "solver" argument is a string which specifies the solver to be used, and can be either "Gurobi", "CPLEX", "Clp", "Cbc", "GLPK", or "Ipopt".

The "solver_settings_path" argument is a string which specifies the path to the directory that contains the settings YAML file for the specified solver.

"""
function configure_solver(solver::String, solver_settings_path::String)

	# Set solver as Gurobi
	if solver == "Gurobi"
		gurobi_settings_path = joinpath(solver_settings_path, "gurobi_settings.yml")
        OPTIMIZER = configure_gurobi(gurobi_settings_path)
	# Set solver as CPLEX
	elseif solver == "CPLEX"
		cplex_settings_path = joinpath(solver_settings_path, "cplex_settings.yml")
        OPTIMIZER = configure_cplex(cplex_settings_path)
	elseif solver == "Clp"
		clp_settings_path = joinpath(solver_settings_path, "clp_settings.yml")
        OPTIMIZER = configure_clp(clp_settings_path)
	elseif solver == "Cbc"
		cbc_settings_path = joinpath(solver_settings_path, "cbc_settings.yml")
        OPTIMIZER = configure_cbc(cbc_settings_path)
	#=elseif solver == "GLPK"
		glpk_settings_path = joinpath(solver_settings_path, "glpk_settings.yml")
        OPTIMIZER = configure_glpk(glpk_settings_path)
	elseif solver == "Ipopt"
		ipopt_settings_path = joinpath(solver_settings_path, "ipopt_settings.yml")
        OPTIMIZER = configure_ipopt(ipopt_settings_path)=#
	end

	return OPTIMIZER
end
