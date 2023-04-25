@doc raw"""
	write_storagedual(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for reporting dual of storage level (state of charge) balance of each resource in each time step.
"""
function write_storagedual(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]

	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)

	START_SUBPERIODS = inputs["START_SUBPERIODS"]
	INTERIOR_SUBPERIODS = inputs["INTERIOR_SUBPERIODS"]
	REP_PERIOD = inputs["REP_PERIOD"]
	STOR_ALL = inputs["STOR_ALL"]
	hours_per_subperiod = inputs["hours_per_subperiod"] #total number of hours per subperiod

	# # Dual of storage level (state of charge) balance of each resource in each time step
	dfStorageDual = DataFrame(Resource = inputs["RESOURCES"], Zone = dfGen[!, :Zone])
	dual_values = zeros(G, T)

	# Loop over W separately hours_per_subperiod
	STOR_ALL_NONLDS = setdiff(STOR_ALL, inputs["STOR_LONG_DURATION"])
	STOR_ALL_LDS = intersect(STOR_ALL, inputs["STOR_LONG_DURATION"])
	dual_values[STOR_ALL, INTERIOR_SUBPERIODS] = (dual.(EP[:cSoCBalInterior][INTERIOR_SUBPERIODS, STOR_ALL]).data ./ inputs["omega"][INTERIOR_SUBPERIODS])'
	dual_values[STOR_ALL_NONLDS, START_SUBPERIODS] = (dual.(EP[:cSoCBalStart][START_SUBPERIODS, STOR_ALL_NONLDS]).data ./ inputs["omega"][START_SUBPERIODS])'
	if !isempty(STOR_ALL_LDS)
		if setup["OperationWrapping"] == 1
			dual_values[STOR_ALL_LDS, START_SUBPERIODS] = (dual.(EP[:cSoCBalLongDurationStorageStart][1:REP_PERIOD, STOR_ALL_LDS]).data ./ inputs["omega"][START_SUBPERIODS])'
		else
			dual_values[STOR_ALL_LDS, START_SUBPERIODS] = (dual.(EP[:cSoCBalStart][START_SUBPERIODS, STOR_ALL_LDS]).data ./ inputs["omega"][START_SUBPERIODS])'
		end
	end

	if setup["ParameterScale"] == 1
	    dual_values *= ModelScalingFactor
	end

	dfStorageDual=hcat(dfStorageDual, DataFrame(dual_values, :auto))
	rename!(dfStorageDual,[Symbol("Resource");Symbol("Zone");[Symbol("t$t") for t in 1:T]])

	CSV.write(joinpath(path, "storagebal_duals.csv"), dftranspose(dfStorageDual, false), writeheader=false)
end
