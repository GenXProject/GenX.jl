function write_shutdown(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    # Operational decision variable states
    COMMIT = inputs["COMMIT"]
    zones = inputs["R_ZONES"][COMMIT]
    # Shutdown state for each resource in each time step
    shut = value.(EP[:vSHUT][COMMIT, :].data)
    resources = inputs["RESOURCE_NAMES"][COMMIT]

    dfShutdown = DataFrame(Resource = resources, Zone = zones)
    dfShutdown.AnnualSum = shut * inputs["omega"]

    filepath = joinpath(path, "shutdown.csv")
    if setup["WriteOutputs"] == "annual"
        write_annual(filepath, dfShutdown)
    else # setup["WriteOutputs"] == "full"
        write_fulltimeseries(filepath, shut, dfShutdown)

        if setup["OutputFullTimeSeries"] == 1 & setup["TimeDomainReduction"] == 1
            T = size(shut, 2)
            dfShutdown = hcat(dfShutdown, DataFrame(shut, :auto))
            auxNew_Names = [Symbol("Resource");
                            Symbol("Zone");
                            Symbol("AnnualSum");
                            [Symbol("t$t") for t in 1:T]]
            rename!(dfShutdown, auxNew_Names)
            total = DataFrame(["Total" 0 sum(dfShutdown[!, :AnnualSum]) fill(0.0, (1, T))], auxNew_Names)
            total[!, 4:(T + 3)] .= sum(shut, dims = 1)
            df_Shutdown = vcat(dfShutdown, total)
            DFMatrix = Matrix(dftranspose(df_Shutdown, true))
            DFnames = DFMatrix[1,:]

            FullTimeSeriesFolder = setup["OutputFullTimeSeriesFolder"]
            output_path = joinpath(path,FullTimeSeriesFolder)
            dfOut_full = full_time_series_reconstruction(path,setup, dftranspose(df_Shutdown, false), DFnames)
            CSV.write(joinpath(output_path,"shutdown.csv"), dfOut_full, writeheader = false)
            println("Writing Full Time Series for Shutdown")
        end
    end
    return nothing
end
