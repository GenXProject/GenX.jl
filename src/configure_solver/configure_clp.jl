function configure_clp(solver_settings_path::String)

	solver_settings = YAML.load(open(solver_settings_path))

	# Optional solver parameters ############################################
        MyPrimalTolerance = 1e-7	#Primal feasibility tolerance
            if(haskey(solver_settings, "PrimalTolerance")) MyPrimalTolerance = solver_settings["PrimalTolerance"] end
        MyDualTolerance = 1e-7	#Dual feasibility tolerance
            if(haskey(solver_settings, "DualTolerance ")) MyDualTolerance = solver_settings["DualTolerance"] end
        MyDualObjectiveLimit = 1e308	#When using dual simplex (where the objective is monotonically changing), terminate when the objective exceeds this limit
            if(haskey(solver_settings, "DualObjectiveLimit")) MyDualObjectiveLimit = solver_settings["DualObjectiveLimit"] end
        MyMaximumIterations = 2147483647	#Terminate after performing this number of simplex iterations
            if(haskey(solver_settings, "MaximumIterations")) MyMaximumIterations = solver_settings["MaximumIterations"] end
        MyMaximumSeconds = -1.0	#Terminate after this many seconds have passed. A negative value means no time limit
            if(haskey(solver_settings, "MaximumSeconds")) MyMaximumSeconds = solver_settings["MaximumSeconds"] end
        MyLogLevel = 1	#Set to 1, 2, 3, or 4 for increasing output. Set to 0 to disable output
            if(haskey(solver_settings, "LogLevel")) MyLogLevel = solver_settings["LogLevel"] end
        MyPresolveType = 0	#Set to 1 to disable presolve
            if(haskey(solver_settings, "PresolveType")) MyPresolveType = solver_settings["PresolveType"] end
        MySolveType = 5	#Solution method: dual simplex (0), primal simplex (1), sprint (2), barrier with crossover (3), barrier without crossover (4), automatic (5)
            if(haskey(solver_settings, "SolveType")) MySolveType = solver_settings["SolveType"] end
        MyInfeasibleReturn = 0	#Set to 1 to return as soon as the problem is found to be infeasible (by default, an infeasibility proof is computed as well)
            if(haskey(solver_settings, "InfeasibleReturn")) MyInfeasibleReturn = solver_settings["InfeasibleReturn"] end
        MyScaling = 3	#0 -off, 1 equilibrium, 2 geometric, 3 auto, 4 dynamic(later)
            if(haskey(solver_settings, "Scaling")) MyScaling = solver_settings["Scaling"] end
        MyPerturbation = 100	#switch on perturbation (50), automatic (100), don't try perturbing (102)
            if(haskey(solver_settings, "Perturbation")) MyPerturbation = solver_settings["Perturbation"] end
	########################################################################

	OPTIMIZER = optimizer_with_attributes(Clp.Optimizer,
        "PrimalTolerance" => MyPrimalTolerance,
        "DualTolerance" => MyDualTolerance,
        "DualObjectiveLimit" => MyDualObjectiveLimit,
        "MaximumIterations" => MyMaximumIterations,
        "MaximumSeconds" => MyMaximumSeconds,
        "LogLevel" => MyLogLevel,
        "PresolveType" => MyPresolveType,
        "SolveType" => MySolveType,
        "InfeasibleReturn" => MyInfeasibleReturn,
        "Scaling" => MyScaling,
        "Perturbation" => MyPerturbation
	)

	return OPTIMIZER
end
