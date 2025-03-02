function write_transmission_losses(path::AbstractString,
        inputs::Dict,
        setup::Dict,
        EP::Model)
    T = inputs["T"]     # Number of time steps (hours)
    L = inputs["L"]

    LOSS_LINES_ASYM = inputs["LOSS_LINES_ASYM"] # Lines for which loss coefficients apply (are non-zero);


    LOSS_LINES_ASYM = inputs["LOSS_LINES_ASYM"] # Lines for which loss coefficients apply (are non-zero);

    SYMMETRIC_LOSS_LINES=inputs["SYMMETRIC_LOSS_LINES"]


    # Power losses for transmission between zones at each time step
    dfTLosses = DataFrame(Line = 1:L)
    tlosses = zeros(L, T)
    if setup["AsymmetricalTransFlowLimit"] == 1
        tlosses[LOSS_LINES_ASYM, :] = value.(EP[:vTLOSS_ASYM][LOSS_LINES_ASYM, :]) # Losses for asymmetrical lines
    end
    tlosses[SYMMETRIC_LOSS_LINES, :] = value.(EP[:vTLOSS][SYMMETRIC_LOSS_LINES, :]) # Losses for symmetrical lines
    if setup["ParameterScale"] == 1
        if setup["AsymmetricalTransFlowLimit"] == 1
            tlosses[LOSS_LINES_ASYM, :] *= ModelScalingFactor
        end
        tlosses[SYMMETRIC_LOSS_LINES, :] *= ModelScalingFactor
    end

    dfTLosses.AnnualSum = tlosses * inputs["omega"]

    if setup["WriteOutputs"] == "annual"
        total = DataFrame(["Total" sum(dfTLosses.AnnualSum)], [:Line, :AnnualSum])
        dfTLosses = vcat(dfTLosses, total)
        CSV.write(joinpath(path, "tlosses.csv"), dfTLosses)
    else
        dfTLosses = hcat(dfTLosses, DataFrame(tlosses, :auto))
        auxNew_Names = [Symbol("Line"); Symbol("AnnualSum"); [Symbol("t$t") for t in 1:T]]
        rename!(dfTLosses, auxNew_Names)
        total = DataFrame(["Total" sum(dfTLosses.AnnualSum) fill(0.0, (1, T))],
            auxNew_Names)
        total[:, 3:(T + 2)] .= sum(tlosses, dims = 1)
        dfTLosses = vcat(dfTLosses, total)
        CSV.write(joinpath(path, "tlosses.csv"),
            dftranspose(dfTLosses, false),
            writeheader = false)

        if setup["OutputFullTimeSeries"] == 1 && setup["TimeDomainReduction"] == 1
            write_full_time_series_reconstruction(path, setup, dfTLosses, "tlosses")
            @info("Writing Full Time Series for Time Losses")
        end
    end
    return nothing
end
