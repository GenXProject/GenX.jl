function write_commit(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    COMMIT = inputs["COMMIT"]
    T = inputs["T"]

    # Commitment state for each resource in each time step
    resources = inputs["RESOURCE_NAMES"][COMMIT]
    zones = inputs["R_ZONES"][COMMIT]
    zones = convert.(Float64,zones)
    commit = value.(EP[:vCOMMIT][COMMIT, :].data)
    dfCommit = DataFrame(Resource = resources, Zone = zones)
    dfCommit = hcat(dfCommit, DataFrame(commit, :auto))
    auxNew_Names = [Symbol("Resource"); Symbol("Zone"); [Symbol("t$t") for t in 1:T]]
    rename!(dfCommit, auxNew_Names)

    #CSV.write(joinpath(path, "commit.csv"), dftranspose(dfCommit, false), header = false)
    dfCommit = dftranspose(dfCommit,false)
    rename!(dfCommit, Symbol.(Vector(dfCommit[1,:])))
    dfCommit = dfCommit[2:end,:]
    dfCommit[!,1] = convert.(String,dfCommit[!,1])
    dfCommit[!,2:end] = convert.(Float64,dfCommit[!,2:end])
    write_output_file(joinpath(path, setup["WriteResultsNamesDict"]["commit"]), dfCommit, filetype = setup["ResultsFileType"], compression = setup["ResultsCompressionType"])

    if setup["OutputFullTimeSeries"] == 1 && setup["TimeDomainReduction"] == 1
        write_full_time_series_reconstruction(path, setup, dfCommit, setup["WriteResultsNamesDict"]["commit"])
        @info("Writing Full Time Series for Commitment")
    end
end
