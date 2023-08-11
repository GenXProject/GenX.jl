@doc raw"""
	write_capacity_retrofit(path::AbstractString, inputs::Dict, setup::Dict, EP::Model))

Function for writing retrofited technologies
"""
function write_capacity_retrofit(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	# Capacity decisions
	dfGen = inputs["dfGen"]
	RETRO_SOURCE_IDS = inputs["RETROFIT_SOURCE_IDS"] # Source technologies by ID for each retrofit [1:G]
	RETRO_EFFICIENCY = inputs["RETROFIT_EFFICIENCIES"]
	NUM_RETRO_SOURCES = inputs["NUM_RETROFIT_SOURCES"]

	# MultiStage = setup["MultiStage"]
	
	# capdischarge = zeros(size(inputs["RESOURCES"]))
	# for i in inputs["NEW_CAP"]
	# 	if i in inputs["COMMIT"]
	# 		capdischarge[i] = value(EP[:vCAP][i])*dfGen[!,:Cap_Size][i]
	# 	else
	# 		capdischarge[i] = value(EP[:vCAP][i])
	# 	end
	# end

	# retcapdischarge = zeros(size(inputs["RESOURCES"]))
	# for i in inputs["RET_CAP"]
	# 	if i in inputs["COMMIT"]
	# 		retcapdischarge[i] = first(value.(EP[:vRETCAP][i]))*dfGen[!,:Cap_Size][i]
	# 	else
	# 		retcapdischarge[i] = first(value.(EP[:vRETCAP][i]))
	# 	end
	# end

	# capcharge = zeros(size(inputs["RESOURCES"]))
	# retcapcharge = zeros(size(inputs["RESOURCES"]))
	# existingcapcharge = zeros(size(inputs["RESOURCES"]))
	# for i in inputs["STOR_ASYMMETRIC"]
	# 	if i in inputs["NEW_CAP_CHARGE"]
	# 		capcharge[i] = value(EP[:vCAPCHARGE][i])
	# 	end
	# 	if i in inputs["RET_CAP_CHARGE"]
	# 		retcapcharge[i] = value(EP[:vRETCAPCHARGE][i])
	# 	end
	# 	existingcapcharge[i] = MultiStage == 1 ? value(EP[:vEXISTINGCAPCHARGE][i]) : dfGen[!,:Existing_Charge_Cap_MW][i]
	# end

	# capenergy = zeros(size(inputs["RESOURCES"]))
	# retcapenergy = zeros(size(inputs["RESOURCES"]))
	# existingcapenergy = zeros(size(inputs["RESOURCES"]))
	# for i in inputs["STOR_ALL"]
	# 	if i in inputs["NEW_CAP_ENERGY"]
	# 		capenergy[i] = value(EP[:vCAPENERGY][i])
	# 	end
	# 	if i in inputs["RET_CAP_ENERGY"]
	# 		retcapenergy[i] = value(EP[:vRETCAPENERGY][i])
	# 	end
	# 	existingcapenergy[i] = MultiStage == 1 ? value(EP[:vEXISTINGCAPENERGY][i]) :  dfGen[!,:Existing_Cap_MWh][i]
	# end

	# RETRO_SOURCE_IDS[r][i] in RET_CAP ? RETRO_EFFICIENCY[r][i] : 0 for i in 1:NUM_RETRO_SOURCES[r]; init=0 

	RETROFIT_SOURCE = [];
	RETROFIT_DEST = [];
	RETROFIT_CAP = [];
	ORIG_CAP = [];
	RETRO_EFF = [];

	for (i,j) in keys(EP[:vRETROFIT].data)
		push!(RETROFIT_SOURCE, inputs["RESOURCES"][i])
		push!(RETROFIT_DEST, inputs["RESOURCES"][j])
		push!(RETROFIT_CAP, value(EP[:vRETROFIT].data[i,j]) * dfGen[!,:Cap_Size][i])
		push!(ORIG_CAP, dfGen[!,:Existing_Cap_MW][i])
		push!(RETRO_EFF, RETRO_EFFICIENCY[j][findfirst(item -> item == i, RETRO_SOURCE_IDS[j])])
	end


	dfCapRetro = DataFrame(
		RetrofitResource = RETROFIT_SOURCE,
		OriginalCapacity = ORIG_CAP,
		RetrofitDestination = RETROFIT_DEST,
		RetrofitedCapacity = RETROFIT_CAP,
		OperationalRetrofitedCapacity = RETROFIT_CAP .* RETRO_EFF
	)
	if setup["ParameterScale"] ==1
		dfCapRetro.OriginalCapacity = dfCapRetro.OriginalCapacity * ModelScalingFactor
		dfCapRetro.RetrofitedCapacity = dfCapRetro.RetrofitedCapacity * ModelScalingFactor
		dfCapRetro.OperationalRetrofitedCapacity = dfCapRetro.OperationalRetrofitedCapacity * ModelScalingFactor
	end
	
	CSV.write(joinpath(path, "capacity_retrofit.csv"), dfCapRetro)
	return dfCapRetro
end