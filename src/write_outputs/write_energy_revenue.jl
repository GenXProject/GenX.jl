@doc raw"""
	write_energy_revenue(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing energy revenue from the different generation technologies.
"""
function write_energy_revenue(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    gen = inputs["RESOURCES"]
    regions = region.(gen)
    clusters = cluster.(gen)
    zones = zone_id.(gen)

    G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
    T = inputs["T"]     # Number of time steps (hours)
    FLEX = inputs["FLEX"]
    NONFLEX = setdiff(collect(1:G), FLEX)
    dfEnergyRevenue = DataFrame(Region = regions,
        Resource = inputs["RESOURCE_NAMES"],
        Zone = zones,
        Cluster = clusters,
        AnnualSum = Array{Float64}(undef, G))
    energyrevenue = zeros(G, T)
    price = locational_marginal_price(EP, inputs, setup)
    energyrevenue[NONFLEX, :] = value.(EP[:vP][NONFLEX, :]) .*
                                transpose(price)[zone_id.(gen[NONFLEX]), :]
    if !isempty(FLEX)
        energyrevenue[FLEX, :] = value.(EP[:vCHARGE_FLEX][FLEX, :]).data .*
                                 transpose(price)[zone_id.(gen[FLEX]), :]
    end
    if setup["ParameterScale"] == 1
        energyrevenue *= ModelScalingFactor
    end
    dfEnergyRevenue.AnnualSum .= energyrevenue * inputs["omega"]
    write_simple_csv(joinpath(path, "EnergyRevenue.csv"), dfEnergyRevenue)
    return dfEnergyRevenue
end
