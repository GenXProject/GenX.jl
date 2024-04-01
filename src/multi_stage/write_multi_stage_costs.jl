@doc raw"""
	write_multi_stage_costs(outpath::String, settings_d::Dict)

This function writes the file costs\_multi\_stage.csv to the Results directory. This file contains variable, fixed, startup, network expansion, unmet reserve, and non-served energy costs discounted to year zero.

inputs:

  * outpath – String which represents the path to the Results directory.
  * settings\_d - Dictionary containing settings dictionary configured in the multi-stage settings file multi\_stage\_settings.yml.
"""
function write_multi_stage_costs(outpath::String, settings_d::Dict, inputs_dict::Dict)
    num_stages = settings_d["NumStages"] # Total number of DDP stages
    wacc = settings_d["WACC"] # Interest Rate and also the discount rate unless specified other wise
    stage_lens = settings_d["StageLengths"]
    myopic = settings_d["Myopic"] == 1 # 1 if myopic (only one forward pass), 0 if full DDP

    costs_d = Dict()
    for p in 1:num_stages
        cur_path = joinpath(outpath, "results_p$p")
        costs_d[p] = load_dataframe(joinpath(cur_path, "costs.csv"))
    end

    OPEXMULTS = [inputs_dict[j]["OPEXMULT"] for j in 1:num_stages] # Stage-wise OPEX multipliers to count multiple years between two model stages

    # Set first column of DataFrame as resource names from the first stage
    df_costs = DataFrame(Costs = costs_d[1][!, :Costs])

    # Store discounted total costs for each stage in a data frame
    for p in 1:num_stages
        if myopic
            DF = 1 # DF=1 because we do not apply discount factor in myopic case
        else
            DF = 1 / (1 + wacc)^(stage_lens[p] * (p - 1))  # Discount factor applied to ALL costs in each stage
        end
        df_costs[!, Symbol("TotalCosts_p$p")] = DF .* costs_d[p][!, Symbol("Total")]
    end

    # For OPEX costs, apply additional discounting
    for cost in ["cVar", "cNSE", "cStart", "cUnmetRsv"]
        if cost in df_costs[!, :Costs]
            df_costs[df_costs[!, :Costs] .== cost, 2:end] = transpose(OPEXMULTS) .*
                                                            df_costs[df_costs[!, :Costs] .== cost,
                2:end]
        end
    end

    # Remove "cTotal" from results (as this includes Cost-to-Go)
    df_costs = df_costs[df_costs[!, :Costs] .!= "cTotal", :]

    CSV.write(joinpath(outpath, "costs_multi_stage.csv"), df_costs)
end
