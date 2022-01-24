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
	write_capacity(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model))

Function for writing the diferent capacities for the different generation technologies (starting capacities or, existing capacities, retired capacities, and new-built capacities).
"""
function write_capacity(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    # Capacity decisions
    dfGen = inputs["dfGen"]
    G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
    NEW_CAP = inputs["NEW_CAP"] # Set of all resources eligible for new capacity
    RET_CAP = inputs["RET_CAP"] # Set of all resources eligible for capacity retirements
    COMMIT = inputs["COMMIT"] # Set of all resources eligible for unit commitment
    STOR_ASYMMETRIC = inputs["STOR_ASYMMETRIC"]
    NEW_CAP_CHARGE = inputs["NEW_CAP_CHARGE"]
    RET_CAP_CHARGE = inputs["RET_CAP_CHARGE"]
    STOR_ALL = inputs["STOR_ALL"]
    NEW_CAP_ENERGY = inputs["NEW_CAP_ENERGY"]
    RET_CAP_ENERGY = inputs["RET_CAP_ENERGY"]

    endcapdischarge = value.(EP[:eTotalCap])
    capdischarge = zeros(G)
    if !isempty(NEW_CAP)
        capdischarge[NEW_CAP] = value.(EP[:vCAP][NEW_CAP]).data
        if !isempty(intersect(NEW_CAP, COMMIT))
            capdischarge[intersect(NEW_CAP, COMMIT)] = (value.(EP[:vCAP][intersect(NEW_CAP, COMMIT)]).data) .* dfGen[intersect(NEW_CAP, COMMIT), :Cap_Size]
        end
    end


    # for i in inputs["NEW_CAP"]
    #     if i in inputs["COMMIT"]
    #         capdischarge[i] = value(EP[:vCAP][i]) * dfGen[!, :Cap_Size][i]
    #     else
    #         capdischarge[i] = value(EP[:vCAP][i])
    #     end
    # end
    retcapdischarge = zeros(G)
    if !isempty(RET_CAP)
        retcapdischarge[RET_CAP] = value.(EP[:vRETCAP][RET_CAP]).data
		if !isempty(intersect(RET_CAP, COMMIT))
		    retcapdischarge[intersect(RET_CAP, COMMIT)] = value.(EP[:vRETCAP][intersect(RET_CAP, COMMIT)]).data .* dfGen[intersect(RET_CAP, COMMIT), :Cap_Size]
		end
    end
    # for i in inputs["RET_CAP"]
    #     if i in inputs["COMMIT"]
    #         retcapdischarge[i] = first(value.(EP[:vRETCAP][i])) * dfGen[!, :Cap_Size][i]
    #     else
    #         retcapdischarge[i] = first(value.(EP[:vRETCAP][i]))
    #     end
    # end

    endcapcharge = zeros(G)
    capcharge = zeros(G)
    retcapcharge = zeros(G)
    if !isempty(STOR_ASYMMETRIC)
        endcapcharge[STOR_ASYMMETRIC] = value.(EP[:eTotalCapCharge][STOR_ASYMMETRIC]).data
        if !isempty(NEW_CAP_CHARGE)
            capcharge[NEW_CAP_CHARGE] = value.(EP[:vCAPCHARGE][NEW_CAP_CHARGE]).data
        end
        if !isempty(RET_CAP_CHARGE)
            retcapcharge[RET_CAP_CHARGE] = value.(EP[:vRETCAPCHARGE][RET_CAP_CHARGE]).data
        end
    end




    # for i in inputs["STOR_ASYMMETRIC"]
    #     if i in inputs["NEW_CAP_CHARGE"]
    #         capcharge[i] = value(EP[:vCAPCHARGE][i])
    #     end
    #     if i in inputs["RET_CAP_CHARGE"]
    #         retcapcharge[i] = value(EP[:vRETCAPCHARGE][i])
    #     end
    # end
    endcapenergy = zeros(G)
    capenergy = zeros(G)
    retcapenergy = zeros(G)
	if !isempty(STOR_ALL)
		endcapenergy[STOR_ALL] = value.(EP[:eTotalCapEnergy][STOR_ALL].data)
		if !isempty(NEW_CAP_ENERGY)
		    capenergy[NEW_CAP_ENERGY] = value.(EP[:vCAPENERGY][NEW_CAP_ENERGY]).data
		end
		if !isempty(RET_CAP_ENERGY)
			retcapenergy[RET_CAP_ENERGY] = value.(EP[:vRETCAPENERGY][RET_CAP_ENERGY]).data
		end
	end

    		

    # for i in inputs["STOR_ALL"]
    #     if i in inputs["NEW_CAP_ENERGY"]
    #         capenergy[i] = value(EP[:vCAPENERGY][i])
    #     end
    #     if i in inputs["RET_CAP_ENERGY"]
    #         retcapenergy[i] = value(EP[:vRETCAPENERGY][i])
    #     end
    # end
    dfCap = DataFrame(
        Resource = inputs["RESOURCES"],
        Zone = dfGen[!, :Zone],
        StartCap = dfGen[!, :Existing_Cap_MW],
        RetCap = retcapdischarge[:],
        NewCap = capdischarge[:],
        EndCap = endcapdischarge[:],
        StartEnergyCap = dfGen[!, :Existing_Cap_MWh],
        RetEnergyCap = retcapenergy[:],
        NewEnergyCap = capenergy[:],
        EndEnergyCap = endcapenergy[:],
        StartChargeCap = dfGen[!, :Existing_Charge_Cap_MW],
        RetChargeCap = retcapcharge[:],
        NewChargeCap = capcharge[:],
        EndChargeCap = endcapcharge[:]
    )
    if setup["ParameterScale"] == 1
        dfCap.StartCap = dfCap.StartCap * ModelScalingFactor
        dfCap.RetCap = dfCap.RetCap * ModelScalingFactor
        dfCap.NewCap = dfCap.NewCap * ModelScalingFactor
        dfCap.EndCap = dfCap.EndCap * ModelScalingFactor
        dfCap.StartEnergyCap = dfCap.StartEnergyCap * ModelScalingFactor
        dfCap.RetEnergyCap = dfCap.RetEnergyCap * ModelScalingFactor
        dfCap.NewEnergyCap = dfCap.NewEnergyCap * ModelScalingFactor
        dfCap.EndEnergyCap = dfCap.EndEnergyCap * ModelScalingFactor
        dfCap.StartChargeCap = dfCap.StartChargeCap * ModelScalingFactor
        dfCap.RetChargeCap = dfCap.RetChargeCap * ModelScalingFactor
        dfCap.NewChargeCap = dfCap.NewChargeCap * ModelScalingFactor
        dfCap.EndChargeCap = dfCap.EndChargeCap * ModelScalingFactor
    end
    total = DataFrame(
        Resource = "Total",
        Zone = "n/a",
        StartCap = sum(dfCap[!, :StartCap]),
        RetCap = sum(dfCap[!, :RetCap]),
        NewCap = sum(dfCap[!, :NewCap]),
        EndCap = sum(dfCap[!, :EndCap]),
        StartEnergyCap = sum(dfCap[!, :StartEnergyCap]),
        RetEnergyCap = sum(dfCap[!, :RetEnergyCap]),
        NewEnergyCap = sum(dfCap[!, :NewEnergyCap]),
        EndEnergyCap = sum(dfCap[!, :EndEnergyCap]),
        StartChargeCap = sum(dfCap[!, :StartChargeCap]),
        RetChargeCap = sum(dfCap[!, :RetChargeCap]),
        NewChargeCap = sum(dfCap[!, :NewChargeCap]),
        EndChargeCap = sum(dfCap[!, :EndChargeCap])
    )

    dfCap = vcat(dfCap, total)
    CSV.write(string(path, sep, "capacity.csv"), dfCap)
    return dfCap
end
