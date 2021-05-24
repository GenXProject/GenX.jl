@doc raw"""
	write_costs(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing the costs pertaining to the objective function (fixed, variable O & M etc.)
"""
function write_costs(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	## Cost results
	dfGen = inputs["dfGen"]
	SEG = inputs["SEG"]  # Number of lines
	Z = inputs["Z"]     # Number of zones
	T = inputs["T"]     # Number of time steps (hours)

	dfCost = DataFrame(Costs = ["cTotal", "cFix", "cVar", "cNSE", "cStart", "cUnmetRsv", "cNetworkExp"])
	if setup["ParameterScale"] == 1
		cVar = (value(EP[:eTotalCVarOut])+value(EP[:eTotalCVarIn])+ (!isempty(inputs["FLEX"]) ? value(EP[:eTotalCVarFlexIn]) : 0)) * (ModelScalingFactor^2)
		cFix = (value(EP[:eTotalCFix]) + (!isempty(inputs["STOR_ALL"]) ? value(EP[:eTotalCFixEnergy]) : 0) + (!isempty(inputs["STOR_ASYMMETRIC"]) ? value(EP[:eTotalCFixCharge]) : 0)) * (ModelScalingFactor^2)
		dfCost[!,Symbol("Total")] = [objective_value(EP) * (ModelScalingFactor^2), cFix, cVar, value(EP[:eTotalCNSE]) * (ModelScalingFactor^2), 0, 0, 0]
	else
		cVar = value(EP[:eTotalCVarOut])+value(EP[:eTotalCVarIn])+ (!isempty(inputs["FLEX"]) ? value(EP[:eTotalCVarFlexIn]) : 0)
		cFix = value(EP[:eTotalCFix]) + (!isempty(inputs["STOR_ALL"]) ? value(EP[:eTotalCFixEnergy]) : 0) + (!isempty(inputs["STOR_ASYMMETRIC"]) ? value(EP[:eTotalCFixCharge]) : 0)
		dfCost[!,Symbol("Total")] = [objective_value(EP), cFix, cVar, value(EP[:eTotalCNSE]), 0, 0, 0]
	end

	if setup["UCommit"]>=1
		if setup["ParameterScale"] == 1
			dfCost[!,2][5] = value(EP[:eTotalCStart]) * (ModelScalingFactor^2)
		else
			dfCost[!,2][5] = value(EP[:eTotalCStart])
		end
	end
	if setup["Reserves"]==1
		if setup["ParameterScale"] == 1
			dfCost[!,2][6] = value(EP[:eTotalCRsvPen]) * (ModelScalingFactor^2)
		else
			dfCost[!,2][6] = value(EP[:eTotalCRsvPen])
		end
	end
	if setup["NetworkExpansion"] == 1 && Z > 1
		if setup["ParameterScale"] == 1
			dfCost[!,2][7] = value(EP[:eTotalCNetworkExp]) * (ModelScalingFactor^2)
		else
			dfCost[!,2][7] = value(EP[:eTotalCNetworkExp])
		end
	end

	for z in 1:Z
		tempCTotal = 0
		tempCFix = 0
		tempCVar = 0
		tempCStart = 0
		for y in dfGen[dfGen[!,:Zone].==z,:][!,:R_ID]
			tempCFix = tempCFix +
				(y in inputs["STOR_ALL"] ? value.(EP[:eCFixEnergy])[y] : 0) +
				(y in inputs["STOR_ASYMMETRIC"] ? value.(EP[:eCFixCharge])[y] : 0) +
				value.(EP[:eCFix])[y]
			tempCVar = tempCVar +
				(y in inputs["STOR_ALL"] ? sum(value.(EP[:eCVar_in])[y,:]) : 0) +
				(y in inputs["FLEX"] ? sum(value.(EP[:eCVarFlex_in])[y,:]) : 0) +
				sum(value.(EP[:eCVar_out])[y,:])
			if setup["UCommit"]>=1
				tempCTotal = tempCTotal +
					value.(EP[:eCFix])[y] +
					(y in inputs["STOR_ALL"] ? sum(value.(EP[:eCVar_in])[y,:]) : 0) +
					(y in inputs["FLEX"] ? sum(value.(EP[:eCVarFlex_in])[y,:]) : 0) +
					sum(value.(EP[:eCVar_out])[y,:])
					(y in inputs["COMMIT"] ? sum(value.(EP[:eCStart])[y,:]) : 0)
				tempCStart = tempCStart +
					(y in inputs["COMMIT"] ? sum(value.(EP[:eCStart])[y,:]) : 0)
			else
				tempCTotal = tempCTotal +
					value.(EP[:eCFix])[y] +
					(y in inputs["STOR_ALL"] ? sum(value.(EP[:eCVar_in])[y,:]) : 0) +
					(y in inputs["FLEX"] ? sum(value.(EP[:eCVarFlex_in])[y,:]) : 0) +
					sum(value.(EP[:eCVar_out])[y,:])
			end
		end

		if setup["ParameterScale"] == 1
			tempCFix = tempCFix * (ModelScalingFactor^2)
			tempCVar = tempCVar * (ModelScalingFactor^2)
			tempCTotal = tempCTotal * (ModelScalingFactor^2)
			tempCStart = tempCStart * (ModelScalingFactor^2)
		end
		if setup["ParameterScale"] == 1
			tempCNSE = sum(value.(EP[:eCNSE])[:,:,z]) * (ModelScalingFactor^2)
		else
			tempCNSE = sum(value.(EP[:eCNSE])[:,:,z])
		end
		dfCost[!,Symbol("Zone$z")] = [tempCTotal, tempCFix, tempCVar, tempCNSE, tempCStart, "-", "-"]
	end
	CSV.write(string(path,sep,"costs.csv"), dfCost)
end
