function get_settings_path(case::AbstractString)
    return joinpath(case, "settings")
end

function get_settings_path(case::AbstractString, filename::AbstractString)
    return joinpath(get_settings_path(case), filename)
end

function get_default_output_folder(case::AbstractString)
    return joinpath(case, "results")
end

@doc raw"""
    run_genx_case!(case::AbstractString, optimizer::Any=HiGHS.Optimizer)

Run a GenX case with the specified optimizer. The optimizer can be any solver supported by MathOptInterface.

# Arguments
- `case::AbstractString`: the path to the case folder
- `optimizer::Any`: the optimizer instance to be used in the optimization model

# Example
```julia
run_genx_case!("path/to/case", HiGHS.Optimizer)
```

```julia
run_genx_case!("path/to/case", Gurobi.Optimizer)
```
"""
function run_genx_case!(case::AbstractString, optimizer::Any = HiGHS.Optimizer)
    print_genx_version() # Log the GenX version
    genx_settings = get_settings_path(case, "genx_settings.yml") # Settings YAML file path
    writeoutput_settings = get_settings_path(case, "output_settings.yml") # Write-output settings YAML file path
    mysetup = configure_settings(genx_settings, writeoutput_settings) # mysetup dictionary stores settings and GenX-specific parameters

    if mysetup["MultiStage"] == 0
        if mysetup["Benders"] == 0
            run_genx_case_simple!(case, mysetup, optimizer)
        else
            benders_settings_path = get_settings_path(case, "benders_settings.yml")
            mysetup_benders = configure_benders(benders_settings_path)
            mysetup = merge(mysetup, mysetup_benders)

            if mysetup["DC_OPF"] != 1 && mysetup[:RunTransportModel]
                @warn "`RunTransportModel` only works with DC_OPF = 1 but DC_OPF is set to $(mysetup["DC_OPF"]). Turning off `RunTransportModel`"
            end

            hotstart_requested = mysetup[:LPDCOPFHotstart] ||
                                 (mysetup[:RunTransportModel] && mysetup[:LPTransportHotstart])
            if hotstart_requested && mysetup[:IntegerInvestment]
                # Additional Note: MacroEnergySolvers.jl could support some of the LP relaxations here via the IntegerInvestment flag, 
                # but the user has more control over the regularization scheme here; in some tests, the best performance we had
                # ran with LP relaxations with regularization for all hot starting stages, and then turned off regularization for the final DC-OPF stage
                # Consequently, the IntegerInvestment flag is handled by the GenX specific hotstarting flags
                @warn "`IntegerInvestment` is incompatible with the LP hot-starts (`LPTransportHotstart` / `LPDCOPFHotstart`), which perform the integer relaxation themselves. Turning off `IntegerInvestment`."
                mysetup[:IntegerInvestment] = false
            end

            if get(mysetup, :Distributed, false)
                target = get(mysetup, :NWorkers, 0)
                if target > 1
                    current = nworkers()
                    if current < target
                        n_to_add = target - current
                        @info "Benders: adding $n_to_add worker process(es) to reach $target total workers."
                        addprocs(n_to_add; exeflags=["--project=$(Base.active_project())"])
                        Distributed.remotecall_eval(Main, workers(), :(using GenX))
                    elseif current > target
                        @warn "Benders: $current workers are already running but NWorkers=$target was requested. Proceeding with $current workers."
                    else
                        @info "Benders: $current workers already running — no additional workers needed."
                    end
                else
                    @warn "Benders: Distributed=true but NWorkers=$target (must be > 1 to enable parallel solving). Running sequentially."
                end
            end

            run_genx_case_benders!(case, mysetup, optimizer)
        end
    else
        run_genx_case_multistage!(case, mysetup, optimizer)
    end
end

