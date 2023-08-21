@doc raw"""
	write_esr_revenue(path::AbstractString, inputs::Dict, setup::Dict, dfPower::DataFrame, dfESR::DataFrame, EP::Model)

Function for reporting the renewable/clean credit revenue earned by each generator listed in the input file. GenX will print this file only when RPS/CES is modeled and the shadow price can be obtained form the solver. Each row corresponds to a generator, and each column starting from the 6th to the second last is the total revenue earned from each RPS constraint. The revenue is calculated as the total annual generation (if elgible for the corresponding constraint) multiplied by the RPS/CES price. The last column is the total revenue received from all constraint. The unit is \$.
"""
function write_esr_revenue(path::AbstractString, inputs::Dict, setup::Dict, dfPower::DataFrame, dfESR::DataFrame, EP::Model)
	dfGen = inputs["dfGen"]
	dfESRRev = DataFrame(region = dfGen[!,:region], Resource = inputs["RESOURCES"], zone = dfGen[!,:Zone], Cluster = dfGen[!,:cluster], R_ID = dfGen[!,:R_ID])
	G = inputs["G"]
	VRE_STOR = inputs["VRE_STOR"]
	dfVRE_STOR = inputs["dfVRE_STOR"]
	if !isempty(VRE_STOR)
		SOLAR = inputs["VS_SOLAR"]
		WIND = inputs["VS_WIND"]
		SOLAR_ONLY = setdiff(SOLAR, WIND)
		WIND_ONLY = setdiff(WIND, SOLAR)
		SOLAR_WIND = intersect(SOLAR, WIND)
	end
	by_rid(rid, sym) = by_rid_df(rid, sym, dfVRE_STOR)
	for i in 1:inputs["nESR"]
		esr_col = Symbol("ESR_$i")
		dfESRRev =  hcat(dfESRRev, dfPower[1:G,:AnnualSum] .* dfGen[!,esr_col] * dfESR[i,:ESR_Price])
		# dfpower is in MWh already, price is in $/MWh already, no need to scale
		# if setup["ParameterScale"] == 1
		# 	#dfESRRev[!,:x1] = dfESRRev[!,:x1] * (1e+3) # MillionUS$ to US$
		# 	dfESRRev[!,:x1] = dfESRRev[!,:x1] * ModelScalingFactor # MillionUS$ to US$  # Is this right? -Jack 4/29/2021
		# end
		rename!(dfESRRev, Dict(:x1 => esr_col))
		if !isempty(VRE_STOR)
			esr_vrestor_col = Symbol("ESRVreStor_$i")
			if !isempty(SOLAR_ONLY)
				dfESRRev[SOLAR, esr_col] = (value.(EP[:vP_SOLAR][SOLAR, :]).data .* dfVRE_STOR[((dfVRE_STOR.WIND.==0) .& (dfVRE_STOR.SOLAR.!=0)), :EtaInverter] * inputs["omega"]) .* dfVRE_STOR[((dfVRE_STOR.WIND.==0) .& (dfVRE_STOR.SOLAR.!=0)),esr_vrestor_col] * dfESR[i,:ESR_Price]
			end
			if !isempty(WIND_ONLY)
				dfESRRev[WIND, esr_col] = (value.(EP[:vP_WIND][WIND, :]).data * inputs["omega"]) .* dfVRE_STOR[((dfVRE_STOR.WIND.!=0) .& (dfVRE_STOR.SOLAR.==0)),esr_vrestor_col] * dfESR[i,:ESR_Price]
			end
			if !isempty(SOLAR_WIND)
				dfESRRev[SOLAR_WIND, esr_col] = (((value.(EP[:vP_WIND][SOLAR_WIND, :]).data * inputs["omega"]) .* dfVRE_STOR[((dfVRE_STOR.WIND.!=0) .& (dfVRE_STOR.SOLAR.!=0)),esr_vrestor_col] * dfESR[i,:ESR_Price])
					+ (value.(EP[:vP_SOLAR][SOLAR_WIND, :]).data .* dfVRE_STOR[((dfVRE_STOR.WIND.!=0) .& (dfVRE_STOR.SOLAR.!=0)), :EtaInverter] * inputs["omega"]) .* dfVRE_STOR[((dfVRE_STOR.WIND.!=0) .& (dfVRE_STOR.SOLAR.!=0)),esr_vrestor_col] * dfESR[i,:ESR_Price])
			end
		end
	end
	dfESRRev.AnnualSum = sum(eachcol(dfESRRev[:,6:inputs["nESR"]+5]))
	CSV.write(joinpath(path, "ESR_Revenue.csv"), dfESRRev)
	return dfESRRev
end
