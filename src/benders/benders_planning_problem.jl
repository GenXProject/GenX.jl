function generate_planning_problem(setup::Dict, inputs::Dict, OPTIMIZER::MOI.OptimizerWithAttributes)

    ## Start pre-solve timer
    presolver_start_time = time()
    EP = Model(OPTIMIZER)

    #set_string_names_on_creation(EP, Bool(setup["EnableJuMPStringNames"]))
    # Introduce dummy variable fixed to zero to ensure that expressions like eTotalCap,
    # eTotalCapCharge, eTotalCapEnergy and eAvail_Trans_Cap all have a JuMP variable
    @variable(EP, vZERO==0)

	if !isempty(inputs["VRE_STOR"])
		error("Benders not yet supported with VRE-STOR")
	elseif !isempty(inputs["RETROFIT_OPTIONS"])
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

function init_planning_problem(setup::Dict, inputs::Dict, optimizer::Any)

    OPTIMIZER = configure_benders_planning_solver(setup["settings_path"], optimizer);

    EP = generate_planning_problem(setup, inputs, OPTIMIZER);

	varnames = name.(setdiff(all_variables(EP), [EP[:vZERO]; EP[:vTHETA]]));

	set_silent(EP);

    return EP, varnames

end

"""
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

function _benders_configure_solver(settings_file::String, optimizer::Any, solver_name::String)
    configure_fn = get(_BENDERS_CONFIGURE_FUNCTIONS, solver_name, nothing)
    if isnothing(configure_fn)
        supported = join(sort(collect(keys(_BENDERS_CONFIGURE_FUNCTIONS))), ", ")
        error("Solver '$solver_name' is not supported for Benders decomposition. Supported solvers: $supported")
    end
    return configure_fn(settings_file, optimizer)
end

function solve_planning_problem(EP::Model,planning_variables::Vector{String})
	
	if any(is_integer.(all_variables(EP)))
		println("The planning model is a MILP")
		optimize!(EP)
			if has_values(EP) #
				planning_sol =  (LB = objective_value(EP), inv_cost =value(EP[:eObj]), values =Dict([s=>value.(variable_by_name(EP,s)) for s in planning_variables]), theta = value.(EP[:vTHETA])) 
			else
				compute_conflict!(EP)
				list_of_conflicting_constraints = ConstraintRef[];
				for (F, S) in list_of_constraint_types(EP)
					for con in all_constraints(EP, F, S)
						if get_attribute(con, MOI.ConstraintConflictStatus()) == MOI.IN_CONFLICT
							push!(list_of_conflicting_constraints, con)
						end
					end
				end
				display(list_of_conflicting_constraints)
				@error "The planning solution failed. This should not happen"
			end
	else 
		### The planning model is an LP
		optimize!(EP)
		if has_values(EP)
			neg_cap_bool = check_negative_capacities(EP);
			
			if neg_cap_bool
				println("***Resolving the planning problem with Crossover=1 because of negative capacities***")
				set_attribute(EP, "Crossover", 1)
				#set_attribute(EP, "BarHomogeneous", 1)
				optimize!(EP)
				if has_values(EP)
					planning_sol =  (LB = objective_value(EP), inv_cost =value(EP[:eObj]), values =Dict([s=>value.(variable_by_name(EP,s)) for s in planning_variables]), theta = value.(EP[:vTHETA])) 
					set_attribute(EP, "Crossover", 0)
					#set_attribute(EP, "BarHomogeneous", -1)
				else			
					println("The planning problem solution failed, trying with BarHomogenous=1")
					set_attribute(EP, "BarHomogeneous", 1)
					optimize!(EP)
					if has_values(EP)
						planning_sol =  (LB = objective_value(EP), inv_cost =value(EP[:eObj]), values =Dict([s=>value.(variable_by_name(EP,s)) for s in planning_variables]), theta = value.(EP[:vTHETA])) 
						set_attribute(EP, "BarHomogeneous", -1)
					else
						@error "The planning solution failed. This should not happen"
					end
				end
			else
				planning_sol =  (LB = objective_value(EP), inv_cost =value(EP[:eObj]), values =Dict([s=>value.(variable_by_name(EP,s)) for s in planning_variables]), theta = value.(EP[:vTHETA])) 
			end
		else
			println("The planning problem solution failed, trying with BarHomogenous=1")
			set_attribute(EP, "BarHomogeneous", 1)
			optimize!(EP)
			if has_values(EP)
				planning_sol =  (LB = objective_value(EP), inv_cost =value(EP[:eObj]), values =Dict([s=>value.(variable_by_name(EP,s)) for s in planning_variables]), theta = value.(EP[:vTHETA])) 
				set_attribute(EP, "BarHomogeneous", -1)
			else
				@error "The planning solution failed. This should not happen"
			end

		end
	end

	return planning_sol

end

function update_with_planning_solution!(planning_problem::JuMP.Model, planning_variable_values::Dict)
	# fix planning_variables
	all_vars = all_variables(planning_problem)
	for var in all_vars
		var_name = name(var)
		if haskey(planning_variable_values, var_name)
			fix(var, planning_variable_values[var_name], force=true)
		end
	end

	optimize!(planning_problem)
	return nothing
end