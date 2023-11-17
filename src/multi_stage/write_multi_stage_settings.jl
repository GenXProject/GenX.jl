@doc raw"""
    write_multi_stage_settings(outpath::AbstractString, settings_d::Dict)

Function for writing the multi-stage settings file to the output path for future reference.
"""
function write_multi_stage_settings(outpath::AbstractString, settings_d::Dict)
    multi_stage_settings_d = settings_d["MultiStageSettingsDict"]
    YAML.write_file(joinpath(outpath, "genx_settings.yml"), settings_d)
    YAML.write_file(joinpath(outpath, "multi_stage_settings.yml"), multi_stage_settings_d)
end
