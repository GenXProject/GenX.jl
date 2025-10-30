@doc raw"""
    load_investment_tax_credits!(path::AbstractString, inputs::Dict, setup::Dict)

Read input parameters related to investment tax credit (ITC) policies.
Investment tax credits provide a one-time credit based on the total new capacity invested.
"""
function load_investment_tax_credits!(path::AbstractString, inputs::Dict, setup::Dict)
    filename = "Investment_tax_credits.csv"
    df = load_dataframe(joinpath(path, filename))
    
    # Number of ITC policies
    inputs["NumberOfITC"] = size(df, 1)
    
    # ITC rate (as a fraction, e.g., 0.30 for 30% credit)
    inputs["ITC_Rate"] = df[!, :ITC_Rate]
    
    # ITC qualification start year (optional, -1 if not applicable)
    if "ITC_Start_Year" in names(df)
        inputs["ITC_Start_Year"] = df[!, :ITC_Start_Year]
    end
    
    # ITC qualification end year (optional, -1 if not applicable)
    if "ITC_End_Year" in names(df)
        inputs["ITC_End_Year"] = df[!, :ITC_End_Year]
    end
    
    println(filename * " Successfully Read!")
end
