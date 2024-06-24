function write_start(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    COMMIT = inputs["COMMIT"]
    # Startup state for each resource in each time step
    resources = inputs["RESOURCE_NAMES"][COMMIT]
    zones = inputs["R_ZONES"][COMMIT]

    dfStart = DataFrame(Resource = resources, Zone = zones)
    start = value.(EP[:vSTART][COMMIT, :].data)
    dfStart.AnnualSum = start * inputs["omega"]

    filepath = joinpath(path, "start.csv")
    if setup["WriteOutputs"] == "annual"
        write_annual(filepath, dfStart)
    else # setup["WriteOutputs"] == "full"	
        write_fulltimeseries(filepath, start, dfStart)
                            # full path, dataout, dfout
        if setup["OutputFullTimeSeries"] == 1 & setup["TimeDomainReduction"] == 1
            T = size(start, 2)
            dfStart = hcat(dfStart, DataFrame(start, :auto))
            auxNew_Names = [Symbol("Resource");
                            Symbol("Zone");
                            Symbol("AnnualSum");
                            [Symbol("t$t") for t in 1:T]]
            rename!(dfStart, auxNew_Names)
            total = DataFrame(["Total" 0 sum(dfStart[!, :AnnualSum]) fill(0.0, (1, T))], auxNew_Names)
            total[!, 4:(T + 3)] .= sum(start, dims = 1)
            df_Start = vcat(dfStart, total)
            DFMatrix = Matrix(dftranspose(df_Start, true))
            DFnames = DFMatrix[1,:]

            FullTimeSeriesFolder = setup["OutputFullTimeSeriesFolder"]
            output_path = joinpath(path, FullTimeSeriesFolder)
            dfOut_full = full_time_series_reconstruction(
                path, setup, dftranspose(df_Start, false), DFnames)
            CSV.write(joinpath(output_path, "start.csv"), dfOut_full, writeheader = false)
            println("Writing Full Time Series for Startup")
        end
    end
    return nothing
end
