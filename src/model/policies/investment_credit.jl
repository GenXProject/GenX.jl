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
	investment_credit!(EP::Model, inputs::Dict, setup::Dict)

Function for reading input parameters related to investment credit (e.g., Investment Tax Credit)
"""
function investment_credit!(EP::Model, inputs::Dict, setup::Dict)
    println("Investment Credit Module")
    dfGen = inputs["dfGen"]
    NICC = inputs["NumberofInvestmentCreditCategory"]
    G = inputs["G"]
    Z = inputs["Z"]
    NEW_CAP = inputs["NEW_CAP"]
    NEW_CAP_CHARGE = inputs["NEW_CAP_CHARGE"]
    NEW_CAP_ENERGY = inputs["NEW_CAP_ENERGY"]
    ### Expression ###
    # calculate investment cost
    @expression(EP, eCPlantInvCredit[y in 1:G, nicc in 1:NICC], 1*EP[:vZERO])
    if !isempty(NEW_CAP)
        @expression(EP, eCPlantInvCreditCap[y in 1:G, nicc in 1:NICC], 
        if y in NEW_CAP
            (EP[:eInvCap][y] * (dfGen[y, :Inv_Cost_per_MWyr] - dfGen[y, :IC_Excluder_Discharge_perMWyr]) * 
            dfGen[y, Symbol("IC_Eligibility_$nicc")] * inputs["ICPercentage"][nicc])
        else
            1*EP[:vZERO]
        end
        )
        add_to_expression!.(EP[:eCPlantInvCredit], EP[:eCPlantInvCreditCap])
    end
    if !isempty(NEW_CAP_CHARGE)
        @expression(EP, eCPlantInvCreditCharge[y in 1:G, nicc in 1:NICC], 
        if y in NEW_CAP_CHARGE
            (EP[:vCAPCHARGE][y] * (dfGen[y, :Inv_Cost_Charge_per_MWyr] - dfGen[y, :IC_Excluder_Charge_perMWyr]) * 
            dfGen[y, Symbol("IC_Eligibility_$nicc")] * inputs["ICPercentage"][nicc])
        else
            1*EP[:vZERO]
        end
        )
        add_to_expression!.(EP[:eCPlantInvCredit], EP[:eCPlantInvCreditCharge])        
    end
    if !isempty(NEW_CAP_ENERGY)
        @expression(EP, eCPlantInvCreditEnergy[y in 1:G, nicc in 1:NICC],
        if y in NEW_CAP_ENERGY
            (EP[:vCAPENERGY][y] * (dfGen[y, :Inv_Cost_per_MWhyr] - dfGen[y, :IC_Excluder_Energy_perMWhyr]) * 
            dfGen[y, Symbol("IC_Eligibility_$nicc")] * inputs["ICPercentage"][nicc])
        else
            1*EP[:vZERO]
        end
        )
        add_to_expression!.(EP[:eCPlantInvCredit], EP[:eCPlantInvCreditEnergy])        
    end
    @expression(EP, eCPlantTotalInvCredit[y in 1:G],
    EP[:vZERO] + sum(EP[:eCPlantInvCredit][y, nicc] for nicc = 1:NICC)
    )
    @expression(EP, eCZonalInvCredit[z in 1:Z, nicc = 1:NICC],
    EP[:vZERO] + sum(EP[:eCPlantInvCredit][y, nicc] for y in dfGen[(dfGen[!, :Zone].==z), :R_ID])
    )
    @expression(EP, eCZonalTotalInvCredit[z in 1:Z], 
    EP[:vZERO] + sum(EP[:eCPlantTotalInvCredit][y] for y in dfGen[(dfGen[!, :Zone].==z), :R_ID])
    )
    @expression(EP, eCTotalInvCredit, sum(EP[:eCZonalTotalInvCredit][z] for z = 1:Z))
    add_to_expression!(EP[:eObj], -1, EP[:eCTotalInvCredit])
end
