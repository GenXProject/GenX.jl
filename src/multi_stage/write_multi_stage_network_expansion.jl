@doc raw"""
	write_multi_stage_network_expansion(outpath::String, settings_d::Dict)

This function writes the file network\_expansion\_multi\_stage.csv to the Results directory. This file contains new transmission capacities for each modeled transmission line for the first and all subsequent model stages.

inputs:

  * outpath – String which represents the path to the Results directory.
  * settings\_d - Dictionary containing settings dictionary configured in the multi-stage settings file multi\_stage\_settings.yml.
"""
function write_multi_stage_network_expansion(outpath::String, settings_d::Dict)
    # [To Be Completed] Should include discounted NE costs and capacities for each model period as well as initial and intermediate capacity sums.
    num_stages = settings_d["NumStages"] # Total number of investment planning stages
    trans_capacities_d = Dict()

    for p in 1:num_stages
        inpath = joinpath(outpath, "results_p$p")
        trans_capacities_d[p] = load_dataframe(joinpath(inpath, "network_expansion.csv"))
    end

    # Set first column of output DataFrame as line IDs
    df_trans_cap = DataFrame(Line = trans_capacities_d[1][!, :Line])

    # Store new transmission capacities for all stages
    for p in 1:num_stages
        df_trans_cap[!, Symbol("New_Trans_Capacity_p$p")] = trans_capacities_d[p][!,
            :New_Trans_Capacity]
    end

    CSV.write(joinpath(outpath, "network_expansion_multi_stage.csv"), df_trans_cap)
end
