@doc raw"""
    write_energy_revenue(path::AbstractString, inputs::Dict, setup::Dict, EP::Model,
        cache::OutputCache = build_output_cache(EP, inputs, setup))

Function for writing energy revenue from the different generation technologies.
The optional `cache` argument allows callers to reuse extracted model outputs across
multiple write functions to reduce memory allocations.
"""
function write_energy_revenue(path::AbstractString,
    inputs::Dict,
    setup::Dict,
    EP::Model,
    cache::OutputCache = build_output_cache(EP, inputs, setup))
    gen = inputs["RESOURCES"]
    regions = region.(gen)
    clusters = cluster.(gen)
    zones = zone_id.(gen)

    G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
    FLEX = inputs["FLEX"]
    NONFLEX = setdiff(collect(1:G), FLEX)
    dfEnergyRevenue = DataFrame(Region = regions,
        Resource = inputs["RESOURCE_NAMES"],
        Zone = zones,
        Cluster = clusters,
        AnnualSum = Array{Float64}(undef, G))
    energyrevenue = resource_time_scratch!(cache)
    price = isnothing(cache.price) ? locational_marginal_price(EP, inputs, setup) :
            cache.price
    energyrevenue[NONFLEX, :] .= cache.vP[NONFLEX, :] .*
                                 transpose(price)[zone_id.(gen[NONFLEX]), :]
    if !isempty(FLEX)
        energyrevenue[FLEX, :] .= cache.vCHARGE_FLEX .*
                                  transpose(price)[zone_id.(gen[FLEX]), :]
    end
    if cache.scale_factor != 1
        rmul!(energyrevenue, cache.scale_factor)
    end
    dfEnergyRevenue.AnnualSum .= energyrevenue * inputs["omega"]
    write_simple_csv(joinpath(path, "EnergyRevenue.csv"), dfEnergyRevenue)
    return dfEnergyRevenue
end
