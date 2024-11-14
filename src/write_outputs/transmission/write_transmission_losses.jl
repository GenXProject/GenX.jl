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
