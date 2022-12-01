@doc raw"""
    prepare_fusion_parasitic_power(EP::Model, inputs::Dict, setup::Dict)::DataFrame

Prepare a dataframe of total fusion parasitic power, with values in MW.
"""
function prepare_fusion_parasitic_power(EP::Model, inputs::Dict, setup::Dict)::DataFrame
    parasitic_expressions = fusion_parasitic_power_expressions(inputs)
    scale = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1.0
    df = prepare_timeseries_variables(EP, parasitic_expressions, scale)
    return df
end

@doc raw"""
    write_fusion_parasitic_power(path::AbstractString, inputs, setup, EP::Model)
"""
function write_fusion_parasitic_power(path::AbstractString, inputs, setup, EP::Model)
    df = prepare_fusion_parasitic_power(EP, inputs, setup)
    filename = joinpath(path, "fusion_parasitic_power.csv")
    write_simple_csv(filename, df)
end
