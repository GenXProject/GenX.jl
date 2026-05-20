@doc raw"""
	write_charge(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing the charging energy values of the different storage technologies.
"""
function write_charge(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    gen = inputs["RESOURCES"]   # Resources (objects) 
    resources = inputs["RESOURCE_NAMES"]    # Resource names
    zones = zone_id.(gen)

    T = inputs["T"]     # Number of time steps (hours)
    STOR_ALL = inputs["STOR_ALL"]
    FLEX = inputs["FLEX"]
    ELECTROLYZER = inputs["ELECTROLYZER"]
    VRE_STOR = inputs["VRE_STOR"]
    VS_STOR = !isempty(VRE_STOR) ? inputs["VS_STOR"] : []
    FUSION = ids_with(gen, :fusion)

    weight = inputs["omega"]
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    charge = Matrix[]
    charge_ids = Vector{Int}[]
    if !isempty(STOR_ALL)
        push!(charge, value.(EP[:vCHARGE]))
        push!(charge_ids, STOR_ALL)
    end
    if !isempty(FLEX)
        push!(charge, value.(EP[:vCHARGE_FLEX]))
        push!(charge_ids, FLEX)
    end
    if (setup["HydrogenMinimumProduction"] > 0) & (!isempty(ELECTROLYZER))
        push!(charge, value.(EP[:vUSE]))
        push!(charge_ids, ELECTROLYZER)
    end
    if !isempty(VS_STOR)
        push!(charge, value.(EP[:vCHARGE_VRE_STOR]))
        push!(charge_ids, VS_STOR)
    end
    if !isempty(FUSION)
        _, mat = prepare_fusion_parasitic_power(EP, inputs)
        push!(charge, mat)
        push!(charge_ids, FUSION)
    end
    charge = reduce(vcat, charge, init = zeros(0, T))
    charge_ids = reduce(vcat, charge_ids, init = Int[])

    charge *= scale_factor

    df = DataFrame(Resource = resources[charge_ids],
        Zone = zones[charge_ids])
    df.AnnualSum = charge * weight

    write_temporal_data(df, charge, path, setup, "charge")
    return nothing
end
