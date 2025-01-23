function write_transmission_losses(path::AbstractString,
        inputs::Dict,
        setup::Dict,
        EP::Model)
    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones
    L_sym = inputs["L_sym"] # Number of transmission lines with symmetrical bidirectional flow
    L_asym = inputs["L_asym"] #Number of transmission lines with different capacities in two directions
    L = inputs["L"]
    
    UCommit = setup["UCommit"]
    NetworkExpansion = setup["NetworkExpansion"]
    CapacityReserveMargin = setup["CapacityReserveMargin"]
    EnergyShareRequirement = setup["EnergyShareRequirement"]
    IncludeLossesInESR = setup["IncludeLossesInESR"]
    
    SYMMETRIC_LINE_INDEX = inputs["symmetric_line_index"]
    ASYMMETRIC_LINE_INDEX = inputs["asymmetric_line_index"]
    ## sets and indices for transmission losses
    TRANS_LOSS_SEGS = inputs["TRANS_LOSS_SEGS"] # Number of segments used in piecewise linear approximations quadratic loss functions - can only take values of TRANS_LOSS_SEGS =1, 2
    LOSS_LINES = inputs["LOSS_LINES"] # Lines for which loss coefficients apply (are non-zero);
    LOSS_LINES_ASYM = inputs["LOSS_LINES_ASYM"] # Lines for which loss coefficients apply (are non-zero);
    LOSS_LINES_SYM = intersect(SYMMETRIC_LINE_INDEX, LOSS_LINES) # Lines for which loss coefficients apply (are non-zero);
    if NetworkExpansion == 1
        # Network lines and zones that are expandable have non-negative maximum reinforcement inputs
        EXPANSION_LINES = inputs["EXPANSION_LINES"]
        EXPANSION_LINES_ASYM = inputs["EXPANSION_LINES_ASYM"]
    
    end
    # Power losses for transmission between zones at each time step
    dfTLosses = DataFrame(Line = 1:L)
    tlosses = zeros(L, T)
    tlosses[LOSS_LINES_ASYM, :] = value.(EP[:vTLOSS_ASYM][LOSS_LINES_ASYM, :]) # Losses for asymmetrical lines
    tlosses[LOSS_LINES_SYM, :] = value.(EP[:vTLOSS][LOSS_LINES_SYM, :]) # Losses for symmetrical lines
    if setup["ParameterScale"] == 1
        tlosses[LOSS_LINES_ASYM, :] *= ModelScalingFactor
        tlosses[LOSS_LINES_SYM, :] *= ModelScalingFactor
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
