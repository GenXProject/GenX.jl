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

Function for writing the diferent capacities for the different generation technologies (starting capacities or, existing capacities, retired capacities, and new-built capacities)
"""
function write_capacity(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	# Capacity decisions
	dfGen = inputs["dfGen"]
	capdischarge = zeros(size(inputs["RESOURCES"]))
	for i in inputs["NEW_CAP"]
		if i in inputs["COMMIT"]
			capdischarge[i] = value(EP[:vCAP][i])*dfGen[!,:Cap_Size][i]
		else
			capdischarge[i] = value(EP[:vCAP][i])
		end
	end

	retcapdischarge = zeros(size(inputs["RESOURCES"]))
	for i in inputs["RET_CAP"]
		if i in inputs["COMMIT"]
			retcapdischarge[i] = first(value.(EP[:vRETCAP][i]))*dfGen[!,:Cap_Size][i]
		else
			retcapdischarge[i] = first(value.(EP[:vRETCAP][i]))
		end
	end

	capcharge = zeros(size(inputs["RESOURCES"]))
	retcapcharge = zeros(size(inputs["RESOURCES"]))
	for i in inputs["STOR_ASYMMETRIC"]
		if i in inputs["NEW_CAP_CHARGE"]
			capcharge[i] = value(EP[:vCAPCHARGE][i])
		end
		if i in inputs["RET_CAP_CHARGE"]
			retcapcharge[i] = value(EP[:vRETCAPCHARGE][i])
		end
	end

	capenergy = zeros(size(inputs["RESOURCES"]))
	retcapenergy = zeros(size(inputs["RESOURCES"]))
	for i in inputs["STOR_ALL"]
		if i in inputs["NEW_CAP_ENERGY"]
			capenergy[i] = value(EP[:vCAPENERGY][i])
		end
		if i in inputs["RET_CAP_ENERGY"]
			retcapenergy[i] = value(EP[:vRETCAPENERGY][i])
		end
	end
	dfCap = DataFrame(
		Resource = inputs["RESOURCES"], Zone = dfGen[!,:Zone],
		StartCap = dfGen[!,:Existing_Cap_MW],
		RetCap = retcapdischarge[:],
		NewCap = capdischarge[:],
		EndCap = value.(EP[:eTotalCap]),
		StartEnergyCap = dfGen[!,:Existing_Cap_MWh],
		RetEnergyCap = retcapenergy[:],
		NewEnergyCap = capenergy[:],
		EndEnergyCap = dfGen[!,:Existing_Cap_MWh]+capenergy[:]-retcapenergy[:],
		StartChargeCap = dfGen[!,:Existing_Charge_Cap_MW],
		RetChargeCap = retcapcharge[:],
		NewChargeCap = capcharge[:],
		EndChargeCap = dfGen[!,:Existing_Charge_Cap_MW]+capcharge[:]-retcapcharge[:]
	)

	if setup["VreStor"] == 1
		dfGen_VRE_STOR = inputs["dfGen_VRE_STOR"]
		VRE_STOR = inputs["VRE_STOR"]
		dfVRECAP = DataFrame(
			Resource = inputs["RESOURCES_VRE"], Zone = dfGen_VRE_STOR[!,:Zone],
			StartCap = dfGen_VRE_STOR[!,:Existing_Cap_MW],
			RetCap = value.(EP[:vRETCAP_VRE]),
			NewCap = value.(EP[:vCAP_VRE]),
			EndCap = value.(EP[:eTotalCap_VRE]),
			StartEnergyCap = zeros(VRE_STOR),
			RetEnergyCap = zeros(VRE_STOR), 
			NewEnergyCap = zeros(VRE_STOR), 
			EndEnergyCap = zeros(VRE_STOR), 
			StartChargeCap = zeros(VRE_STOR), 
			RetChargeCap = zeros(VRE_STOR), 
			NewChargeCap = zeros(VRE_STOR), 
			EndChargeCap = zeros(VRE_STOR)
		)

		dfSTORCAP = DataFrame(
			Resource = inputs["RESOURCES_STOR"], Zone = dfGen_VRE_STOR[!,:Zone],
			StartCap = dfGen_VRE_STOR[!,:Existing_Cap_MWh] .* dfGen_VRE_STOR[!,:Power_To_Energy_Ratio],
			RetCap = value.(EP[:vRETCAPSTORAGE_VRE_STOR]) .* dfGen_VRE_STOR[!,:Power_To_Energy_Ratio],
			NewCap = value.(EP[:vCAPSTORAGE_VRE_STOR]) .* dfGen_VRE_STOR[!,:Power_To_Energy_Ratio],
			EndCap = value.(EP[:eTotalCap_STOR]) .* dfGen_VRE_STOR[!,:Power_To_Energy_Ratio],
			StartEnergyCap = dfGen_VRE_STOR[!,:Existing_Cap_MWh],
			RetEnergyCap = value.(EP[:vRETCAPSTORAGE_VRE_STOR]), 
			NewEnergyCap = value.(EP[:vCAPSTORAGE_VRE_STOR]), 
			EndEnergyCap = value.(EP[:eTotalCap_STOR]), 
			StartChargeCap = zeros(VRE_STOR), 
			RetChargeCap = zeros(VRE_STOR), 
			NewChargeCap = zeros(VRE_STOR), 
			EndChargeCap = zeros(VRE_STOR)
		)

		dfGRIDCAP = DataFrame(
			Resource = inputs["RESOURCES_GRID"], Zone = dfGen_VRE_STOR[!,:Zone],
			StartCap = dfGen_VRE_STOR[!,:Existing_Cap_Grid_MW],
			RetCap = value.(EP[:vRETGRIDCAP]),
			NewCap = value.(EP[:vGRIDCAP]),
			EndCap = value.(EP[:eTotalCap_GRID]),
			StartEnergyCap = zeros(VRE_STOR),
			RetEnergyCap = zeros(VRE_STOR), 
			NewEnergyCap = zeros(VRE_STOR), 
			EndEnergyCap = zeros(VRE_STOR), 
			StartChargeCap = zeros(VRE_STOR), 
			RetChargeCap = zeros(VRE_STOR), 
			NewChargeCap = zeros(VRE_STOR), 
			EndChargeCap = zeros(VRE_STOR)
		)
		
		dfCap = vcat(dfCap, dfVRECAP)
		dfCap = vcat(dfCap, dfSTORCAP)
		dfCap = vcat(dfCap, dfGRIDCAP)

	end
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
			Resource = "Total", Zone = "n/a",
			StartCap = (sum(dfCap[!,:StartCap]) - (setup["VreStor"]==1 ? sum(dfGRIDCAP[!,:StartCap]) : 0)), 
			RetCap = (sum(dfCap[!,:RetCap]) - (setup["VreStor"]==1 ? sum(dfGRIDCAP[!,:RetCap]) : 0)),
			NewCap = (sum(dfCap[!,:NewCap]) - (setup["VreStor"]==1 ? sum(dfGRIDCAP[!,:NewCap]) : 0)),
			EndCap = (sum(dfCap[!,:EndCap]) - (setup["VreStor"]==1 ? sum(dfGRIDCAP[!,:EndCap]) : 0)),
			StartEnergyCap = sum(dfCap[!,:StartEnergyCap]), RetEnergyCap = sum(dfCap[!,:RetEnergyCap]),
			NewEnergyCap = sum(dfCap[!,:NewEnergyCap]), EndEnergyCap = sum(dfCap[!,:EndEnergyCap]),
			StartChargeCap = sum(dfCap[!,:StartChargeCap]), RetChargeCap = sum(dfCap[!,:RetChargeCap]),
			NewChargeCap = sum(dfCap[!,:NewChargeCap]), EndChargeCap = sum(dfCap[!,:EndChargeCap])
		)

	dfCap = vcat(dfCap, total)
	CSV.write(string(path,sep,"capacity.csv"), dfCap)
	return dfCap
end
