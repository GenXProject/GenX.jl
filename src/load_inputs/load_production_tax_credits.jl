@doc raw"""
    load_production_tax_credits!(path::AbstractString, inputs::Dict, setup::Dict)

Read input parameters related to production tax credit (PTC) policies.
Production tax credits provide ongoing credits based on energy production.
"""
function load_production_tax_credits!(path::AbstractString, inputs::Dict, setup::Dict)
    filename = "Production_tax_credits.csv"
    df = load_dataframe(joinpath(path, filename))
    
    # Number of PTC policies
    inputs["NumberOfPTC"] = size(df, 1)
    
    # PTC rate (in $/MWh)
    inputs["PTC_Rate"] = df[!, :PTC_Rate]
    
    # Scale PTC rate based on parameter scaling
    if setup["ParameterScale"] == 1
        inputs["PTC_Rate"] /= ModelScalingFactor # Convert to million $/GWh
    end
    
    # PTC qualification duration in years (optional)
    if "PTC_Duration_Years" in names(df)
        inputs["PTC_Duration_Years"] = df[!, :PTC_Duration_Years]
    end
    
    # PTC qualification start year (optional, -1 if not applicable)
    if "PTC_Start_Year" in names(df)
        inputs["PTC_Start_Year"] = df[!, :PTC_Start_Year]
    end
    
    # PTC qualification end year (optional, -1 if not applicable)
    if "PTC_End_Year" in names(df)
        inputs["PTC_End_Year"] = df[!, :PTC_End_Year]
    end
    
    println(filename * " Successfully Read!")
end
