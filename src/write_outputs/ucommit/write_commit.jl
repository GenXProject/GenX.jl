function write_commit(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    COMMIT = inputs["COMMIT"]
    T = inputs["T"]

    # Commitment state for each resource in each time step
    resources = inputs["RESOURCE_NAMES"][COMMIT]
    zones = inputs["R_ZONES"][COMMIT]
    commit = value.(EP[:vCOMMIT][COMMIT, :].data)
    dfCommit = DataFrame(Resource = resources, Zone = zones)
    dfCommit = hcat(dfCommit, DataFrame(commit, :auto))
    auxNew_Names = [Symbol("Resource"); Symbol("Zone"); [Symbol("t$t") for t in 1:T]]
    rename!(dfCommit, auxNew_Names)
    CSV.write(joinpath(path, "commit.csv"), dftranspose(dfCommit, false), header = false)
end
