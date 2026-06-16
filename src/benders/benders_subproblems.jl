
function generate_operation_subproblem(setup::Dict, inputs::Dict, OPTIMIZER::MOI.OptimizerWithAttributes)
    ## Start pre-solve timer
    presolver_start_time = time()
    EP = Model(OPTIMIZER)

    #set_string_names_on_creation(EP, Bool(setup["EnableJuMPStringNames"]))
    # Introduce dummy variable fixed to zero to ensure that expressions like eTotalCap,
    # eTotalCapCharge, eTotalCapEnergy and eAvail_Trans_Cap all have a JuMP variable
    @variable(EP, vZERO==0)

    # Initialize Objective Function Expression
    EP[:eObj] = AffExpr(0.0)

    operation_model!(EP,setup,inputs)

    ## Define the objective function
    @objective(EP, Min, setup["ObjScale"]*EP[:eObj])

    ## Record pre-solver time
    presolver_time = time() - presolver_start_time

    return EP
end

function init_subproblem(setup::Dict, inputs::Dict, OPTIMIZER::MOI.OptimizerWithAttributes,planning_variables::Vector{String})
    EP = generate_operation_subproblem(setup, inputs, OPTIMIZER)

    set_silent(EP)

    planning_variables_sub = intersect(name.(all_variables(EP)),planning_variables);

	for sv in planning_variables_sub
		if has_lower_bound(variable_by_name(EP,sv))
			delete_lower_bound(variable_by_name(EP,sv))
		end
		if has_upper_bound(variable_by_name(EP,sv))
			delete_upper_bound(variable_by_name(EP,sv))
		end
		set_objective_coefficient(EP,variable_by_name(EP,sv),0)
	end

    return EP, planning_variables_sub
end

function init_local_subproblems!(setup::Dict,inputs_local::Vector{Dict{Any,Any}},subproblems_local::Vector{Dict{Any,Any}},planning_variables::Vector{String},OPTIMIZER::MOI.OptimizerWithAttributes)

    nW = length(inputs_local)

    for i=1:nW
		EP, planning_variables_sub = init_subproblem(setup,inputs_local[i],OPTIMIZER,planning_variables);
        subproblems_local[i][:model] = EP;
        subproblems_local[i][:linking_variables_sub] = planning_variables_sub
        subproblems_local[i][:subproblem_index] = inputs_local[i]["SubPeriod"];
    end
end

function init_dist_subproblems(setup::Dict, inputs_decomp::Dict, planning_variables::Vector{String}, optimizer::Any)

    ##### Initialize a distributed arrays of JuMP models
	## Start pre-solve timer
	subproblem_generation_time = time()

    subproblems_all = distribute([Dict() for i in 1:length(inputs_decomp)]);

    p_id = workers();
    np_id = length(p_id);

    # Pre-compute the DArray partition on the master so each worker only receives its own
    # slice of inputs_decomp rather than the full dictionary.  Capturing the full
    # inputs_decomp in every @spawnat closure would serialise all subperiod data (potentially
    # hundreds of GB) for each of the np_id workers, causing an apparent hang.
    da_pids    = vec(subproblems_all.pids)
    da_indices = vec(subproblems_all.indices)
    pid_to_range = Dict(da_pids[k] => da_indices[k][1] for k in 1:length(da_pids))

    init_futures = Vector{Future}(undef, np_id)
    for k in 1:np_id
        p = p_id[k]
        # Extract only this worker's subperiod inputs here on the master.
        W_local      = get(pid_to_range, p, 1:0)
        inputs_local = [inputs_decomp[idx] for idx in W_local]
        init_futures[k] = @spawnat p begin
			SUBPROB_OPTIMIZER = configure_benders_subprob_solver(setup["settings_path"], optimizer);
            init_local_subproblems!(setup,inputs_local,localpart(subproblems_all),planning_variables,SUBPROB_OPTIMIZER);
            return (worker = myid(), n_local = length(inputs_local))
        end
    end

    for k in 1:np_id
        p = p_id[k]
        result = fetch(init_futures[k])
    end

    planning_variables_sub = [Dict() for k in 1:np_id];

    @sync for k in 1:np_id
              @async planning_variables_sub[k]= @fetchfrom p_id[k] get_local_planning_variables(localpart(subproblems_all))
    end

	planning_variables_sub = merge(planning_variables_sub...);

    ## Record pre-solver time
	subproblem_generation_time = time() - subproblem_generation_time
	println("Distributed operational subproblems generation took $subproblem_generation_time seconds")

    return subproblems_all,planning_variables_sub

end

"""
    configure_benders_subprob_solver(solver_settings_path, optimizer)

Return a solver `OptimizerWithAttributes` for Benders operational subproblems.
Looks first for `{solver}_benders_subprob_settings.yml` in `solver_settings_path`,
falling back to `{solver}_settings.yml`.
"""
function configure_benders_subprob_solver(solver_settings_path::String, optimizer::Any)
    solver_name = infer_solver(optimizer)
    benders_file = joinpath(solver_settings_path, "$(solver_name)_benders_subprob_settings.yml")
    std_file     = joinpath(solver_settings_path, "$(solver_name)_settings.yml")
    settings_file = isfile(benders_file) ? benders_file : std_file
    @info "Benders subproblem solver: $solver_name (settings from $(basename(settings_file)))"
    return _benders_configure_solver(settings_file, optimizer, solver_name)
end

function get_local_planning_variables(subproblems_local::Vector{Dict{Any,Any}})

    local_variables=Dict();

    for m in subproblems_local
		w = m[:subproblem_index];
        local_variables[w] = m[:linking_variables_sub]
    end

    return local_variables


end

function update_with_subproblem_solutions!(subproblems::Union{Vector{Dict{Any, Any}},DistributedArrays.DArray}, results::NamedTuple)

    subop_sol = MacroEnergySolvers.solve_subproblems(subproblems, results.planning_sol, true)

    results = (; results..., subop_sol = subop_sol)

    return nothing
    
end