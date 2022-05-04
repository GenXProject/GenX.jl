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

    dfCost = DataFrame(Costs = ["cTotal", "cInv", "cFOM", "cFuel", "cVOM", "cNSE", "cStart", "cUnmetRsv", "cNetworkExp"], Total = zeros(Float64, 9))
    dfCost.Total[1] = objective_value(EP)
    dfCost.Total[2] = (value(EP[:eTotalCInv]) +
                       (!isempty(inputs["STOR_ALL"]) ? value(EP[:eTotalCInvEnergy]) : 0) +
                       (!isempty(inputs["STOR_ASYMMETRIC"]) ? value(EP[:eTotalCInvCharge]) : 0))
    dfCost.Total[3] = (value(EP[:eTotalCFOM]) +
                       (!isempty(inputs["STOR_ALL"]) ? value(EP[:eTotalCFOMEnergy]) : 0) +
                       (!isempty(inputs["STOR_ASYMMETRIC"]) ? value(EP[:eTotalCFOMCharge]) : 0))
    dfCost.Total[4] = value(EP[:eTotalCFuelOut])
    if haskey(setup, "PieceWiseHeatRate")
        if setup["PieceWiseHeatRate"] == 1 && setup["UCommit"] >= 1
            dfCost.Total[4] += value(EP[:eCVar_fuel_piecewise])
        end
    end

    dfCost.Total[5] = (value(EP[:eTotalCVOMOut]) +
                       (!isempty(inputs["STOR_ALL"]) ? value(EP[:eTotalCVarIn]) : 0) +
                       (!isempty(inputs["FLEX"]) ? value(EP[:eTotalCVarFlexIn]) : 0))
    if haskey(setup, "CO2Tax")
        if setup["CO2Tax"] == 1
            dfCost.Total[5] += value(EP[:eTotalCCO2Tax])
        end
    end
    if haskey(setup, "CO2Credit")
        if setup["CO2Credit"] == 1
            dfCost.Total[5] += value(EP[:eTotalCCO2Credit])
        end
    end
    dfCost.Total[5] += value(EP[:eTotaleCCO2Sequestration])

    dfCost.Total[6] = value(EP[:eTotalCNSE])
    if setup["UCommit"] >= 1
        dfCost.Total[7] = value(EP[:eTotalCStart])
    end
    if haskey(setup, "Reserves")
        if setup["Reserves"] == 1
            dfCost.Total[8] = value(EP[:eTotalCRsvPen])
        end
    end    
    if setup["NetworkExpansion"] == 1 && Z > 1
        dfCost.Total[9] = value(EP[:eTotalCNetworkExp])
    end
    if setup["ParameterScale"] == 1
        dfCost.Total *= (ModelScalingFactor^2)
    end


    for z in 1:Z
        tempCInv = (value.(EP[:eZonalCInv])[z] +
                    (!isempty(inputs["STOR_ALL"]) ? value.(EP[:eZonalCInvEnergyCap])[z] : 0) +
                    (!isempty(inputs["STOR_ASYMMETRIC"]) ? value.(EP[:eZonalCInvChargeCap])[z] : 0))
        tempCFOM = (value.(EP[:eZonalCFOM])[z] +
                    (!isempty(inputs["STOR_ALL"]) ? value.(EP[:eZonalCFOMEnergyCap])[z] : 0) +
                    (!isempty(inputs["STOR_ASYMMETRIC"]) ? value.(EP[:eZonalCFOMChargeCap])[z] : 0))
        tempCFuel = value.(EP[:eZonalCFuelOut])[z]
        if haskey(setup, "PieceWiseHeatRate")
            if setup["PieceWiseHeatRate"] == 1 && setup["UCommit"] >= 1
                tempCFuel += value.(EP[:eZonalCFuel_piecewise])[z]
            end
        end
        tempCVOM = (value.(EP[:eZonalCVOMOut])[z] +
                    (!isempty(inputs["STOR_ALL"]) ? value.(EP[:eZonalCVarIn])[z] : 0) +
                    (!isempty(inputs["FLEX"]) ? value.(EP[:eZonalCVarFlexIn])[z] : 0))
        if haskey(setup, "CO2Tax")
            if setup["CO2Tax"] == 1
                tempCVOM += value.(EP[:eZonalCCO2Tax])[z]
            end
        end
        if haskey(setup, "CO2Credit")
            if setup["CO2Credit"] == 1
                tempCVOM += value.(EP[:eZonalCCO2Credit])[z]
            end
        end
        tempCVOM += value.(EP[:eZonalCCO2Sequestration])[z]
        tempCStart = (!isempty(inputs["COMMIT"]) ? value.(EP[:eZonalCStart])[z] : 0)
        tempCNSE = value.(EP[:eZonalCNSE])[z]

        tempCTotal = tempCInv + tempCFOM + tempCFuel + tempCVOM + tempCNSE + tempCStart
        if setup["ParameterScale"] == 1
            tempCInv *= ModelScalingFactor^2
            tempCFOM *= ModelScalingFactor^2
            tempCFuel *= ModelScalingFactor^2
            tempCVOM *= ModelScalingFactor^2
            tempCStart *= ModelScalingFactor^2
            tempCNSE *= ModelScalingFactor^2
            tempCTotal *= ModelScalingFactor^2
        end
        dfCost[!, Symbol("Zone$z")] = [tempCTotal, tempCInv, tempCFOM, tempCFuel, tempCVOM, tempCNSE, tempCStart, "-", "-"]
    end
    CSV.write(joinpath(path, "costs.csv"), dfCost)
end
