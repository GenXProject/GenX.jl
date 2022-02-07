"""
GenX: An Configurable Capacity Expansion Model
Copyright (C) 2021,  Massachusetts Institute of Technology
This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
A complete copy of the GNU General Public License v2 (GPLv2) is available
in LICENSE.txt.  Users uncompressing this from an archive may not have
received this license file.  If not, see <http://www.gnu.org/licenses/>.
"""

@doc raw"""
	write_costs(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing the costs pertaining to the objective function (fixed, variable O&M etc.).
"""
function write_costs(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	## Cost results
	dfGen = inputs["dfGen"]
	SEG = inputs["SEG"]  # Number of lines
	Z = inputs["Z"]     # Number of zones
	T = inputs["T"]     # Number of time steps (hours)

	dfCost = DataFrame(Costs = ["cTotal", "cFix", "cVar", "cCO2Tax", "cNSE", "cStart", "cUnmetRsv", "cNetworkExp"])
	if setup["ParameterScale"] == 1
		cVar = (value(EP[:eTotalCVarOut])+value(EP[:eTotalCVarIn])+ (!isempty(inputs["FLEX"]) ? value(EP[:eTotalCVarFlexIn]) : 0)) * (ModelScalingFactor^2)
		if setup["PieceWiseHeatRate"] == 1 && setup["UCommit"] >= 1
			cVar = cVar + value(EP[:eCVar_fuel_piecewise]) * (ModelScalingFactor^2)
		end
		cFix = (value(EP[:eTotalCFix]) + (!isempty(inputs["STOR_ALL"]) ? value(EP[:eTotalCFixEnergy]) : 0) + (!isempty(inputs["STOR_ASYMMETRIC"]) ? value(EP[:eTotalCFixCharge]) : 0)) * (ModelScalingFactor^2)
		if setup["FLECCS"] >= 1 
			cVar = cVar + value.(EP[:eTotalCVar_FLECCS])* (ModelScalingFactor^2)
			cFix = cFix  + value.(EP[:eTotalCFixFLECCS])* (ModelScalingFactor^2)
		end
		cCO2Tax = value.(EP[:eTotalCCO2Tax])* (ModelScalingFactor^2)

		dfCost[!,Symbol("Total")] = [objective_value(EP) * (ModelScalingFactor^2), cFix, cVar, cCO2Tax, value(EP[:eTotalCNSE]) * (ModelScalingFactor^2), 0, 0, 0]
	else
		cVar = value(EP[:eTotalCVarOut])+value(EP[:eTotalCVarIn])+ (!isempty(inputs["FLEX"]) ? value(EP[:eTotalCVarFlexIn]) : 0)
		if setup["PieceWiseHeatRate"] == 1 && setup["UCommit"] >= 1
			cVar = cVar + value(EP[:eCVar_fuel_piecewise])
		end
		cFix = value(EP[:eTotalCFix]) + (!isempty(inputs["STOR_ALL"]) ? value(EP[:eTotalCFixEnergy]) : 0) + (!isempty(inputs["STOR_ASYMMETRIC"]) ? value(EP[:eTotalCFixCharge]) : 0)
		if setup["FLECCS"] >= 1 
			cVar = cVar + value.(EP[:eTotalCVar_FLECCS])
			cFix = cFix  + value.(EP[:eTotalCFixFLECCS])
		end
		cCO2Tax = value.(EP[:eTotalCCO2Tax])
		dfCost[!,Symbol("Total")] = [objective_value(EP), cFix, cVar, cCO2Tax, value(EP[:eTotalCNSE]), 0, 0, 0]
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


			if setup["PieceWiseHeatRate"] == 1 && setup["UCommit"] >= 1
				tempCVar = tempCVar + (y in inputs["COMMIT"] ? sum(value.(EP[:eCFuel_piecewise])[y,:]) : 0)
			end

			if setup["UCommit"]>=1
				tempCTotal = tempCTotal +
					value.(EP[:eCFix])[y] +
					(y in inputs["STOR_ALL"] ? sum(value.(EP[:eCVar_in])[y,:]) : 0) +
					(y in inputs["FLEX"] ? sum(value.(EP[:eCVarFlex_in])[y,:]) : 0) +
					sum(value.(EP[:eCVar_out])[y,:])
					(y in inputs["COMMIT"] ? sum(value.(EP[:eCStart])[y,:]) : 0)
				tempCStart = tempCStart +
					(y in inputs["COMMIT"] ? sum(value.(EP[:eCStart])[y,:]) : 0)
				if setup["PieceWiseHeatRate"] == 1
					tempCTotal = tempCTotal + (y in inputs["COMMIT"] ? sum(value.(EP[:eCFuel_piecewise])[y,:]) : 0)
				end


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
		if Z >1			
		    dfCost[!,Symbol("Zone$z")] = [tempCTotal, tempCFix, tempCVar, tempCNSE, tempCStart, "-", "-"]
		end
	end
	CSV.write(string(path,sep,"costs.csv"), dfCost)
end
