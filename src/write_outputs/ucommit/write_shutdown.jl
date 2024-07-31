function write_shutdown(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    # Operational decision variable states
    COMMIT = inputs["COMMIT"]
    zones = inputs["R_ZONES"][COMMIT]
    # Shutdown state for each resource in each time step
    shut = value.(EP[:vSHUT][COMMIT, :].data)
    resources = inputs["RESOURCE_NAMES"][COMMIT]

    dfShutdown = DataFrame(Resource = resources, Zone = zones)
    dfShutdown.AnnualSum = shut * inputs["omega"]

    filepath = joinpath(path,setup["WriteResultsNamesDict"]["shutdown_name"])
    if setup["WriteOutputs"] == "annual"
        write_annual(filepath, dfShutdown, setup)
    else # setup["WriteOutputs"] == "full"
        df_Shutdown = write_fulltimeseries(filepath, shut, dfShutdown, setup)
        if setup["OutputFullTimeSeries"] == 1 && setup["TimeDomainReduction"] == 1
            write_full_time_series_reconstruction(path, setup, df_Shutdown, "shutdown")
            @info("Writing Full Time Series for Shutdown")
        end
    end
    return nothing
end
