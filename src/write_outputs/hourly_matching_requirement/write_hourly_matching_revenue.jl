@doc raw"""
	write_hourly_matching_revenue(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for reporting the hourly matching revenue earned by each generator listed in the input file.
GenX will print this file only when an hourly matching requirement is modeled and the shadow price can be obtained form the solver.
Each row corresponds to a generator, and each column starting from the is the total revenue from each hourly matching constraint.
The revenue is calculated as the net generation in each time step multiplied by the shadow price, and then the sum is taken over all modeled time steps.
The last column is the total revenue received from all hourly matching constraints.
"""
function write_hourly_matching_revenue(path::AbstractString,
        inputs::Dict,
        setup::Dict,
        EP::Model)
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
    gen = inputs["RESOURCES"]
    nHM = inputs["nHM"]
    regions = region.(gen)
    clusters = cluster.(gen)
    zones = zone_id.(gen)

    G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
    T = inputs["T"]     # Number of time steps (hours)
    ELECTROLYZERS = inputs["ELECTROLYZER"]
    STOR_ALL = inputs["STOR_ALL"]
    FLEX = inputs["FLEX"]
    NONFLEX = setdiff(collect(1:G), FLEX)
    NONFLEXGEN = setdiff(NONFLEX, STOR_ALL)
    NONFLEXSTOR = intersect(NONFLEX, STOR_ALL)

    dfHMRevenue = DataFrame(Region = regions,
        Resource = inputs["RESOURCE_NAMES"],
        Zone = zones,
        Cluster = clusters)
    annual_sum = zeros(G)
    for i in 1:nHM
        weighted_price = dual.(EP[:cHourlyMatching][:, i]) * scale_factor
        temphmrev = zeros(G)
        temphmrev[NONFLEXGEN] = hm.(gen[NONFLEXGEN], tag = i) .* 
                                (value.(EP[:vP][NONFLEXGEN, :]) * weighted_price)
        if !isempty(STOR_ALL)
            temphmrev[NONFLEXSTOR] = hm.(gen[NONFLEXSTOR], tag = i) .*
                                    ((value.(EP[:vP][NONFLEXSTOR, :]) - value.(EP[:vCHARGE][NONFLEXSTOR, :]).data) * weighted_price)
        end
        if !isempty(FLEX)
            temphmrev[FLEX] = hm.(gen[FLEX], tag = i) .*
                              ((value.(EP[:vCHARGE_FLEX][FLEX,:]).data - value.(EP[:vP][FLEX, :])) * weighted_price)
        end
        if !isempty(ELECTROLYZERS)
            temphmrev[ELECTROLYZERS] = hm.(gen[ELECTROLYZERS], tag = i) .*
                                       (-value.(EP[:vUSE][ELECTROLYZERS, :]).data * weighted_price)
        end

        temphmrev *= scale_factor
        annual_sum .+= temphmrev
        dfHMRevenue = hcat(dfHMRevenue, DataFrame([temphmrev], [Symbol("HM_$i")]))
    end
    dfHMRevenue.AnnualSum = annual_sum
    CSV.write(joinpath(path, "HourlyMatchingRevenue.csv"), dfHMRevenue)
    return dfHMRevenue
end
