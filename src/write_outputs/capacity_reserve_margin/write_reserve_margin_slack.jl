function write_reserve_margin_slack(path::AbstractString,
        inputs::Dict,
        setup::Dict,
        EP::Model)
    NCRM = inputs["NCapacityReserveMargin"]
    T = inputs["T"]     # Number of time steps (hours)
    dfResMar_slack = DataFrame(CRM_Constraint = [Symbol("CapRes_$res") for res in 1:NCRM],
        AnnualSum = value.(EP[:eCapResSlack_Year]),
        Penalty = value.(EP[:eCCapResSlack]))

    if setup["ParameterScale"] == 1
        dfResMar_slack.AnnualSum .*= ModelScalingFactor # Convert GW to MW
        dfResMar_slack.Penalty .*= ModelScalingFactor^2 # Convert Million $ to $
    end

    if setup["WriteOutputs"] == "annual"
        CSV.write(joinpath(path, "ReserveMargin_prices_and_penalties.csv"), dfResMar_slack)
    else     # setup["WriteOutputs"] == "full"
        temp_ResMar_slack = value.(EP[:vCapResSlack])
        if setup["ParameterScale"] == 1
            temp_ResMar_slack .*= ModelScalingFactor # Convert GW to MW
        end
        dfResMar_slack = hcat(dfResMar_slack,
            DataFrame(temp_ResMar_slack, [Symbol("t$t") for t in 1:T]))
        CSV.write(joinpath(path, "ReserveMargin_prices_and_penalties.csv"),
            dftranspose(dfResMar_slack, false),
            writeheader = false)
    end
    return nothing
end
