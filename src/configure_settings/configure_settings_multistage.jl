function default_settings_multistage()
    Dict{Any, Any}("NumStages" => 3,
        "StageLengths" => [10,10,10],
        "WACC" => 0.045,
        "ConvergenceTolerance" => 0.01,
        "Myopic" => 0),
        "WriteIntermittentOutputs" => 0
end

@doc raw"""
    configure_settings(settings_path::String, output_settings_path::String)

Reads in the settings from the `multi_stage_settings.yml` YAML file and
merges them with the default multistage settings. It then returns the
settings dictionary.

# Arguments
- `settings_path::String`: The path to the multistage settings YAML file.

# Returns
- `settings::Dict`: The multistage settings dictionary.
"""
function configure_settings_multistage(settings_path::String)
    println("Configuring Multistage Settings")
    model_settings = YAML.load(open(settings_path))

    settings = default_settings_multistage()
    merge!(settings, model_settings)

    return settings
end
