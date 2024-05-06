@doc raw"""
	write_multi_stage_capacities_energy(outpath::String, settings_d::Dict)

This function writes the file capacities\_energy\_multi\_stage.csv to the Results directory. This file contains starting resource energy capacities from the first model stage and end resource energy capacities for the first and all subsequent model stages.

inputs:

  * outpath – String which represents the path to the Results directory.
  * settings\_d - Dictionary containing settings dictionary configured in the multi-stage settings file multi\_stage\_settings.yml.
"""
function write_multi_stage_capacities_energy(outpath::String, settings_d::Dict)
    num_stages = settings_d["NumStages"] # Total number of investment planning stages
    capacities_d = Dict()

    for p in 1:num_stages
        inpath = joinpath(outpath, "results_p$p")
        capacities_d[p] = load_dataframe(joinpath(inpath, "capacity.csv"))
    end

    # Set first column of DataFrame as resource names from the first stage
    df_cap = DataFrame(Resource = capacities_d[1][!, :Resource],
        Zone = capacities_d[1][!, :Zone])

    # Store starting capacities from the first stage
    df_cap[!, Symbol("StartEnergyCap_p1")] = capacities_d[1][!, :StartEnergyCap]

    # Store end capacities for all stages
    for p in 1:num_stages
        df_cap[!, Symbol("EndEnergyCap_p$p")] = capacities_d[p][!, :EndEnergyCap]
    end

    CSV.write(joinpath(outpath, "capacities_energy_multi_stage.csv"), df_cap)
end
