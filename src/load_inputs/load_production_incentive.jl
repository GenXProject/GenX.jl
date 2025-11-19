@doc raw"""
    load_production_incentive!(path::AbstractString, inputs::Dict, setup::Dict)

Read input parameters related to production incentive policies.
Production incentives provide ongoing credits based on energy production or CO₂ captured.

The `ProdIncentive_Type` column accepts the following values (case-insensitive):
- "MWh" or "mwh" for energy-based incentives ($/MWh)
- "Tonne_CO2" or "tonne_co2" (preferred) for CO₂ capture-based incentives ($/tonne CO₂)
- "ton_CO2" or "ton_co2" (accepted alias for Tonne_CO2)
"""
function load_production_incentive!(path::AbstractString, inputs::Dict, setup::Dict)
    filename = "Production_incentive.csv"
    df = load_dataframe(joinpath(path, filename))
    
    # Number of production incentive policies
    inputs["NumberOfProdIncentive"] = size(df, 1)
    
    # Production incentive rate (in $/MWh for energy-based or $/tonne for CO2-based)
    inputs["ProdIncentive_Rate"] = df[!, :ProdIncentive_Rate]
    
    # Production incentive type: must be explicitly provided as "MWh" or "Tonne_CO2" (alias "ton_CO2")
    if "ProdIncentive_Type" in names(df)
        raw_types = df[!, :ProdIncentive_Type]
    else
        @error "Missing required column 'ProdIncentive_Type' in Production_incentive.csv."
        @error "Add a ProdIncentive_Type column with values: 'MWh', 'Tonne_CO2', or 'ton_CO2' (case-insensitive)."
        error("Production_incentive.csv is missing the ProdIncentive_Type column")
    end
    
    # Validate and normalize ProdIncentive_Type values
    # Create new array to avoid issues with PooledArrays
    accepted_types = ["mwh", "tonne_co2", "ton_co2"]
    normalized_types = String[]
    
    for (i, incentive_type) in enumerate(raw_types)
        # Strip whitespace and convert to lowercase for comparison
        normalized_type = lowercase(strip(string(incentive_type)))
        if !(normalized_type in accepted_types)
            @error """Invalid value for ProdIncentive_Type in row $i of Production_incentive.csv.
            Expected one of: 'MWh', 'Tonne_CO2', 'ton_CO2' (case-insensitive)
            Got: "$incentive_type"
            """
            error("Invalid ProdIncentive_Type value detected")
        end
        # Normalize "ton_co2" to "tonne_co2" for consistency
        if normalized_type == "ton_co2"
            normalized_type = "tonne_co2"
        end
        push!(normalized_types, normalized_type)
    end
    
    # Store normalized types
    inputs["ProdIncentive_Type"] = normalized_types
    
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
