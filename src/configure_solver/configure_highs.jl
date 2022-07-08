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
	configure_highs(solver_settings_path::String)

Reads user-specified solver settings from highs\_settings.yml in the directory specified by the string solver\_settings\_path.

Returns a MathOptInterface OptimizerWithAttributes HiGHS optimizer instance to be used in the GenX.generate_model() method.

The HiGHS optimizer instance is configured with the following default parameters if a user-specified parameter for each respective field is not provided:

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
function configure_highs(solver_settings_path::String)

	solver_settings = YAML.load(open(solver_settings_path))

	# Optional solver parameters ############################################
	MyFeasibilityTol = 1e-6 # Constraint (primal) feasibility tolerances. See https://github.com/jump-dev/HiGHS.jl, https://github.com/ERGO-Code/HiGHS, and https://highs.dev/
		if(haskey(solver_settings, "Feasib_Tol")) MyFeasibilityTol = solver_settings["Feasib_Tol"] end
	MyOptimalityTol = 1e-6  # Dual feasibility tolerances. See https://github.com/jump-dev/HiGHS.jl, https://github.com/ERGO-Code/HiGHS, and https://highs.dev/
		if(haskey(solver_settings, "Optimal_Tol")) MyOptimalityTol = solver_settings["Optimal_Tol"] end
	MyPresolve = "choose" 	# Controls presolve level. See https://github.com/jump-dev/HiGHS.jl, https://github.com/ERGO-Code/HiGHS, and https://highs.dev/
		if(haskey(solver_settings, "Pre_Solve")) MyPresolve = solver_settings["Pre_Solve"] end
	MyTimeLimit = Inf	# Limits total time solver. See https://www.gurobi.com/documentation/8.1/refman/timelimit.html
		if(haskey(solver_settings, "TimeLimit")) MyTimeLimit = solver_settings["TimeLimit"] end
	MyMethod = "ipm"	# Algorithm used to solve continuous models (including MIP root relaxation). See https://www.gurobi.com/documentation/8.1/refman/method.html
		if(haskey(solver_settings, "Method")) MyMethod = solver_settings["Method"] end
	Myparallel = "choose"	# Allowed fill during presolve aggregation. See https://www.gurobi.com/documentation/8.1/refman/aggfill.html#parameter:AggFill
		if(haskey(solver_settings, "parallel")) Myparallel = solver_settings["parallel"] end
	#Myranging = "off"		# Presolve dualization. See https://www.gurobi.com/documentation/8.1/refman/predual.html#parameter:PreDual
		#if(haskey(solver_settings, "ranging")) Myranging = solver_settings["ranging"] end
	Myinfinite_cost = 1e+20	# Relative (p.u. of optimal) mixed integer optimality tolerance for MIP problems (ignored otherwise). See https://www.gurobi.com/documentation/8.1/refman/mipgap2.html
		if(haskey(solver_settings, "infinite_cost")) Myinfinite_cost = solver_settings["infinite_cost"] end
	Myinfinite_bound = 1e+20 # Barrier crossver strategy. See https://www.gurobi.com/documentation/8.1/refman/crossover.html#parameter:Crossover
		if(haskey(solver_settings, "infinite_bound")) Myinfinite_bound = solver_settings["infinite_bound"] end
	Mysmall_matrix_value = 1e-09 	# Barrier convergence tolerance (determines when barrier terminates). See https://www.gurobi.com/documentation/8.1/refman/barconvtol.html
		if(haskey(solver_settings, "small_matrix_value")) Mysmall_matrix_value = solver_settings["small_matrix_value"] end
	Mylarge_matrix_value = 1e+15 	# Numerical precision emphasis. See https://www.gurobi.com/documentation/8.1/refman/numericfocus.html
		if(haskey(solver_settings, "large_matrix_value")) Mylarge_matrix_value = solver_settings["large_matrix_value"] end
	Myipm_optimality_tolerance = 1e-08	# Controls Gurobi output. See https://www.gurobi.com/documentation/8.1/refman/numericfocus.html
		if(haskey(solver_settings, "ipm_optimality_tolerance")) Myipm_optimality_tolerance = solver_settings["ipm_optimality_tolerance"] end
	Myobjective_bound = Inf # Constraint (primal) feasibility tolerances. See https://github.com/jump-dev/HiGHS.jl, https://github.com/ERGO-Code/HiGHS, and https://highs.dev/
		if(haskey(solver_settings, "objective_bound")) Myobjective_bound = solver_settings["objective_bound"] end
	Myobjective_target = -Inf  # Dual feasibility tolerances. See https://github.com/jump-dev/HiGHS.jl, https://github.com/ERGO-Code/HiGHS, and https://highs.dev/
		if(haskey(solver_settings, "objective_target")) Myobjective_target = solver_settings["objective_target"] end
	#Myrandom_seed = 0 	# Controls presolve level. See https://github.com/jump-dev/HiGHS.jl, https://github.com/ERGO-Code/HiGHS, and https://highs.dev/
		#if(haskey(solver_settings, "random_seed")) Myrandom_seed = solver_settings["random_seed"] end
	#Mythreads = 0	# Limits total time solver. See https://www.gurobi.com/documentation/8.1/refman/timelimit.html
		#if(haskey(solver_settings, "threads")) Mythreads = solver_settings["threads"] end
	Myhighs_debug_level = 0	# Algorithm used to solve continuous models (including MIP root relaxation). See https://www.gurobi.com/documentation/8.1/refman/method.html
		if(haskey(solver_settings, "highs_debug_level")) Myhighs_debug_level = solver_settings["highs_debug_level"] end
	Myhighs_analysis_level = 0	# Allowed fill during presolve aggregation. See https://www.gurobi.com/documentation/8.1/refman/aggfill.html#parameter:AggFill
		if(haskey(solver_settings, "highs_analysis_level")) Myhighs_analysis_level = solver_settings["highs_analysis_level"] end
	Mysimplex_strategy = 1		# Presolve dualization. See https://www.gurobi.com/documentation/8.1/refman/predual.html#parameter:PreDual
		if(haskey(solver_settings, "simplex_strategy")) Mysimplex_strategy = solver_settings["simplex_strategy"] end
	Mysimplex_scale_strategy = 1	# Relative (p.u. of optimal) mixed integer optimality tolerance for MIP problems (ignored otherwise). See https://www.gurobi.com/documentation/8.1/refman/mipgap2.html
		if(haskey(solver_settings, "simplex_scale_strategy")) Mysimplex_scale_strategy = solver_settings["simplex_scale_strategy"] end
	Mysimplex_crash_strategy = 0 # Barrier crossver strategy. See https://www.gurobi.com/documentation/8.1/refman/crossover.html#parameter:Crossover
		if(haskey(solver_settings, "simplex_crash_strategy")) Mysimplex_crash_strategy = solver_settings["simplex_crash_strategy"] end
	Mysimplex_dual_edge_weight_strategy = -1 	# Barrier convergence tolerance (determines when barrier terminates). See https://www.gurobi.com/documentation/8.1/refman/barconvtol.html
		if(haskey(solver_settings, "simplex_dual_edge_weight_strategy")) Mysimplex_dual_edge_weight_strategy = solver_settings["simplex_dual_edge_weight_strategy"] end
	Mysimplex_primal_edge_weight_strategy = -1 	# Numerical precision emphasis. See https://www.gurobi.com/documentation/8.1/refman/numericfocus.html
		if(haskey(solver_settings, "simplex_primal_edge_weight_strategy")) Mysimplex_primal_edge_weight_strategy = solver_settings["simplex_primal_edge_weight_strategy"] end
	Mysimplex_iteration_limit = 2147483647	# Controls Gurobi output. See https://www.gurobi.com/documentation/8.1/refman/numericfocus.html
		if(haskey(solver_settings, "simplex_iteration_limit")) Mysimplex_iteration_limit = solver_settings["simplex_iteration_limit"] end
	Mysimplex_update_limit = 5000 # Constraint (primal) feasibility tolerances. See https://github.com/jump-dev/HiGHS.jl, https://github.com/ERGO-Code/HiGHS, and https://highs.dev/
		if(haskey(solver_settings, "simplex_update_limit")) Mysimplex_update_limit = solver_settings["simplex_update_limit"] end
	Myipm_iteration_limit = 2147483647  # Dual feasibility tolerances. See https://github.com/jump-dev/HiGHS.jl, https://github.com/ERGO-Code/HiGHS, and https://highs.dev/
		if(haskey(solver_settings, "ipm_iteration_limit")) Myipm_iteration_limit = solver_settings["ipm_iteration_limit"] end
	#Mysimplex_min_concurrency = 1 	# Controls presolve level. See https://github.com/jump-dev/HiGHS.jl, https://github.com/ERGO-Code/HiGHS, and https://highs.dev/
		#if(haskey(solver_settings, "simplex_min_concurrency")) Mysimplex_min_concurrency = solver_settings["simplex_min_concurrency"] end
	#Mysimplex_max_concurrency = 8	# Limits total time solver. See https://www.gurobi.com/documentation/8.1/refman/timelimit.html
		#if(haskey(solver_settings, "simplex_max_concurrency")) Mysimplex_max_concurrency = solver_settings["simplex_max_concurrency"] end
	Myoutput_flag = true	# Algorithm used to solve continuous models (including MIP root relaxation). See https://www.gurobi.com/documentation/8.1/refman/method.html
		if(haskey(solver_settings, "output_flag")) Myoutput_flag = solver_settings["output_flag"] end
	Mylog_to_console = true	# Allowed fill during presolve aggregation. See https://www.gurobi.com/documentation/8.1/refman/aggfill.html#parameter:AggFill
		if(haskey(solver_settings, "log_to_console")) Mylog_to_console = solver_settings["log_to_console"] end
	Mysolution_file = 		# Presolve dualization. See https://www.gurobi.com/documentation/8.1/refman/predual.html#parameter:PreDual
		if(haskey(solver_settings, "solution_file")) Mysolution_file = solver_settings["solution_file"] end
	Mylog_file = 	# Relative (p.u. of optimal) mixed integer optimality tolerance for MIP problems (ignored otherwise). See https://www.gurobi.com/documentation/8.1/refman/mipgap2.html
		if(haskey(solver_settings, "log_file")) Mylog_file = solver_settings["log_file"] end
	Mywrite_solution_to_file = false # Barrier crossver strategy. See https://www.gurobi.com/documentation/8.1/refman/crossover.html#parameter:Crossover
		if(haskey(solver_settings, "write_solution_to_file")) Mywrite_solution_to_file = solver_settings["write_solution_to_file"] end
	Mywrite_solution_style = 0	# Barrier convergence tolerance (determines when barrier terminates). See https://www.gurobi.com/documentation/8.1/refman/barconvtol.html
		if(haskey(solver_settings, "write_solution_style")) Mywrite_solution_style = solver_settings["write_solution_style"] end
	Mywrite_model_file = 	# Numerical precision emphasis. See https://www.gurobi.com/documentation/8.1/refman/numericfocus.html
		if(haskey(solver_settings, "write_model_file")) Mywrite_model_file = solver_settings["write_model_file"] end
	Mywrite_model_to_file = false	# Controls Gurobi output. See https://www.gurobi.com/documentation/8.1/refman/numericfocus.html
		if(haskey(solver_settings, "write_model_to_file")) Mywrite_model_to_file = solver_settings["write_model_to_file"] end
	Mymip_detect_symmetry = true # Constraint (primal) feasibility tolerances. See https://github.com/jump-dev/HiGHS.jl, https://github.com/ERGO-Code/HiGHS, and https://highs.dev/
		if(haskey(solver_settings, "mip_detect_symmetry")) Mymip_detect_symmetry = solver_settings["mip_detect_symmetry"] end
	Mymip_max_nodes = 2147483647  # Dual feasibility tolerances. See https://github.com/jump-dev/HiGHS.jl, https://github.com/ERGO-Code/HiGHS, and https://highs.dev/
		if(haskey(solver_settings, "mip_max_nodes")) Mymip_max_nodes = solver_settings["mip_max_nodes"] end
	Mymip_max_stall_nodes = 2147483647	# Controls presolve level. See https://github.com/jump-dev/HiGHS.jl, https://github.com/ERGO-Code/HiGHS, and https://highs.dev/
		if(haskey(solver_settings, "mip_max_stall_nodes")) Mymip_max_stall_nodes = solver_settings["mip_max_stall_nodes"] end
	Mymip_max_leaves = 2147483647	# Limits total time solver. See https://www.gurobi.com/documentation/8.1/refman/timelimit.html
		if(haskey(solver_settings, "mip_max_leaves")) Mymip_max_leaves = solver_settings["mip_max_leaves"] end
	Mymip_max_improving_sols = 2147483647	# Algorithm used to solve continuous models (including MIP root relaxation). See https://www.gurobi.com/documentation/8.1/refman/method.html
		if(haskey(solver_settings, "mip_max_improving_sols")) Mymip_max_improving_sols = solver_settings["mip_max_improving_sols"] end
	Mymip_lp_age_limit = 10	# Allowed fill during presolve aggregation. See https://www.gurobi.com/documentation/8.1/refman/aggfill.html#parameter:AggFill
		if(haskey(solver_settings, "mip_lp_age_limit")) Mymip_lp_age_limit = solver_settings["mip_lp_age_limit"] end
	Mymip_pool_age_limit = 30	# Presolve dualization. See https://www.gurobi.com/documentation/8.1/refman/predual.html#parameter:PreDual
		if(haskey(solver_settings, "mip_pool_age_limit")) Mymip_pool_age_limit = solver_settings["mip_pool_age_limit"] end
	Mymip_pool_soft_limit = 10000	# Relative (p.u. of optimal) mixed integer optimality tolerance for MIP problems (ignored otherwise). See https://www.gurobi.com/documentation/8.1/refman/mipgap2.html
		if(haskey(solver_settings, "mip_pool_soft_limit")) Mymip_pool_soft_limit = solver_settings["mip_pool_soft_limit"] end
	Mymip_pscost_minreliable = 8 # Barrier crossver strategy. See https://www.gurobi.com/documentation/8.1/refman/crossover.html#parameter:Crossover
		if(haskey(solver_settings, "mip_pscost_minreliable")) Mymip_pscost_minreliable = solver_settings["mip_pscost_minreliable"] end
	Mymip_min_cliquetable_entries_for_parallelism = 100000 	# Barrier convergence tolerance (determines when barrier terminates). See https://www.gurobi.com/documentation/8.1/refman/barconvtol.html
		if(haskey(solver_settings, "mip_min_cliquetable_entries_for_parallelism")) Mymip_min_cliquetable_entries_for_parallelism = solver_settings["mip_min_cliquetable_entries_for_parallelism"] end
	Mymip_report_level = 1	# Numerical precision emphasis. See https://www.gurobi.com/documentation/8.1/refman/numericfocus.html
		if(haskey(solver_settings, "mip_report_level")) Mymip_report_level = solver_settings["mip_report_level"] end
	Mymip_feasibility_tolerance = 1e-06	# Controls Gurobi output. See https://www.gurobi.com/documentation/8.1/refman/numericfocus.html
		if(haskey(solver_settings, "mip_feasibility_tolerance")) Mymip_feasibility_tolerance = solver_settings["mip_feasibility_tolerance"] end
	Mymip_heuristic_effort = 0.05 # Constraint (primal) feasibility tolerances. See https://github.com/jump-dev/HiGHS.jl, https://github.com/ERGO-Code/HiGHS, and https://highs.dev/
		if(haskey(solver_settings, "mip_heuristic_effort")) Mymip_heuristic_effort = solver_settings["mip_heuristic_effort"] end
	Mymip_rel_gap = 0.0001  # Dual feasibility tolerances. See https://github.com/jump-dev/HiGHS.jl, https://github.com/ERGO-Code/HiGHS, and https://highs.dev/
		if(haskey(solver_settings, "mip_rel_gap")) Mymip_rel_gap = solver_settings["mip_rel_gap"] end
	Mymip_abs_gap = 1e-06	# Controls presolve level. See https://github.com/jump-dev/HiGHS.jl, https://github.com/ERGO-Code/HiGHS, and https://highs.dev/
		if(haskey(solver_settings, "mip_abs_gap")) Mymip_abs_gap = solver_settings["mip_abs_gap"] end
	Mylog_dev_level = 0	# Limits total time solver. See https://www.gurobi.com/documentation/8.1/refman/timelimit.html
		if(haskey(solver_settings, "log_dev_level")) Mylog_dev_level = solver_settings["log_dev_level"] end
	Myrun_crossover = false	# Algorithm used to solve continuous models (including MIP root relaxation). See https://www.gurobi.com/documentation/8.1/refman/method.html
		if(haskey(solver_settings, "run_crossover")) Myrun_crossover = solver_settings["run_crossover"] end
	Myallow_unbounded_or_infeasible = false	# Allowed fill during presolve aggregation. See https://www.gurobi.com/documentation/8.1/refman/aggfill.html#parameter:AggFill
		if(haskey(solver_settings, "allow_unbounded_or_infeasible")) Myallow_unbounded_or_infeasible = solver_settings["allow_unbounded_or_infeasible"] end
	Myuse_implied_bounds_from_presolve = false	# Presolve dualization. See https://www.gurobi.com/documentation/8.1/refman/predual.html#parameter:PreDual
		if(haskey(solver_settings, "use_implied_bounds_from_presolve")) Myuse_implied_bounds_from_presolve = solver_settings["use_implied_bounds_from_presolve"] end
	Mylp_presolve_requires_basis_postsolve = true	# Relative (p.u. of optimal) mixed integer optimality tolerance for MIP problems (ignored otherwise). See https://www.gurobi.com/documentation/8.1/refman/mipgap2.html
		if(haskey(solver_settings, "lp_presolve_requires_basis_postsolve")) Mylp_presolve_requires_basis_postsolve = solver_settings["lp_presolve_requires_basis_postsolve"] end
	Mymps_parser_type_free = true # Barrier crossver strategy. See https://www.gurobi.com/documentation/8.1/refman/crossover.html#parameter:Crossover
		if(haskey(solver_settings, "mps_parser_type_free")) Mymps_parser_type_free = solver_settings["mps_parser_type_free"] end
	Mykeep_n_rows = -1 	# Barrier convergence tolerance (determines when barrier terminates). See https://www.gurobi.com/documentation/8.1/refman/barconvtol.html
		if(haskey(solver_settings, "keep_n_rows")) Mykeep_n_rows = solver_settings["keep_n_rows"] end
	Mycost_scale_factor = 0	# Numerical precision emphasis. See https://www.gurobi.com/documentation/8.1/refman/numericfocus.html
		if(haskey(solver_settings, "cost_scale_factor")) Mycost_scale_factor = solver_settings["cost_scale_factor"] end
	Myallowed_matrix_scale_factor = 20	# Controls Gurobi output. See https://www.gurobi.com/documentation/8.1/refman/numericfocus.html
		if(haskey(solver_settings, "allowed_matrix_scale_factor")) Myallowed_matrix_scale_factor = solver_settings["allowed_matrix_scale_factor"] end
	Myallowed_cost_scale_factor = 0 # Constraint (primal) feasibility tolerances. See https://github.com/jump-dev/HiGHS.jl, https://github.com/ERGO-Code/HiGHS, and https://highs.dev/
		if(haskey(solver_settings, "allowed_cost_scale_factor")) Myallowed_cost_scale_factor = solver_settings["allowed_cost_scale_factor"] end
	Mysimplex_dualise_strategy = -1  # Dual feasibility tolerances. See https://github.com/jump-dev/HiGHS.jl, https://github.com/ERGO-Code/HiGHS, and https://highs.dev/
		if(haskey(solver_settings, "simplex_dualise_strategy")) Mysimplex_dualise_strategy = solver_settings["simplex_dualise_strategy"] end
	Mysimplex_permute_strategy = -1	# Controls presolve level. See https://github.com/jump-dev/HiGHS.jl, https://github.com/ERGO-Code/HiGHS, and https://highs.dev/
		if(haskey(solver_settings, "simplex_permute_strategy")) Mysimplex_permute_strategy = solver_settings["simplex_permute_strategy"] end
	Mymax_dual_simplex_cleanup_level = 1	# Limits total time solver. See https://www.gurobi.com/documentation/8.1/refman/timelimit.html
		if(haskey(solver_settings, "max_dual_simplex_cleanup_level")) Mymax_dual_simplex_cleanup_level = solver_settings["max_dual_simplex_cleanup_level"] end
	Mymax_dual_simplex_phase1_cleanup_level = 2	# Algorithm used to solve continuous models (including MIP root relaxation). See https://www.gurobi.com/documentation/8.1/refman/method.html
		if(haskey(solver_settings, "max_dual_simplex_phase1_cleanup_level")) Mymax_dual_simplex_phase1_cleanup_level = solver_settings["max_dual_simplex_phase1_cleanup_level"] end
	Mysimplex_price_strategy = 3	# Allowed fill during presolve aggregation. See https://www.gurobi.com/documentation/8.1/refman/aggfill.html#parameter:AggFill
		if(haskey(solver_settings, "simplex_price_strategy")) Mysimplex_price_strategy = solver_settings["simplex_price_strategy"] end
	Mysimplex_unscaled_solution_strategy = 1		# Presolve dualization. See https://www.gurobi.com/documentation/8.1/refman/predual.html#parameter:PreDual
		if(haskey(solver_settings, "simplex_unscaled_solution_strategy")) Mysimplex_unscaled_solution_strategy = solver_settings["simplex_unscaled_solution_strategy"] end
	Mysimplex_initial_condition_check = true	# Relative (p.u. of optimal) mixed integer optimality tolerance for MIP problems (ignored otherwise). See https://www.gurobi.com/documentation/8.1/refman/mipgap2.html
		if(haskey(solver_settings, "simplex_initial_condition_check")) Mysimplex_initial_condition_check = solver_settings["simplex_initial_condition_check"] end
	Myno_unnecessary_rebuild_refactor = true # Barrier crossver strategy. See https://www.gurobi.com/documentation/8.1/refman/crossover.html#parameter:Crossover
		if(haskey(solver_settings, "no_unnecessary_rebuild_refactor")) Myno_unnecessary_rebuild_refactor = solver_settings["no_unnecessary_rebuild_refactor"] end
	Mysimplex_initial_condition_tolerance = 1e+14 	# Barrier convergence tolerance (determines when barrier terminates). See https://www.gurobi.com/documentation/8.1/refman/barconvtol.html
		if(haskey(solver_settings, "simplex_initial_condition_tolerance")) Mysimplex_initial_condition_tolerance = solver_settings["simplex_initial_condition_tolerance"] end
	Myrebuild_refactor_solution_error_tolerance = 1e-08	# Numerical precision emphasis. See https://www.gurobi.com/documentation/8.1/refman/numericfocus.html
		if(haskey(solver_settings, "rebuild_refactor_solution_error_tolerance")) Myrebuild_refactor_solution_error_tolerance = solver_settings["rebuild_refactor_solution_error_tolerance"] end
	Mydual_steepest_edge_weight_error_tolerance = Inf	# Controls Gurobi output. See https://www.gurobi.com/documentation/8.1/refman/numericfocus.html
		if(haskey(solver_settings, "dual_steepest_edge_weight_error_tolerance")) Mydual_steepest_edge_weight_error_tolerance = solver_settings["dual_steepest_edge_weight_error_tolerance"] end
	Mydual_steepest_edge_weight_log_error_threshold = 10 # Constraint (primal) feasibility tolerances. See https://github.com/jump-dev/HiGHS.jl, https://github.com/ERGO-Code/HiGHS, and https://highs.dev/
		if(haskey(solver_settings, "dual_steepest_edge_weight_log_error_threshold")) Mydual_steepest_edge_weight_log_error_threshold = solver_settings["dual_steepest_edge_weight_log_error_threshold"] end
	Mydual_simplex_cost_perturbation_multiplier = 1  # Dual feasibility tolerances. See https://github.com/jump-dev/HiGHS.jl, https://github.com/ERGO-Code/HiGHS, and https://highs.dev/
		if(haskey(solver_settings, "dual_simplex_cost_perturbation_multiplier")) Mydual_simplex_cost_perturbation_multiplier = solver_settings["dual_simplex_cost_perturbation_multiplier"] end
	Myprimal_simplex_bound_perturbation_multiplier = 1 	# Controls presolve level. See https://github.com/jump-dev/HiGHS.jl, https://github.com/ERGO-Code/HiGHS, and https://highs.dev/
		if(haskey(solver_settings, "primal_simplex_bound_perturbation_multiplier")) Myprimal_simplex_bound_perturbation_multiplier = solver_settings["primal_simplex_bound_perturbation_multiplier"] end
	Mydual_simplex_pivot_growth_tolerance = 1e-09	# Limits total time solver. See https://www.gurobi.com/documentation/8.1/refman/timelimit.html
		if(haskey(solver_settings, "dual_simplex_pivot_growth_tolerance")) Mydual_simplex_pivot_growth_tolerance = solver_settings["dual_simplex_pivot_growth_tolerance"] end
	Mypresolve_pivot_threshold = 0.01	# Algorithm used to solve continuous models (including MIP root relaxation). See https://www.gurobi.com/documentation/8.1/refman/method.html
		if(haskey(solver_settings, "presolve_pivot_threshold")) Mypresolve_pivot_threshold = solver_settings["presolve_pivot_threshold"] end
	Mypresolve_substitution_maxfillin = 10	# Allowed fill during presolve aggregation. See https://www.gurobi.com/documentation/8.1/refman/aggfill.html#parameter:AggFill
		if(haskey(solver_settings, "presolve_substitution_maxfillin")) Mypresolve_substitution_maxfillin = solver_settings["presolve_substitution_maxfillin"] end
	Myfactor_pivot_threshold = 0.1		# Presolve dualization. See https://www.gurobi.com/documentation/8.1/refman/predual.html#parameter:PreDual
		if(haskey(solver_settings, "factor_pivot_threshold")) Myfactor_pivot_threshold = solver_settings["factor_pivot_threshold"] end
	Myfactor_pivot_tolerance = 1e-10 	# Relative (p.u. of optimal) mixed integer optimality tolerance for MIP problems (ignored otherwise). See https://www.gurobi.com/documentation/8.1/refman/mipgap2.html
		if(haskey(solver_settings, "factor_pivot_tolerance")) Myfactor_pivot_tolerance = solver_settings["factor_pivot_tolerance"] end
	Mystart_crossover_tolerance = 1e-08 # Barrier crossver strategy. See https://www.gurobi.com/documentation/8.1/refman/crossover.html#parameter:Crossover
		if(haskey(solver_settings, "start_crossover_tolerance")) Mystart_crossover_tolerance = solver_settings["start_crossover_tolerance"] end
	Myuse_original_HFactor_logic = true	# Barrier convergence tolerance (determines when barrier terminates). See https://www.gurobi.com/documentation/8.1/refman/barconvtol.html
		if(haskey(solver_settings, "use_original_HFactor_logic")) Myuse_original_HFactor_logic = solver_settings["use_original_HFactor_logic"] end
	Myless_infeasible_DSE_check = true 	# Numerical precision emphasis. See https://www.gurobi.com/documentation/8.1/refman/numericfocus.html
		if(haskey(solver_settings, "less_infeasible_DSE_check")) Myless_infeasible_DSE_check = solver_settings["less_infeasible_DSE_check"] end
	Myless_infeasible_DSE_choose_row = true	# Controls Gurobi output. See https://www.gurobi.com/documentation/8.1/refman/numericfocus.html
		if(haskey(solver_settings, "less_infeasible_DSE_choose_row")) Myless_infeasible_DSE_choose_row = solver_settings["less_infeasible_DSE_choose_row"] end
	########################################################################

	OPTIMIZER = optimizer_with_attributes(HiGHS.Optimizer,
		"primal_feasibility_tolerance" => MyFeasibilityTol,
		"dual_feasibility_tolerance" => MyOptimalityTol,
		"time_limit" => MyTimeLimit,
		"presolve" => MyPresolve,
		"solver" => MyMethod,
		"parallel" => Myparallel,
		#"ranging" => Myranging,
		"infinite_cost" => Myinfinite_cost,
		"infinite_bound" => Myinfinite_bound,
		"small_matrix_value" => Mysmall_matrix_value,
		"large_matrix_value" => Mylarge_matrix_value,
		"ipm_optimality_tolerance" => Myipm_optimality_tolerance,
		"objective_bound" => Myobjective_bound,
		"objective_target" => Myobjective_target,
		#"random_seed" => Myrandom_seed,
		#"threads" => Mythreads,
		"highs_debug_level" => Myhighs_debug_level,
		"highs_analysis_level" => Myhighs_analysis_level,
		"simplex_strategy" => Mysimplex_strategy,
		"simplex_scale_strategy" => Mysimplex_scale_strategy,
		"simplex_crash_strategy" => Mysimplex_crash_strategy,
		"simplex_dual_edge_weight_strategy" => Mysimplex_dual_edge_weight_strategy,
		"simplex_primal_edge_weight_strategy" => Mysimplex_primal_edge_weight_strategy,
		"simplex_iteration_limit" => Mysimplex_iteration_limit,
		"simplex_update_limit" => Mysimplex_update_limit,
		"ipm_iteration_limit" => Myipm_iteration_limit,
		#"simplex_min_concurrency" => Mysimplex_min_concurrency,
		#"simplex_max_concurrency" => Mysimplex_max_concurrency,
		"output_flag" => Myoutput_flag,
		"log_to_console" => Mylog_to_console,
		"solution_file" => Mysolution_file,
		"log_file" => Mylog_file,
		"write_solution_to_file" => Mywrite_solution_to_file,
		"write_solution_style" => Mywrite_solution_style,
		"write_model_file" => Mywrite_model_file,
		"write_model_to_file" => Mywrite_model_to_file,
		"mip_detect_symmetry" => Mymip_detect_symmetry,
		"mip_max_nodes" => Mymip_max_nodes,
		"mip_max_stall_nodes" => Mymip_max_stall_nodes,
		"mip_max_leaves" => Mymip_max_leaves,
		"mip_max_improving_sols" => Mymip_max_improving_sols,
		"mip_lp_age_limit" => Mymip_lp_age_limit,
		"mip_pool_age_limit" => Mymip_pool_age_limit,
		"mip_pool_soft_limit" => Mymip_pool_soft_limit,
		"mip_pscost_minreliable" => Mymip_pscost_minreliable,
		"mip_min_cliquetable_entries_for_parallelism" => Mymip_min_cliquetable_entries_for_parallelism,
		"mip_report_level" => Mymip_report_level,
		"mip_feasibility_tolerance" => Mymip_feasibility_tolerance,
		"mip_heuristic_effort" => Mymip_heuristic_effort,
		"mip_rel_gap" => Mymip_rel_gap,
		"mip_abs_gap" => Mymip_abs_gap,
		"log_dev_level" => Mylog_dev_level,
		"run_crossover" => Myrun_crossover,
		"allow_unbounded_or_infeasible" => Myallow_unbounded_or_infeasible,
		"use_implied_bounds_from_presolve" => Myuse_implied_bounds_from_presolve,
		"lp_presolve_requires_basis_postsolve" => Mylp_presolve_requires_basis_postsolve,
		"mps_parser_type_free" => Mymps_parser_type_free,
		"keep_n_rows" => Mykeep_n_rows,
		"cost_scale_factor" => Mycost_scale_factor,
		"allowed_matrix_scale_factor" => Myallowed_matrix_scale_factor,
		"allowed_cost_scale_factor" => Myallowed_cost_scale_factor,
		"simplex_dualise_strategy" => Mysimplex_dualise_strategy,
		"simplex_permute_strategy" => Mysimplex_permute_strategy,
		"max_dual_simplex_cleanup_level" => Mymax_dual_simplex_cleanup_level,
		"max_dual_simplex_phase1_cleanup_level" => Mymax_dual_simplex_phase1_cleanup_level,
		"simplex_price_strategy" => Mysimplex_price_strategy,
		"simplex_unscaled_solution_strategy" => Mysimplex_unscaled_solution_strategy,
		"simplex_initial_condition_check" => Mysimplex_initial_condition_check,
		"no_unnecessary_rebuild_refactor" => Myno_unnecessary_rebuild_refactor,
		"simplex_initial_condition_tolerance" => Mysimplex_initial_condition_tolerance,
		"rebuild_refactor_solution_error_tolerance" => Myrebuild_refactor_solution_error_tolerance,
		"dual_steepest_edge_weight_error_tolerance" => Mydual_steepest_edge_weight_error_tolerance,
		"dual_steepest_edge_weight_log_error_threshold" => Mydual_steepest_edge_weight_log_error_threshold,
		"dual_simplex_cost_perturbation_multiplier" => Mydual_simplex_cost_perturbation_multiplier,
		"primal_simplex_bound_perturbation_multiplier" => Myprimal_simplex_bound_perturbation_multiplier,
		"dual_simplex_pivot_growth_tolerance" => Mydual_simplex_pivot_growth_tolerance,
		"presolve_pivot_threshold" => Mypresolve_pivot_threshold,
		"presolve_substitution_maxfillin" => Mypresolve_substitution_maxfillin,
		"factor_pivot_threshold" => Myfactor_pivot_threshold,
		"factor_pivot_tolerance" => Myfactor_pivot_tolerance,
		"start_crossover_tolerance" => Mystart_crossover_tolerance,
		"use_original_HFactor_logic" => Myuse_original_HFactor_logic,
		"less_infeasible_DSE_check" => Myless_infeasible_DSE_check,
		"less_infeasible_DSE_choose_row" => Myless_infeasible_DSE_choose_row

	)

	return OPTIMIZER
end
