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

    stored = Matrix[]
    if !isempty(STOR_ALL)
        push!(stored, value.(EP[:vS]))
    end
    if !isempty(HYDRO_RES)
        push!(stored, value.(EP[:vS_HYDRO]))
    end
    if !isempty(FLEX)
        push!(stored, value.(EP[:vS_FLEX]))
    end
    if !isempty(VS_STOR)
        push!(stored, value.(EP[:vS_VRE_STOR]))
    end
    stored = reduce(vcat, stored, init = zeros(0, T))
    stored *= scale_factor

    stored_ids = convert(Vector{Int}, vcat(STOR_ALL, HYDRO_RES, FLEX, VS_STOR))
    df = DataFrame(Resource = resources[stored_ids],
        Zone = zones[stored_ids])
    df.AnnualSum = stored * weight

    write_temporal_data(df, stored, path, setup, "storage")
end
