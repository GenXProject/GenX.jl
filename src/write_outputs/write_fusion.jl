###############
# prepare data
# #############

function prepare_fusion_parasitic_power(EP::Model, inputs::Dict)
    return prepare_timeseries_variables(EP,
        inputs,
        fusion_parasitic_power_expressions(inputs),
        "eFusionParasiticTotal_")
end

# similar but zonal; needed for write_power_balance
function fusion_total_parasitic_power_unscaled(
        EP::Model, inputs::Dict, zone::Int)::Vector{Float64}
    symbols = fusion_parasitic_power_expressions(inputs, zone)
    _, mat = prepare_timeseries_variables(EP,
        inputs,
        symbols,
        "eFusionParasiticTotal_")
    return vec(sum(mat, dims = 1))
end

function prepare_fusion_pulse_starts(EP::Model, inputs::Dict)
    prepare_timeseries_variables(EP,
        inputs,
        fusion_pulse_start_expressions(inputs),
        "vFusionPulseStart_")
end

###############
# writing data
###############

# NB: there is no 'write_fusion_parasitic_power'; it is in 'charge.csv'.

function write_fusion_pulse_starts(
        path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    set, data = prepare_fusion_pulse_starts(EP, inputs)
    df = _create_annualsum_df(inputs, set, data)
    write_temporal_data(df, data, path, setup, "fusion_pulse_starts")
end
