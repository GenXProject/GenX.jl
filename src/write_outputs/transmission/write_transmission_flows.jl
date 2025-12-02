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

    dfFlow_price_out = DataFrame(Line = 1:L)
    dfFlow_price_in = DataFrame(Line = 1:L)
    congestion_price_out = dual.(EP[:cMaxFlow_out])
    congestion_price_in = dual.(EP[:cMaxFlow_in])
    if setup["ParameterScale"] == 1
        flow *= ModelScalingFactor
    end

    filepath = joinpath(path, "flow.csv")
    filepath_price_in = joinpath(path, "flow_price_in.csv")
    filepath_price_out = joinpath(path, "flow_price_out.csv")
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

        dfFlow_price_in = hcat(dfFlow_price_in, DataFrame(congestion_price_in, :auto))
        rename!(dfFlow_price_in, auxNew_Names)
        CSV.write(filepath_price_in, dftranspose(dfFlow_price_in, false), writeheader = false)
        dfFlow_price_out = hcat(dfFlow_price_out, DataFrame(congestion_price_out, :auto))
        rename!(dfFlow_price_out, auxNew_Names)
        CSV.write(filepath_price_out, dftranspose(dfFlow_price_out, false), writeheader = false)

        if setup["OutputFullTimeSeries"] == 1 && setup["TimeDomainReduction"] == 1
            write_full_time_series_reconstruction(path, setup, dfFlow, "flow")
            @info("Writing Full Time Series for Transmission Flows")
        end
    end
    return nothing
end
