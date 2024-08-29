function write_start(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    COMMIT = inputs["COMMIT"]
    # Startup state for each resource in each time step
    resources = inputs["RESOURCE_NAMES"][COMMIT]
    zones = inputs["R_ZONES"][COMMIT]

    dfStart = DataFrame(Resource = resources, Zone = zones)
    start = value.(EP[:vSTART][COMMIT, :].data)
    dfStart.AnnualSum = start * inputs["omega"]

    filepath = joinpath(path, setup["WriteResultsNamesDict"]["start"])
    if setup["WriteOutputs"] == "annual"
        write_annual(filepath, dfStart, setup)
    else # setup["WriteOutputs"] == "full"	
        df_Start = write_fulltimeseries(filepath, start, dfStart, setup)
        if setup["OutputFullTimeSeries"] == 1 && setup["TimeDomainReduction"] == 1
            write_full_time_series_reconstruction(path, setup, df_Start, "start")
            @info("Writing Full Time Series for Startup")
        end
    end
    return nothing
end
