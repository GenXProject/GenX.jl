@doc raw"""
	write_charge(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing the charging energy values of the different storage technologies.
"""
function write_charge(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    gen = inputs["RESOURCES"]   # Resources (objects) 
    resources = inputs["RESOURCE_NAMES"]    # Resource names
    zones = zone_id.(gen)

    G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
    T = inputs["T"]     # Number of time steps (hours)
    STOR_ALL = inputs["STOR_ALL"]
    FLEX = inputs["FLEX"]
    ELECTROLYZER = inputs["ELECTROLYZER"]
    VRE_STOR = inputs["VRE_STOR"]
    VS_STOR = !isempty(VRE_STOR) ? inputs["VS_STOR"] : []

    weight = inputs["omega"]
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    charge = zeros(G, T)
    if !isempty(STOR_ALL)
        charge[STOR_ALL, :] = value.(EP[:vCHARGE][STOR_ALL, :])
    end
    if !isempty(FLEX)
        charge[FLEX, :] = value.(EP[:vCHARGE_FLEX][FLEX, :])
    end
    if (setup["HydrogenMinimumProduction"] > 0) & (!isempty(ELECTROLYZER))
        charge[ELECTROLYZER, :] = value.(EP[:vUSE][ELECTROLYZER, :])
    end
    if !isempty(VS_STOR)
        charge[VS_STOR, :] = value.(EP[:vCHARGE_VRE_STOR][VS_STOR, :])
    end

    charge *= scale_factor

    df = DataFrame(Resource = resources,
        Zone = zones,
        AnnualSum = zeros(G))
    df.AnnualSum .= charge * weight

    write_temporal_data(df, charge, path, setup, "charge")
    return nothing
end
