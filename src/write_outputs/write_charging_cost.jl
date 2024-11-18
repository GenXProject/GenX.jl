function write_charging_cost(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    gen = inputs["RESOURCES"]  # Resources (objects)
    resources = inputs["RESOURCE_NAMES"] # Resource names

    regions = region.(gen)
    clusters = cluster.(gen)
    zones = zone_id.(gen)

    G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
    T = inputs["T"]     # Number of time steps (hours)
    STOR_ALL = inputs["STOR_ALL"]
    FLEX = inputs["FLEX"]
    ELECTROLYZER = inputs["ELECTROLYZER"]
    VRE_STOR = inputs["VRE_STOR"]
    VS_STOR = !isempty(VRE_STOR) ? inputs["VS_STOR"] : []
    FUSION = ids_with(gen, :fusion)

    weight = inputs["omega"]
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    price = locational_marginal_price(EP, inputs, setup)

    chargecost = zeros(G, T)
    if !isempty(STOR_ALL)
        chargecost[STOR_ALL, :] .= (value.(EP[:vCHARGE][STOR_ALL, :]).data) .*
                                   transpose(price)[zone_id.(gen.Storage), :]
    end
    if !isempty(FLEX)
        chargecost[FLEX, :] .= value.(EP[:vP][FLEX, :]) .*
                               transpose(price)[zone_id.(gen.FlexDemand), :]
    end
    if !isempty(ELECTROLYZER)
        chargecost[ELECTROLYZER, :] .= (value.(EP[:vUSE][ELECTROLYZER, :]).data) .*
                                       transpose(price)[zone_id.(gen.Electrolyzer), :]
    end
    if !isempty(VS_STOR)
        chargecost[VS_STOR, :] .= value.(EP[:vCHARGE_VRE_STOR][VS_STOR, :].data) .*
                                  transpose(price)[zone_id.(gen[VS_STOR]), :]
    end
    if !isempty(FUSION)
        _, mat = prepare_fusion_parasitic_power(EP, inputs)
        chargecost[FUSION, :] = mat
    end
    chargecost *= scale_factor

    dfChargingcost = DataFrame(Region = regions,
        Resource = resources,
        Zone = zones,
        Cluster = clusters,
        AnnualSum = Array{Float64}(undef, G))
    dfChargingcost.AnnualSum .= chargecost * weight

    write_simple_csv(joinpath(path, "ChargingCost.csv"), dfChargingcost)
    return dfChargingcost
end
