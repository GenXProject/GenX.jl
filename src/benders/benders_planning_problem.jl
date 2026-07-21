@doc raw"""
	generate_planning_problem(setup, inputs, OPTIMIZER)

Build and return the Benders master (planning) JuMP model.

Calls `planning_model!` to add capacity expansion variables and constraints, then adds one
recourse-value variable `vTHETA[w]` per representative period and minimizes total fixed cost
plus the sum of those recourse approximations.  Also constructs the expression
`eAvailableCapacity` (scalar sum over all installed capacity variables) used by
the Benders algorithm.

Raises an error if retrofits or multi-stage planning are enabled, as these are not yet
compatible with Benders decomposition.
"""
function generate_planning_problem(setup::Dict, inputs::Dict, OPTIMIZER::MOI.OptimizerWithAttributes)

    ## Start pre-solve timer
    presolver_start_time = time()
    EP = Model(OPTIMIZER)

    #set_string_names_on_creation(EP, Bool(setup["EnableJuMPStringNames"]))
    # Introduce dummy variable fixed to zero to ensure that expressions like eTotalCap,
    # eTotalCapCharge, eTotalCapEnergy and eAvail_Trans_Cap all have a JuMP variable
    @variable(EP, vZERO==0)

	if !isempty(inputs["RETROFIT_OPTIONS"])
		error("Benders not yet supported with retrofits")
	elseif setup["MultiStage"] > 0
		error("Multistage and Benders are not integrated yet.")
	end

    # Initialize Objective Function Expression
    EP[:eObj] = AffExpr(0.0)

    planning_model!(EP,setup,inputs)

    @variable(EP,vTHETA[1:inputs["REP_PERIOD"]]>=setup[:ThetaLB])

    ## Define the objective function
    @objective(EP, Min, setup["ObjScale"]*(EP[:eObj]+sum(vTHETA)))

	@expression(EP, eAvailableCapacity, sum(EP[:eTotalCap]))
	if haskey(EP, :eTotalCap_AllamcycleLOX)
		add_to_expression!(EP[:eAvailableCapacity], sum(EP[:eTotalCap_AllamcycleLOX]))
	end
	if haskey(EP, :eTotalCapCharge)
		add_to_expression!(EP[:eAvailableCapacity], sum(EP[:eTotalCapCharge]))
	end
	if haskey(EP, :eTotalCapEnergy)
		add_to_expression!(EP[:eAvailableCapacity], sum(EP[:eTotalCapEnergy]))
	end
	if haskey(EP, :vNEW_TRANS_CAP)
		add_to_expression!(EP[:eAvailableCapacity], sum(EP[:vNEW_TRANS_CAP]))
	end

    ## Record pre-solver time
    presolver_time = time() - presolver_start_time

    return EP
end

@doc raw"""
	init_planning_problem(setup, inputs, optimizer)

Initialize the Benders master problem and return `(EP, varnames)`.

Configures the planning solver via `configure_benders_planning_solver`, builds the model
with `generate_planning_problem`, and returns the JuMP model together with the names of all
decision variables except `vZERO` and `vTHETA` (i.e., the linking/planning variables that
will be fixed in subproblems).
"""
function init_planning_problem(setup::Dict, inputs::Dict, optimizer::Any)

    OPTIMIZER = configure_benders_planning_solver(setup["settings_path"], optimizer);

    EP = generate_planning_problem(setup, inputs, OPTIMIZER);

	varnames = name.(setdiff(all_variables(EP), [EP[:vZERO]; EP[:vTHETA]]));

	set_silent(EP);

    return EP, varnames

end

