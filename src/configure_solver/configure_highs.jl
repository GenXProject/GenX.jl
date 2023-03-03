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
	# [type: string, advanced: "on", range: {"off", "on"}, default: "off"]
	run_crossover: "off"
	
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
	solver_settings = convert(Dict{String, Any}, solver_settings)

    default_settings = Dict{String,Any}(
        "Feasib_Tol" => 1e-6,
        "Optimal_Tol" => 1e-4,
        "Pre_Solve" => "choose",
        "TimeLimit" => Inf,
        "Method" => "ipm",
        "parallel" => "choose",
        "ranging" => "off",
        "infinite_cost" => 1e+20,
        "infinite_bound" => 1e+20,
        "small_matrix_value" => 1e-09,
        "large_matrix_value" => 1e+15,
        "ipm_optimality_tolerance" => 1e-08,
        "objective_bound" => Inf,
        "objective_target" => -Inf,
        "random_seed" => 0,
        "threads" => 0,
        "highs_debug_level" => 0,
        "highs_analysis_level" => 0,
        "simplex_strategy" => 1,
        "simplex_scale_strategy" => 1,
        "simplex_crash_strategy" => 0,
        "simplex_dual_edge_weight_strategy" => -1,
        "simplex_primal_edge_weight_strategy" => -1,
        "simplex_iteration_limit" => 2147483647,
        "simplex_update_limit" => 5000,
        "ipm_iteration_limit" => 2147483647,
        "simplex_min_concurrency" => 1,
        "simplex_max_concurrency" => 8,
        "output_flag" => true,
        "log_to_console" => true,
        "solution_file" => "",
        "log_file" => "",
        "write_solution_to_file" => false,
        "write_solution_style" => 0,
        "write_model_file" => "",
        "write_model_to_file" => false,
        "mip_detect_symmetry" => true,
        "mip_max_nodes" => 2147483647,
        "mip_max_stall_nodes" => 2147483647,
        "mip_max_leaves" => 2147483647,
        "mip_max_improving_sols" => 2147483647,
        "mip_lp_age_limit" => 10,
        "mip_pool_age_limit" => 30,
        "mip_pool_soft_limit" => 10000,
        "mip_pscost_minreliable" => 8,
        "mip_min_cliquetable_entries_for_parallelism" => 100000,
        "mip_report_level" => 1,
        "mip_feasibility_tolerance" => 1e-06,
        "mip_heuristic_effort" => 0.05,
        "mip_rel_gap" => 0.001,
        "mip_abs_gap" => 1e-06,
        "log_dev_level" => 0,
        "run_crossover" => "off",
        "allow_unbounded_or_infeasible" => false,
        "use_implied_bounds_from_presolve" => false,
        "lp_presolve_requires_basis_postsolve" => true,
        "mps_parser_type_free" => true,
        "keep_n_rows" => -1,
        "cost_scale_factor" => 0,
        "allowed_matrix_scale_factor" => 20,
        "allowed_cost_scale_factor" => 0,
        "simplex_dualise_strategy" => -1,
        "simplex_permute_strategy" => -1,
        "max_dual_simplex_cleanup_level" => 1,
        "max_dual_simplex_phase1_cleanup_level" => 2,
        "simplex_price_strategy" => 3,
        "simplex_unscaled_solution_strategy" => 1,
        "simplex_initial_condition_check" => true,
        "no_unnecessary_rebuild_refactor" => true,
        "simplex_initial_condition_tolerance" => 1e+14,
        "rebuild_refactor_solution_error_tolerance" => 1e-08,
        "dual_steepest_edge_weight_error_tolerance" => Inf,
        "dual_steepest_edge_weight_log_error_threshold" => 10.0,
        "dual_simplex_cost_perturbation_multiplier" => 1.0,
        "primal_simplex_bound_perturbation_multiplier" => 1.0,
        "dual_simplex_pivot_growth_tolerance" => 1e-09,
        "presolve_pivot_threshold" => 0.01,
        "presolve_substitution_maxfillin" => 10,
        "factor_pivot_threshold" => 0.1,
        "factor_pivot_tolerance" => 1e-10,
        "start_crossover_tolerance" => 1e-08,
        "use_original_HFactor_logic" => true,
        "less_infeasible_DSE_check" => true,
        "less_infeasible_DSE_choose_row" => true,
    )

    attributes = merge(default_settings, solver_settings)

    key_replacement = Dict("Feasib_Tol" => "primal_feasibility_tolerance",
                           "Optimal_Tol" => "dual_feasibility_tolerance",
                           "TimeLimit" => "time_limit",
                           "Pre_Solve" => "presolve",
                           "Method" => "solver",
                          )

    attributes = rename_keys(attributes, key_replacement)

    attributes::Dict{String, Any}
    return optimizer_with_attributes(HiGHS.Optimizer, attributes...)
end
