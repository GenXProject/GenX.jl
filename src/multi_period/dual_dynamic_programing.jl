function run_ddp(models_d::Dict, setup::Dict, inputs::Dict)

    # start_cap_d dictionary contains key-value pairs of available capacity investment expressions
    # as keys and their corresponding linking constraints as values
    start_cap_d = Dict([(Symbol("eTotalCap"),Symbol("cExistingCap"))])

    if !isempty(inputs["STOR_ALL"])
        start_cap_d[Symbol("eTotalCapEnergy")] = Symbol("cExistingCapEnergy")
    end

    if !isempty(inputs["STOR_ASYMMETRIC"])
        start_cap_d[Symbol("eTotalCapCharge")] = Symbol("cExistingCapCharge")
    end

    # This dictionary contains the endogenous retirement constraint name as a key,
    # and a tuple consisting of the associated tracking array constraint and variable as the value
    retirements_d = Dict([(Symbol("vCAPTRACK"),Symbol("cCapTrack"))])

    if !isempty(inputs["STOR_ALL"])
        retirements_d[Symbol("vCAPTRACKENERGY")] = Symbol("cCapTrackEnergy")
    end

    if !isempty(inputs["STOR_ASYMMETRIC"])
        retirements_d[Symbol("vCAPTRACKCHARGE")] = Symbol("cCapTrackCharge")
    end
    
    settings_d = setup["MultiPeriodSettingsDict"]

    num_periods = settings_d["NumPeriods"]  # Total number of time periods
    EPSILON = settings_d["ConvergenceTolerance"] # Tolerance

    ic = 0 # Iteration Counter

    results_d = Dict() # Dictionary to store the results to return
    stats_d = Dict() # Dictionary to store the statistics (total time, upper bound, and lower bound for each iteration)
    times_a = [] # Array to store the total time of each iteration
    upper_bounds_a = [] # Array to store the upper bound of each iteration
    lower_bounds_a = [] # Array to store the lower bound of each iteration

    # Step a.i) Initialize cost-to-go function for t = 1:num_periods
    for t in 1:num_periods
        models_d[t] = initialize_cost_to_go(settings_d, models_d[t])
    end

    # Step a.ii) Set objective upper bound
    global z_upper = Inf

    # Step b.i) Solve the approximate first-stage problem
    println("***********")
    println("Solving First Stage Problem")
    println("***********")


    t = 1 # Period = 1
    solve_time_d = Dict()
    ddp_prev_time = time() # Begin tracking time of each iteration
    models_d[t], solve_time_d[t] = solve_model(models_d[t],setup)

    #results_d[t] = results

    println("***********")
    println(string("Objective Function At Time ", t, " : ",objective_value(models_d[t])))
    println(string("Cost-to-Go At Time ", t, " : ", value(models_d[t][:vALPHA])))
    println(string("Actual Cost At Time ", t, ": ", objective_value(models_d[t]) - value(models_d[t][:vALPHA])))
    println("***********")

    # Step c.i) Initialize the lower bound, equal to the objective function value for the first period in the first iteration
    global z_lower = objective_value(models_d[t])

    # Step c.ii) If the relative difference between upper and lower bounds are small, break loop
    while((z_upper - z_lower)/z_lower > EPSILON)

        ic = ic + 1 # Increase iteration counter by 1

        if (ic > 10000)
            println("***********")
            println("Exiting Without Covergence!")
            println(string("Upper Bound = ", z_upper))
            println(string("Lower Bound = ", z_lower))
            println("***********")

            stats_d["TIMES"] = times_a
            stats_d["UPPER_BOUNDS"] = upper_bounds_a
            statd_d["LOWER_BOUNDS"] = lower_bounds_a

            return results_d, stats_d
        end

        println("***********")
        println(string("Iteration Number: ", ic))
        println(string("Upper Bound = ", z_upper))
        println(string("Lower Bound = ", z_lower))
        println("***********")

        # Step d) Forward pass for t = 1:num_periods
		## For first iteration we dont need to solve forward pass for first period (we did that already above),
		## but we need to update forward pass solution for the first period for subsequent iterations
		if ic > 1
			t = 1 #  update forward pass solution for the first period
			models_d[t], solve_time_d[t] = solve_model(models_d[t],setup)
		end
		## Forward pass for t=2:num_periods
        for t in 2:num_periods

            println("***********")
            println(string("Forward Pass t = ", t))
            println("***********")

            # Step d.i) Fix initial investments for model at time t given optimal solution for time t-1
            models_d[t] = fix_initial_investments(models_d[t-1], models_d[t], start_cap_d)

            # Step d.ii) Fix capacity tracking variables for endogenous retirements
            models_d[t] = fix_capacity_tracking(models_d[t-1], models_d[t], retirements_d, t)

            # Step d.iii) Solve the model at time t
            models_d[t], solve_time_d[t] = solve_model(models_d[t],setup)
            #results_d[t] = results

            println("***********")
            println(string("Objective Function At Time ", t, " : ",objective_value(models_d[t])))
            println(string("Cost-to-Go At Time ", t, " : ", value(models_d[t][:vALPHA])))
            println(string("Actual Cost At Time ", t, ": ", objective_value(models_d[t]) - value(models_d[t][:vALPHA])))
            println("***********")
        end

        # Step e) Calculate the new upper bound
        z_upper_temp = 0
        for t in 1:num_periods
            z_upper_temp = z_upper_temp + (objective_value(models_d[t]) - value(models_d[t][:vALPHA]))
        end

        # If the upper bound decreased, set it as the new upper bound
        if z_upper_temp < z_upper
            z_upper = z_upper_temp
        end

        append!(upper_bounds_a, z_upper) # Store current iteration upper bound

        # Step f) Backward pass for t = num_periods:2
        for t in num_periods:-1:2

            println("***********")
            println(string("Backward Pass t = ", t))
            println("***********")

            # Step f.i) Add a cut to the previous time step using information from the current time step
            models_d[t-1] = add_cut(models_d[t-1], models_d[t], start_cap_d, retirements_d)

            # Step f.ii) Solve the model with the additional cut at time t-1
            models_d[t-1], solve_time_d[t-1] = solve_model(models_d[t-1],setup)
            #results_d[t-1] = results 
            ### Aaron - need to compare to original DDP code. Do we want to overwright the results from the FP with BP results in displaying the results?

            println("***********")
            println(string("Objective Function At Time ", t-1, " : ",objective_value(models_d[t-1])))
            println(string("Cost-to-Go At Time ", t-1, " : ", value(models_d[t-1][:vALPHA])))
            println(string("Actual Cost At Time ", t-1, ": ", objective_value(models_d[t-1]) - value(models_d[t-1][:vALPHA])))
            println("***********")
        end

        # Step g) Recalculate lower bound and go back to c)
        z_lower = objective_value(models_d[1])
        append!(lower_bounds_a, z_lower) # Store current iteration lower bound

        # Step h) Store the total time of the current iteration (in seconds)
        ddp_iteration_time = time() - ddp_prev_time
        append!(times_a, ddp_iteration_time)
        ddp_prev_time = time()
    end

    println("***********")
    println("Successful Convergence!")
    println(string("Upper Bound = ", z_upper))
    println(string("Lower Bound = ", z_lower))
    println("***********")

    stats_d["TIMES"] = times_a
    stats_d["UPPER_BOUNDS"] = upper_bounds_a
    stats_d["LOWER_BOUNDS"] = lower_bounds_a

    return results_d, stats_d
