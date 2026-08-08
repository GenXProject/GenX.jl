@doc raw"""
    write_charge(path::AbstractString, inputs::Dict, setup::Dict, EP::Model,
        cache::OutputCache = build_output_cache(EP, inputs, setup))

Function for writing the charging energy values of the different storage technologies.
The optional `cache` argument allows callers to reuse extracted model outputs across
multiple write functions to reduce memory allocations.
"""
function write_charge(path::AbstractString,
    inputs::Dict,
    setup::Dict,
    EP::Model,
    cache::OutputCache = build_output_cache(EP, inputs, setup))
    gen = inputs["RESOURCES"]   # Resources (objects) 
    resources = inputs["RESOURCE_NAMES"]    # Resource names
    zones = zone_id.(gen)

    T = inputs["T"]     # Number of time steps (hours)
    STOR_ALL = inputs["STOR_ALL"]
    FLEX = inputs["FLEX"]
    ELECTROLYZER = inputs["ELECTROLYZER"]
    ALLAM_CYCLE_LOX = inputs["ALLAM_CYCLE_LOX"] 
    VRE_STOR = inputs["VRE_STOR"]
    VS_STOR = !isempty(VRE_STOR) ? inputs["VS_STOR"] : []
    FUSION = ids_with(gen, :fusion)

    weight = inputs["omega"]
    charge = Matrix{Float64}[]
    charge_ids = Vector{Int}[]
    if !isempty(STOR_ALL)
        push!(charge, cache.vCHARGE)
        push!(charge_ids, STOR_ALL)
    end
    if !isempty(FLEX)
        push!(charge, cache.vCHARGE_FLEX)
        push!(charge_ids, FLEX)
    end
    if (setup["HydrogenMinimumProduction"] > 0) & (!isempty(ELECTROLYZER))
        push!(charge, cache.vUSE)
        push!(charge_ids, ELECTROLYZER)
    end
    if !isempty(VS_STOR)
        push!(charge, cache.vCHARGE_VRE_STOR)
        push!(charge_ids, VS_STOR)
    end
    if !isempty(FUSION)
        _, mat = prepare_fusion_parasitic_power(EP, inputs)
        push!(charge, Matrix{Float64}(mat))
        push!(charge_ids, FUSION)
    end
    if !isempty(ALLAM_CYCLE_LOX)
        push!(charge, cache.vCHARGE_ALLAM)
        push!(charge_ids, ALLAM_CYCLE_LOX)
    end
    charge, charge_ids = materialize_output_blocks(charge, charge_ids, T)

    if cache.scale_factor != 1
        charge .*= cache.scale_factor
    end

    df = DataFrame(Resource = resources[charge_ids],
        Zone = zones[charge_ids])
    df.AnnualSum = charge * weight

    write_temporal_data(df, charge, path, setup, "charge")
    return nothing
end
