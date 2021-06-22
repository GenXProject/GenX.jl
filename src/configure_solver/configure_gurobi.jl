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
	configure_gurobi(solver_settings_path::String)

Reads user-specified solver settings from gurobi\_settings.yml in the directory specified by the string solver\_settings\_path.

Returns a MathOptInterface OptimizerWithAttributes Gurobi optimizer instance to be used in the GenX.generate_model() method.

The Gurobi optimizer instance is configured with the following default parameters if a user-specified parameter for each respective field is not provided:

 - FeasibilityTol = 1e-6 (Constraint (primal) feasibility tolerances. See https://www.gurobi.com/documentation/8.1/refman/feasibilitytol.html)
 - OptimalityTol = 1e-6 (Dual feasibility tolerances. See https://www.gurobi.com/documentation/8.1/refman/optimalitytol.html#parameter:OptimalityTol)
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
		"NumericFocus" => MyNumericFocus,
		"Crossover" =>  MyCrossover
	)

	return OPTIMIZER
end
