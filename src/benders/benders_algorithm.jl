
function benders(benders_inputs::Dict{Any,Any},setup::Dict)
	
    #### Algorithm from:
    ### Pecci, F. and Jenkins, J. D. “Regularized Benders Decomposition for High Performance Capacity Expansion Models”. arXiv:2403.02559 [math]. URL: http://arxiv.org/abs/2403.02559.

	### It's a regularized version of the Benders decomposition algorithm in:
	### A. Jacobson, F. Pecci, N. Sepulveda, Q. Xu, and J. Jenkins, “A computationally efficient Benders decomposition for energy systems planning problems with detailed operations and time-coupling constraints.” INFORMS Journal on Optimization 6(1):32-45. doi: https://doi.org/10.1287/ijoo.2023.0005

	## Start solver time
	solver_start_time = time()

    planning_problem = benders_inputs["planning_problem"];
	planning_variables = benders_inputs["planning_variables"];

	subproblems = benders_inputs["subproblems"];
	planning_variables_sub = benders_inputs["planning_variables_sub"];
    
    #### Algorithm parameters:
	MaxIter = setup["BD_MaxIter"]
    ConvTol = setup["BD_ConvTol"]
	MaxCpuTime = setup["BD_MaxCpuTime"]
	γ = setup["BD_StabParam"];
	stab_method = setup["BD_Stab_Method"];
    integer_investment = setup["IntegerInvestments"]

	integer_routine_flag = false

	if integer_investment == 1 && stab_method != "off"
		all_planning_variables = all_variables(planning_problem);
		integer_variables = all_planning_variables[is_integer.(all_planning_variables)];
		binary_variables = all_planning_variables[is_binary.(all_planning_variables)];
		unset_integer.(integer_variables)
		unset_binary.(binary_variables)
		integer_routine_flag = true;
	end

    #### Initialize UB and LB
	planning_sol = solve_planning_problem(planning_problem,planning_variables);

    UB = Inf;
    LB = planning_sol.LB;

    LB_hist = Float64[];
    UB_hist = Float64[];
    cpu_time = Float64[];
	feasibility_hist = Float64[];

	planning_sol_best = deepcopy(planning_sol);

    #### Run Benders iterations
    for k = 0:MaxIter
		
		start_subop_sol = time();

        subop_sol = solve_dist_subproblems(subproblems,planning_sol);
        
		cpu_subop_sol = time()-start_subop_sol;
		println("Solving the subproblems required $cpu_subop_sol seconds")

		UBnew = sum((subop_sol[w].theta_coeff==0 ? Inf : subop_sol[w].op_cost) for w in keys(subop_sol))+planning_sol.inv_cost;
		if UBnew < UB
			planning_sol_best = deepcopy(planning_sol);
			UB = UBnew;
		end

		print("Updating the planning problem....")
		time_start_update = time()

		update_planning_problem_multi_cuts!(planning_problem,subop_sol,planning_sol,planning_variables_sub)
		
		time_planning_update = time()-time_start_update
		println("done (it took $time_planning_update s).")

		start_planning_sol = time()
		unst_planning_sol = solve_planning_problem(planning_problem,planning_variables);
		cpu_planning_sol = time()-start_planning_sol;
		println("Solving the planning problem required $cpu_planning_sol seconds")

		LB = max(LB,unst_planning_sol.LB);
		
		append!(LB_hist,LB)
        append!(UB_hist,UB)
		append!(feasibility_hist,sum(subop_sol[w].feasibility_slack for w in keys(subop_sol)))
        append!(cpu_time,time()-solver_start_time)

		if any(subop_sol[w].theta_coeff==0 for w in keys(subop_sol))
			println("***k = ", k,"      LB = ", LB,"     UB = ", UB,"       Gap = ", (UB-LB)/abs(LB),"       CPU Time = ",cpu_time[end])
		else
			println("k = ", k,"      LB = ", LB,"     UB = ", UB,"       Gap = ", (UB-LB)/abs(LB),"       CPU Time = ",cpu_time[end])
		end

        if (UB-LB)/abs(LB) <= ConvTol
			if integer_routine_flag
				println("*** Switching on integer constraints *** ")
				UB = Inf;
				set_integer.(integer_variables)
				set_binary.(binary_variables)
				planning_sol = solve_planning_problem(planning_problem,planning_variables);
				LB = planning_sol.LB;
				planning_sol_best = deepcopy(planning_sol);
				integer_routine_flag = false;
			else
				break
			end
		elseif (cpu_time[end] >= MaxCpuTime)|| (k == MaxIter)
			break
		elseif UB==Inf
			planning_sol = deepcopy(unst_planning_sol);
		else
			if stab_method == "int_level_set"
				start_stab_method = time()
				if  integer_investment==1 && integer_routine_flag==false
					unset_integer.(integer_variables)
					unset_binary.(binary_variables)
					for v in integer_variables
						fix(v,unst_planning_sol.values[name(v)];force=true)
					end
					for v in binary_variables
						fix(v,unst_planning_sol.values[name(v)];force=true)
					end
                    println("Solving the interior level set problem with γ = $γ")
					planning_sol = solve_int_level_set_problem(planning_problem,planning_variables,unst_planning_sol,LB,UB,γ);
					unfix.(integer_variables)
					unfix.(binary_variables)
					set_integer.(integer_variables)
					set_binary.(binary_variables)
					set_lower_bound.(integer_variables,0.0)
					set_lower_bound.(binary_variables,0.0)
				else
                    println("Solving the interior level set problem with γ = $γ")
					planning_sol = solve_int_level_set_problem(planning_problem,planning_variables,unst_planning_sol,LB,UB,γ);
				end
				cpu_stab_method = time()-start_stab_method;
				println("Solving the interior level set problem required $cpu_stab_method seconds")
			else
				planning_sol = deepcopy(unst_planning_sol);
			end

		end

    end

	return (planning_problem=planning_problem,planning_sol = planning_sol_best,LB_hist = LB_hist,UB_hist = UB_hist,cpu_time = cpu_time,feasibility_hist = feasibility_hist)
end

function update_planning_problem_multi_cuts!(EP::Model,subop_sol::Dict,planning_sol::NamedTuple,planning_variables_sub::Dict)
    
	W = keys(subop_sol);
	
    @constraint(EP,[w in W],subop_sol[w].theta_coeff*EP[:vTHETA][w] >= subop_sol[w].op_cost + sum(subop_sol[w].lambda[i]*(variable_by_name(EP,planning_variables_sub[w][i]) - planning_sol.values[planning_variables_sub[w][i]]) for i in 1:length(planning_variables_sub[w])));

       
end
