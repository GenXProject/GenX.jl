
function solve_int_level_set_problem(EP::Model,planning_variables::Vector{String},planning_sol::NamedTuple,LB,UB,γ)
	
	@constraint(EP,cLevel_set,EP[:eObj] + sum(EP[:vTHETA])<=LB+γ*(UB-LB))

	@objective(EP,Min, 0*sum(EP[:vTHETA]))

    optimize!(EP)

	if has_values(EP)
		
		planning_sol = (;planning_sol..., inv_cost=value(EP[:eObj]), values=Dict([s=>value(variable_by_name(EP,s)) for s in planning_variables]), theta = value.(EP[:vTHETA]))

	else

		if !has_values(EP)
			@warn  "the interior level set problem solution failed"
		else
			planning_sol = (;planning_sol..., inv_cost=value(EP[:eObj]), values=Dict([s=>value(variable_by_name(EP,s)) for s in planning_variables]), theta = value.(EP[:vTHETA]))
		end
	end


	delete(EP,EP[:cLevel_set])
	unregister(EP,:cLevel_set)
	@objective(EP,Min, EP[:eObj] + sum(EP[:vTHETA]))
	
	return planning_sol

end
