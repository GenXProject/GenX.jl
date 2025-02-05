function write_time_weights(path::AbstractString, inputs::Dict, setup::Dict)
    T = inputs["T"]     # Number of time steps (hours)
    # Save array of weights for each time period (when using time sampling)
    dfTimeWeights = DataFrame(Time = 1:T, Weight = inputs["omega"])

    write_output_file(joinpath(path, setup["WriteResultsNamesDict"]["time_weights"]),
            dfTimeWeights,
            filetype = setup["ResultsFileType"],
            compression = setup["ResultsCompressionType"])

end
