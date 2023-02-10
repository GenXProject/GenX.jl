@doc raw"""
	configure_solver(solver::String, solver_settings_path::String)

This method returns a solver-specific MathOptInterface OptimizerWithAttributes optimizer instance to be used in the GenX.generate\_model() method.

The "solver" argument is a string which specifies the solver to be used. It is not case sensitive.
Currently supported solvers include: "Gurobi", "CPLEX", "Clp", "Cbc", or "SCIP"

The "solver\_settings\_path" argument is a string which specifies the path to the directory that contains the settings YAML file for the specified solver.

"""
function configure_solver(solver::String, solver_settings_path::String)

	solver = lowercase(solver)

	# Set solver as HiGHS
	if solver == "highs"
		highs_settings_path = joinpath(solver_settings_path, "highs_settings.yml")
        	OPTIMIZER = configure_highs(highs_settings_path)
	# Set solver as Gurobi
	elseif solver == "gurobi"
		gurobi_settings_path = joinpath(solver_settings_path, "gurobi_settings.yml")
        	OPTIMIZER = configure_gurobi(gurobi_settings_path)
	# Set solver as CPLEX
	elseif solver == "cplex"
		cplex_settings_path = joinpath(solver_settings_path, "cplex_settings.yml")
        	OPTIMIZER = configure_cplex(cplex_settings_path)
	# Set solver as Clp
	elseif solver == "clp"
		clp_settings_path = joinpath(solver_settings_path, "clp_settings.yml")
        	OPTIMIZER = configure_clp(clp_settings_path)
	# Set solver as Cbc
	elseif solver == "cbc"
		cbc_settings_path = joinpath(solver_settings_path, "cbc_settings.yml")
        	OPTIMIZER = configure_cbc(cbc_settings_path)
	# Set solver as SCIP
	elseif solver == "scip"
		scip_settings_path = joinpath(solver_settings_path, "scip_settings.yml")
		OPTIMIZER = configure_scip(scip_settings_path)
	end

	return OPTIMIZER
end
