function load_multistage_dataframe(path::AbstractString)
    filename = "multistage_data.csv"
    filepath = joinpath(path, filename)

    if !isfile(filepath)
        error("Multistage data file not found at $filepath")
    end

    multistage_in = load_dataframe(filepath)

    validate_multistage_data!(multistage_in)

    return multistage_in
end

function validate_multistage_data!(multistage_df::DataFrame)
    # cols that the user must provide
    required_cols = ("Lifetime","Capital_Recovery_Period")
    # check that all required columns are present
    for col in required_cols
        if col ∉ names(multistage_df)
            error("Multistage data file is missing column $col")
        end
    end
end