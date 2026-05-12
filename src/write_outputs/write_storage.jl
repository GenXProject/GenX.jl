@doc raw"""
    write_storage(path::AbstractString, inputs::Dict,setup::Dict, EP::Model,
        cache::OutputCache = build_output_cache(EP, inputs, setup))

Function for writing the capacities of different storage technologies, including hydro reservoir, flexible storage tech etc.
The optional `cache` argument allows callers to reuse extracted model outputs across
multiple write functions to reduce memory allocations.
"""
function write_storage(path::AbstractString,
    inputs::Dict,
    setup::Dict,
    EP::Model,
    cache::OutputCache = build_output_cache(EP, inputs, setup))
    gen = inputs["RESOURCES"]   # Resources (objects)
    resources = inputs["RESOURCE_NAMES"]   # Resource names
    zones = zone_id.(gen)

    T = inputs["T"]     # Number of time steps (hours)
    STOR_ALL = inputs["STOR_ALL"]
    HYDRO_RES = inputs["HYDRO_RES"]
    FLEX = inputs["FLEX"]
    VRE_STOR = inputs["VRE_STOR"]
    VS_STOR = !isempty(VRE_STOR) ? inputs["VS_STOR"] : []

    weight = inputs["omega"]
    stored = Matrix{Float64}[]
    stored_groups = Vector{Int}[]
    if !isempty(STOR_ALL)
        push!(stored, cache.vS)
        push!(stored_groups, STOR_ALL)
    end
    if !isempty(HYDRO_RES)
        push!(stored, cache.vS_HYDRO)
        push!(stored_groups, HYDRO_RES)
    end
    if !isempty(FLEX)
        push!(stored, cache.vS_FLEX)
        push!(stored_groups, FLEX)
    end
    if !isempty(VS_STOR)
        push!(stored, cache.vS_VRE_STOR)
        push!(stored_groups, VS_STOR)
    end
    stored, stored_ids = materialize_output_blocks(stored, stored_groups, T)
    if cache.scale_factor != 1
        stored .*= cache.scale_factor
    end

    df = DataFrame(Resource = resources[stored_ids],
        Zone = zones[stored_ids])
    df.AnnualSum = stored * weight

    write_temporal_data(df, stored, path, setup, "storage")
end
