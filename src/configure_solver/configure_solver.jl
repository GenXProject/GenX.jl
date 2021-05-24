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
        OPTIMIZER = configure_cplex(clp_settings_path)
	end

	return OPTIMIZER
end