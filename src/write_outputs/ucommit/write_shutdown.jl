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

        if setup["OutputFullTimeSeries"] == 1
            df_Shutdown = CSV.read(joinpath(path,"shutdown.csv"),DataFrame)
            FullTimeSeriesFolder = setup["OutputFullTimeSeriesFolder"]
            output_path = joinpath(path,FullTimeSeriesFolder)
            dfOut_full = full_time_series_reconstruction(path,setup, df_Shutdown,names(df_Shutdown))
            CSV.write(joinpath(output_path,"shutdown.csv"), dfOut_full)
            println("Writing Full Time Series for Shutdown")
        end
    end
    return nothing
end
