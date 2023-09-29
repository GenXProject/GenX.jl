@doc raw"""Run the GenX time domain reduction on the given case folder

case - folder for the case
stage_id - possibly something to do with MultiStage
verbose - print extra outputs

This function overwrites the time-domain-reduced inputs if they already exist.

"""
function run_timedomainreduction!(case::AbstractString)
    settings_path = get_settings_path(case) #Settings YAML file path
    genx_settings = get_settings_path(case, "genx_settings.yml") #Settings YAML file path
    mysetup = configure_settings(genx_settings) # mysetup dictionary stores settings and GenX-specific parameters

    if mysetup["MultiStage"] == 0
        cluster_inputs(case, settings_path, mysetup)
    elseif mysetup["MultiStage"] == 1
        run_timedomainreduction_multistage!(case)
    else
        error(
            "Unexpected value for key 'MultiStage' in genx_settings.yml. Expected either 0 or 1.",
        )
    end

    return
end

function run_timedomainreduction_multistage!(case::AbstractString)
    # special multistage version
    settings_path = get_settings_path(case)
    genx_settings = get_settings_path(case, "genx_settings.yml")
    mysetup = configure_settings(genx_settings)
    multistage_settings = get_settings_path(case, "multi_stage_settings.yml")

    mysetup["MultiStageSettingsDict"] = YAML.load(open(multistage_settings))

    tdr_settings = get_settings_path(case, "time_domain_reduction_settings.yml")
    TDRSettingsDict = YAML.load(open(tdr_settings))
    if TDRSettingsDict["MultiStageConcatenate"] == 0
        println("Clustering Time Series Data (Individually)...")
        for stage_id = 1:mysetup["MultiStageSettingsDict"]["NumStages"]
            cluster_inputs(case, settings_path, mysetup, stage_id)
        end
    else
        println("Clustering Time Series Data (Grouped)...")
        cluster_inputs(case, settings_path, mysetup)
    end

    return
end
