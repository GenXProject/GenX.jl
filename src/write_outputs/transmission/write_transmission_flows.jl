function write_transmission_flows(path::AbstractString,
        inputs::Dict,
        setup::Dict,
        EP::Model)
    # Transmission related values
    T = inputs["T"]     # Number of time steps (hours)
    L = inputs["L"]     # Number of transmission lines
    # Power flows on transmission lines at each time step
    dfFlow = DataFrame(Line = 1:L)
    flow = value.(EP[:vFLOW])

    filepath = joinpath(path, "flow.csv")
    if setup["WriteOutputs"] == "annual"
        dfFlow.AnnualSum = flow * inputs["omega"]
        total = DataFrame(["Total" sum(dfFlow.AnnualSum)], [:Line, :AnnualSum])
        dfFlow = vcat(dfFlow, total)
        CSV.write(filepath, dfFlow)
    else # setup["WriteOutputs"] == "full" 
        dfFlow = hcat(dfFlow, DataFrame(flow, :auto))
        auxNew_Names = [Symbol("Line"); [Symbol("t$t") for t in 1:T]]
        rename!(dfFlow, auxNew_Names)
        CSV.write(filepath, dftranspose(dfFlow, false), writeheader = false)

        if setup["OutputFullTimeSeries"] == 1 && setup["TimeDomainReduction"] == 1
            write_full_time_series_reconstruction(path, setup, dfFlow, "flow")
            @info("Writing Full Time Series for Transmission Flows")
        end
    end
    return nothing
end
