@doc raw"""
	write_capacity(path::AbstractString, inputs::Dict, setup::Dict, EP::Model))

Function for writing the diferent capacities for the different generation technologies (starting capacities or, existing capacities, retired capacities, and new-built capacities).
"""
function write_capacity(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	# Capacity decisions
	dfGen = inputs["dfGen"]
	MultiStage = setup["MultiStage"]
	
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

	retrocapdischarge = zeros(size(inputs["RESOURCES"]))
	for i in inputs["RETRO_CAP"]
		if i in inputs["COMMIT"]
			retrocapdischarge[i] = first(value.(EP[:vRETROCAP][i]))*dfGen[!,:Cap_Size][i]
		else
			retrocapdischarge[i] = first(value.(EP[:vRETROCAP][i]))
		end
	end

	retrocreatdischarge = zeros(size(inputs["RESOURCES"]))
	for i in inputs["RETRO"]
		if i in inputs["COMMIT"]
			retrocreatdischarge[i] = first(value.(EP[:vRETROCREATCAP][i]))*dfGen[!,:Cap_Size][i]
		else
			retrocreatdischarge[i] = first(value.(EP[:vRETROCREATCAP][i]))
		end
	end

	capcharge = zeros(size(inputs["RESOURCES"]))
	retcapcharge = zeros(size(inputs["RESOURCES"]))
	retrocapcharge = zeros(size(inputs["RESOURCES"]))
	existingcapcharge = zeros(size(inputs["RESOURCES"]))

	for i in inputs["STOR_ASYMMETRIC"]
		if i in inputs["NEW_CAP_CHARGE"]
			capcharge[i] = value(EP[:vCAPCHARGE][i])
		end
		if i in inputs["RET_CAP_CHARGE"]
			retcapcharge[i] = value(EP[:vRETCAPCHARGE][i])
		end
		if i in inputs["RETRO_CAP_CHARGE"]
			retrocapcharge[i] = value(EP[:vRETROCAPCHARGE][i])
		end
		existingcapcharge[i] = MultiStage == 1 ? value(EP[:vEXISTINGCAPCHARGE][i]) : dfGen[!,:Existing_Charge_Cap_MW][i]
	end

	capenergy = zeros(size(inputs["RESOURCES"]))
	retcapenergy = zeros(size(inputs["RESOURCES"]))
	retrocapenergy = zeros(size(inputs["RESOURCES"]))
	existingcapenergy = zeros(size(inputs["RESOURCES"]))

	for i in inputs["STOR_ALL"]
		if i in inputs["NEW_CAP_ENERGY"]
			capenergy[i] = value(EP[:vCAPENERGY][i])
		end
		if i in inputs["RET_CAP_ENERGY"]
			retcapenergy[i] = value(EP[:vRETCAPENERGY][i])
		end
		if i in inputs["RETRO_CAP_ENERGY"]
			retrocapenergy[i] = value(EP[:vRETROCAPENERGY][i])
		end
		existingcapenergy[i] = MultiStage == 1 ? value(EP[:vEXISTINGCAPENERGY][i]) :  dfGen[!,:Existing_Cap_MWh][i]
	end
	dfCap = DataFrame(
		Resource = inputs["RESOURCES"], 
		Zone = dfGen[!,:Zone],
		Cluster = dfGen[!,:cluster],
		StartCap = MultiStage == 1 ? value.(EP[:vEXISTINGCAP]) : dfGen[!,:Existing_Cap_MW],
		RetCap = retcapdischarge[:],
		RetroCap = retrocapdischarge[:], #### Need to change later
		NewCap = capdischarge[:] + retrocreatdischarge[:],
		EndCap = value.(EP[:eTotalCap]),
		StartEnergyCap = existingcapenergy[:],
		RetEnergyCap = retcapenergy[:],
		RetroEnergyCap = retrocapenergy[:], #### Need to change later
		NewEnergyCap = capenergy[:],
		EndEnergyCap = existingcapenergy[:] - retcapenergy[:] + capenergy[:] + retrocapenergy[:],
		StartChargeCap = existingcapcharge[:],
		RetChargeCap = retcapcharge[:],
		RetroChargeCap = retrocapcharge[:], #### Need to change later
		NewChargeCap = capcharge[:],
		EndChargeCap = existingcapcharge[:] - retcapcharge[:] + capcharge[:] + retrocapcharge[:]
	)
	if setup["ParameterScale"] ==1
		dfCap.StartCap = dfCap.StartCap * ModelScalingFactor
		dfCap.RetCap = dfCap.RetCap * ModelScalingFactor
		dfCap.RetroCap = dfCap.RetroCap * ModelScalingFactor
		dfCap.NewCap = dfCap.NewCap * ModelScalingFactor
		dfCap.EndCap = dfCap.EndCap * ModelScalingFactor
		dfCap.StartEnergyCap = dfCap.StartEnergyCap * ModelScalingFactor
		dfCap.RetEnergyCap = dfCap.RetEnergyCap * ModelScalingFactor
		dfCap.RetroEnergyCap = dfCap.RetroEnergyCap * ModelScalingFactor
		dfCap.NewEnergyCap = dfCap.NewEnergyCap * ModelScalingFactor
		dfCap.EndEnergyCap = dfCap.EndEnergyCap * ModelScalingFactor
		dfCap.StartChargeCap = dfCap.StartChargeCap * ModelScalingFactor
		dfCap.RetChargeCap = dfCap.RetChargeCap * ModelScalingFactor
		dfCap.RetroChargeCap = dfCap.RetroChargeCap * ModelScalingFactor
		dfCap.NewChargeCap = dfCap.NewChargeCap * ModelScalingFactor
		dfCap.EndChargeCap = dfCap.EndChargeCap * ModelScalingFactor
	end
	total = DataFrame(
			Resource = "Total", Zone = "n/a", Cluster = "n/a",
			StartCap = sum(dfCap[!,:StartCap]), RetCap = sum(dfCap[!,:RetCap]),
			NewCap = sum(dfCap[!,:NewCap]), EndCap = sum(dfCap[!,:EndCap]),
			RetroCap = sum(dfCap[!,:RetroCap]),
			StartEnergyCap = sum(dfCap[!,:StartEnergyCap]), RetEnergyCap = sum(dfCap[!,:RetEnergyCap]),
			RetroEnergyCap = sum(dfCap[!,:RetroEnergyCap]),
			NewEnergyCap = sum(dfCap[!,:NewEnergyCap]), EndEnergyCap = sum(dfCap[!,:EndEnergyCap]),
			StartChargeCap = sum(dfCap[!,:StartChargeCap]), RetChargeCap = sum(dfCap[!,:RetChargeCap]),
			RetroChargeCap = sum(dfCap[!,:RetroChargeCap]),
			NewChargeCap = sum(dfCap[!,:NewChargeCap]), EndChargeCap = sum(dfCap[!,:EndChargeCap])
		)

	dfCap = vcat(dfCap, total)
	CSV.write(joinpath(path, "capacity.csv"), dfCap)
	return dfCap
end
