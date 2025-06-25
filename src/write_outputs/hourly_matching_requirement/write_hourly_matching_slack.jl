function write_hourly_matching_slack(path::AbstractString,
        inputs::Dict,
        setup::Dict,
        EP::Model)
    nHM = inputs["nHM"]
    T = inputs["T"] 
    dfHM_slack = DataFrame(HM_Constraint = [Symbol("HM_$hm") for hm in 1:nHM],
        AnnualSum = value.(EP[:eHMSlack_Year]),
        Penalty = value.(EP[:eCHMSlack]))

    if setup["ParameterScale"] == 1
        dfHM_slack.AnnualSum .*= ModelScalingFactor # Convert GW to MW
        dfHM_slack.Penalty .*= ModelScalingFactor^2 # Convert Million $ to $
    end

    if setup["WriteOutputs"] == "annual"
        CSV.write(joinpath(path, "HourlyMatching_slack_and_penalties.csv"), dfHM_slack)
    else     # setup["WriteOutputs"] == "full"
        temp_HM_slack = transpose(value.(EP[:vHMSlack]))
        if setup["ParameterScale"] == 1
            temp_HM_slack .*= ModelScalingFactor # Convert GW to MW
        end
        dfHM_slack = hcat(dfHM_slack,
            DataFrame(temp_HM_slack, [Symbol("t$t") for t in 1:T]))
        CSV.write(joinpath(path, "HourlyMatching_slack_and_penalties.csv"),
            dftranspose(dfHM_slack, false),
            writeheader = false)
    end
    return nothing
end
