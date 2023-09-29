@doc raw"""
    load_minimum_capacity_requirement!(path::AbstractString, inputs::Dict, setup::Dict)

Read input parameters related to mimimum capacity requirement constraints (e.g. technology specific deployment mandates)
"""
function load_minimum_capacity_requirement!(path::AbstractString, inputs::Dict, setup::Dict)
    filename = "Minimum_capacity_requirement.csv"
    df = load_dataframe(joinpath(path, filename))
    NumberOfMinCapReqs = length(df[!, :MinCapReqConstraint])
    inputs["NumberOfMinCapReqs"] = NumberOfMinCapReqs
    inputs["MinCapReq"] = df[!, :Min_MW]
    if setup["ParameterScale"] == 1
        inputs["MinCapReq"] /= ModelScalingFactor # Convert to GW
    end
    if "PriceCap" in names(df)
        inputs["MinCapPriceCap"] = df[!, :PriceCap]
        if setup["ParameterScale"] == 1
            inputs["MinCapPriceCap"] /= ModelScalingFactor # Convert to million $/GW
        end
    end
    println(filename * " Successfully Read!")
end