function time_domain_reduced_files_exist(tdrpath)
    tdr_demand = file_exists(tdrpath, ["Demand_data.csv", "Load_data.csv"])
    tdr_genvar = isfile(joinpath(tdrpath, "Generators_variability.csv"))
    tdr_fuels = isfile(joinpath(tdrpath, "Fuels_data.csv"))
    return (tdr_demand && tdr_genvar && tdr_fuels)
end

function run_genx_case_simple!(case::AbstractString, mysetup::Dict, optimizer::Any)
    settings_path = get_settings_path(case)

    ### Cluster time series inputs if necessary and if specified by the user
    if mysetup["TimeDomainReduction"] == 1
        TDRpath = joinpath(case, mysetup["TimeDomainReductionFolder"])
        system_path = joinpath(case, mysetup["SystemFolder"])
        prevent_doubled_timedomainreduction(system_path)
        if !time_domain_reduced_files_exist(TDRpath)
            println("Clustering Time Series Data (Grouped)...")
            cluster_inputs(case, settings_path, mysetup)
        else
            println("Time Series Data Already Clustered.")
        end
    end

    ### Configure solver
    println("Configuring Solver")
    solver_name = lowercase(get(mysetup, "Solver", ""))
    OPTIMIZER = configure_solver(settings_path, optimizer; solver_name=solver_name)

    #### Running a case

    ### Load inputs
    println("Loading Inputs")
    myinputs = load_inputs(mysetup, case)

    println("Generating the Optimization Model")
    time_elapsed = @elapsed EP = generate_model(mysetup, myinputs, OPTIMIZER)
    println("Time elapsed for model building is")
    println(time_elapsed)

    println("Solving Model")
    EP, solve_time = solve_model(EP, mysetup)
    myinputs["solve_time"] = solve_time # Store the model solve time in myinputs

    # Run MGA if the MGA flag is set to 1 else only save the least cost solution
    if has_values(EP)
        println("Writing Output")
        outputs_path = get_default_output_folder(case)
        elapsed_time = @elapsed outputs_path = write_outputs(EP,
            outputs_path,
            mysetup,
            myinputs)
        println("Time elapsed for writing is")
        println(elapsed_time)
        if mysetup["ModelingToGenerateAlternatives"] == 1
            println("Starting Model to Generate Alternatives (MGA) Iterations")
            mga(EP, case, mysetup, myinputs)
        end

        if mysetup["MethodofMorris"] == 1
            println("Starting Global sensitivity analysis with Method of Morris")
            morris(EP, case, mysetup, myinputs, outputs_path, OPTIMIZER)
        end
    end
end

