@doc raw"""
    load_energy_share_requirement!(setup::Dict, path::AbstractString, inputs::Dict)

Read input parameters related to mimimum energy share requirement constraints
(e.g. renewable portfolio standard or clean electricity standard policies)
"""
function load_energy_share_requirement!(setup::Dict, path::AbstractString, inputs::Dict)
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    filename = "Energy_share_requirement_slack.csv"
    if isfile(joinpath(path, filename))
        df = load_dataframe(joinpath(path, filename))
        inputs["dfESR_slack"] = df
        inputs["dfESR_slack"][!, :PriceCap] ./= scale_factor # million $/GWh if scaled, $/MWh if not scaled
    end

    filename = "Energy_share_requirement.csv"
    df = load_dataframe(joinpath(path, filename))
    mat = extract_matrix_from_dataframe(df, "ESR")
    inputs["dfESR"] = mat
    inputs["nESR"] = size(mat, 2)

    println(filename * " Successfully Read!")
end
