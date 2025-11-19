@doc raw"""
    load_investment_incentive!(path::AbstractString, inputs::Dict, setup::Dict)

Read input parameters related to investment incentive policies.
Investment incentives provide a one-time credit based on the total new capacity invested.
"""
function load_investment_incentive!(path::AbstractString, inputs::Dict, setup::Dict)
    filename = "Investment_incentive.csv"
    df = load_dataframe(joinpath(path, filename))

    # Number of investment incentive policies
    inputs["NumberOfInvIncentive"] = size(df, 1)

    # Investment incentive rate (as a fraction, e.g., 0.30 for 30% credit)
    inputs["InvIncentive_Rate"] = df[!, :InvIncentive_Rate]

    # Investment incentive qualification start year (optional, -1 if not applicable)
    if "InvIncentive_Start_Year" in names(df)
        inputs["InvIncentive_Start_Year"] = df[!, :InvIncentive_Start_Year]
    end

    # Investment incentive qualification end year (optional, -1 if not applicable)
    if "InvIncentive_End_Year" in names(df)
        inputs["InvIncentive_End_Year"] = df[!, :InvIncentive_End_Year]
    end

    println(filename * " Successfully Read!")
end
