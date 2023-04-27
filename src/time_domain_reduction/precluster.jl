@doc raw"""Run the GenX time domain reduction on the given case folder

case - folder for the case
stage_id - possibly something to do with MultiStage
verbose - print extra outputs

This function overwrites the time-domain-reduced inputs if they already exist.

"""
function run_timedomainreduction!(case::AbstractString; stage_id=-99, verbose=false)
    settings_path = get_settings_path(case) #Settings YAML file path
    genx_settings = get_settings_path(case, "genx_settings.yml") #Settings YAML file path
    mysetup = configure_settings(genx_settings) # mysetup dictionary stores settings and GenX-specific parameters

    cluster_inputs(case, settings_path, mysetup, stage_id, verbose)
    return
end

