@doc raw"""
	write_reliability(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for reporting dual variable of maximum non-served energy constraint (shadow price of reliability constraint) for each model zone and time step.
"""
function write_reliability(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones

    # reliability: Dual variable of maximum NSE constraint = shadow value of reliability constraint
    dfReliability = DataFrame(Zone = 1:Z)
    # Dividing dual variable for each hour with corresponding hourly weight to retrieve marginal cost of generation
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
    dfReliability = hcat(dfReliability,
        DataFrame(transpose(dual.(EP[:cMaxNSE]) ./ inputs["omega"] * scale_factor), :auto))

    auxNew_Names = [Symbol("Zone"); [Symbol("t$t") for t in 1:T]]
    rename!(dfReliability, auxNew_Names)

    #=CSV.write(joinpath(path, setup["WriteResultsNamesDict"]["reliability"]),
        dftranspose(dfReliability, false),
        header = false)=#

    # Maya: Transpose dataframe, make the first row the header, convert columns to type String and Float 64
    dfReliability = dftranspose(dfReliability, false)
    rename!(dfReliability, Symbol.(Vector(dfReliability[1,:])))
    dfReliability = dfReliability[2:end,:]
    dfReliability[!,2:end] = convert.(Float64,dfReliability[!,2:end])
    
    write_output_file(joinpath(path, setup["WriteResultsNamesDict"]["reliability"]),
            dfReliability,
            filetype = setup["ResultsFileType"],
            compression = setup["ResultsCompressionType"])


    if setup["OutputFullTimeSeries"] == 1 && setup["TimeDomainReduction"] == 1
        write_full_time_series_reconstruction(path, setup, dfReliability, setup["WriteResultsNamesDict"]["reliability"])
        @info("Writing Full Time Series for Reliability")
    end
end
