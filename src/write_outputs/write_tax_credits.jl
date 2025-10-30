@doc raw"""
    write_tax_credits(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing investment tax credit (ITC) and production tax credit (PTC) benefits.
This function writes the total tax credit benefits to the costs.csv file and also creates
detailed tax credit output files.
"""
function write_tax_credits(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    # Write ITC benefits if applicable
    if setup["InvestmentTaxCredit"] == 1
        write_investment_tax_credits(path, inputs, setup, EP)
    end
    
    # Write PTC benefits if applicable
    if setup["ProductionTaxCredit"] == 1
        write_production_tax_credits(path, inputs, setup, EP)
    end
end

@doc raw"""
    write_investment_tax_credits(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing investment tax credit (ITC) benefits to output files.
"""
function write_investment_tax_credits(path::AbstractString,
        inputs::Dict,
        setup::Dict,
        EP::Model)
    gen = inputs["RESOURCES"]
    NumberOfITC = inputs["NumberOfITC"]
    
    # Create DataFrame for ITC benefits
    dfITC = DataFrame(ITC_Policy = 1:NumberOfITC)
    
    # Calculate ITC benefits for each policy
    itc_benefits = zeros(NumberOfITC)
    for itc in 1:NumberOfITC
        itc_benefits[itc] = value(EP[:eITCBenefit][itc])
    end
    
    # Scale back if parameter scaling is on
    if setup["ParameterScale"] == 1
        itc_benefits *= ModelScalingFactor^2  # Convert from million $ to $
    end
    
    dfITC[!, :ITC_Benefit] = itc_benefits
    
    # Calculate total ITC benefit
    total_itc = sum(itc_benefits)
    
    # Add total row
    push!(dfITC, (ITC_Policy = "Total", ITC_Benefit = total_itc))
    
    # Write to CSV
    CSV.write(joinpath(path, "investment_tax_credits.csv"), dfITC)
    
    return total_itc
end

@doc raw"""
    write_production_tax_credits(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing production tax credit (PTC) benefits to output files.
"""
function write_production_tax_credits(path::AbstractString,
        inputs::Dict,
        setup::Dict,
        EP::Model)
    gen = inputs["RESOURCES"]
    NumberOfPTC = inputs["NumberOfPTC"]
    
    # Create DataFrame for PTC benefits
    dfPTC = DataFrame(PTC_Policy = 1:NumberOfPTC)
    
    # Calculate PTC benefits for each policy
    ptc_benefits = zeros(NumberOfPTC)
    for ptc in 1:NumberOfPTC
        ptc_benefits[ptc] = value(EP[:ePTCBenefit][ptc])
    end
    
    # Scale back if parameter scaling is on
    if setup["ParameterScale"] == 1
        ptc_benefits *= ModelScalingFactor^2  # Convert from million $ to $
    end
    
    dfPTC[!, :PTC_Benefit] = ptc_benefits
    
    # Calculate total PTC benefit
    total_ptc = sum(ptc_benefits)
    
    # Add total row
    push!(dfPTC, (PTC_Policy = "Total", PTC_Benefit = total_ptc))
    
    # Write to CSV
    CSV.write(joinpath(path, "production_tax_credits.csv"), dfPTC)
    
    return total_ptc
end
