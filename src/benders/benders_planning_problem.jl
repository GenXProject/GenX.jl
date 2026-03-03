function generate_planning_problem(setup::Dict, inputs::Dict, OPTIMIZER::MOI.OptimizerWithAttributes)

    ## Start pre-solve timer
    presolver_start_time = time()
    EP = Model(OPTIMIZER)

    #set_string_names_on_creation(EP, Bool(setup["EnableJuMPStringNames"]))
    # Introduce dummy variable fixed to zero to ensure that expressions like eTotalCap,
    # eTotalCapCharge, eTotalCapEnergy and eAvail_Trans_Cap all have a JuMP variable
    @variable(EP, vZERO==0)

    # Initialize Objective Function Expression
    EP[:eObj] = AffExpr(0.0)

    planning_model!(EP,setup,inputs)

    @variable(EP,vTHETA[1:inputs["REP_PERIOD"]]>=0)

	if setup["ModelingToGenerateAlternatives"] == 1
		Z = inputs["Z"]
		TechTypes = collect(unique(inputs["RESOURCES"].resource_type))
		@variable(EP, vSumvCap[TechTypes = 1:length(TechTypes), z = 1:Z] >= 0)
		@constraint(EP, cCapEquiv[tt = 1:length(TechTypes), z = 1:Z], vSumvCap[tt,z] == sum(EP[:eTotalCap][y] for y in  inputs["RESOURCES"][(inputs["RESOURCES"].resource_type .== inputs["RESOURCES"].resource_type[tt]) .& (inputs["RESOURCES"].zone .== z)].id))
	
	end

    ## Define the objective function
    @objective(EP, Min, setup["ObjScale"]*(EP[:eObj]+sum(vTHETA)))

    ## Record pre-solver time
    presolver_time = time() - presolver_start_time

    return EP


end

function init_planning_problem(setup::Dict,inputs::Dict)

    OPTIMIZER = configure_benders_planning_solver(setup["settings_path"]);

    EP =  generate_planning_problem(setup, inputs, OPTIMIZER);

	if haskey(inputs, "Zonal_Capacity_Results")
		for i in keys(inputs["Zonal_Capacity_Results"])
			if i in inputs["RESOURCE_NAMES"]
				new_cap_ids = GenX.get_resource_ids_by_name(inputs, i)
				@constraint(EP, sum(EP[:vCAP][j] for j in new_cap_ids) == inputs["Zonal_Capacity_Results"][i])
			end
		end
	end

	varnames = name.(setdiff(all_variables(EP),[EP[:vZERO];EP[:vTHETA]]));

	set_silent(EP);

    return EP, varnames

end

function configure_benders_planning_solver(solver_settings_path::String)

	gurobi_settings_path = joinpath(solver_settings_path, "gurobi_benders_planning_settings.yml")

	mysettings = convert(Dict{String, Any}, YAML.load(open(gurobi_settings_path)))

	settings = Dict("Crossover"=>0,"Method"=>2,"BarConvTol"=>1e-3,"MIPGap"=>1e-3);

	attributes = merge(settings, mysettings)
	println("Planning Gurobi attributes:")
	display(attributes)

    OPTIMIZER = optimizer_with_attributes(()->Gurobi.Optimizer(GRB_ENV[]),attributes...)
	
	return OPTIMIZER
end


function solve_planning_problem(EP::Model,planning_variables::Vector{String},inputs)
    println("TRYING TO SOLVE PLANNING PROBLEM!")
    flush(stdout)
	if any(is_integer.(all_variables(EP)))
		println("The planning model is a MILP")
		t = @elapsed optimize!(EP)
		println("TIME FOR SOLVING PLANNING PROBLEM IS ", t, " seconds")
		flush(stdout)
			if has_values(EP) #
				println("OBJECTIVE OF MASTER IS :", objective_value(EP) - sum(value.(EP[:vTHETA])))
				zone_inv_cost = 0#make_benders_zonal_invcost(inputs, EP)
				planning_sol =  (LB = objective_value(EP), inv_cost =value(EP[:eObj]), zone_inv_cost = zone_inv_cost,values =Dict([s=>value.(variable_by_name(EP,s)) for s in planning_variables]), theta = value.(EP[:vTHETA])) 
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
		t = @elapsed optimize!(EP)
		println("TIME FOR SOLVING (LP?) PLANNING PROBLEM IS ", t, " seconds")
		flush(stdout)
		if has_values(EP)
			neg_cap_bool = check_negative_capacities(EP);
			
			if neg_cap_bool
				println("***Resolving the planning problem with Crossover=1 because of negative capacities***")
				set_attribute(EP, "Crossover", 1)
				#set_attribute(EP, "BarHomogeneous", 1)
				optimize!(EP)
				if has_values(EP)
					zone_inv_cost = 0#make_benders_zonal_invcost(inputs, EP)
					planning_sol =  (LB = objective_value(EP), inv_cost =value(EP[:eObj]), zone_inv_cost = zone_inv_cost,values =Dict([s=>value.(variable_by_name(EP,s)) for s in planning_variables]), theta = value.(EP[:vTHETA])) 
					set_attribute(EP, "Crossover", 0)
					#set_attribute(EP, "BarHomogeneous", -1)
				else			
					println("The planning problem solution failed, trying with BarHomogenous=1")
					set_attribute(EP, "BarHomogeneous", 1)
					optimize!(EP)
					if has_values(EP)
						zone_inv_cost = 0#make_benders_zonal_invcost(inputs, EP)
						planning_sol =  (LB = objective_value(EP), inv_cost =value(EP[:eObj]), zone_inv_cost = zone_inv_cost,values =Dict([s=>value.(variable_by_name(EP,s)) for s in planning_variables]), theta = value.(EP[:vTHETA])) 
						set_attribute(EP, "BarHomogeneous", -1)
					else
						@error "The planning solution failed. This should not happen"
					end
				end
			else
				zone_inv_cost = 0#make_benders_zonal_invcost(inputs, EP)
				planning_sol =  (LB = objective_value(EP), inv_cost =value(EP[:eObj]), zone_inv_cost = zone_inv_cost,values =Dict([s=>value.(variable_by_name(EP,s)) for s in planning_variables]), theta = value.(EP[:vTHETA])) 
			end
		else
			println("The planning problem solution failed, trying with BarHomogenous=1")
			set_attribute(EP, "BarHomogeneous", 1)
			optimize!(EP)
			if has_values(EP)
				zone_inv_cost = 0#make_benders_zonal_invcost(inputs, EP)
				planning_sol =  (LB = objective_value(EP), inv_cost =value(EP[:eObj]), zone_inv_cost = zone_inv_cost,values =Dict([s=>value.(variable_by_name(EP,s)) for s in planning_variables]), theta = value.(EP[:vTHETA])) 
				set_attribute(EP, "BarHomogeneous", -1)
			else
				@error "The planning solution failed. This should not happen"
			end

		end
	end

	return planning_sol
end
