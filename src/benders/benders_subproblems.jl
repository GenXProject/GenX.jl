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
    EP.ext[:solver] = OPTIMIZER
    if haskey(setup, "ptdf")
        if setup["ptdf"] == 1
            if get_optimizer_attribute(OPTIMIZER, "ObjScale") > 1e3
                set_optimizer_attribute(OPTIMIZER, "ObjScale", 1e-1)
            end
        end
    end
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

function init_local_subproblems!(setup::Dict,inputs_local::Vector,subproblems_local::Vector{Dict{Any,Any}},planning_variables::Vector{String},OPTIMIZER::MOI.OptimizerWithAttributes)

    nW = length(inputs_local)

    for i=1:nW
		EP, planning_variables_sub = init_subproblem(setup,inputs_local[i],OPTIMIZER,planning_variables);
        subproblems_local[i]["Model"] = EP;
        subproblems_local[i]["planning_variables_sub"] = planning_variables_sub
        subproblems_local[i]["SubPeriod"] = inputs_local[i]["SubPeriod"];
    end
end

function init_dist_subproblems(setup::Dict,inputs_decomp::Dict,planning_variables::Vector{String})

    ##### Initialize a distributed arrays of JuMP models
	## Start pre-solve timer
	subproblem_generation_time = time()
    
    subproblems_all = distribute([Dict() for i in 1:length(inputs_decomp)]);

    @sync for p in workers()
        @async @spawnat p begin
            W_local = localindices(subproblems_all)[1];
            inputs_local = [inputs_decomp[k] for k in W_local];
			SUBPROB_OPTIMIZER =  configure_benders_subprob_solver(setup["settings_path"]);
            init_local_subproblems!(setup,inputs_local,localpart(subproblems_all),planning_variables,SUBPROB_OPTIMIZER);
        end
    end

	p_id = workers();
    np_id = length(p_id);

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

function configure_benders_subprob_solver(solver_settings_path::String)

	gurobi_settings_path = joinpath(solver_settings_path, "gurobi_benders_subprob_settings.yml")

	mysettings = convert(Dict{String, Any}, YAML.load(open(gurobi_settings_path)))

	settings = Dict("Crossover"=>1,"Method"=>2,"BarConvTol"=>1e-3);

	attributes = merge(settings, mysettings)

	println("Subproblem Gurobi attributes:")
	display(attributes)

    OPTIMIZER = optimizer_with_attributes(()->Gurobi.Optimizer(GRB_ENV[]),attributes...)

	return OPTIMIZER
end

function get_local_planning_variables(subproblems_local::Vector{Dict{Any,Any}})

    local_variables=Dict();

    for m in subproblems_local
		w = m["SubPeriod"];
        local_variables[w] = m["planning_variables_sub"]
    end

    return local_variables


end

function solve_dist_subproblems(EP_subproblems::DArray{Dict{Any, Any}, 1, Vector{Dict{Any, Any}}},planning_sol::NamedTuple,inputs)

    p_id = workers();
    np_id = length(p_id);

    sub_results = [Dict() for k in 1:np_id];
    has_duals_indicator = [true for k in 1:np_id]

    @sync for k in 1:np_id
              @async sub_results[k], has_duals_indicator[k] = @fetchfrom p_id[k] solve_local_subproblem(localpart(EP_subproblems),planning_sol,inputs); ### This is equivalent to fetch(@spawnat p .....)

    end

	sub_results = merge(sub_results...);
    has_duals = all(has_duals_indicator)

    return sub_results, has_duals
end

function solve_local_subproblem(subproblem_local::Vector{Dict{Any,Any}},planning_sol::NamedTuple,inputs)

    local_sol=Dict();
    has_duals = [true]
    for m in subproblem_local
        EP = m["Model"];
        planning_variables_sub = m["planning_variables_sub"]
        w = m["SubPeriod"];
		local_sol[w] = solve_subproblem(EP,planning_sol,planning_variables_sub,inputs);
        if !(local_sol[w].has_duals)
            has_duals[1] = false
        end
    end
    return local_sol, has_duals[1]
end

