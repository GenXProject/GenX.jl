function configure_gurobi(solver_settings_path::String)

	solver_settings = YAML.load(open(solver_settings_path))

	# Optional solver parameters ############################################
	MyFeasibilityTol = 1e-6 # Constraint (primal) feasibility tolerances. See https://www.gurobi.com/documentation/8.1/refman/feasibilitytol.html
		if(haskey(solver_settings, "Feasib_Tol")) MyFeasibilityTol = solver_settings["Feasib_Tol"] end
	MyOptimalityTol = 1e-6 # Dual feasibility tolerances. See https://www.gurobi.com/documentation/8.1/refman/optimalitytol.html#parameter:OptimalityTol
		if(haskey(solver_settings, "Optimal_Tol")) MyOptimalityTol = solver_settings["Optimal_Tol"] end
	MyPresolve = -1 	# Controls presolve level. See https://www.gurobi.com/documentation/8.1/refman/presolve.html
		if(haskey(solver_settings, "Pre_Solve")) MyPresolve = solver_settings["Pre_Solve"] end
	MyAggFill = -1 		# Allowed fill during presolve aggregation. See https://www.gurobi.com/documentation/8.1/refman/aggfill.html#parameter:AggFill
		if(haskey(solver_settings, "AggFill")) MyAggFill = solver_settings["AggFill"] end
	MyPreDual = -1		# Presolve dualization. See https://www.gurobi.com/documentation/8.1/refman/predual.html#parameter:PreDual
		if(haskey(solver_settings, "PreDual")) MyPreDual = solver_settings["PreDual"] end
	MyTimeLimit = Inf	# Limits total time solver. See https://www.gurobi.com/documentation/8.1/refman/timelimit.html
		if(haskey(solver_settings, "TimeLimit")) MyTimeLimit = solver_settings["TimeLimit"] end
	MyMIPGap = 1e-4		# Relative (p.u. of optimal) mixed integer optimality tolerance for MIP problems (ignored otherwise). See https://www.gurobi.com/documentation/8.1/refman/mipgap2.html
		if(haskey(solver_settings, "MIPGap")) MyMIPGap = solver_settings["MIPGap"] end
	MyCrossover = -1 	# Barrier crossver strategy. See https://www.gurobi.com/documentation/8.1/refman/crossover.html#parameter:Crossover
		if(haskey(solver_settings, "Crossover")) MyCrossover = solver_settings["Crossover"] end
	MyMethod = -1		# Algorithm used to solve continuous models (including MIP root relaxation). See https://www.gurobi.com/documentation/8.1/refman/method.html
		if(haskey(solver_settings, "Method")) MyMethod = solver_settings["Method"] end
	MyBarConvTol = 1e-8 	# Barrier convergence tolerance (determines when barrier terminates). See https://www.gurobi.com/documentation/8.1/refman/barconvtol.html
		if(haskey(solver_settings, "BarConvTol")) MyBarConvTol = solver_settings["BarConvTol"] end
	MyNumericFocus = 0 	# Numerical precision emphasis. See https://www.gurobi.com/documentation/8.1/refman/numericfocus.html
		if(haskey(solver_settings, "NumericFocus")) MyNumericFocus = solver_settings["NumericFocus"] end
	########################################################################

	OPTIMIZER = optimizer_with_attributes(Gurobi.Optimizer, 
		"OptimalityTol" => MyOptimalityTol,
		"FeasibilityTol" => MyFeasibilityTol,
		"Presolve" => MyPresolve,
		"AggFill" => MyAggFill,
		"PreDual" => MyPreDual,
		"TimeLimit" => MyTimeLimit,
		"MIPGap" => MyMIPGap,
		"Method" => MyMethod,
		"BarConvTol" => MyBarConvTol,
		"NumericFocus" => MyNumericFocus
	)

	return OPTIMIZER
end