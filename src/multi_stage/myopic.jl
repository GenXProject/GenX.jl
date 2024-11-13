@doc raw"""
	run_myopic_multistage(outpath::AbstractString, models_d::Dict, setup::Dict, inputs_d::Dict)

This function solves each stage of the planning problem sequentially, where capacity additions and
retirements from the previous stages are used to determine initial (or existing) capacity at the
beginning of the next stage.

inputs:

  * outpath - string for where to write results
  * models\_d – Dictionary which contains a JuMP model for each model period.
  * setup - Dictionary object containing GenX settings and key parameters.
  * inputs\_d – Dictionary of inputs for each model stage, generated by the load\_inputs() method.

returns:

  * models\_d – Dictionary which contains a JuMP model for each model stage, modified by this method.
  * inputs\_d – Dictionary of inputs for each model stage, generated by the load\_inputs() method, modified by this method.
"""
function run_myopic_multistage(outpath::AbstractString, models_d::Dict, setup::Dict, inputs_d::Dict)
    settings_d = setup["MultiStageSettingsDict"]
    @assert settings_d["Myopic"] == 1 "run_myopic_multistage is only valid for myopic models. update your settings to have Myopic: 1."

    num_stages = settings_d["NumStages"]  # Total number of investment planning stages
    write_intermittent_outputs = settings_d["WriteIntermittentOutputs"] == 1 # 1 if write outputs for each stage

    start_cap_d, cap_track_d = configure_ddp_dicts(setup, inputs_d[1])

    # Step a.i) Initialize cost-to-go function for t = 1:num_stages
    for t in 1:num_stages
        settings_d["CurStage"] = t
        models_d[t] = initialize_cost_to_go(settings_d, models_d[t], inputs_d[t])
    end

    ## solve
    for t in 1:num_stages
        println("***********")
        println("Running stage $t...")
        println("***********")

        if t > 1
            # Fix initial investments for model at time t given optimal solution for time t-1
            models_d[t] = fix_initial_investments(models_d[t - 1],
                models_d[t],
                start_cap_d,
                inputs_d[t])

            # Fix capacity tracking variables for endogenous retirements
            models_d[t] = fix_capacity_tracking(models_d[t - 1],
                models_d[t],
                cap_track_d,
                t)
        end

        # Solve the model at time t
        @objective(models_d[t], Min, models_d[t][:eObj])
        models_d[t], inputs_d[t]["solve_time"] = solve_model(models_d[t], setup)

        if write_intermittent_outputs
            outpath_cur = joinpath(outpath, "results_p$t")
            write_outputs(models_d[t], outpath_cur, setup, inputs_d[t])
        end
    end

    return models_d, inputs_d
        
end