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
Outputs per-resource investment incentive benefits for each policy.
"""
function write_investment_incentive(path::AbstractString,
        inputs::Dict,
        setup::Dict,
        EP::Model)
    gen = inputs["RESOURCES"]
    G = inputs["G"]
    NumberOfInvIncentive = inputs["NumberOfInvIncentive"]
    
    # Initialize vectors to store data
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
            benefit = value(EP[:eInvIncentiveBenefitByResource][y, incentive]) * scale_factor
            
            push!(regions, string(region(gen[y])))
            push!(resources, resource_name(gen[y]))
            push!(zones, zone_id(gen[y]))
            push!(policies, incentive)
            push!(benefits, benefit)
        end
    end
    
    # Create DataFrame
    dfInvIncentive = DataFrame(
        Region = regions,
        Resource = resources,
        Zone = zones,
        InvIncentive_Policy = policies,
        AnnualSum = benefits
    )
    
    # Write to CSV
    CSV.write(joinpath(path, "InvestmentIncentive.csv"), dfInvIncentive)
    
    return sum(benefits)
end

@doc raw"""
    write_production_incentive(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing production incentive benefits to output files.
Outputs per-resource production incentive benefits for each policy.
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
    
    # Initialize vectors to store data
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
            benefit = value(EP[:eProdIncentiveBenefitByResource][y, incentive]) * scale_factor
            
            push!(regions, string(region(gen[y])))
            push!(resources, resource_name(gen[y]))
            push!(zones, zone_id(gen[y]))
            push!(policies, incentive)
            push!(types, display_types[incentive])
            push!(benefits, benefit)
        end
    end
    
    # Create DataFrame
    dfProdIncentive = DataFrame(
        Region = regions,
        Resource = resources,
        Zone = zones,
        ProdIncentive_Policy = policies,
        ProdIncentive_Type = types,
        AnnualSum = benefits
    )
    
    # Write to CSV
    CSV.write(joinpath(path, "ProductionIncentive.csv"), dfProdIncentive)
    
    return sum(benefits)
end