end

function write_ddp_outputs(results_d::Dict, stats_d::Dict, outpath::String, setup::Dict)

    if setup["MacOrWindows"]=="Mac"
		sep = "/"
	else
		sep = "\U005c"
    end

    df_cap = write_capacities(results_d, setup)
    df_costs = write_costs(results_d, setup)
    df_stats = write_times(stats_d)

    CSV.write(string(outpath,sep,"capacities_ddp.csv"), df_cap)
    CSV.write(string(outpath,sep,"costs_ddp.csv"), df_costs)
    CSV.write(string(outpath,sep,"stats_ddp.csv"), df_stats)

end

function write_capacities(results_d::Dict, setup::Dict)
	# TO DO - DO THIS FOR ENERGY CAPACITY AS WELL

    P = setup["NumPeriods"] # Total number of time periods

    # Set first column of DataFrame as resource names from the first time period
    df_cap = DataFrame(Resource = results_d[1]["CAP"][!,:Resource], Zone = results_d[1]["CAP"][!,:Zone])

    # Store starting capacities from the first time period
    df_cap[!,Symbol("Starting_Capacity")] = results_d[1]["CAP"][!,:StartCap]

    # Store end capacities for all time periods
    for p in 1:P
        df_cap[!, Symbol("End_Capacity_Period$p")] = results_d[p]["CAP"][!,:EndCap]
    end

    return df_cap
