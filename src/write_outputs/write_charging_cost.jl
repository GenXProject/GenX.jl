function write_charging_cost(path::AbstractString, sep::AbstractString, inputs::Dict, dfCharge::DataFrame, dfPrice::DataFrame, dfPower::DataFrame, setup::Dict)
	dfGen = inputs["dfGen"]
	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
	#calculating charging cost
 	dfChargingcost = DataFrame(Region = dfGen[!,:region], Resource = inputs["RESOURCES"], Zone = dfGen[!,:Zone], Cluster = dfGen[!,:cluster], AnnualSum = Array{Union{Missing,Float32}}(undef, G), )
	# the price is already US$/MWh, and dfPower and dfCharge is already in MW, so no scaling is needed
	i = 1
	dfChargingcost_ = (DataFrame([[names(dfCharge)]; collect.(eachrow(dfCharge))], [:column; Symbol.(axes(dfCharge, 1))])[4:T+3,i+1] .*
	DataFrame([[names(dfPrice)]; collect.(eachrow(dfPrice))], [:column; Symbol.(axes(dfPrice, 1))])[2:T+1,dfPower[i,:][:Zone]+1].*
	inputs["omega"])
	if i in inputs["FLEX"]
		dfChargingcost_ = (DataFrame([[names(dfPower)]; collect.(eachrow(dfPower))], [:column; Symbol.(axes(dfPower, 1))])[4:T+3,i+1] .*
		DataFrame([[names(dfPrice)]; collect.(eachrow(dfPrice))], [:column; Symbol.(axes(dfPrice, 1))])[2:T+1,dfPower[i,:][:Zone]+1].*
		inputs["omega"])
	end
	for i in 2:G
		if i in inputs["FLEX"]
			dfChargingcost_1 = (DataFrame([[names(dfPower)]; collect.(eachrow(dfPower))], [:column; Symbol.(axes(dfPower, 1))])[4:T+3,i+1] .*
			DataFrame([[names(dfPrice)]; collect.(eachrow(dfPrice))], [:column; Symbol.(axes(dfPrice, 1))])[2:T+1,dfPower[i,:][:Zone]+1].*
			inputs["omega"])
		else
			dfChargingcost_1 = (DataFrame([[names(dfCharge)]; collect.(eachrow(dfCharge))], [:column; Symbol.(axes(dfCharge, 1))])[4:T+3,i+1] .*
			DataFrame([[names(dfPrice)]; collect.(eachrow(dfPrice))], [:column; Symbol.(axes(dfPrice, 1))])[2:T+1,dfPower[i,:][:Zone]+1].*
			inputs["omega"])
		end
		dfChargingcost_ = hcat(dfChargingcost_, dfChargingcost_1)
	end
	dfChargingcost = hcat(dfChargingcost, convert(DataFrame, dfChargingcost_'))
 	for i in 1:G
 		dfChargingcost[!,:AnnualSum][i] = sum(dfChargingcost[i,6:T+5])
 	end
	dfChargingcost_annualonly = dfChargingcost[!,1:5]
	CSV.write(string(path,sep,"ChargingCost.csv"), dfChargingcost_annualonly)
	return dfChargingcost
end
#=function write_charging_cost(path::AbstractString, sep::AbstractString, inputs::Dict, dfCharge::DataFrame, dfPrice::DataFrame, dfPower::DataFrame, setup::Dict)
	dfGen = inputs["dfGen"]
	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
	#calculating charging cost
 	dfChargingcost = DataFrame(Resource = inputs["RESOURCES"], Zone = dfGen[!,:Zone], Sum = Array{Union{Missing,Float32}}(undef, G))
	# the price is already US$/MWh, and dfPower and dfCharge is already in MW, so no scaling is needed

	for i in 1:G
		if i in inputs["FLEX"]
			dfChargingcost_1 = (DataFrame([[names(dfPower)]; collect.(eachrow(dfPower))], [:column; Symbol.(axes(dfPower, 1))])[4:T+3,i+1] .*
			DataFrame([[names(dfPrice)]; collect.(eachrow(dfPrice))], [:column; Symbol.(axes(dfPrice, 1))])[2:T+1,dfPower[i,:][:Zone]+1] .*
			inputs["omega"])
		else
			dfChargingcost_1 = (DataFrame([[names(dfCharge)]; collect.(eachrow(dfCharge))], [:column; Symbol.(axes(dfCharge, 1))])[4:T+3,i+1] .*
			DataFrame([[names(dfPrice)]; collect.(eachrow(dfPrice))], [:column; Symbol.(axes(dfPrice, 1))])[2:T+1,dfPower[i,:][:Zone]+1] .*
			inputs["omega"])
		end
		dfChargingcost = hcat(dfChargingcost, convert(DataFrame, dfChargingcost_1'))
	end

 	for i in 1:G
 		dfChargingcost[!,:Sum][i] = sum(dfChargingcost[i,6:T+5])
 	end
	CSV.write(string(path,sep,"ChargingCost.csv"), dfChargingcost)
	return dfChargingcost
end
=#
