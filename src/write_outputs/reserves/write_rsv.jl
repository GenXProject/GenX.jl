function write_rsv(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    T = inputs["T"]     # Number of time steps (hours)
    RSV = inputs["RSV"]
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    resources = inputs["RESOURCE_NAMES"][RSV]
    zones = inputs["R_ZONES"][RSV]
    rsv = value.(EP[:vRSV][RSV, :].data) * scale_factor

    dfRsv = DataFrame(Resource = resources, Zone = zones)

    dfRsv.AnnualSum = rsv * inputs["omega"]

    if setup["WriteOutputs"] == "annual"
        write_annual(joinpath(path, "reg_dn.csv"), dfRsv)
    else # setup["WriteOutputs"] == "full"
        unmet_vec = value.(EP[:vUNMET_RSV]) * scale_factor
        total_unmet = sum(unmet_vec)
        dfRsv = hcat(dfRsv, DataFrame(rsv, :auto))
        auxNew_Names = [Symbol("Resource");
            Symbol("Zone");
            Symbol("AnnualSum");
            [Symbol("t$t") for t in 1:T]]
        rename!(dfRsv, auxNew_Names)

        total = DataFrame(["Total" 0 sum(dfRsv.AnnualSum) zeros(1, T)], :auto)
        unmet = DataFrame(["unmet" 0 total_unmet zeros(1, T)], :auto)
        total[!, 4:(T + 3)] .= sum(rsv, dims = 1)
        unmet[!, 4:(T + 3)] .= transpose(unmet_vec)
        rename!(total, auxNew_Names)
        rename!(unmet, auxNew_Names)
        dfRsv = vcat(dfRsv, unmet, total)
        CSV.write(joinpath(path, "reg_dn.csv"),
            dftranspose(dfRsv, false),
            writeheader = false)
    end
end
