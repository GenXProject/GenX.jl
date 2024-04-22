@doc raw"""
    write_multi_stage_outputs(stats_d::Dict, 
        outpath::String, 
        settings_d::Dict, 
        inputs_dict::Dict)

This function calls various methods which write multi-stage modeling outputs as .csv files.

# Arguments:
  * stats\_d: Dictionary which contains the run time, upper bound, and lower bound of each DDP iteration.
  * outpath: String which represents the path to the Results directory.
  * settings\_d: Dictionary containing settings configured in the GenX settings `genx_settings.yml` file as well as the multi-stage settings file `multi_stage_settings.yml`.
  * inputs\_dict: Dictionary containing the input data for the multi-stage model.
"""
function write_multi_stage_outputs(stats_d::Dict,
        outpath::String,
        settings_d::Dict,
        inputs_dict::Dict)
    multi_stage_settings_d = settings_d["MultiStageSettingsDict"]

    write_multi_stage_capacities_discharge(outpath, multi_stage_settings_d)
    write_multi_stage_capacities_charge(outpath, multi_stage_settings_d)
    write_multi_stage_capacities_energy(outpath, multi_stage_settings_d)
    if settings_d["NetworkExpansion"] == 1
        write_multi_stage_network_expansion(outpath, multi_stage_settings_d)
    end
    write_multi_stage_costs(outpath, multi_stage_settings_d, inputs_dict)
    multi_stage_settings_d["Myopic"] == 0 && write_multi_stage_stats(outpath, stats_d)
    write_multi_stage_settings(outpath, settings_d)
end
