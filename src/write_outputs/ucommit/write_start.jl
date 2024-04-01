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
    end
    return nothing
end
