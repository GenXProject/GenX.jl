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

        if setup["OutputFullTimeSeries"] == 1 & setup["TimeDomainReduction"] == 1
            df_Start = CSV.read(joinpath(path,"start.csv"),DataFrame)
            FullTimeSeriesFolder = setup["OutputFullTimeSeriesFolder"]
            output_path = joinpath(path,FullTimeSeriesFolder)
            dfOut_full = full_time_series_reconstruction(path,setup, df_Start,names(df_Start))
            CSV.write(joinpath(output_path,"start.csv"), dfOut_full)
            println("Writing Full Time Series for Startup")
        end
    end
    return nothing
end
