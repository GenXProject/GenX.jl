@doc raw"""
    load_maximum_capacity_requirement!(path::AbstractString, inputs::Dict, setup::Dict)

Read input parameters related to maximum capacity requirement constraints (e.g. technology specific deployment mandates)
"""
function load_maximum_capacity_requirement!(path::AbstractString, inputs::Dict, setup::Dict)
    filename = "Maximum_capacity_requirement.csv"
    df = load_dataframe(joinpath(path, filename))
    inputs["NumberOfMaxCapReqs"] = nrow(df)
    inputs["MaxCapReq"] = df[!, :Max_MW]

    


    if "PriceCap" in names(df)
        inputs["MaxCapPriceCap"] = df[!, :PriceCap] 
    end
    println(filename * " Successfully Read!")
end
