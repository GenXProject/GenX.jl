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
	All the references are in https://github.com/jump-dev/HiGHS.jl, https://github.com/ERGO-Code/HiGHS, and https://highs.dev/

	# HiGHS Solver Parameters
	# Common solver settings
	Feasib_Tol: 1.0e-06        # Primal feasibility tolerance # [type: double, advanced: false, range: [1e-10, inf], default: 1e-07]
	Optimal_Tol: 1.0e-03       # Dual feasibility tolerance # [type: double, advanced: false, range: [1e-10, inf], default: 1e-07]
	TimeLimit: Inf             # Time limit # [type: double, advanced: false, range: [0, inf], default: inf]
	Pre_Solve: choose          # Presolve option: "off", "choose" or "on" # [type: string, advanced: false, default: "choose"]
	Method: ipm #choose        #HiGHS-specific solver settings # Solver option: "simplex", "choose" or "ipm" # [type: string, advanced: false, default: "choose"] In order to run a case when the UCommit is set to 1, i.e. MILP instance, set the Method to choose
	
	#HiGHS-specific solver settings
	# Parallel option: "off", "choose" or "on"
	# [type: string, advanced: false, default: "choose"]
	parallel: choose
	
	# Compute cost, bound, RHS and basic solution ranging: "off" or "on"
	# [type: string, advanced: false, default: "off"]
	ranging: off
	
	# Limit on cost coefficient: values larger than this will be treated as infinite
	# [type: double, advanced: false, range: [1e+15, inf], default: 1e+20]
	infinite_cost: 1e+20
	
	# Limit on |constraint bound|: values larger than this will be treated as infinite
	# [type: double, advanced: false, range: [1e+15, inf], default: 1e+20]
	infinite_bound: 1e+20
	
	# Lower limit on |matrix entries|: values smaller than this will be treated as zero
	# [type: double, advanced: false, range: [1e-12, inf], default: 1e-09]
	small_matrix_value: 1e-09
	
	# Upper limit on |matrix entries|: values larger than this will be treated as infinite
	# [type: double, advanced: false, range: [1, inf], default: 1e+15]
	large_matrix_value: 1e+15
	
	# IPM optimality tolerance
	# [type: double, advanced: false, range: [1e-12, inf], default: 1e-08]
	ipm_optimality_tolerance: 1e-08
	
	# Objective bound for termination
	# [type: double, advanced: false, range: [-inf, inf], default: inf]
	objective_bound: Inf
	
	# Objective target for termination
	# [type: double, advanced: false, range: [-inf, inf], default: -inf]
	objective_target: -Inf
	
	# random seed used in HiGHS
	# [type: HighsInt, advanced: false, range: {0, 2147483647}, default: 0]
	random_seed: 0
	
	# number of threads used by HiGHS (0: automatic)
	# [type: HighsInt, advanced: false, range: {0, 2147483647}, default: 0]
	threads: 0
	
	# Debugging level in HiGHS
	# [type: HighsInt, advanced: false, range: {0, 3}, default: 0]
	highs_debug_level: 0
	
	# Analysis level in HiGHS
	# [type: HighsInt, advanced: false, range: {0, 63}, default: 0]
	highs_analysis_level: 0
	
	# Strategy for simplex solver 0 => Choose; 1 => Dual (serial); 2 => Dual (PAMI); 3 => Dual (SIP); 4 => Primal
	# [type: HighsInt, advanced: false, range: {0, 4}, default: 1]
	simplex_strategy: 1
	
	# Simplex scaling strategy: off / choose / equilibration / forced equilibration / max value 0 / max value 1 (0/1/2/3/4/5)
	# [type: HighsInt, advanced: false, range: {0, 5}, default: 1]
	simplex_scale_strategy: 1
	
	# Strategy for simplex crash: off / LTSSF / Bixby (0/1/2)
	# [type: HighsInt, advanced: false, range: {0, 9}, default: 0]
	simplex_crash_strategy: 0
	
	# Strategy for simplex dual edge weights: Choose / Dantzig / Devex / Steepest Edge (-1/0/1/2)
	# [type: HighsInt, advanced: false, range: {-1, 2}, default: -1]
	simplex_dual_edge_weight_strategy: -1
	
	# Strategy for simplex primal edge weights: Choose / Dantzig / Devex / Steepest Edge (-1/0/1/2)
	# [type: HighsInt, advanced: false, range: {-1, 2}, default: -1]
	simplex_primal_edge_weight_strategy: -1
	
	# Iteration limit for simplex solver
	# [type: HighsInt, advanced: false, range: {0, 2147483647}, default: 2147483647]
	simplex_iteration_limit: 2147483647
	
	# Limit on the number of simplex UPDATE operations
	# [type: HighsInt, advanced: false, range: {0, 2147483647}, default: 5000]
	simplex_update_limit: 5000
	
	# Iteration limit for IPM solver
	# [type: HighsInt, advanced: false, range: {0, 2147483647}, default: 2147483647]
	ipm_iteration_limit: 2147483647
	
	# Minimum level of concurrency in parallel simplex
	# [type: HighsInt, advanced: false, range: {1, 8}, default: 1]
	simplex_min_concurrency: 1
	
	# Maximum level of concurrency in parallel simplex
	# [type: HighsInt, advanced: false, range: {1, 8}, default: 8]
	simplex_max_concurrency: 8
	
	# Enables or disables solver output
	# [type: bool, advanced: false, range: {false, true}, default: true]
	output_flag: true
	
	# Enables or disables console logging
	# [type: bool, advanced: false, range: {false, true}, default: true]
	log_to_console: true
	
	# Solution file
	# [type: string, advanced: false, default: ""]
	solution_file: ""
	
	# Log file
	# [type: string, advanced: false, default: ""]
	log_file: ""
	
	# Write the primal and dual solution to a file
	# [type: bool, advanced: false, range: {false, true}, default: false]
	write_solution_to_file: false
	
	# Write the solution in style: 0=>Raw (computer-readable); 1=>Pretty (human-readable) 
	# [type: HighsInt, advanced: false, range: {0, 2}, default: 0]
	write_solution_style: 0
	
	# Write model file
	# [type: string, advanced: false, default: ""]
	write_model_file: ""
	
	# Write the model to a file
	# [type: bool, advanced: false, range: {false, true}, default: false]
	write_model_to_file: false
	
	# Whether symmetry should be detected
	# [type: bool, advanced: false, range: {false, true}, default: true]
	mip_detect_symmetry: true
	
	# MIP solver max number of nodes
	# [type: HighsInt, advanced: false, range: {0, 2147483647}, default: 2147483647]
	mip_max_nodes: 2147483647
	
	# MIP solver max number of nodes where estimate is above cutoff bound
	# [type: HighsInt, advanced: false, range: {0, 2147483647}, default: 2147483647]
	mip_max_stall_nodes: 2147483647
	
	# MIP solver max number of leave nodes
	# [type: HighsInt, advanced: false, range: {0, 2147483647}, default: 2147483647]
	mip_max_leaves: 2147483647
	
	# limit on the number of improving solutions found to stop the MIP solver prematurely
	# [type: HighsInt, advanced: false, range: {1, 2147483647}, default: 2147483647]
	mip_max_improving_sols: 2147483647
	
	# maximal age of dynamic LP rows before they are removed from the LP relaxation
	# [type: HighsInt, advanced: false, range: {0, 32767}, default: 10]
	mip_lp_age_limit: 10
	
	# maximal age of rows in the cutpool before they are deleted
	# [type: HighsInt, advanced: false, range: {0, 1000}, default: 30]
	mip_pool_age_limit: 30
	
	# soft limit on the number of rows in the cutpool for dynamic age adjustment
	# [type: HighsInt, advanced: false, range: {1, 2147483647}, default: 10000]
	mip_pool_soft_limit: 10000
	
	# minimal number of observations before pseudo costs are considered reliable
	# [type: HighsInt, advanced: false, range: {0, 2147483647}, default: 8]
	mip_pscost_minreliable: 8
	
	# minimal number of entries in the cliquetable before neighborhood queries of the conflict graph use parallel processing
	# [type: HighsInt, advanced: false, range: {0, 2147483647}, default: 100000]
	mip_min_cliquetable_entries_for_parallelism: 100000
	
	# MIP solver reporting level
	# [type: HighsInt, advanced: false, range: {0, 2}, default: 1]
	mip_report_level: 1
	
	# MIP feasibility tolerance
	# [type: double, advanced: false, range: [1e-10, inf], default: 1e-06]
	mip_feasibility_tolerance: 1e-06
	
	# effort spent for MIP heuristics
	# [type: double, advanced: false, range: [0, 1], default: 0.05]
	mip_heuristic_effort: 0.05
	
	# tolerance on relative gap, |ub-lb|/|ub|, to determine whether optimality has been reached for a MIP instance
	# [type: double, advanced: false, range: [0, inf], default: 0.0001]
	mip_rel_gap: 0.0001
	
	# tolerance on absolute gap of MIP, |ub-lb|, to determine whether optimality has been reached for a MIP instance
	# [type: double, advanced: false, range: [0, inf], default: 1e-06]
	mip_abs_gap: 1e-06
	
	# Output development messages: 0 => none; 1 => info; 2 => verbose
	# [type: HighsInt, advanced: true, range: {0, 3}, default: 0]
	log_dev_level: 0
	
	# Run the crossover routine for IPX
	# [type: bool, advanced: true, range: {false, true}, default: true]
	run_crossover: false #true
	
	# Allow ModelStatus::kUnboundedOrInfeasible
	# [type: bool, advanced: true, range: {false, true}, default: false]
	allow_unbounded_or_infeasible: false
	
	# Use relaxed implied bounds from presolve
	# [type: bool, advanced: true, range: {false, true}, default: false]
	use_implied_bounds_from_presolve: false
	
	# Prevents LP presolve steps for which postsolve cannot maintain a basis
	# [type: bool, advanced: true, range: {false, true}, default: true]
	lp_presolve_requires_basis_postsolve: true
	
	# Use the free format MPS file reader
	# [type: bool, advanced: true, range: {false, true}, default: true]
	mps_parser_type_free: true
	
	# For multiple N-rows in MPS files: delete rows / delete entries / keep rows (-1/0/1)
	# [type: HighsInt, advanced: true, range: {-1, 1}, default: -1]
	keep_n_rows: -1
	
	# Scaling factor for costs
	# [type: HighsInt, advanced: true, range: {-20, 20}, default: 0]
	cost_scale_factor: 0
	
	# Largest power-of-two factor permitted when scaling the constraint matrix
	# [type: HighsInt, advanced: true, range: {0, 30}, default: 20]
	allowed_matrix_scale_factor: 20
	
	# Largest power-of-two factor permitted when scaling the costs
	# [type: HighsInt, advanced: true, range: {0, 20}, default: 0]
	allowed_cost_scale_factor: 0
	
	# Strategy for dualising before simplex
	# [type: HighsInt, advanced: true, range: {-1, 1}, default: -1]
	simplex_dualise_strategy: -1
	
	# Strategy for permuting before simplex
	# [type: HighsInt, advanced: true, range: {-1, 1}, default: -1]
	simplex_permute_strategy: -1
	
	# Max level of dual simplex cleanup
	# [type: HighsInt, advanced: true, range: {0, 2147483647}, default: 1]
	max_dual_simplex_cleanup_level: 1
	
	# Max level of dual simplex phase 1 cleanup
	# [type: HighsInt, advanced: true, range: {0, 2147483647}, default: 2]
	max_dual_simplex_phase1_cleanup_level: 2
	
	# Strategy for PRICE in simplex
	# [type: HighsInt, advanced: true, range: {0, 3}, default: 3]
	simplex_price_strategy: 3
	
	Strategy for solving unscaled LP in simplex
	[type: HighsInt, advanced: true, range: {0, 2}, default: 1]
	simplex_unscaled_solution_strategy: 1
	
	Perform initial basis condition check in simplex
	[type: bool, advanced: true, range: {false, true}, default: true]
	simplex_initial_condition_check: true
	
	No unnecessary refactorization on simplex rebuild
	[type: bool, advanced: true, range: {false, true}, default: true]
	no_unnecessary_rebuild_refactor: true
	
	Tolerance on initial basis condition in simplex
	[type: double, advanced: true, range: [1, inf], default: 1e+14]
	simplex_initial_condition_tolerance: 1e+14
	
	Tolerance on solution error when considering refactorization on simplex rebuild
	[type: double, advanced: true, range: [-inf, inf], default: 1e-08]
	rebuild_refactor_solution_error_tolerance: 1e-08
	
	Tolerance on dual steepest edge weight errors
	[type: double, advanced: true, range: [0, inf], default: inf]
	dual_steepest_edge_weight_error_tolerance: Inf
	
	Threshold on dual steepest edge weight errors for Devex switch
	[type: double, advanced: true, range: [1, inf], default: 10]
	dual_steepest_edge_weight_log_error_threshold: 10.0
	
	Dual simplex cost perturbation multiplier: 0 => no perturbation
	[type: double, advanced: true, range: [0, inf], default: 1]
	dual_simplex_cost_perturbation_multiplier: 1.0
	
	Primal simplex bound perturbation multiplier: 0 => no perturbation
	[type: double, advanced: true, range: [0, inf], default: 1]
	primal_simplex_bound_perturbation_multiplier: 1.0
	
	Dual simplex pivot growth tolerance
	[type: double, advanced: true, range: [1e-12, inf], default: 1e-09]
	dual_simplex_pivot_growth_tolerance: 1e-09
	
	Matrix factorization pivot threshold for substitutions in presolve
	[type: double, advanced: true, range: [0.0008, 0.5], default: 0.01]
	presolve_pivot_threshold: 0.01
	
	Maximal fillin allowed for substitutions in presolve
	[type: HighsInt, advanced: true, range: {0, 2147483647}, default: 10]
	presolve_substitution_maxfillin: 10
	
	Matrix factorization pivot threshold
	[type: double, advanced: true, range: [0.0008, 0.5], default: 0.1]
	factor_pivot_threshold: 0.1
	
	Matrix factorization pivot tolerance
	[type: double, advanced: true, range: [0, 1], default: 1e-10]
	factor_pivot_tolerance: 1e-10
	
	Tolerance to be satisfied before IPM crossover will start
	[type: double, advanced: true, range: [1e-12, inf], default: 1e-08]
	start_crossover_tolerance: 1e-08
	
	Use original HFactor logic for sparse vs hyper-sparse TRANs
	[type: bool, advanced: true, range: {false, true}, default: true]
	use_original_HFactor_logic: true
	
	Check whether LP is candidate for LiDSE
	[type: bool, advanced: true, range: {false, true}, default: true]
	less_infeasible_DSE_check: true
	
	Use LiDSE if LP has right properties
	[type: bool, advanced: true, range: {false, true}, default: true]
	less_infeasible_DSE_choose_row: true
	

