@doc raw"""
    load_production_incentive!(path::AbstractString, inputs::Dict, setup::Dict)

Read input parameters related to production incentive policies.
Production incentives provide ongoing credits based on energy production or CO₂ captured.
"""
function load_production_incentive!(path::AbstractString, inputs::Dict, setup::Dict)
    filename = "Production_incentive.csv"
    df = load_dataframe(joinpath(path, filename))
    
    # Number of production incentive policies
    inputs["NumberOfProdIncentive"] = size(df, 1)
    
    # Production incentive rate (in $/MWh for energy-based or $/tonne for CO2-based)
    inputs["ProdIncentive_Rate"] = df[!, :ProdIncentive_Rate]
    
    # Production incentive type: "energy" for MWh-based, "co2" for CO₂ captured-based
    if "ProdIncentive_Type" in names(df)
        inputs["ProdIncentive_Type"] = df[!, :ProdIncentive_Type]
    else
        # Default to energy-based for backward compatibility
        inputs["ProdIncentive_Type"] = fill("energy", size(df, 1))
    end
    
    # Scale production incentive rate based on parameter scaling
    if setup["ParameterScale"] == 1
        inputs["ProdIncentive_Rate"] /= ModelScalingFactor # Convert to million $/GWh or million $/ktonne
    end
    
    # Production incentive qualification duration in years (optional)
    if "ProdIncentive_Duration_Years" in names(df)
        inputs["ProdIncentive_Duration_Years"] = df[!, :ProdIncentive_Duration_Years]
    end
    
    # Production incentive qualification start year (optional, -1 if not applicable)
    if "ProdIncentive_Start_Year" in names(df)
        inputs["ProdIncentive_Start_Year"] = df[!, :ProdIncentive_Start_Year]
    end
    
    # Production incentive qualification end year (optional, -1 if not applicable)
    if "ProdIncentive_End_Year" in names(df)
        inputs["ProdIncentive_End_Year"] = df[!, :ProdIncentive_End_Year]
    end
    
    println(filename * " Successfully Read!")
end
