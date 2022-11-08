@doc raw"""
    load_energy_share_requirement!(setup::Dict, path::AbstractString, inputs::Dict)

Read input parameters related to mimimum energy share requirement constraints
(e.g. renewable portfolio standard or clean electricity standard policies)
"""
function load_energy_share_requirement!(setup::Dict, path::AbstractString, inputs::Dict)
    filename = "Energy_share_requirement.csv"
    df = load_dataframe(joinpath(path, filename))
    mat = extract_matrix_from_dataframe(df, "ESR")
    inputs["dfESR"] = mat
    inputs["nESR"] = size(mat, 2)

    println(filename * " Successfully Read!")
end
