@doc raw"""
	write_storage(path::AbstractString, inputs::Dict,setup::Dict, EP::Model)

Function for writing the capacities of different storage technologies, including hydro reservoir, flexible storage tech etc.
"""
function write_storage(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    gen = inputs["RESOURCES"]   # Resources (objects)
    resources = inputs["RESOURCE_NAMES"]   # Resource names
    zones = zone_id.(gen)

    T = inputs["T"]     # Number of time steps (hours)
    G = inputs["G"]
    STOR_ALL = inputs["STOR_ALL"]
    HYDRO_RES = inputs["HYDRO_RES"]
    FLEX = inputs["FLEX"]
    VRE_STOR = inputs["VRE_STOR"]
    VS_STOR = !isempty(VRE_STOR) ? inputs["VS_STOR"] : []

    weight = inputs["omega"]
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    stored = zeros(G, T)
    if !isempty(STOR_ALL)
        stored[STOR_ALL, :] = value.(EP[:vS][STOR_ALL, :])
    end
    if !isempty(HYDRO_RES)
        stored[HYDRO_RES, :] = value.(EP[:vS_HYDRO][HYDRO_RES, :])
    end
    if !isempty(FLEX)
        stored[FLEX, :] = value.(EP[:vS_FLEX][FLEX, :])
    end
    if !isempty(VS_STOR)
        stored[VS_STOR, :] = value.(EP[:vS_VRE_STOR][VS_STOR, :])
    end
    stored *= scale_factor

    df = DataFrame(Resource = resources, Zone = zones)
    df.AnnualSum = stored * weight
    
    write_temporal_data(df, stored, path, setup, "storage")
end
