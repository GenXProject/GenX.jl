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
"""
function write_investment_incentive(path::AbstractString,
        inputs::Dict,
        setup::Dict,
        EP::Model)
    gen = inputs["RESOURCES"]
    NumberOfInvIncentive = inputs["NumberOfInvIncentive"]
    
    # Create DataFrame for investment incentive benefits
    dfInvIncentive = DataFrame(InvIncentive_Policy = string.(1:NumberOfInvIncentive))
    
    # Calculate investment incentive benefits for each policy
    inv_incentive_benefits = zeros(NumberOfInvIncentive)
    for incentive in 1:NumberOfInvIncentive
        inv_incentive_benefits[incentive] = value(EP[:eInvIncentiveBenefit][incentive])
    end
    
    # Scale back if parameter scaling is on
    if setup["ParameterScale"] == 1
        inv_incentive_benefits *= ModelScalingFactor^2  # Convert from million $ to $
    end
    
    dfInvIncentive[!, :InvIncentive_Benefit] = inv_incentive_benefits
    
    # Calculate total investment incentive benefit
    total_inv_incentive = sum(inv_incentive_benefits)
    
    # Add total row
    push!(dfInvIncentive, (InvIncentive_Policy = "Total", InvIncentive_Benefit = total_inv_incentive))
    
    # Write to CSV
    CSV.write(joinpath(path, "investment_incentive.csv"), dfInvIncentive)
    
    return total_inv_incentive
end

@doc raw"""
    write_production_incentive(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing production incentive benefits to output files.
"""
function write_production_incentive(path::AbstractString,
        inputs::Dict,
        setup::Dict,
        EP::Model)
    gen = inputs["RESOURCES"]
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
    
    # Create DataFrame for production incentive benefits
    dfProdIncentive = DataFrame(ProdIncentive_Policy = string.(1:NumberOfProdIncentive),
                                ProdIncentive_Type = display_types)
    
    # Calculate production incentive benefits for each policy
    prod_incentive_benefits = zeros(NumberOfProdIncentive)
    for incentive in 1:NumberOfProdIncentive
        prod_incentive_benefits[incentive] = value(EP[:eProdIncentiveBenefit][incentive])
    end
    
    # Scale back if parameter scaling is on
    if setup["ParameterScale"] == 1
        prod_incentive_benefits *= ModelScalingFactor^2  # Convert from million $ to $
    end
    
    dfProdIncentive[!, :ProdIncentive_Benefit] = prod_incentive_benefits
    
    # Calculate total production incentive benefit
    total_prod_incentive = sum(prod_incentive_benefits)
    
    # Add total row
    push!(dfProdIncentive, (ProdIncentive_Policy = "Total", ProdIncentive_Type = "All", ProdIncentive_Benefit = total_prod_incentive))
    
    # Write to CSV
    CSV.write(joinpath(path, "production_incentive.csv"), dfProdIncentive)
    
    return total_prod_incentive
end
