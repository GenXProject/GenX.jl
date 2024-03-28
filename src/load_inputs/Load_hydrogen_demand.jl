@doc raw"""
    load_hydrogen_demand!(setup::Dict, path::AbstractString, inputs::Dict)

Read input parameters related to regional hydrogen demand from electrolysis
"""
function load_hydrogen_demand!(setup::Dict, path::AbstractString, inputs::Dict)
    filename = "Hydrogen_demand.csv"
    df = load_dataframe(joinpath(path, filename))
    inputs["dfH2Demand"] = df
    inputs["H2Zone"] = df[!, :Zone]
    inputs["H2DemandReq"] = df[!, :Hydrogen_Demand_kt]
    println(filename * " Successfully Read!")
end