@doc raw"""
	write_costs(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing the costs pertaining to the objective function (fixed, variable O&M etc.).
"""
function write_costs(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    ## Cost results
    dfGen = inputs["dfGen"]
    SEG = inputs["SEG"]  # Number of lines
    Z = inputs["Z"]     # Number of zones
    T = inputs["T"]     # Number of time steps (hours)

    dfCost = DataFrame(
        Costs = [
            "cTotal",
            "cFix",
            "cVar",
            "cNSE",
            "cStart",
            "cUnmetRsv",
            "cNetworkExp",
            "cUnmetPolicyPenalty",
        ],
    )
    cVar =
        value(EP[:eTotalCVarOut]) +
        (!isempty(inputs["STOR_ALL"]) ? value(EP[:eTotalCVarIn]) : 0.0) +
        (!isempty(inputs["FLEX"]) ? value(EP[:eTotalCVarFlexIn]) : 0.0)
    cFix =
        value(EP[:eTotalCFix]) +
        (!isempty(inputs["STOR_ALL"]) ? value(EP[:eTotalCFixEnergy]) : 0.0) +
        (!isempty(inputs["STOR_ASYMMETRIC"]) ? value(EP[:eTotalCFixCharge]) : 0.0)
    dfCost[!, Symbol("Total")] =
        [value(EP[:eObj]), cFix, cVar, value(EP[:eTotalCNSE]), 0.0, 0.0, 0.0, 0.0]

    if setup["ParameterScale"] == 1
        dfCost.Total *= ModelScalingFactor^2
    end

    if setup["UCommit"] >= 1
        dfCost[5, 2] = value(EP[:eTotalCStart])
    end

    if setup["Reserves"] == 1
        dfCost[6, 2] = value(EP[:eTotalCRsvPen])
    end

    if setup["NetworkExpansion"] == 1 && Z > 1
        dfCost[7, 2] = value(EP[:eTotalCNetworkExp])
    end

    if haskey(inputs, "dfCapRes_slack")
        dfCost[8, 2] += value(EP[:eCTotalCapResSlack])
    end

    if haskey(inputs, "dfESR_slack")
        dfCost[8, 2] += value(EP[:eCTotalESRSlack])
    end

    if haskey(inputs, "dfCO2Cap_slack")
        dfCost[8, 2] += value(EP[:eCTotalCO2CapSlack])
    end

    if haskey(inputs, "MinCapPriceCap")
        dfCost[8, 2] += value(EP[:eTotalCMinCapSlack])
    end

    if setup["ParameterScale"] == 1
        dfCost[5, 2] *= ModelScalingFactor^2
        dfCost[6, 2] *= ModelScalingFactor^2
        dfCost[7, 2] *= ModelScalingFactor^2
        dfCost[8, 2] *= ModelScalingFactor^2
    end

    for z = 1:Z
        tempCTotal = 0.0
        tempCFix = 0.0
        tempCVar = 0.0
        tempCStart = 0.0
        tempCNSE = 0.0

        Y_ZONE = dfGen[dfGen[!, :Zone].==z, :R_ID]
        STOR_ALL_ZONE = intersect(inputs["STOR_ALL"], Y_ZONE)
        STOR_ASYMMETRIC_ZONE = intersect(inputs["STOR_ASYMMETRIC"], Y_ZONE)
        FLEX_ZONE = intersect(inputs["FLEX"], Y_ZONE)
        COMMIT_ZONE = intersect(inputs["COMMIT"], Y_ZONE)

        eCFix = sum(value.(EP[:eCFix][Y_ZONE]))
        tempCFix += eCFix
        tempCTotal += eCFix

        tempCVar = sum(value.(EP[:eCVar_out][Y_ZONE, :]))
        tempCTotal += tempCVar

        if !isempty(STOR_ALL_ZONE)
            eCVar_in = sum(value.(EP[:eCVar_in][STOR_ALL_ZONE, :]))
            tempCVar += eCVar_in
            eCFixEnergy = sum(value.(EP[:eCFixEnergy][STOR_ALL_ZONE]))
            tempCFix += eCFixEnergy

            tempCTotal += eCVar_in + eCFixEnergy
        end
        if !isempty(STOR_ASYMMETRIC_ZONE)
            eCFixCharge = sum(value.(EP[:eCFixCharge][STOR_ASYMMETRIC_ZONE]))
            tempCFix += eCFixCharge
            tempCTotal += eCFixCharge
        end
        if !isempty(FLEX_ZONE)
            eCVarFlex_in = sum(value.(EP[:eCVarFlex_in][FLEX_ZONE, :]))
            tempCVar += eCVarFlex_in
            tempCTotal += eCVarFlex_in
        end

        if setup["UCommit"] >= 1 && !isempty(COMMIT_ZONE)
            eCStart = sum(value.(EP[:eCStart][COMMIT_ZONE, :]))
            tempCStart += eCStart
            tempCTotal += eCStart
        end

        tempCNSE = sum(value.(EP[:eCNSE][:, :, z]))
        tempCTotal += tempCNSE

        if setup["ParameterScale"] == 1
            tempCTotal *= ModelScalingFactor^2
            tempCFix *= ModelScalingFactor^2
            tempCVar *= ModelScalingFactor^2
            tempCNSE *= ModelScalingFactor^2
            tempCStart *= ModelScalingFactor^2
        end
        dfCost[!, Symbol("Zone$z")] =
            [tempCTotal, tempCFix, tempCVar, tempCNSE, tempCStart, "-", "-", "-"]
    end
    CSV.write(joinpath(path, "costs.csv"), dfCost)
end