end

function write_costs(results_d::Dict, setup::Dict)

	P = setup["DDP_Total_Periods"] # Total number of DDP time periods
	L = setup["DDP_Period_Length"] # Length (in years) of each period
	I = setup["Cost_of_Capital"] # Interest Rate and also the discount rate unless specified other wise

	OPEXMULT = sum([1/(1+I)^(i-1) for i in range(1,stop=L)]) # OPEX multiplier to count multiple years between two model time periods
    # Set first column of DataFrame as resource names from the first time period
    df_costs = DataFrame(Costs = results_d[1]["COSTS"][!,:Costs])

    # Store discounted total costs for each time period in a data frame
    for p in 1:P
        DF = 1/(1+I)^(L*(p-1))  # Discount factor applied to ALL costs in each period

        df_costs[!, Symbol("Total_Costs_Period$p")] = DF .* results_d[p]["COSTS"][!,Symbol("Total")]
    end

    # For OPEX costs, apply additional discounting
    for cost in ["cVar", "cNSE", "cHeatCost", "cHeatRev"]
        if cost in df_costs[!,:Costs]
            df_costs[df_costs[!,:Costs] .== cost, 2:end] = OPEXMULT .* df_costs[df_costs[!,:Costs] .== cost, 2:end]
        end
    end

    # Remove "cTotal" from results (as this includes Cost-to-Go)
    df_costs = df_costs[df_costs[!,:Costs].!="cTotal",:]

    return df_costs
end

function write_times(stats_d::Dict)

    times_a = stats_d["TIMES"] # Time (seconds) of each iteration
    upper_bounds_a = stats_d["UPPER_BOUNDS"] # Upper bound of each iteration
    lower_bounds_a = stats_d["LOWER_BOUNDS"] # Lower bound of each iteration

    # Create an array of numbers 1 through total number of iterations
    iteration_count_a = collect(1:length(times_a))

    realtive_gap_a = (upper_bounds_a .- lower_bounds_a) ./ lower_bounds_a

    # Construct dataframe where first column is iteration number, second is iteration time
    df_stats = DataFrame(Iteration_Number = iteration_count_a,
                        Seconds = times_a,
                        Upper_Bound = upper_bounds_a,
                        Lower_Bound = lower_bounds_a,
                        Relative_Gap = realtive_gap_a)

    return df_stats
end

function fix_initial_investments(EP_prev::Model, EP_cur::Model, start_cap_d::Dict)

    # start_cap_d dictionary contains the starting capacity expression name (e) as a key,
    # and the associated linking constraint name (c) as a value
    for (e, c) in start_cap_d
        for y in keys(EP_cur[c])

	        # Set the right hand side value of the linking initial capacity constraint in the current time
	        # period to the value of the available capacity variable solved for in the previous time period
            set_normalized_rhs(EP_cur[c][y], value(EP_prev[e][y]))
        end
    end
	return EP_cur
end

function fix_capacity_tracking(EP_prev::Model, EP_cur::Model, retirements_d::Dict, cur_period::Int)

    # retirements_d dictionary contains the endogenous retirement tracking array variable name (v) as a key,
    # and the associated linking constraint name (c) as a value
    for (v, c) in retirements_d

	    # Tracking variables and constraints for retired capacity are named identicaly to those for newly
	    # built capacity, except have the prefex "vRET" and "cRet", accordingly
        rv = Symbol("vRET",string(v)[2:end]) # Retired capacity tracking variable name (rv)
	    rc = Symbol("cRet",string(c)[2:end]) # Retired capacity tracking constraint name (rc)

        for i in keys(EP_cur[c])
            i = i[1] # Extract integer index value from keys tuple - corresponding to generator index

	        # For all previous time periods, set the right hand side value of the tracking constraint in the current
	        # time period to the value of the tracking constraint observed in the previous time period
            for p in 1:(cur_period-1)
		        # Tracking newly buily capacity over all previous time periods
                JuMP.set_normalized_rhs(EP_cur[c][i,p],value(EP_prev[v][i,p]))
		        # Tracking retired capacity over all previous time periods
                JuMP.set_normalized_rhs(EP_cur[rc][i,p],value(EP_prev[rv][i,p]))
            end
        end
    end

	return EP_cur
