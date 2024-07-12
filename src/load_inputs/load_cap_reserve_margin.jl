@doc raw"""
	load_cap_reserve_margin!(setup::Dict, path::AbstractString, inputs::Dict, input_names::Dict)

Read input parameters related to planning reserve margin constraints
"""
function load_cap_reserve_margin!(setup::Dict, path::AbstractString, inputs::Dict, input_names::Dict)
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    filename = input_names["CRM_slack_name"]
    if isfile(joinpath(path, filename))
        df = load_dataframe(joinpath(path, filename))
        inputs["dfCapRes_slack"] = df
        inputs["dfCapRes_slack"][!, :PriceCap] ./= scale_factor # Million $/GW if scaled, $/MW if not scaled
    end

    filename = input_names["capacity_name"]
    df = load_dataframe(joinpath(path, filename))

    mat = extract_matrix_from_dataframe(df, "CapRes")
    inputs["dfCapRes"] = mat
    inputs["NCapacityReserveMargin"] = size(mat, 2)

    println(filename * " Successfully Read!")
end

@doc raw"""
	load_cap_reserve_margin_trans!(setup::Dict, inputs::Dict, network_var::DataFrame)

Read input parameters related to participation of transmission imports/exports in capacity reserve margin constraint.
"""
function load_cap_reserve_margin_trans!(setup::Dict, inputs::Dict, network_var::DataFrame)
    mat = extract_matrix_from_dataframe(network_var, "DerateCapRes")
    inputs["dfDerateTransCapRes"] = mat

    mat = extract_matrix_from_dataframe(network_var, "CapRes_Excl")
    inputs["dfTransCapRes_excl"] = mat
end
