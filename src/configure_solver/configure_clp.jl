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
	configure_clp(solver_settings_path::String)

# Reads user-specified solver settings from clp_settings.yml in the directory specified by the string solver_settings_path.

# Returns a MathOptInterface OptimizerWithAttributes Clp optimizer instance to be used in the GenX.generate_model() method.

The Clp optimizer instance is configured with the following default parameters if a user-specified parameter for each respective field is not provided:

#     - PrimalTolerance = 1e-7 (Primal feasibility tolerance)
#     - DualTolerance = 1e-7 (Dual feasibility tolerance)
#     - DualObjectiveLimit = 1e308 (When using dual simplex (where the objective is monotonically changing), terminate when the objective exceeds this limit)
#     - MaximumIterations = 2147483647 (Terminate after performing this number of simplex iterations)
#     - MaximumSeconds = -1.0	(Terminate after this many seconds have passed. A negative value means no time limit)
#     - LogLevel = 1 (Set to 1, 2, 3, or 4 for increasing output. Set to 0 to disable output)
#     - PresolveType = 0 (Set to 1 to disable presolve)
#     - SolveType = 5 (Solution method: dual simplex (0), primal simplex (1), sprint (2), barrier with crossover (3), barrier without crossover (4), automatic (5))
#     - InfeasibleReturn = 0 (Set to 1 to return as soon as the problem is found to be infeasible (by default, an infeasibility proof is computed as well))
#     - Scaling = 3 (0 0ff, 1 equilibrium, 2 geometric, 3 auto, 4 dynamic (later))
#     - Perturbation = 100 (switch on perturbation (50), automatic (100), don't try perturbing (102))

# """
function configure_clp(solver_settings_path::String)

	solver_settings = YAML.load(open(solver_settings_path))

	# Optional solver parameters ############################################
        MyDualObjectiveLimit = 1e100
            if(haskey(solver_settings, "DualObjectiveLimit")) MyDualObjectiveLimit = solver_settings["DualObjectiveLimit"] end
        MyPrimalTolerance = 1e-7	#Primal feasibility tolerance
            if(haskey(solver_settings, "Feasib_Tol")) MyPrimalTolerance = solver_settings["Feasib_Tol"] end
        MyDualTolerance = 1e-7	#Dual feasibility tolerance
            if(haskey(solver_settings, "Feasib_Tol ")) MyDualTolerance = solver_settings["Feasib_Tol"] end
        MyDualObjectiveLimit = 1e308	#When using dual simplex (where the objective is monotonically changing), terminate when the objective exceeds this limit
            if(haskey(solver_settings, "DualObjectiveLimit")) MyDualObjectiveLimit = solver_settings["DualObjectiveLimit"] end
        MyMaximumIterations = 2147483647	#Terminate after performing this number of simplex iterations
            if(haskey(solver_settings, "MaximumIterations")) MyMaximumIterations = solver_settings["MaximumIterations"] end
        MyMaximumSeconds = -1.0	#Terminate after this many seconds have passed. A negative value means no time limit
            if(haskey(solver_settings, "TimeLimit")) MyMaximumSeconds = solver_settings["TimeLimit"] end
        MyLogLevel = 1	#Set to 1, 2, 3, or 4 for increasing output. Set to 0 to disable output
            if(haskey(solver_settings, "LogLevel")) MyLogLevel = solver_settings["LogLevel"] end
        MyPresolveType = 0	#Set to 1 to disable presolve
            if(haskey(solver_settings, "Pre_Solve")) MyPresolveType = solver_settings["Pre_Solve"] end
        MySolveType = 5	#Solution method: dual simplex (0), primal simplex (1), sprint (2), barrier with crossover (3), barrier without crossover (4), automatic (5)
            if(haskey(solver_settings, "Method")) MySolveType = solver_settings["Method"] end
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
