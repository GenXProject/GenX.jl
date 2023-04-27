function write_power_balance(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]
	T = inputs["T"]     # Number of time steps (hours)
	Z = inputs["Z"]     # Number of zones
	SEG = inputs["SEG"] # Number of load curtailment segments
	THERM_ALL = inputs["THERM_ALL"]
	VRE = inputs["VRE"]
	MUST_RUN = inputs["MUST_RUN"]
	HYDRO_RES = inputs["HYDRO_RES"]
	STOR_ALL = inputs["STOR_ALL"]
	FLEX = inputs["FLEX"]
	## Power balance for each zone
	# dfPowerBalance = Array{Any}
	Com_list = ["Generation", "Storage_Discharge", "Storage_Charge",
	    "Flexible_Demand_Defer", "Flexible_Demand_Stasify",
	    "Demand_Response", "Nonserved_Energy",
	    "Transmission_NetExport", "Transmission_Losses",
	    "Demand"]
	dfPowerBalance = DataFrame(BalanceComponent = repeat(Com_list, outer = Z), Zone = repeat(1:Z, inner = 10), AnnualSum = zeros(10 * Z))
	# rowoffset = 3
	powerbalance = zeros(Z * 10, T) # following the same style of power/charge/storage/nse
	for z in 1:Z
		POWER_ZONE = intersect(dfGen[(dfGen[!, :Zone].==z), :R_ID], union(THERM_ALL, VRE, MUST_RUN, HYDRO_RES))
		powerbalance[(z-1)*10+1, :] = sum(value.(EP[:vP][POWER_ZONE, :]), dims = 1)
		if !isempty(intersect(dfGen[dfGen.Zone.==z, :R_ID], STOR_ALL))
		    STOR_ALL_ZONE = intersect(dfGen[dfGen.Zone.==z, :R_ID], STOR_ALL)
		    powerbalance[(z-1)*10+2, :] = sum(value.(EP[:vP][STOR_ALL_ZONE, :]), dims = 1)
		    # You cannot do the following because vCHARGE is not one-based. use [CartesianIndex(1:length(STOR_ALL_ZONE))]
		    #powerbalance[(z-1)*10+3, :] = (-1) * sum(value.(EP[:vCHARGE])[STOR_ALL_ZONE, :], dims = 1)
		    powerbalance[(z-1)*10+3, :] = (-1) * sum((value.(EP[:vCHARGE][STOR_ALL_ZONE, :]).data), dims = 1)
		end
		if !isempty(intersect(dfGen[dfGen.Zone.==z, :R_ID], FLEX))
		    FLEX_ZONE = intersect(dfGen[dfGen.Zone.==z, :R_ID], FLEX)
		    powerbalance[(z-1)*10+4, :] = sum((value.(EP[:vCHARGE_FLEX][FLEX_ZONE, :]).data), dims = 1)
		    powerbalance[(z-1)*10+5, :] = (-1) * sum(value.(EP[:vP][FLEX_ZONE, :]), dims = 1)
		end
		if SEG > 1
		    powerbalance[(z-1)*10+6, :] = sum(value.(EP[:vNSE][2:SEG, :, z]), dims = 1)
		end
		powerbalance[(z-1)*10+7, :] = value.(EP[:vNSE][1, :, z])
		if Z >= 2
		    powerbalance[(z-1)*10+8, :] = (value.(EP[:ePowerBalanceNetExportFlows][:, z]))' # Transpose
		    powerbalance[(z-1)*10+9, :] = (-0.5) * (value.(EP[:eLosses_By_Zone][z, :]))
		end
		powerbalance[(z-1)*10+10, :] = (((-1) * inputs["pD"][:, z]))' # Transpose
	end
	if setup["ParameterScale"] == 1
		powerbalance *= ModelScalingFactor
	end
	dfPowerBalance.AnnualSum .= powerbalance * inputs["omega"]
	dfPowerBalance = hcat(dfPowerBalance, DataFrame(powerbalance, :auto))
	auxNew_Names = [Symbol("BalanceComponent"); Symbol("Zone"); Symbol("AnnualSum"); [Symbol("t$t") for t in 1:T]]
	rename!(dfPowerBalance,auxNew_Names)
	CSV.write(joinpath(path, "power_balance.csv"), dftranspose(dfPowerBalance, false), writeheader=false)
end