end

function add_cut(EP_cur::Model, EP_next::Model, start_cap_d::Dict, retirements_d::Dict)

    next_obj_value = objective_value(EP_next) # Get the objective function value for the next time period

    eRHS = @expression(EP_cur, 0) # Initialize RHS of cut to 0
    println("eRHS Init: ", eRHS)

    # Generate cut components for investment decisions

    # start_cap_d dictionary contains the starting capacity expression name (e) as a key,
    # and the associated linking constraint name (c) as a value
    for (e,c) in start_cap_d

        # Continue if nothing to add to the cut
        if isempty(EP_next[e])
            continue
        end

        # Generate the cut component
        eCurRHS = generate_cut_component_inv(EP_cur, EP_next, e, c)

        # Add the cut component to the RHS
        eRHS = eRHS + eCurRHS
        println("eRHS Updated: ", eRHS)
    end

    # Generate cut components for endogenous retirements.

    # retirements_d dictionary contains the endogenous retirement tracking array variable name (v) as a key,
    # and the associated linking constraint name (c) as a value
    for (v,c) in retirements_d

        # Continue if nothing to add to the cut
        if isempty(EP_next[c])
            continue
        end

        # Generate the cut component for new capacity
        eCurRHS_cap = generate_cut_component_track(EP_cur, EP_next, v, c)

        rv = Symbol("vRET",string(v)[2:end]) # Retired capacity tracking variable (rv)
        rc = Symbol("cRet",string(c)[2:end]) # Retired capacity tracking constraint (rc)

        # Generate the cut component for retired capacity
        eCurRHS_ret = generate_cut_component_track(EP_cur, EP_next, rv, rc)

        # Add the cut component to the RHS
        eRHS = eRHS + eCurRHS_cap + eCurRHS_ret
    end

    # Add the cut to the model
    @constraint(EP_cur, EP_cur[:vALPHA] >= next_obj_value - eRHS)

    return EP_cur
end

function generate_cut_component_track(EP_cur::Model, EP_next::Model, var_name::Symbol, constr_name::Symbol)

    next_dual_value = Float64[]
    cur_inv_value = Float64[]
    cur_inv_var = []

    for k in keys(EP_next[constr_name])
        y = k[1] # Index representing resource
        p = k[2] # Index representing period

        push!(next_dual_value, getdual(EP_next[constr_name][y,p]))
        push!(cur_inv_value, getvalue(EP_cur[var_name][y,p]))
        push!(cur_inv_var, EP_cur[var_name][y,p])
    end

    eCutComponent = @expression(EP_cur, dot(next_dual_value,(cur_inv_value .- cur_inv_var)))

    return eCutComponent
end

function generate_cut_component_inv(EP_cur::Model, EP_next::Model, expr_name::Symbol, constr_name::Symbol)

    next_dual_value = Float64[]
    cur_inv_value = Float64[]
    cur_inv_var = []

    for y in keys(EP_next[constr_name])

        push!(next_dual_value, dual(EP_next[constr_name][y]))
        push!(cur_inv_value, value(EP_cur[expr_name][y]))
        push!(cur_inv_var, EP_cur[expr_name][y])
    end

    eCutComponent = @expression(EP_cur, dot(next_dual_value,(cur_inv_value .- cur_inv_var)))

    return eCutComponent
end

function initialize_cost_to_go(settings_d::Dict, EP::Model)

	cur_period = settings_d["CurPeriod"] # Current DDP Time Period
	period_len = settings_d["PeriodLength"] # Length (in years) of each period
	wacc = settings_d["WACC"] # Interest Rate  and also the discount rate unless specified other wise

    DF = 1/(1+wacc)^(period_len*(cur_period-1))  # Discount factor applied all to costs in each period
	OPEXMULT = sum([1/(1+wacc)^(i-1) for i in range(1,stop=period_len)]) # OPEX multiplier to count multiple years between two model time periods

	# Initialize the cost-to-go variable
    @variable(EP, vALPHA >= 0);

	# Overwrite the objective function to include the cost-to-go variable
	# Multiply discount factor to all terms except the alpha term or the cost-to-go function
	# All OPEX terms get an additional adjustment factor
	@objective(EP, Min, DF*OPEXMULT*EP[:eObj] + vALPHA)

	return EP

end
