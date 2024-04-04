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
    genx_settings = get_settings_path(case, "genx_settings.yml") # Settings YAML file path
    writeoutput_settings = get_settings_path(case, "output_settings.yml") # Write-output settings YAML file path
    mysetup = configure_settings(genx_settings, writeoutput_settings) # mysetup dictionary stores settings and GenX-specific parameters

    if mysetup["MultiStage"] == 0
        run_genx_case_simple!(case, mysetup, optimizer)
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
    OPTIMIZER = configure_solver(settings_path, optimizer)

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
            mga(EP, case, mysetup, myinputs, outputs_path)
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
    mysetup["MultiStageSettingsDict"] = YAML.load(open(multistage_settings))

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
    OPTIMIZER = configure_solver(settings_path, optimizer)

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

    ### Solve model
    println("Solving Model")

    # Step 3) Run DDP Algorithm
    ## Solve Model
    model_dict, mystats_d, inputs_dict = run_ddp(model_dict, mysetup, inputs_dict)

    # Step 4) Write final outputs from each stage

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

    for p in 1:mysetup["MultiStageSettingsDict"]["NumStages"]
        outpath_cur = joinpath(outpath, "results_p$p")
        write_outputs(model_dict[p], outpath_cur, mysetup, inputs_dict[p])
    end

    # Step 5) Write DDP summary outputs

    write_multi_stage_outputs(mystats_d, outpath, mysetup, inputs_dict)
end