function run_genx_case_multistage!(case::AbstractString, mysetup::Dict, optimizer::Any)
    settings_path = get_settings_path(case)
    multistage_settings = get_settings_path(case, "multi_stage_settings.yml") # Multi stage settings YAML file path
    # merge default settings with those specified in the YAML file
    mysetup["MultiStageSettingsDict"] = configure_settings_multistage(multistage_settings)

    ### Cluster time series inputs if necessary and if specified by the user
    if mysetup["TimeDomainReduction"] == 1
        tdr_settings = get_settings_path(case, "time_domain_reduction_settings.yml") # Multi stage settings YAML file path
        TDRSettingsDict = YAML.load(open(tdr_settings))

        first_stage_path = joinpath(case, "inputs", "inputs_p1")
        TDRpath = joinpath(first_stage_path, mysetup["TimeDomainReductionFolder"])
        system_path = joinpath(first_stage_path, mysetup["SystemFolder"])
        prevent_doubled_timedomainreduction(system_path)
        if !time_domain_reduced_files_exist(TDRpath)
            if (mysetup["MultiStage"] == 1) &&
               (TDRSettingsDict["MultiStageConcatenate"] == 0)
                println("Clustering Time Series Data (Individually)...")
                for stage_id in 1:mysetup["MultiStageSettingsDict"]["NumStages"]
                    cluster_inputs(case, settings_path, mysetup, stage_id)
                end
            else
                println("Clustering Time Series Data (Grouped)...")
                cluster_inputs(case, settings_path, mysetup)
            end
        else
            println("Time Series Data Already Clustered.")
        end
    end

    ### Configure solver
    println("Configuring Solver")
    solver_name = lowercase(get(mysetup, "Solver", ""))
    OPTIMIZER = configure_solver(settings_path, optimizer; solver_name=solver_name)

    model_dict = Dict()
    inputs_dict = Dict()

    for t in 1:mysetup["MultiStageSettingsDict"]["NumStages"]

        # Step 0) Set Model Year
        mysetup["MultiStageSettingsDict"]["CurStage"] = t

        # Step 1) Load Inputs
        inpath_sub = joinpath(case, "inputs", string("inputs_p", t))

        inputs_dict[t] = load_inputs(mysetup, inpath_sub)
        inputs_dict[t] = configure_multi_stage_inputs(inputs_dict[t],
            mysetup["MultiStageSettingsDict"],
            mysetup["NetworkExpansion"])

        compute_cumulative_min_retirements!(inputs_dict, t)
        # Step 2) Generate model
        model_dict[t] = generate_model(mysetup, inputs_dict[t], OPTIMIZER)
    end

    # check that resources do not switch from can_retire = 0 to can_retire = 1 between stages
    validate_can_retire_multistage(
        inputs_dict, mysetup["MultiStageSettingsDict"]["NumStages"])

    # Prepare folder for results    
    outpath = get_default_output_folder(case)

    if mysetup["OverwriteResults"] == 1
        # Overwrite existing results if dir exists
        # This is the default behaviour when there is no flag, to avoid breaking existing code
        if !(isdir(outpath))
            mkdir(outpath)
        end
    else
        # Find closest unused ouput directory name and create it
        outpath = choose_output_dir(outpath)
        mkdir(outpath)
    end

    ### Solve model
    println("Solving Model")

    # Step 3) Run DDP Algorithm or Myopic single pass
    if mysetup["MultiStageSettingsDict"]["Myopic"] == 1
        mystats_d = Dict()  # mystats_d is for DDP iteration metadata
        model_dict, inputs_dict = run_myopic_multistage(outpath, model_dict, mysetup, inputs_dict)
    else
        model_dict, mystats_d, inputs_dict = run_ddp(outpath, model_dict, mysetup, inputs_dict)
    end

    # Step 4) Write final outputs from each stage
    if mysetup["MultiStageSettingsDict"]["Myopic"] == 0 ||
       mysetup["MultiStageSettingsDict"]["WriteIntermittentOutputs"] == 0
        for p in 1:mysetup["MultiStageSettingsDict"]["NumStages"]
            mysetup["MultiStageSettingsDict"]["CurStage"] = p
            outpath_cur = joinpath(outpath, "results_p$p")
            write_outputs(model_dict[p], outpath_cur, mysetup, inputs_dict[p])
        end
    end

    # Step 5) Write DDP summary outputs

    write_multi_stage_outputs(mystats_d, outpath, mysetup, inputs_dict)
end

