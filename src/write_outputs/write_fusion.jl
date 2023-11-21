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
    prepare_fusion_pulse_starts(EP::Model, inputs::Dict, setup::Dict)::DataFrame

Prepare a dataframe of the number of fusion plant pulse starts.
"""
function prepare_fusion_pulse_starts(EP::Model, inputs::Dict, setup::Dict)::DataFrame
    expressions = fusion_pulse_start_expressions(inputs)
    df = prepare_timeseries_variables(EP, expressions)
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

@doc raw"""
    write_fusion_pulse_starts(path::AbstractString, inputs, setup, EP::Model)
"""
function write_fusion_pulse_starts(path::AbstractString, inputs, setup, EP::Model)
    df = prepare_fusion_pulse_starts(EP, inputs, setup)
    filename = joinpath(path, "fusion_pulse_starts.csv")
    write_simple_csv(filename, df)
end
