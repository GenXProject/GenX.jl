function write_reserve_margin_revenue(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, dfPower::DataFrame, dfCharge::DataFrame, dfResMar::DataFrame, dfCap::DataFrame)
	dfGen = inputs["dfGen"]
	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
	SEG = inputs["SEG"]  # Number of lines
	Z = inputs["Z"]     # Number of zonests
	L = inputs["L"] # Number of lines
	THERM_ALL = inputs["THERM_ALL"]
	VRE_HYDRO_RES = union(inputs["HYDRO_RES"],inputs["VRE"])
	STOR_ALL = inputs["STOR_ALL"]
	FLEX = inputs["FLEX"]
	### calculating capacity reserve revenue

	dfResRevenue = DataFrame(region = dfGen[!,:region], Resource = inputs["RESOURCES"], zone = dfGen[!,:Zone], Cluster = dfGen[!,:cluster], R_ID = dfGen[!,:R_ID])
	for i in 1:inputs["NCapacityReserveMargin"]
		# initiate the process by assuming everything is thermal
		dfResRevenue = hcat(dfResRevenue, round.(Int, dfCap[1:end-1,:EndCap] .* dfGen[!,Symbol("CapRes_$i")] .* sum(dfResMar[i,:])))
		for y in 1:G
			if (y in STOR_ALL)
				dfResRevenue[y,:x1] = round.(Int, sum(
				(DataFrame([[names(dfPower)]; collect.(eachrow(dfPower))], [:column; Symbol.(axes(dfPower, 1))])[4:T+3,y+1] .-
				DataFrame([[names(dfPower)]; collect.(eachrow(dfCharge))], [:column; Symbol.(axes(dfPower, 1))])[4:T+3,y+1]) .*
				DataFrame([[names(dfResMar)]; collect.(eachrow(dfResMar))], [:column; Symbol.(axes(dfResMar, 1))])[!,i+1] .* dfGen[y,Symbol("CapRes_$i")]))
			elseif (y in VRE_HYDRO_RES)
				dfResRevenue[y,:x1] = round.(Int, sum((DataFrame([[names(dfPower)]; collect.(eachrow(dfPower))], [:column; Symbol.(axes(dfPower, 1))])[4:T+3,y+1]) .*
				DataFrame([[names(dfResMar)]; collect.(eachrow(dfResMar))], [:column; Symbol.(axes(dfResMar, 1))])[!,i+1] .* dfGen[y,Symbol("CapRes_$i")]))
			elseif (y in FLEX)
				dfResRevenue[y,:x1] = round.(Int, sum(
				(DataFrame([[names(dfPower)]; collect.(eachrow(dfCharge))], [:column; Symbol.(axes(dfPower, 1))])[4:T+3,y+1] .-
				DataFrame([[names(dfPower)]; collect.(eachrow(dfPower))], [:column; Symbol.(axes(dfPower, 1))])[4:T+3,y+1]) .*
				DataFrame([[names(dfResMar)]; collect.(eachrow(dfResMar))], [:column; Symbol.(axes(dfResMar, 1))])[!,i+1] .* dfGen[y,Symbol("CapRes_$i")]))
			end
		end
		# the capacity and power is in MW already, no need to scale
		# if setup["ParameterScale"] == 1
		# 	dfResRevenue[!,:x1] = dfResRevenue[!,:x1] * ModelScalingFactor #(1e+3) # This is because although the unit of price is US$/MWh, the capacity or generation is in GW
		# end
		rename!(dfResRevenue, Dict(:x1 => Symbol("CapRes_$i")))
	end
	dfResRevenue.AnnualSum = sum(eachcol(dfResRevenue[:,6:inputs["NCapacityReserveMargin"]+5]))


	CSV.write(string(path,sep,"ReserveMarginRevenue.csv"), dfResRevenue)
	return dfResRevenue
end
