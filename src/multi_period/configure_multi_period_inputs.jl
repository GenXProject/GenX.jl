function configure_multi_period_inputs(inputs::Dict)

    dfGen = inputs["dfGen"]

    # Set of all resources eligible for capacity retirements
	inputs["RET_CAP"] = intersect(dfGen[dfGen.New_Build.!=-1,:R_ID])
	# Set of all storage resources eligible for energy capacity retirements
	inputs["RET_CAP_ENERGY"] = intersect(dfGen[dfGen.New_Build.!=-1,:R_ID], inputs["STOR_ALL"])
	# Set of asymmetric charge/discharge storage resources eligible for charge capacity retirements
	inputs["RET_CAP_CHARGE"] = intersect(dfGen[dfGen.New_Build.!=-1,:R_ID], inputs["STOR_ASYMMETRIC"])

    return inputs
end