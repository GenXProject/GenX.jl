
function write_planning_problem_costs(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    ## Cost results
    gen = inputs["RESOURCES"]
    Z = inputs["Z"]     # Number of zones

    cost_list = [
        "cTotal",
        "cFix",
        "cNetworkExp",
        "cUnmetPlanningPolicyPenalty",
    ]

    dfCost = DataFrame(Costs = cost_list)

    cFix = value(EP[:eTotalCFix]) +
           (!isempty(inputs["STOR_ALL"]) ? value(EP[:eTotalCFixEnergy]) : 0.0) +
           (!isempty(inputs["STOR_ASYMMETRIC"]) ? value(EP[:eTotalCFixCharge]) : 0.0)

    total_cost = [
        value(EP[:eObj]),
        cFix,
        0.0,
        0.0,
        ]
    
    dfCost[!, Symbol("Total")] = total_cost

    if setup["ParameterScale"] == 1
        dfCost.Total *= ModelScalingFactor^2
    end


    if setup["NetworkExpansion"] == 1 && Z > 1
        dfCost[3, 2] = value(EP[:eTotalCNetworkExp])
    end


    if haskey(inputs, "MinCapPriceCap")
        dfCost[4, 2] += value(EP[:eTotalCMinCapSlack])
    end

    if haskey(inputs, "MaxCapPriceCap")
        dfCost[4, 2] += value(EP[:eTotalCMaxCapSlack])
    end


    if setup["ParameterScale"] == 1
        dfCost[3, 2] *= ModelScalingFactor^2
        dfCost[4, 2] *= ModelScalingFactor^2
    end

    for z in 1:Z
        tempCFix = 0.0

        Y_ZONE = resources_in_zone_by_rid(gen, z)
        STOR_ALL_ZONE = intersect(inputs["STOR_ALL"], Y_ZONE)
        STOR_ASYMMETRIC_ZONE = intersect(inputs["STOR_ASYMMETRIC"], Y_ZONE)

        eCFix = sum(value.(EP[:eCFix][Y_ZONE]))
        tempCFix += eCFix

        if !isempty(STOR_ALL_ZONE)
            eCFixEnergy = sum(value.(EP[:eCFixEnergy][STOR_ALL_ZONE]))
            tempCFix += eCFixEnergy
        end
        if !isempty(STOR_ASYMMETRIC_ZONE)
            eCFixCharge = sum(value.(EP[:eCFixCharge][STOR_ASYMMETRIC_ZONE]))
            tempCFix += eCFixCharge
        end
        

        if setup["ParameterScale"] == 1
            tempCFix *= ModelScalingFactor^2
        end
        temp_cost_list = [
            "-",
            tempCFix,
            "-",
            "-"
        ]

        dfCost[!, Symbol("Zone$z")] = temp_cost_list
    end
    
    CSV.write(joinpath(path, "planning_problem_costs.csv"), dfCost)
end
