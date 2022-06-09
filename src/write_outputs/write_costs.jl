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
	write_costs(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing the costs pertaining to the objective function (fixed, variable O&M etc.).
"""
function write_costs(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	## Cost results
	dfGen = inputs["dfGen"]
	SEG = inputs["SEG"]  # Number of lines
	Z = inputs["Z"]     # Number of zones
	T = inputs["T"]     # Number of time steps (hours)
	STOR_ALL = inputs["STOR_ALL"]
	FLEX = inputs["FLEX"]
	STOR_ASYMMETRIC = inputs["STOR_ASYMMETRIC"]


	dfCost = DataFrame(Costs = ["cTotal", "cInv", "cFOM", "cFuel", "cVOM", "cNSE", "cStart", "cUnmetRsv", "cNetworkExp", "cUnmetPolicyPenalty"])
	cInv = value(EP[:eTotalCInv]) + (!isempty(inputs["STOR_ALL"]) ? value(EP[:eTotalCInvEnergy]) : 0.0) + (!isempty(inputs["STOR_ASYMMETRIC"]) ? value(EP[:eTotalCInvCharge]) : 0.0)
	cFOM = value(EP[:eTotalCFOM]) + (!isempty(inputs["STOR_ALL"]) ? value(EP[:eTotalCFOMEnergy]) : 0.0) + (!isempty(inputs["STOR_ASYMMETRIC"]) ? value(EP[:eTotalCFOMCharge]) : 0.0)
	cFuel = value(EP[:eTotalCFuelOut])
	cVOM = value(EP[:eTotalCVOMOut]) + (!isempty(inputs["STOR_ALL"]) ? value(EP[:eTotalCVarIn]) : 0.0) + (!isempty(inputs["FLEX"]) ? value(EP[:eTotalCVarFlexIn]) : 0.0)
	dfCost[!,Symbol("Total")] = [objective_value(EP), cInv, cFOM, cFuel, cVOM, value(EP[:eTotalCNSE]), 0.0, 0.0, 0.0, 0.0]

	if setup["CO2Tax"] == 1
		dfCost[5,2] += value(EP[:eTotalCCO2Tax])
	end

	# CO2 Capture Cost is counted as an VOM cost
    if setup["CO2Capture"] == 1	
        dfCost[5,2] += value(EP[:eTotaleCCO2Sequestration])
        if setup["CO2Credit"] == 1
            dfCost[5,2] -= value(EP[:eTotalCCO2Credit])
        end
    end

	# Energy Credit cost is counted as an VOM cost
	if setup["EnergyCredit"] == 1
		dfCost[5,2] -= value(EP[:eCTotalEnergyCredit])
	end

	if setup["UCommit"]>=1
		dfCost[7,2] = value(EP[:eTotalCStart])
	end

	if setup["Reserves"]==1
		dfCost[8,2] = value(EP[:eTotalCRsvPen])
	end

	if setup["NetworkExpansion"] == 1 && Z > 1
		dfCost[9,2] = value(EP[:eTotalCNetworkExp])
	end

	if setup["EnergyShareRequirement"] == 1
		dfCost[10,2] += value(EP[:eCTotalESRSlack])
	end

	if setup["CapacityReserveMargin"] == 1
		dfCost[10,2] += value(EP[:eCTotalCapResSlack])
	end

	if setup["CO2Cap"] == 1
		dfCost[10,2] += value(EP[:eCTotalCO2Emissions_mass_slack])
	end

	if setup["CO2GenRateCap"] == 1
		dfCost[10,2] += value(EP[:eCTotalCO2Emissions_genrate_slack])
	end

	if setup["CO2LoadRateCap"] == 1
		dfCost[10,2] += value(EP[:cCTotalCO2Emissions_loadrate_slack])
	end

	if setup["TFS"] == 1
		dfCost[10,2] += value(EP[:eCTotalTFSSlack])
		dfCost[10,2] += value(EP[:eTFSTotalTranscationCost])
	end

	if setup["ParameterScale"] == 1
		dfCost.Total *= ModelScalingFactor^2
	end

	# Grab zonal cost, because nonmet reserve cost, and transmission expansion cost is system wide,
	# They are put as zero.
	tempzonalcost = zeros(10, Z)
	# Investment Cost
	tempzonalcost[2, :] += vec(value.(EP[:eZonalCInv]))
	if !isempty(STOR_ALL)
		tempzonalcost[2, :] += vec(value.(EP[:eZonalCInvEnergyCap]))
	end
	if !isempty(STOR_ASYMMETRIC)
		tempzonalcost[2, :] += vec(value.(EP[:eZonalCInvChargeCap]))
	end

	# FOM Cost
	tempzonalcost[3, :] += vec(value.(EP[:eZonalCFOM]))
	if !isempty(STOR_ALL)
		tempzonalcost[3, :] += vec(value.(EP[:eZonalCFOMEnergyCap]))
	end
	if !isempty(STOR_ASYMMETRIC)
		tempzonalcost[3, :] += vec(value.(EP[:eZonalCFOMChargeCap]))
	end	

	# Fuel Cost
	tempzonalcost[4, :] += vec(value.(EP[:eZonalCFuelOut]))

	# Variable OM Cost
	tempzonalcost[5, :] += vec(value.(EP[:eZonalCVOMOut]))
	if !isempty(STOR_ALL)
		tempzonalcost[5, :] += vec(value.(EP[:eZonalCVarIn]))
	end
	if !isempty(FLEX)
		tempzonalcost[5, :] += vec(value.(EP[:eZonalCVarFlexIn]))
	end
	if setup["CO2Tax"] == 1
		tempzonalcost[5, :] += vec(value.(EP[:eZonalCCO2Tax]))
	end
	if setup["CO2Capture"] == 1
		tempzonalcost[5, :] += vec(value.(EP[:eZonalCCO2Sequestration]))
		if setup["CO2Credit"] == 1
			tempzonalcost[5, :] -= vec(value.(EP[:eZonalCCO2Credit]))
		end
	end
	if setup["EnergyCredit"] == 1
		tempzonalcost[5, :] -= vec(value.(EP[:eCEnergyCreditZonalTotal]))
	end

	# Start up cost
	if setup["UCommit"] >= 1
		tempzonalcost[6, :] += vec(value.(EP[:eZonalCStart]))
	end

	# NSE Cost
	tempzonalcost[7, :] += vec(value.(EP[:eZonalCNSE]))

	# Sum of the total
	tempzonalcost[1, :] = vec(sum(tempzonalcost[2:end, :], dims = 1))

	# build the dataframe to append on total
	dfCost = hcat(dfCost, DataFrame(tempzonalcost, [Symbol("Zone$z") for z in 1:Z]))

	CSV.write(joinpath(path, "costs.csv"), dfCost)
end
