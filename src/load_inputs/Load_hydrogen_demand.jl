@doc raw"""
    load_hydrogen_demand!(setup::Dict, path::AbstractString, inputs::Dict)

Read input parameters related to regional hydrogen demand from electrolysis
"""
function load_hydrogen_demand!(setup::Dict, path::AbstractString, inputs::Dict)
    filename = "Hydrogen_demand.csv"
    df = load_dataframe(joinpath(path, filename))

    inputs["NumberOfH2DemandReqs"] = nrow(df)
    inputs["H2DemandReq"] = df[!, :Hydrogen_Demand_kt]

    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1 # Million $/kton if scaled, $/ton if not scaled

    if "PriceH2" in names(df)
        inputs["H2DemandPriceH2"] = df[!, :PriceH2] / scale_factor
    end
    println(filename * " Successfully Read!")
end