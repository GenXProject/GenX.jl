function write_transmission_losses(path::AbstractString,
        inputs::Dict,
        setup::Dict,
        EP::Model)
    T = inputs["T"]     # Number of time steps (hours)
    L = inputs["L"]     # Number of transmission lines
    LOSS_LINES = inputs["LOSS_LINES"]
    # Power losses for transmission between zones at each time step
    dfTLosses = DataFrame(Line = 1:L)
    tlosses = zeros(L, T)
    tlosses[LOSS_LINES, :] = value.(EP[:vTLOSS][LOSS_LINES, :])
    if setup["ParameterScale"] == 1
        tlosses[LOSS_LINES, :] *= ModelScalingFactor
    end

    dfTLosses.AnnualSum = tlosses * inputs["omega"]

    if setup["WriteOutputs"] == "annual"
        total = DataFrame(["Total" sum(dfTLosses.AnnualSum)], [:Line, :AnnualSum])
        dfTLosses = vcat(dfTLosses, total)
        #CSV.write(joinpath(path, setup["WriteResultsNamesDict"]["tlosses"]), dfTLosses)
        write_output_file(joinpath(path, setup["WriteResultsNamesDict"]["tlosses"]),
                dfTLosses,
                filetype = setup["ResultsFileType"],
                compression = setup["ResultsCompressionType"])
    else
        dfTLosses = hcat(dfTLosses, DataFrame(tlosses, :auto))
        auxNew_Names = [Symbol("Line"); Symbol("AnnualSum"); [Symbol("t$t") for t in 1:T]]
        rename!(dfTLosses, auxNew_Names)
        total = DataFrame(["Total" sum(dfTLosses.AnnualSum) fill(0.0, (1, T))],
            auxNew_Names)
        total[:, 3:(T + 2)] .= sum(tlosses, dims = 1)
        dfTLosses = vcat(dfTLosses, total)
        #=CSV.write(joinpath(path, setup["WriteResultsNamesDict"]["tlosses"]),
            dftranspose(dfTLosses, false),
            writeheader = false)=#
        
        # Maya: Transpose dataframe, make the first row the header, convert columns to type String and Float 64
        dfTLosses = dftranspose(dfTLosses, false)
        rename!(dfTLosses, Symbol.(Vector(dfTLosses[1,:])))
        dfTLosses = dfTLosses[2:end,:]
        dfTLosses[!,2:end] = convert.(Float64,dfTLosses[!,2:end])
        
        write_output_file(joinpath(path, setup["WriteResultsNamesDict"]["tlosses"]),
            dfTLosses,
            filetype = setup["ResultsFileType"],
            compression = setup["ResultsCompressionType"])

        if setup["OutputFullTimeSeries"] == 1 && setup["TimeDomainReduction"] == 1
            write_full_time_series_reconstruction(path, setup, dfTLosses, setup["WriteResultsNamesDict"]["tlosses"])
            @info("Writing Full Time Series for Time Losses")
        end
    end
    return nothing
end
