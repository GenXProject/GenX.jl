@doc raw"""
    load_minimum_capacity_requirement!(path::AbstractString, inputs::Dict, setup::Dict)

Read input parameters related to minimum capacity requirement constraints (e.g. technology specific deployment mandates)
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

@doc raw"""
    load_minimum_capacity_requirement_p!(p::Portfolio, inputs::Dict, setup::Dict)

Read input parameters from portfolio related to mimimum capacity requirement constraints (e.g. technology specific deployment mandates)
"""
function load_minimum_capacity_requirement_p!(p::Portfolio, inputs::Dict, setup::Dict)
    #filename = "Minimum_capacity_requirement.csv"
    #df = load_dataframe(joinpath(path, filename))
    
    mincaps = collect(get_requirements(MinimumCapacityRequirements, p))
    mincaps = sort(mincaps, by= PSIP.get_name)

    NumberOfMinCapReqs = length(mincaps)
    inputs["NumberOfMinCapReqs"] = NumberOfMinCapReqs
    inputs["MinCapReq"] = [m.min_mw for m in mincaps]
    if setup["ParameterScale"] == 1
        inputs["MinCapReq"] /= ModelScalingFactor # Convert to GW
    end

    # Add this slack back in later since I think they store it differently
    #inputs["MinCapPriceCap"] = [m.pricecap for m in mincaps]
    #if setup["ParameterScale"] == 1
    #    inputs["MinCapPriceCap"] /= ModelScalingFactor # Convert to million $/GW
    #end

    println("Minimum Requirements Successfully Read!")
end