
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

function solve_dist_subproblems(EP_subproblems::DArray{Dict{Any, Any}, 1, Vector{Dict{Any, Any}}},planning_sol::NamedTuple)

    p_id = workers();
    np_id = length(p_id);

    sub_results = [Dict() for k in 1:np_id];

    @sync for k in 1:np_id
              @async sub_results[k]= @fetchfrom p_id[k] solve_local_subproblem(localpart(EP_subproblems),planning_sol); ### This is equivalent to fetch(@spawnat p .....)
    end

	sub_results = merge(sub_results...);

    return sub_results
end

function solve_local_subproblem(subproblem_local::Vector{Dict{Any,Any}},planning_sol::NamedTuple)

    local_sol=Dict();
    for m in subproblem_local
        EP = m["Model"];
        planning_variables_sub = m["planning_variables_sub"]
        w = m["SubPeriod"];
		local_sol[w] = solve_subproblem(EP,planning_sol,planning_variables_sub);
    end
    return local_sol
end

function solve_subproblem(EP::Model,planning_sol::NamedTuple,planning_variables_sub::Vector{String})

	
	fix_planning_variables!(EP,planning_sol,planning_variables_sub)

	optimize!(EP)
	
	if has_values(EP)
		op_cost = objective_value(EP);
		lambda = [dual(FixRef(variable_by_name(EP,y))) for y in planning_variables_sub];
		theta_coeff = 1;
		if haskey(EP,:eObjSlack)
			feasibility_slack = value(EP[:eObjSlack]);
		else
			feasibility_slack = 0.0;
		end
		
	else
		op_cost = 0;
		lambda = zeros(length(planning_variables_sub));
		theta_coeff = 0;
		feasibility_slack = 0;
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
    
	return (op_cost=op_cost,lambda = lambda,theta_coeff=theta_coeff,feasibility_slack=feasibility_slack)

end

function fix_planning_variables!(EP::Model,planning_sol::NamedTuple,planning_variables_sub::Vector{String})
	for y in planning_variables_sub
		vy = variable_by_name(EP,y);
		fix(vy,planning_sol.values[y];force=true)
		if is_integer(vy)
			unset_integer(vy)
		elseif is_binary(vy)
			unset_binary(vy)
		end
	end
end