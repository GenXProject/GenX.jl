@doc raw"""
    load_hydrogen_demand!(setup::Dict, path::AbstractString, inputs::Dict)

Read input parameters related to regional hydrogen demand from electrolysis
"""
function load_hydrogen_demand!(setup::Dict, path::AbstractString, inputs::Dict)
    filename = "Hydrogen_demand.csv"
    df = load_dataframe(joinpath(path, filename))

    inputs["NumberOfH2DemandReqs"] = nrow(df)
    inputs["H2DemandReq"] = df[!, :Hydrogen_Demand_kt]

     # Million $/kton if scaled, $/ton if not scaled

    if "PriceCap" in names(df)
        inputs["H2DemandPriceCap"] = df[!, :PriceCap] 
    end
    println(filename * " Successfully Read!")
end
