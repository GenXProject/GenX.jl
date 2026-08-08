@doc raw"""
	write_charging_cost(path::AbstractString, inputs::Dict, setup::Dict, EP::Model,
	    cache::OutputCache = build_output_cache(EP, inputs, setup))

Function for writing charging cost from storage, flexible demand, electrolyzers,
and co-located VRE-storage resources.
The optional `cache` argument allows callers to reuse extracted model outputs across
multiple write functions to reduce memory allocations.
"""
function write_charging_cost(path::AbstractString,
    inputs::Dict,
    setup::Dict,
    EP::Model,
    cache::OutputCache = build_output_cache(EP, inputs, setup))
    gen = inputs["RESOURCES"]  # Resources (objects)
    resources = inputs["RESOURCE_NAMES"] # Resource names

    regions = region.(gen)
    clusters = cluster.(gen)
    zones = zone_id.(gen)

    G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
    STOR_ALL = inputs["STOR_ALL"]
    FLEX = inputs["FLEX"]
    ELECTROLYZER = inputs["ELECTROLYZER"]
    VRE_STOR = inputs["VRE_STOR"]
    VS_STOR = !isempty(VRE_STOR) ? inputs["VS_STOR"] : []
    FUSION = ids_with(gen, :fusion)

    weight = inputs["omega"]
    price = isnothing(cache.price) ? locational_marginal_price(EP, inputs, setup) :
            cache.price

    chargecost = resource_time_scratch!(cache)
    if !isempty(STOR_ALL)
        chargecost[STOR_ALL, :] .= cache.vCHARGE .*
                                   transpose(price)[zone_id.(gen.Storage), :]
    end
    if !isempty(FLEX)
        chargecost[FLEX, :] .= cache.vP[FLEX, :] .*
                               transpose(price)[zone_id.(gen.FlexDemand), :]
    end
    if !isempty(ELECTROLYZER)
        chargecost[ELECTROLYZER, :] .= cache.vUSE .*
                                       transpose(price)[zone_id.(gen.Electrolyzer), :]
    end
    if !isempty(VS_STOR)
        chargecost[VS_STOR, :] .= cache.vCHARGE_VRE_STOR .*
                                  transpose(price)[zone_id.(gen[VS_STOR]), :]
    end
    if !isempty(FUSION)
        _, mat = prepare_fusion_parasitic_power(EP, inputs)
        chargecost[FUSION, :] .= mat
    end
    if cache.scale_factor != 1
        rmul!(chargecost, cache.scale_factor)
    end

    dfChargingcost = DataFrame(Region = regions,
        Resource = resources,
        Zone = zones,
        Cluster = clusters,
        AnnualSum = Array{Float64}(undef, G))
    dfChargingcost.AnnualSum .= chargecost * weight

    write_simple_csv(joinpath(path, "ChargingCost.csv"), dfChargingcost)
    return dfChargingcost
end
