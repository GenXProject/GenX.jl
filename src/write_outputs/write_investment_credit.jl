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
	write_investment_credit(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
"""


function write_investment_credit(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    dfGen = inputs["dfGen"]
    NICC = inputs["NumberofInvestmentCreditCategory"]
	G = inputs["G"]
    Z = inputs["Z"]
    # Investment Credit earned by plant
    dfInvestmentCreditRevenue = DataFrame(Region = dfGen[!, :region], 
                                        Resource = inputs["RESOURCES"], 
                                        Zone = dfGen[!, :Zone], 
                                        Cluster = dfGen[!, :cluster], 
                                        AnnualSum = zeros(G))
    tempannualsum = value.(EP[:eCPlantTotalInvCredit])
    icrevenue = value.(EP[:eCPlantInvCredit])
    if setup["ParameterScale"] == 1
        tempannualsum *= ModelScalingFactor^2 #convert from Million US$ to US$
        icrevenue *= ModelScalingFactor^2 #convert from Million US$ to US$
    end
    tempannualsum = round.(tempannualsum, digits = 2)
    icrevenue = round.(icrevenue, digits = 2)
    dfInvestmentCreditRevenue.AnnualSum .+= tempannualsum
    dfInvestmentCreditRevenue = hcat(dfInvestmentCreditRevenue, 
            DataFrame(icrevenue, [Symbol("IC_Category_$ic") for ic in 1:NICC]))
    CSV.write(joinpath(path, "InvestmentCreditRevenue.csv"), dfInvestmentCreditRevenue)
    
    # Investment Credit earned by plants of each zone
    # if assumes intra-zonal allocation, this is also the cost paied by the consumers in each zone.
    dfInvestmentCreditZonalCost = DataFrame(Zone = 1:Z, AnnualSum = zeros(Z))
    tempzonalannualsum = value.(EP[:eCZonalTotalInvCredit])
    zonaliccost = value.(EP[:eCZonalInvCredit])
    if setup["ParameterScale"] == 1
        tempzonalannualsum *= ModelScalingFactor^2 #convert from Million US$ to US$
        zonaliccost *= ModelScalingFactor^2 #convert from Million US$ to US$
    end
    tempzonalannualsum = round.(tempzonalannualsum, digits = 2)
    zonaliccost = round.(zonaliccost, digits = 2)
    dfInvestmentCreditZonalCost.AnnualSum .+= tempzonalannualsum
    dfInvestmentCreditZonalCost = hcat(dfInvestmentCreditZonalCost, 
        DataFrame(zonaliccost, [Symbol("IC_Category_$ic") for ic in 1:NICC]))
    CSV.write(joinpath(path, "InvestmentCreditZonalCost.csv"), dfInvestmentCreditZonalCost)

end