function solve_subproblem(EP::Model,planning_sol::NamedTuple,planning_variables_sub::Vector{String},inputs)
	fix_planning_variables!(EP,planning_sol,planning_variables_sub)

    new_optimizer = EP.ext[:solver]
    if get_optimizer_attribute(new_optimizer, "ObjScale") != get_optimizer_attribute(EP, "ObjScale")
        set_optimizer(EP, new_optimizer)
    end

	t = @elapsed optimize!(EP)
	println("Time for solving subproblem was ", t/60, " minutes")
	flush(stdout)

    if !haskey(EP.ext, :idx)
        EP.ext[:idx] = [1.]
    end
	
	if has_values(EP)
		op_cost = objective_value(EP);
        zone_cost = 0#make_benders_zonal_opcost(inputs,EP)
		emissions = value.(EP[:eEmissionsByZone])
        original_obj_scale = get_attribute(EP, "ObjScale")
        lambda=[]
        if dual_status(EP) == MOI.NO_SOLUTION
            @warn "No solution with Gurobi; trying to skip this cut"

            for y in planning_variables_sub
                push!(lambda, 0.)#dual(FixRef(vy)))
            end
            theta_coeff = 1;
            if haskey(EP,:eObjSlack)
                feasibility_slack = value(EP[:eObjSlack]);
            else
                feasibility_slack = 0.0;
            end
            summation_sol_map = Dict{String, Float64}()
            summation_sol_map["vNSE"] = sum(value.(EP[:vNSE]))
            summation_sol_map["vP"] = sum(value.(EP[:vP]))
            #summation_sol_map["OverProduction"] = sum(value.(EP[:vOverProduction]))
            avs = all_variables(EP)
            vals = value.(avs)
            sol_map = Dict{String, Float64}()
            for (i, var) in enumerate(avs)
                sol_map[name(var)] = vals[i]
            end
            op_cost = objective_value(EP)
            return (op_cost=op_cost,zone_cost = zone_cost, emissions = emissions,lambda = lambda,theta_coeff=theta_coeff,feasibility_slack=feasibility_slack, solution_map=sol_map, summation_map=summation_sol_map, has_duals = false, cut_value = 0.)
        elseif !has_values(EP)
            error("NO SOLUTIONS COMPUTED!")
        end

        for y in planning_variables_sub
            vy = variable_by_name(EP,y)
		    if is_parameter(vy)
                push!(lambda, dual(ParameterRef(vy)))
            else
                push!(lambda, dual(FixRef(vy)))
            end
        end
		theta_coeff = 1;
		if haskey(EP,:eObjSlack)
			feasibility_slack = value(EP[:eObjSlack]);
		else
			feasibility_slack = 0.0;
		end
        summation_sol_map = Dict{String, Float64}()
        summation_sol_map["vNSE"] = sum(value.(EP[:vNSE]))
        summation_sol_map["vP"] = sum(value.(EP[:vP]))
	else
        println("TERMINATION_STATUS = ", termination_status(EP))
        JuMP.write_to_file(EP, (@__DIR__)*"/numerical_error_file.lp")
		op_cost = 0;
        summation_sol_map = Dict()
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
		@warn "The subproblem solution failed. This should not happen, double check the input files"
	end

    avs = all_variables(EP)
    vals = value.(avs)
    sol_map = Dict{String, Float64}()
    for (i, var) in enumerate(avs)
        sol_map[name(var)] = vals[i]
    end
    
	return (op_cost=op_cost,zone_cost = zone_cost, emissions = emissions,lambda = lambda,theta_coeff=theta_coeff,feasibility_slack=feasibility_slack, solution_map=sol_map, summation_map=summation_sol_map, has_duals=true, cut_value = op_cost)

end

function fix_planning_variables!(EP::Model,planning_sol::NamedTuple,planning_variables_sub::Vector{String})
	for y in planning_variables_sub
		vy = variable_by_name(EP,y);
        if is_parameter(vy)
            # vCAP and vNEW_TRANS_CAP cannot be less than 0
            if occursin("CAP", name(vy)) || occursin("TRANS", name(vy))
                if planning_sol.values[y] < 1e-15
                    set_parameter_value(vy, 0)
                else
                    set_parameter_value(vy,planning_sol.values[y])
                end
            else
                set_parameter_value(vy,planning_sol.values[y])
            end
        else
            # vCAP and vNEW_TRANS_CAP cannot be less than 0
            if occursin("CAP", name(vy)) || occursin("TRANS", name(vy))
                if planning_sol.values[y] < 0
                    fix(vy, 0; force = true)
                else
                    fix(vy,planning_sol.values[y];force=true)
                end
            else
                fix(vy,planning_sol.values[y];force=true)
            end
        end
		if is_integer(vy)
			unset_integer(vy)
		elseif is_binary(vy)
			unset_binary(vy)
		end
	end
end