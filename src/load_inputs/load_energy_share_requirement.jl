@doc raw"""
    load_energy_share_requirement!(setup::Dict, path::AbstractString, inputs::Dict)

Read input parameters related to mimimum energy share requirement constraints
(e.g. renewable portfolio standard or clean electricity standard policies)
"""
function load_energy_share_requirement!(setup::Dict, path::AbstractString, inputs::Dict)
    filename = "Energy_share_requirement.csv"
    df = load_dataframe(joinpath(path, filename))

    f = s -> startswith(s, "ESR")
    columns = names(df)
    first_col = findfirst(f, columns)
    last_col = findlast(f, columns)

    inputs["dfESR"] = Matrix{Float64}(df[:, first_col:last_col])
    inputs["nESR"] = count(f, columns)

    println(filename * " Successfully Read!")
end