"""
function configure_highs(solver_settings_path::String)

	solver_settings = YAML.load(open(solver_settings_path))

	# Optional solver parameters ############################################
	MyFeasibilityTol = 1e-6 
		if(haskey(solver_settings, "Feasib_Tol")) MyFeasibilityTol = solver_settings["Feasib_Tol"] end
	MyOptimalityTol = 1e-4
		if(haskey(solver_settings, "Optimal_Tol")) MyOptimalityTol = solver_settings["Optimal_Tol"] end
	MyPresolve = "choose"
		if(haskey(solver_settings, "Pre_Solve")) MyPresolve = solver_settings["Pre_Solve"] end
	MyTimeLimit = Inf
		if(haskey(solver_settings, "TimeLimit")) MyTimeLimit = solver_settings["TimeLimit"] end
	MyMethod = "ipm"
		if(haskey(solver_settings, "Method")) MyMethod = solver_settings["Method"] end
	Myparallel = "choose"
		if(haskey(solver_settings, "parallel")) Myparallel = solver_settings["parallel"] end
	Myranging = "off"
		if(haskey(solver_settings, "ranging")) Myranging = solver_settings["ranging"] end
	Myinfinite_cost = 1e+20
		if(haskey(solver_settings, "infinite_cost")) Myinfinite_cost = solver_settings["infinite_cost"] end
	Myinfinite_bound = 1e+20
		if(haskey(solver_settings, "infinite_bound")) Myinfinite_bound = solver_settings["infinite_bound"] end
	Mysmall_matrix_value = 1e-09
		if(haskey(solver_settings, "small_matrix_value")) Mysmall_matrix_value = solver_settings["small_matrix_value"] end
	Mylarge_matrix_value = 1e+15 	
		if(haskey(solver_settings, "large_matrix_value")) Mylarge_matrix_value = solver_settings["large_matrix_value"] end
	Myipm_optimality_tolerance = 1e-08
		if(haskey(solver_settings, "ipm_optimality_tolerance")) Myipm_optimality_tolerance = solver_settings["ipm_optimality_tolerance"] end
	Myobjective_bound = Inf
		if(haskey(solver_settings, "objective_bound")) Myobjective_bound = solver_settings["objective_bound"] end
	Myobjective_target = -Inf
		if(haskey(solver_settings, "objective_target")) Myobjective_target = solver_settings["objective_target"] end
	Myrandom_seed = 0
		if(haskey(solver_settings, "random_seed")) Myrandom_seed = solver_settings["random_seed"] end
	Mythreads = 0
		if(haskey(solver_settings, "threads")) Mythreads = solver_settings["threads"] end
	Myhighs_debug_level = 0	
		if(haskey(solver_settings, "highs_debug_level")) Myhighs_debug_level = solver_settings["highs_debug_level"] end
	Myhighs_analysis_level = 0
		if(haskey(solver_settings, "highs_analysis_level")) Myhighs_analysis_level = solver_settings["highs_analysis_level"] end
	Mysimplex_strategy = 1
		if(haskey(solver_settings, "simplex_strategy")) Mysimplex_strategy = solver_settings["simplex_strategy"] end
	Mysimplex_scale_strategy = 1
		if(haskey(solver_settings, "simplex_scale_strategy")) Mysimplex_scale_strategy = solver_settings["simplex_scale_strategy"] end
	Mysimplex_crash_strategy = 0
		if(haskey(solver_settings, "simplex_crash_strategy")) Mysimplex_crash_strategy = solver_settings["simplex_crash_strategy"] end
	Mysimplex_dual_edge_weight_strategy = -1
		if(haskey(solver_settings, "simplex_dual_edge_weight_strategy")) Mysimplex_dual_edge_weight_strategy = solver_settings["simplex_dual_edge_weight_strategy"] end
	Mysimplex_primal_edge_weight_strategy = -1
		if(haskey(solver_settings, "simplex_primal_edge_weight_strategy")) Mysimplex_primal_edge_weight_strategy = solver_settings["simplex_primal_edge_weight_strategy"] end
	Mysimplex_iteration_limit = 2147483647
		if(haskey(solver_settings, "simplex_iteration_limit")) Mysimplex_iteration_limit = solver_settings["simplex_iteration_limit"] end
	Mysimplex_update_limit = 5000
		if(haskey(solver_settings, "simplex_update_limit")) Mysimplex_update_limit = solver_settings["simplex_update_limit"] end
	Myipm_iteration_limit = 2147483647
		if(haskey(solver_settings, "ipm_iteration_limit")) Myipm_iteration_limit = solver_settings["ipm_iteration_limit"] end
	Mysimplex_min_concurrency = 1
		if(haskey(solver_settings, "simplex_min_concurrency")) Mysimplex_min_concurrency = solver_settings["simplex_min_concurrency"] end
	Mysimplex_max_concurrency = 8
		if(haskey(solver_settings, "simplex_max_concurrency")) Mysimplex_max_concurrency = solver_settings["simplex_max_concurrency"] end
	Myoutput_flag = true
		if(haskey(solver_settings, "output_flag")) Myoutput_flag = solver_settings["output_flag"] end
	Mylog_to_console = true
		if(haskey(solver_settings, "log_to_console")) Mylog_to_console = solver_settings["log_to_console"] end
	Mysolution_file = ""
		if(haskey(solver_settings, "solution_file")) Mysolution_file = solver_settings["solution_file"] end
	Mylog_file = ""
		if(haskey(solver_settings, "log_file")) Mylog_file = solver_settings["log_file"] end
	Mywrite_solution_to_file = false
		if(haskey(solver_settings, "write_solution_to_file")) Mywrite_solution_to_file = solver_settings["write_solution_to_file"] end
	Mywrite_solution_style = 0
		if(haskey(solver_settings, "write_solution_style")) Mywrite_solution_style = solver_settings["write_solution_style"] end
	Mywrite_model_file = ""	
		if(haskey(solver_settings, "write_model_file")) Mywrite_model_file = solver_settings["write_model_file"] end
	Mywrite_model_to_file = false
		if(haskey(solver_settings, "write_model_to_file")) Mywrite_model_to_file = solver_settings["write_model_to_file"] end
	Mymip_detect_symmetry = true
		if(haskey(solver_settings, "mip_detect_symmetry")) Mymip_detect_symmetry = solver_settings["mip_detect_symmetry"] end
	Mymip_max_nodes = 2147483647
		if(haskey(solver_settings, "mip_max_nodes")) Mymip_max_nodes = solver_settings["mip_max_nodes"] end
	Mymip_max_stall_nodes = 2147483647
		if(haskey(solver_settings, "mip_max_stall_nodes")) Mymip_max_stall_nodes = solver_settings["mip_max_stall_nodes"] end
	Mymip_max_leaves = 2147483647
		if(haskey(solver_settings, "mip_max_leaves")) Mymip_max_leaves = solver_settings["mip_max_leaves"] end
	Mymip_max_improving_sols = 2147483647
		if(haskey(solver_settings, "mip_max_improving_sols")) Mymip_max_improving_sols = solver_settings["mip_max_improving_sols"] end
	Mymip_lp_age_limit = 10	
		if(haskey(solver_settings, "mip_lp_age_limit")) Mymip_lp_age_limit = solver_settings["mip_lp_age_limit"] end
	Mymip_pool_age_limit = 30
		if(haskey(solver_settings, "mip_pool_age_limit")) Mymip_pool_age_limit = solver_settings["mip_pool_age_limit"] end
	Mymip_pool_soft_limit = 10000
		if(haskey(solver_settings, "mip_pool_soft_limit")) Mymip_pool_soft_limit = solver_settings["mip_pool_soft_limit"] end
	Mymip_pscost_minreliable = 8
		if(haskey(solver_settings, "mip_pscost_minreliable")) Mymip_pscost_minreliable = solver_settings["mip_pscost_minreliable"] end
	Mymip_min_cliquetable_entries_for_parallelism = 100000
		if(haskey(solver_settings, "mip_min_cliquetable_entries_for_parallelism")) Mymip_min_cliquetable_entries_for_parallelism = solver_settings["mip_min_cliquetable_entries_for_parallelism"] end
	Mymip_report_level = 1
		if(haskey(solver_settings, "mip_report_level")) Mymip_report_level = solver_settings["mip_report_level"] end
	Mymip_feasibility_tolerance = 1e-06
		if(haskey(solver_settings, "mip_feasibility_tolerance")) Mymip_feasibility_tolerance = solver_settings["mip_feasibility_tolerance"] end
	Mymip_heuristic_effort = 0.05
		if(haskey(solver_settings, "mip_heuristic_effort")) Mymip_heuristic_effort = solver_settings["mip_heuristic_effort"] end
	Mymip_rel_gap = 0.001
		if(haskey(solver_settings, "mip_rel_gap")) Mymip_rel_gap = solver_settings["mip_rel_gap"] end
	Mymip_abs_gap = 1e-06
		if(haskey(solver_settings, "mip_abs_gap")) Mymip_abs_gap = solver_settings["mip_abs_gap"] end
	Mylog_dev_level = 0
		if(haskey(solver_settings, "log_dev_level")) Mylog_dev_level = solver_settings["log_dev_level"] end
	Myrun_crossover = false
		if(haskey(solver_settings, "run_crossover")) Myrun_crossover = solver_settings["run_crossover"] end
	Myallow_unbounded_or_infeasible = false
		if(haskey(solver_settings, "allow_unbounded_or_infeasible")) Myallow_unbounded_or_infeasible = solver_settings["allow_unbounded_or_infeasible"] end
	Myuse_implied_bounds_from_presolve = false
		if(haskey(solver_settings, "use_implied_bounds_from_presolve")) Myuse_implied_bounds_from_presolve = solver_settings["use_implied_bounds_from_presolve"] end
	Mylp_presolve_requires_basis_postsolve = true
		if(haskey(solver_settings, "lp_presolve_requires_basis_postsolve")) Mylp_presolve_requires_basis_postsolve = solver_settings["lp_presolve_requires_basis_postsolve"] end
	Mymps_parser_type_free = true
		if(haskey(solver_settings, "mps_parser_type_free")) Mymps_parser_type_free = solver_settings["mps_parser_type_free"] end
	Mykeep_n_rows = -1 
		if(haskey(solver_settings, "keep_n_rows")) Mykeep_n_rows = solver_settings["keep_n_rows"] end
	Mycost_scale_factor = 0
		if(haskey(solver_settings, "cost_scale_factor")) Mycost_scale_factor = solver_settings["cost_scale_factor"] end
	Myallowed_matrix_scale_factor = 20
		if(haskey(solver_settings, "allowed_matrix_scale_factor")) Myallowed_matrix_scale_factor = solver_settings["allowed_matrix_scale_factor"] end
	Myallowed_cost_scale_factor = 0 
		if(haskey(solver_settings, "allowed_cost_scale_factor")) Myallowed_cost_scale_factor = solver_settings["allowed_cost_scale_factor"] end
	Mysimplex_dualise_strategy = -1
		if(haskey(solver_settings, "simplex_dualise_strategy")) Mysimplex_dualise_strategy = solver_settings["simplex_dualise_strategy"] end
	Mysimplex_permute_strategy = -1
		if(haskey(solver_settings, "simplex_permute_strategy")) Mysimplex_permute_strategy = solver_settings["simplex_permute_strategy"] end
	Mymax_dual_simplex_cleanup_level = 1
		if(haskey(solver_settings, "max_dual_simplex_cleanup_level")) Mymax_dual_simplex_cleanup_level = solver_settings["max_dual_simplex_cleanup_level"] end
	Mymax_dual_simplex_phase1_cleanup_level = 2
		if(haskey(solver_settings, "max_dual_simplex_phase1_cleanup_level")) Mymax_dual_simplex_phase1_cleanup_level = solver_settings["max_dual_simplex_phase1_cleanup_level"] end
	Mysimplex_price_strategy = 3
		if(haskey(solver_settings, "simplex_price_strategy")) Mysimplex_price_strategy = solver_settings["simplex_price_strategy"] end
	Mysimplex_unscaled_solution_strategy = 1
		if(haskey(solver_settings, "simplex_unscaled_solution_strategy")) Mysimplex_unscaled_solution_strategy = solver_settings["simplex_unscaled_solution_strategy"] end
	Mysimplex_initial_condition_check = true
		if(haskey(solver_settings, "simplex_initial_condition_check")) Mysimplex_initial_condition_check = solver_settings["simplex_initial_condition_check"] end
	Myno_unnecessary_rebuild_refactor = true
		if(haskey(solver_settings, "no_unnecessary_rebuild_refactor")) Myno_unnecessary_rebuild_refactor = solver_settings["no_unnecessary_rebuild_refactor"] end
	Mysimplex_initial_condition_tolerance = 1e+14 
		if(haskey(solver_settings, "simplex_initial_condition_tolerance")) Mysimplex_initial_condition_tolerance = solver_settings["simplex_initial_condition_tolerance"] end
	Myrebuild_refactor_solution_error_tolerance = 1e-08
		if(haskey(solver_settings, "rebuild_refactor_solution_error_tolerance")) Myrebuild_refactor_solution_error_tolerance = solver_settings["rebuild_refactor_solution_error_tolerance"] end
	Mydual_steepest_edge_weight_error_tolerance = Inf
		if(haskey(solver_settings, "dual_steepest_edge_weight_error_tolerance")) Mydual_steepest_edge_weight_error_tolerance = solver_settings["dual_steepest_edge_weight_error_tolerance"] end
	Mydual_steepest_edge_weight_log_error_threshold = 10.0
		if(haskey(solver_settings, "dual_steepest_edge_weight_log_error_threshold")) Mydual_steepest_edge_weight_log_error_threshold = solver_settings["dual_steepest_edge_weight_log_error_threshold"] end
	Mydual_simplex_cost_perturbation_multiplier = 1.0
		if(haskey(solver_settings, "dual_simplex_cost_perturbation_multiplier")) Mydual_simplex_cost_perturbation_multiplier = solver_settings["dual_simplex_cost_perturbation_multiplier"] end
	Myprimal_simplex_bound_perturbation_multiplier = 1.0
		if(haskey(solver_settings, "primal_simplex_bound_perturbation_multiplier")) Myprimal_simplex_bound_perturbation_multiplier = solver_settings["primal_simplex_bound_perturbation_multiplier"] end
	Mydual_simplex_pivot_growth_tolerance = 1e-09
		if(haskey(solver_settings, "dual_simplex_pivot_growth_tolerance")) Mydual_simplex_pivot_growth_tolerance = solver_settings["dual_simplex_pivot_growth_tolerance"] end
	Mypresolve_pivot_threshold = 0.01
		if(haskey(solver_settings, "presolve_pivot_threshold")) Mypresolve_pivot_threshold = solver_settings["presolve_pivot_threshold"] end
	Mypresolve_substitution_maxfillin = 10
		if(haskey(solver_settings, "presolve_substitution_maxfillin")) Mypresolve_substitution_maxfillin = solver_settings["presolve_substitution_maxfillin"] end
	Myfactor_pivot_threshold = 0.1
		if(haskey(solver_settings, "factor_pivot_threshold")) Myfactor_pivot_threshold = solver_settings["factor_pivot_threshold"] end
	Myfactor_pivot_tolerance = 1e-10
		if(haskey(solver_settings, "factor_pivot_tolerance")) Myfactor_pivot_tolerance = solver_settings["factor_pivot_tolerance"] end
	Mystart_crossover_tolerance = 1e-08
		if(haskey(solver_settings, "start_crossover_tolerance")) Mystart_crossover_tolerance = solver_settings["start_crossover_tolerance"] end
	Myuse_original_HFactor_logic = true
		if(haskey(solver_settings, "use_original_HFactor_logic")) Myuse_original_HFactor_logic = solver_settings["use_original_HFactor_logic"] end
	Myless_infeasible_DSE_check = true
		if(haskey(solver_settings, "less_infeasible_DSE_check")) Myless_infeasible_DSE_check = solver_settings["less_infeasible_DSE_check"] end
	Myless_infeasible_DSE_choose_row = true
		if(haskey(solver_settings, "less_infeasible_DSE_choose_row")) Myless_infeasible_DSE_choose_row = solver_settings["less_infeasible_DSE_choose_row"] end
	########################################################################

	OPTIMIZER = optimizer_with_attributes(HiGHS.Optimizer,
		"primal_feasibility_tolerance" => MyFeasibilityTol,
		"dual_feasibility_tolerance" => MyOptimalityTol,
		"time_limit" => MyTimeLimit,
		"presolve" => MyPresolve,
		"solver" => MyMethod,
		"parallel" => Myparallel,
		"ranging" => Myranging,
		"infinite_cost" => Myinfinite_cost,
		"infinite_bound" => Myinfinite_bound,
		"small_matrix_value" => Mysmall_matrix_value,
		"large_matrix_value" => Mylarge_matrix_value,
		"ipm_optimality_tolerance" => Myipm_optimality_tolerance,
		"objective_bound" => Myobjective_bound,
		"objective_target" => Myobjective_target,
		"random_seed" => Myrandom_seed,
		"threads" => Mythreads,
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
		"simplex_min_concurrency" => Mysimplex_min_concurrency,
		"simplex_max_concurrency" => Mysimplex_max_concurrency,
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
