@doc raw"""
    write_incentives(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing investment incentive and production incentive benefits.
This function writes the total incentive benefits to the costs.csv file and also creates
detailed incentive output files.
"""
function write_incentives(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    # Write investment incentive benefits if applicable
    if setup["InvestmentIncentive"] == 1
        write_investment_incentive(path, inputs, setup, EP)
    end

    # Write production incentive benefits if applicable
    if setup["ProductionIncentive"] == 1
        write_production_incentive(path, inputs, setup, EP)
    end
end

@doc raw"""
    write_investment_incentive(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing investment incentive benefits to output files.
Outputs both per-resource and per-policy investment incentive benefits.
"""
function write_investment_incentive(path::AbstractString,
        inputs::Dict,
        setup::Dict,
        EP::Model)
    gen = inputs["RESOURCES"]
    G = inputs["G"]
    NumberOfInvIncentive = inputs["NumberOfInvIncentive"]

    # Initialize vectors to store per-resource data
    regions = String[]
    resources = String[]
    zones = Int[]
    policies = Int[]
    benefits = Float64[]

    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor^2 : 1.0

    # Iterate through each policy and each resource
    for incentive in 1:NumberOfInvIncentive
        eligible_resources = ids_with_policy(gen, :inv_incentive, tag = incentive)

        for y in eligible_resources
            benefit = value(EP[:eInvIncentiveBenefitByResource][y, incentive]) *
                      scale_factor

            push!(regions, string(region(gen[y])))
            push!(resources, resource_name(gen[y]))
            push!(zones, zone_id(gen[y]))
            push!(policies, incentive)
            push!(benefits, benefit)
        end
    end

    # Create per-resource DataFrame
    dfInvIncentive = DataFrame(
        Region = regions,
        Resource = resources,
        Zone = zones,
        Policy_ID = policies,
        AnnualSum = benefits
    )

    # Write per-resource CSV
    CSV.write(joinpath(path, "InvestmentIncentive.csv"), dfInvIncentive)

    # Create per-policy summary DataFrame
    policy_benefits = zeros(NumberOfInvIncentive)
    for incentive in 1:NumberOfInvIncentive
        policy_benefits[incentive] = value(EP[:eInvIncentiveBenefit][incentive]) * scale_factor
    end

    dfInvIncentivePolicy = DataFrame(
        Policy_ID = 1:NumberOfInvIncentive,
        AnnualSum = policy_benefits
    )

    # Add total row
    push!(dfInvIncentivePolicy, (Policy_ID = 0, AnnualSum = sum(policy_benefits)))

    # Write per-policy summary CSV
    CSV.write(joinpath(path, "InvestmentIncentivePolicy.csv"), dfInvIncentivePolicy)

    return sum(benefits)
end

@doc raw"""
    write_production_incentive(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing production incentive benefits to output files.
Outputs both per-resource and per-policy production incentive benefits.
"""
function write_production_incentive(path::AbstractString,
        inputs::Dict,
        setup::Dict,
        EP::Model)
    gen = inputs["RESOURCES"]
    G = inputs["G"]
    NumberOfProdIncentive = inputs["NumberOfProdIncentive"]

    # Map normalized internal values to display format
    display_types = map(inputs["ProdIncentive_Type"]) do type
        if type == "mwh"
            "MWh"
        elseif type == "tonne_co2"
            "Tonne_CO2"
        else
            type  # Fallback, should not happen with validation
        end
    end

    # Initialize vectors to store per-resource data
    regions = String[]
    resources = String[]
    zones = Int[]
    policies = Int[]
    types = String[]
    benefits = Float64[]

    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor^2 : 1.0

    # Iterate through each policy and each resource
    for incentive in 1:NumberOfProdIncentive
        eligible_resources = ids_with_policy(gen, :prod_incentive, tag = incentive)

        for y in eligible_resources
            benefit = value(EP[:eProdIncentiveBenefitByResource][y, incentive]) *
                      scale_factor

            push!(regions, string(region(gen[y])))
            push!(resources, resource_name(gen[y]))
            push!(zones, zone_id(gen[y]))
            push!(policies, incentive)
            push!(types, display_types[incentive])
            push!(benefits, benefit)
        end
    end

    # Create per-resource DataFrame
    dfProdIncentive = DataFrame(
        Region = regions,
        Resource = resources,
        Zone = zones,
        Policy_ID = policies,
        Production_Type = types,
        AnnualSum = benefits
    )

    # Write per-resource CSV
    CSV.write(joinpath(path, "ProductionIncentive.csv"), dfProdIncentive)

    # Create per-policy summary DataFrame
    policy_benefits = zeros(NumberOfProdIncentive)
    for incentive in 1:NumberOfProdIncentive
        policy_benefits[incentive] = value(EP[:eProdIncentiveBenefit][incentive]) * scale_factor
    end

    dfProdIncentivePolicy = DataFrame(
        Policy_ID = 1:NumberOfProdIncentive,
        Production_Type = display_types,
        AnnualSum = policy_benefits
    )

    # Add total row
    push!(dfProdIncentivePolicy, (Policy_ID = 0, Production_Type = "All", AnnualSum = sum(policy_benefits)))

    # Write per-policy summary CSV
    CSV.write(joinpath(path, "ProductionIncentivePolicy.csv"), dfProdIncentivePolicy)

    return sum(benefits)
end