function run_genx_case_benders!(case::AbstractString, mysetup::Dict, optimizer::Any = HiGHS.Optimizer)
    function append_to_benders_results(results::NamedTuple, new_results::NamedTuple)
        return (planning_problem = new_results.planning_problem, planning_sol = new_results.planning_sol, subop_sol = new_results.subop_sol, LB_hist = vcat(results.LB_hist, new_results.LB_hist), UB_hist = vcat(results.UB_hist, new_results.UB_hist), gap_hist = vcat(results.gap_hist, new_results.gap_hist), termination_status = new_results.termination_status, cpu_time = vcat(results.cpu_time, new_results.cpu_time), planning_sol_hist = new_results.planning_sol_hist)
    end

    settings_path = get_settings_path(case)    
    ### Cluster time series inputs if necessary and if specified by the user
    if mysetup["TimeDomainReduction"] == 1
        TDRpath = joinpath(case, mysetup["TimeDomainReductionFolder"])
        system_path = joinpath(case, mysetup["SystemFolder"])
        prevent_doubled_timedomainreduction(system_path)
        if !time_domain_reduced_files_exist(TDRpath)
            println("Clustering Time Series Data (Grouped)...")
            cluster_inputs(case, settings_path, mysetup)
        else
            println("Time Series Data Already Clustered.")
        end
    end
    mysetup["settings_path"] = settings_path;

    myinputs = load_inputs(mysetup, case);

    myinputs_decomp = separate_inputs_subperiods(myinputs);

    # Worker setup happens here, rather than in run_genx_case!, because sizing the worker pool
    # requires knowing how many operational subproblems there are.
    setup_benders_workers!(mysetup, length(myinputs_decomp));

    # The transport model is the DC-OPF model without the flow-angle constraints, so the transport
    # pass builds the planning problem and the subproblems with DC_OPF switched off. Remember what
    # was actually requested: DC_OPF is restored once the relaxation has been solved.
    dcopf_requested = mysetup["DC_OPF"]
    if mysetup[:RunTransportModel]
        mysetup["DC_OPF"] = 0
    end

    benders_inputs = generate_benders_inputs(mysetup, myinputs, myinputs_decomp, optimizer)
    planning_problem = benders_inputs["planning_problem"]
    planning_variables_sub = benders_inputs["planning_variables_sub"]
    subproblems = benders_inputs["subproblems"]

    cpu_solve_time = 0
    if dcopf_requested == 1
        results = (planning_problem=nothing, planning_sol = nothing, subop_sol = nothing, LB_hist = Float64[], UB_hist = Float64[], gap_hist = Float64[], termination_status = nothing, cpu_time = Float64[], planning_sol_hist = nothing)

        # The DC-OPF run calls `benders` several times on the same subproblems (LP hot-starts, a
        # transport relaxation pass, then the full run). When feasibility cuts are enabled
        # (ExpectFeasibleSubproblems = false), MacroEnergySolvers attaches slack variables to every
        # subproblem on entry to `benders`, which breaks that reuse twice over: re-entering fails on
        # the duplicate `slack_max` registration, and only the constraints present when the slacks
        # were attached carry a slack term, so anything added later (the DC-OPF constraints) could
        # never be relaxed by a feasibility cut. Both are handled by rebuilding the subproblems
        # before any `benders` call that would otherwise reuse already-slacked models. The rebuild
        # reads the current mysetup, so it also picks up DC_OPF once it is switched on below.
        # The planning problem is never rebuilt, so its accumulated cuts survive as a warm start.
        slacks_attached = false
        function run_benders_pass!()
            if slacks_attached
                subproblems, planning_variables_sub = init_benders_subproblems(mysetup,
                    myinputs_decomp,
                    benders_inputs["planning_variables"],
                    optimizer)
                # Keep benders_inputs pointing at the models actually in use: it otherwise holds the
                # last reference to the superseded subproblems, keeping them (and their solver
                # instances) alive alongside the new ones.
                benders_inputs["subproblems"] = subproblems
                benders_inputs["planning_variables_sub"] = planning_variables_sub
            end
            new_results = MacroEnergySolvers.benders(planning_problem,
                subproblems,
                planning_variables_sub,
                mysetup)
            slacks_attached = !mysetup[:ExpectFeasibleSubproblems]
            return new_results
        end

        planning_variables = all_variables(planning_problem)
        integer_variables = planning_variables[is_integer.(planning_variables)]
        binary_variables = planning_variables[is_binary.(planning_variables)]
        if mysetup[:RunTransportModel]
            println("Running Transport Model Pass")
            if mysetup[:LPTransportHotstart]
                println("Relaxing integer/binary variables for transport model pass")
                # unset integer and binary variables and solve
                unset_integer.(integer_variables)
                unset_binary.(binary_variables)
                set_lower_bound.(binary_variables, 0)
                set_upper_bound.(binary_variables, 1)

                results = append_to_benders_results(results, run_benders_pass!())

                println("Transport model pass complete with LP hot-start. Resetting integer/binary variables and solving again.")
                # reset integer and binary variables
                set_integer.(integer_variables)
                set_binary.(binary_variables)
                results = append_to_benders_results(results, run_benders_pass!())
                cpu_solve_time += results.cpu_time[end]
            else
                results = append_to_benders_results(results, run_benders_pass!())
                cpu_solve_time += results.cpu_time[end]
            end

            # Switch to DC-OPF. The transport model just solved is a relaxation of DC-OPF, so the
            # cuts already accumulated in the planning problem remain valid underestimators of the
            # DC-OPF recourse cost: the planning problem is kept as-is and acts as a warm start.
            # Only the subproblems have to gain the DC-OPF constraints.
            mysetup["DC_OPF"] = 1
            if !slacks_attached
                # Nothing was slacked, so the constraints can be added to the existing models in
                # place — on the owning worker when the subproblems live in a DArray. Otherwise the
                # next run_benders_pass! rebuilds the subproblems, and because DC_OPF is now 1 they
                # come back with the DC-OPF constraints already in them.
                add_dcopf_to_subproblems!(subproblems, myinputs_decomp, mysetup)
            end
        end
        if mysetup[:LPDCOPFHotstart]
            println("Relaxing integer/binary variables for DC-OPF model pass")
            # unset integer variables and solve
            unset_integer.(integer_variables)
            unset_binary.(binary_variables)
            set_lower_bound.(binary_variables, 0)
            set_upper_bound.(binary_variables, 1)

            results = append_to_benders_results(results, run_benders_pass!())

            if !(mysetup[:RegularizationPostHotstart])
                mysetup[:StabParam] = 0.0
            end
            
            println("DC-OPF model pass complete with LP hot-start. Resetting integer/binary variables and solving again.")

            # reset integer and binary variables
            set_integer.(integer_variables)
            set_binary.(binary_variables)

            results = append_to_benders_results(results, run_benders_pass!())
            cpu_solve_time += results.cpu_time[end]
        elseif !(mysetup[:RegularizationPostHotstart])
            mysetup[:StabParam] = 0.0

            results = append_to_benders_results(results, run_benders_pass!())
            cpu_solve_time += results.cpu_time[end]
        else
            results = append_to_benders_results(results, run_benders_pass!())
            cpu_solve_time += results.cpu_time[end]
        end
    else
        results = MacroEnergySolvers.benders(planning_problem, subproblems, planning_variables_sub, mysetup)
        cpu_solve_time += results.cpu_time[end]
    end

    myinputs["solve_time"] = cpu_solve_time

    subop_sol = MacroEnergySolvers.solve_subproblems(subproblems, results.planning_sol, true)
    
    results = (; results..., subop_sol = subop_sol)

    # Note: the planning problem is intentionally NOT re-solved/realigned here. All first-stage
    # outputs (capacity, network expansion, planning costs) are read directly from the incumbent
    # results.planning_sol inside write_benders_output, so they reflect the same solution as the
    # subproblem dispatch without depending on the planning-problem model's post-Benders state.
    println("Writing Output")

    outputs_path = joinpath(case, "results_benders")

    if mysetup["OverwriteResults"] == 1
		# Overwrite existing results if dir exists
		# This is the default behaviour when there is no flag, to avoid breaking existing code
		if !(isdir(outputs_path))
		    mkdir(outputs_path)
		end
	else
		# Find closest unused ouput directory name and create it
		outputs_path = choose_output_dir(outputs_path)
		mkdir(outputs_path)
	end
    
    elapsed_time = @elapsed write_benders_output(results, outputs_path, mysetup, myinputs, planning_problem, subproblems);
end