@doc raw"""
    configure_benders_planning_solver(solver_settings_path, optimizer)

Return a solver `OptimizerWithAttributes` for the Benders planning (master) problem.

Looks first for `{solver}_benders_planning_settings.yml` in `solver_settings_path`,
falling back to `{solver}_settings.yml`. Supports any solver that GenX's
`configure_solver` infrastructure supports (HiGHS, Gurobi, CPLEX, Clp, Cbc, SCIP).
"""
function configure_benders_planning_solver(solver_settings_path::String, optimizer::Any)
    solver_name = infer_solver(optimizer)
    benders_file = joinpath(solver_settings_path, "$(solver_name)_benders_planning_settings.yml")
    std_file     = joinpath(solver_settings_path, "$(solver_name)_settings.yml")
    settings_file = isfile(benders_file) ? benders_file : std_file
    @info "Benders planning solver: $solver_name (settings from $(basename(settings_file)))"
    return _benders_configure_solver(settings_file, optimizer, solver_name)
end

# Private helper: dispatch to the appropriate solver-specific configure function.
const _BENDERS_CONFIGURE_FUNCTIONS = Dict{String, Function}(
    "highs"  => configure_highs,
    "gurobi" => configure_gurobi,
    "cplex"  => configure_cplex,
    "clp"    => configure_clp,
    "cbc"    => configure_cbc,
    "scip"   => configure_scip,
)

@doc raw"""
	_benders_configure_solver(settings_file, optimizer, solver_name)

Private helper: look up `solver_name` in `_BENDERS_CONFIGURE_FUNCTIONS` and call the
matching solver-specific configure function with `settings_file` and `optimizer`.
Raises an error listing supported solvers if `solver_name` is not recognised.
"""
function _benders_configure_solver(settings_file::String, optimizer::Any, solver_name::String)
    configure_fn = get(_BENDERS_CONFIGURE_FUNCTIONS, solver_name, nothing)
    if isnothing(configure_fn)
        supported = join(sort(collect(keys(_BENDERS_CONFIGURE_FUNCTIONS))), ", ")
        error("Solver '$solver_name' is not supported for Benders decomposition. Supported solvers: $supported")
    end
    return configure_fn(settings_file, optimizer)
end

@doc raw"""
	update_with_planning_solution!(planning_problem, planning_variable_values)

Fix every planning variable in `planning_problem` to the value supplied in
`planning_variable_values` (a `Dict` mapping variable name → value), then re-solve
the model.  Used after Benders convergence to realign the planning problem with a
specific first-stage solution (e.g. the best incumbent) so that capacity and
dual-based outputs are read from that solution rather than the last master solve.

If the fixed re-solve does not yield a primal solution (e.g. a numerically infeasible
fixing), the fixings are reverted and the model is re-solved unfixed so that the
caller is left with a usable solution instead of an empty one. Returns `true` when the
planning problem holds a primal solution at the requested values, `false` otherwise.
"""
function update_with_planning_solution!(planning_problem::JuMP.Model, planning_variable_values::Dict)
	# Fix the planning variables, remembering their prior lower bounds so the fixing can
	# be cleanly reverted if the re-solve fails.
	fixed_vars = JuMP.VariableRef[]
	prior_lower_bounds = Dict{JuMP.VariableRef, Union{Nothing, Float64}}()
	for var in all_variables(planning_problem)
		var_name = name(var)
		if haskey(planning_variable_values, var_name)
			prior_lower_bounds[var] = has_lower_bound(var) ? lower_bound(var) : nothing
			fix(var, planning_variable_values[var_name], force = true)
			push!(fixed_vars, var)
		end
	end

	optimize!(planning_problem)

	if has_values(planning_problem)
		return true
	end

	# Realignment failed: revert the fixings and recover the unfixed solution so that
	# downstream output writing still has a valid (if not incumbent-aligned) solution.
	@warn "update_with_planning_solution!: fixed re-solve returned no primal solution " *
		  "(status: $(termination_status(planning_problem))). Reverting fixings and " *
		  "re-solving unfixed; capacity/dual outputs will reflect the last master solve."
	for var in fixed_vars
		unfix(var)
		lb = prior_lower_bounds[var]
		isnothing(lb) || set_lower_bound(var, lb)
	end
	optimize!(planning_problem)
	return false
end