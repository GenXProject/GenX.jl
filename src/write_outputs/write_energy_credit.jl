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
	write_energy_credit_revenue(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
"""


function write_energy_credit(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    dfGen = inputs["dfGen"]
    NumberofEnergyCreditCategory = inputs["NumberofEnergyCreditCategory"]
	G = inputs["G"]
    Z = inputs["Z"]
    # Energy Credit earned by plant
    dfEnergyCreditRevenue = DataFrame(Region = dfGen[!, :region], Resource = inputs["RESOURCES"], Zone = dfGen[!, :Zone], Cluster = dfGen[!, :cluster], AnnualSum = zeros(G))
    dfEnergyCreditRevenue.AnnualSum .+= value.(EP[:eCEnergyCreditPlantTotal])
    ecrevenue = value.(EP[:eCEnergyCredit])
    if setup["ParameterScale"] == 1
        dfEnergyCreditRevenue.AnnualSum *= ModelScalingFactor^2 #convert from Million US$ to US$
        ecrevenue *= ModelScalingFactor^2 #convert from Million US$ to US$
    end
    # Not sure if it works if there is only one energy credit revenue category, to be tested
    dfEnergyCreditRevenue = hcat(dfEnergyCreditRevenue, DataFrame(ecrevenue, [Symbol("EC_Category_$ec") for ec in 1:NumberofEnergyCreditCategory]))
    CSV.write(joinpath(path, "EnergyCreditRevenue.csv"), dfEnergyCreditRevenue)
    
    # Energy Credit earned by plants of each zone
    # if assumes intra-zonal allocation, this is also the cost paied by the consumers in each zone.
    dfEnergyCreditZonalCost = DataFrame(Zone = 1:Z, AnnualSum = zeros(Z))
    dfEnergyCreditZonalCost.AnnualSum .+= value.(EP[:eCEnergyCreditZonalTotal])
    zonaleccost = value.(EP[:eCEnergyCreditZonal])
    if setup["ParameterScale"] == 1
        dfEnergyCreditZonalCost.AnnualSum *= ModelScalingFactor^2 #convert from Million US$ to US$
        zonaleccost *= ModelScalingFactor^2 #convert from Million US$ to US$
    end
    # Not sure if it works if there is only one energy credit revenue category, to be tested
    dfEnergyCreditZonalCost = hcat(dfEnergyCreditZonalCost, DataFrame(zonaleccost, [Symbol("EC_Category_$ec") for ec in 1:NumberofEnergyCreditCategory]))
    CSV.write(joinpath(path, "EnergyCreditZonalCost.csv"), dfEnergyCreditZonalCost)

    return dfEnergyCreditRevenue, dfEnergyCreditZonalCost
end