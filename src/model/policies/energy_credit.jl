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
    energy_credit!(EP::Model, inputs::Dict, setup::Dict)
    Energy credit module is to facilitate if a user wants to model a fix price of clean/renewable energy credit.
"""
function energy_credit!(EP::Model, inputs::Dict, setup::Dict)
    dfGen = inputs["dfGen"]
	println("Energy Credit Module")
	NECC = inputs["NumberofEnergyCreditCategory"]
	G = inputs["G"]
	Z = inputs["Z"]
    T = inputs["T"]
    ALLGEN = collect(1:inputs["G"])
    STOR_ALL = inputs["STOR_ALL"]
    FLEX = inputs["FLEX"]
	### Expressions ###
    # Energy credits earned by each plant under each credit category
	@expression(EP, eCEnergyCredit[y = 1:G, ec = 1:NECC], 
        if y in setdiff(ALLGEN, union(STOR_ALL, FLEX)) # for normal generation, they earn credit 
            sum(inputs["omega"][t] * EP[:vP][y,t] * dfGen[y, Symbol("EC_Eligibility_$ec")] * inputs["EnergyCredit"][ec] for t in 1:T)
        elseif y in STOR_ALL # for storage, they pay credit
            if setup["StorageLosses"] == 1
                (-1) * EP[:eELOSS][y] * dfGen[y, Symbol("EC_Eligibility_$ec")] * inputs["EnergyCredit"][ec]
            else
                1*EP[:vZERO]
            end
        elseif y in FLEX # for flexible load, they pay credit
            if setup["StorageLosses"] == 1
                (-1) * EP[:eExtraDemand][y] * dfGen[y, Symbol("EC_Eligibility_$ec")] * inputs["EnergyCredit"][ec]
            else
                1*EP[:vZERO]
            end
        end
    )
    # Energy credits earned by each plant
    @expression(EP, eCEnergyCreditPlantTotal[y = 1:G], sum(EP[:eCEnergyCredit][y, ec] for ec in 1:NECC))
    # Energy credits earned plants of each zone under each credit category
    @expression(EP, eCEnergyCreditZonal[z = 1:Z, ec = 1:NECC], sum(EP[:eCEnergyCredit][y, ec] for y in dfGen[(dfGen[!, :Zone].==z), :R_ID]))
    # Energy credits earned plants of each zone
    @expression(EP, eCEnergyCreditZonalTotal[z = 1:Z], sum(EP[:eCEnergyCreditZonal][z, ec] for ec in 1:NECC))
	# Total energy credits earned by the system
    @expression(EP, eCTotalEnergyCredit, sum(EP[:eCEnergyCreditZonalTotal][z] for z in 1:Z))
    # Add the total energy credit 
	add_to_expression!(EP[:eObj], -1, EP[:eCTotalEnergyCredit])
end
