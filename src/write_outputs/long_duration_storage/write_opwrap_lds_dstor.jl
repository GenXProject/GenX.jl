function write_opwrap_lds_dstor(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    ## Extract data frames from input dictionary
    gen = inputs["RESOURCES"]
    zones = zone_id.(gen)

    W = inputs["REP_PERIOD"]     # Number of subperiods
    G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)

    #Excess inventory of storage period built up during representative period w
    dfdStorage = DataFrame(Resource = inputs["RESOURCE_NAMES"], Zone = zones)
    dsoc = zeros(G, W)
    for i in 1:G
        if i in inputs["STOR_LONG_DURATION"]
            dsoc[i, :] = value.(EP[:vdSOC])[i, :]
        end
        if !isempty(inputs["VRE_STOR"])
            if i in inputs["VS_LDS"]
                dsoc[i, :] = value.(EP[:vdSOC_VRE_STOR])[i, :]
            end
        end
    end
    if setup["ParameterScale"] == 1
        dsoc *= ModelScalingFactor
    end

    dfdStorage = hcat(dfdStorage, DataFrame(dsoc, :auto))
    auxNew_Names = [Symbol("Resource"); Symbol("Zone"); [Symbol("w$t") for t in 1:W]]
    rename!(dfdStorage, auxNew_Names)
    CSV.write(joinpath(path, "dStorage.csv"),
        dftranspose(dfdStorage, false),
        header = false)
end
