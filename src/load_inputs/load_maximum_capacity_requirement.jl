@doc raw"""
    load_maximum_capacity_requirement!(path::AbstractString, inputs::Dict, setup::Dict)

Read input parameters related to maximum capacity requirement constraints (e.g. technology specific deployment mandates)
"""
function load_maximum_capacity_requirement!(path::AbstractString, inputs::Dict, setup::Dict)
    filename = "Maximum_capacity_requirement.csv"
    df = load_dataframe(joinpath(path, filename))
    inputs["NumberOfMaxCapReqs"] = nrow(df)
    inputs["MaxCapReq"] = df[!, :Max_MW]

    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    inputs["MaxCapReq"] /= scale_factor
    if "PriceCap" in names(df)
        inputs["MaxCapPriceCap"] = df[!, :PriceCap] / scale_factor
    end
    println(filename * " Successfully Read!")
end
