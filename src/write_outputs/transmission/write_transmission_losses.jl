function write_transmission_losses(path::AbstractString,
        inputs::Dict,
        setup::Dict,
        EP::Model)
    T = inputs["T"]     # Number of time steps (hours)
    L_sym = inputs["L_sym"] # Number of transmission lines with symmetrical bidirectional flow
    L_asym = 0 #Default number of asymmetrical lines
    # Number of lines in the network
    if setup["asymmetrical_trans_flow_limit"] == 1
        L_asym = inputs["L_asym"] #Number of transmission lines with different capacities in two directions
    end
    L = L_sym + L_asym
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
