function write_energy_revenue(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model, dfPower::DataFrame, dfPrice::DataFrame, dfCharge::DataFrame)
	dfGen = inputs["dfGen"]
	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
	# dfEnergyRevenue = DataFrame(Resource = inputs["RESOURCES"], Zone = dfGen[!,:Zone], AnnualSum = Array{Union{Missing,Float32}}(undef, G))
	# the price is already US$/MWh, and dfPower and dfCharge is already in MW, so no scaling is needed
	dfEnergyRevenue = DataFrame(Region = dfGen[!,:region], Resource = inputs["RESOURCES"], Zone = dfGen[!,:Zone], Cluster = dfGen[!,:cluster], AnnualSum = Array{Union{Missing,Float32}}(undef, G), )
	# initiation
	i = 1
	dfEnergyRevenue_ = (DataFrame([[names(dfPower)]; collect.(eachrow(dfPower))], [:column; Symbol.(axes(dfPower, 1))])[4:T+3,2] .*
	DataFrame([[names(dfPrice)]; collect.(eachrow(dfPrice))], [:column; Symbol.(axes(dfPrice, 1))])[2:T+1,dfPower[1,:][:Zone]+1].*
	inputs["omega"])
	if i in inputs["FLEX"]
		dfEnergyRevenue_ = (DataFrame([[names(dfCharge)]; collect.(eachrow(dfCharge))], [:column; Symbol.(axes(dfCharge, 1))])[4:T+3,2] .*
		DataFrame([[names(dfPrice)]; collect.(eachrow(dfPrice))], [:column; Symbol.(axes(dfPrice, 1))])[2:T+1,dfPower[1,:][:Zone]+1].*
		inputs["omega"])
	end
	for i in 2:G
		if i in inputs["FLEX"]
			dfEnergyRevenue_1 = (DataFrame([[names(dfCharge)]; collect.(eachrow(dfCharge))], [:column; Symbol.(axes(dfCharge, 1))])[4:T+3,i+1] .*
			DataFrame([[names(dfPrice)]; collect.(eachrow(dfPrice))], [:column; Symbol.(axes(dfPrice, 1))])[2:T+1,dfPower[i,:][:Zone]+1].*
			inputs["omega"])
		else
			dfEnergyRevenue_1 = (DataFrame([[names(dfPower)]; collect.(eachrow(dfPower))], [:column; Symbol.(axes(dfPower, 1))])[4:T+3,i+1] .*
			DataFrame([[names(dfPrice)]; collect.(eachrow(dfPrice))], [:column; Symbol.(axes(dfPrice, 1))])[2:T+1,dfPower[i,:][:Zone]+1].*
			inputs["omega"])
		end
		dfEnergyRevenue_ = hcat(dfEnergyRevenue_, dfEnergyRevenue_1)
	end
	dfEnergyRevenue = hcat(dfEnergyRevenue, convert(DataFrame, dfEnergyRevenue_'))
	for i in 1:G
		dfEnergyRevenue[!,:AnnualSum][i] = sum(dfEnergyRevenue[i,6:T+5])
	end
	dfEnergyRevenue_annualonly = dfEnergyRevenue[!,1:5]
	CSV.write(string(path,sep,"EnergyRevenue.csv"), dfEnergyRevenue_annualonly)
	return dfEnergyRevenue
end
#=function write_energy_revenue(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model, dfPower::DataFrame, dfPrice::DataFrame, dfCharge::DataFrame)
	dfGen = inputs["dfGen"]
	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
	dfEnergyRevenue = DataFrame(Resource = inputs["RESOURCES"], Zone = dfGen[!,:Zone], AnnualSum = Array{Union{Missing,Float32}}(undef, G))
	# the price is already US$/MWh, and dfPower and dfCharge is already in MW, so no scaling is needed

	# dfEnergyRevenue_ = (DataFrame([[names(dfPower)]; collect.(eachrow(dfPower))], [:column; Symbol.(axes(dfPower, 1))])[4:T+3,2] .*
	# DataFrame([[names(dfPrice)]; collect.(eachrow(dfPrice))], [:column; Symbol.(axes(dfPrice, 1))])[2:T+1,dfPower[1,:][:Zone]+1] .*
	# inputs["omega"])
	# for i in 2:G
	# 	dfEnergyRevenue_1 = (DataFrame([[names(dfPower)]; collect.(eachrow(dfPower))], [:column; Symbol.(axes(dfPower, 1))])[4:T+3,i+1] .*
	# 	DataFrame([[names(dfPrice)]; collect.(eachrow(dfPrice))], [:column; Symbol.(axes(dfPrice, 1))])[2:T+1,dfPower[i,:][:Zone]+1] .*
	# 	inputs["omega"])
	# 	dfEnergyRevenue_ = hcat(dfEnergyRevenue_, dfEnergyRevenue_1)
	# end
	for i in 1:G
		if i in inputs["FLEX"]
			dfEnergyRevenue_1 = (DataFrame([[names(dfCharge)]; collect.(eachrow(dfCharge))], [:column; Symbol.(axes(dfCharge, 1))])[4:T+3,i+1] .*
			DataFrame([[names(dfPrice)]; collect.(eachrow(dfPrice))], [:column; Symbol.(axes(dfPrice, 1))])[2:T+1,dfPower[i,:][:Zone]+1] .*
			inputs["omega"])
		else
			dfEnergyRevenue_1 = (DataFrame([[names(dfPower)]; collect.(eachrow(dfPower))], [:column; Symbol.(axes(dfPower, 1))])[4:T+3,i+1] .*
			DataFrame([[names(dfPrice)]; collect.(eachrow(dfPrice))], [:column; Symbol.(axes(dfPrice, 1))])[2:T+1,dfPower[i,:][:Zone]+1] .*
			inputs["omega"])
		end
		dfEnergyRevenue = hcat(dfEnergyRevenue, convert(DataFrame, dfEnergyRevenue_1'))
	end

	# dfEnergyRevenue = hcat(dfEnergyRevenue, convert(DataFrame, dfEnergyRevenue_'))
	for i in 1:G
		dfEnergyRevenue[!,:AnnualSum][i] = sum(dfEnergyRevenue[i,6:T+5])
	end
	CSV.write(string(path,sep,"EnergyRevenue.csv"), dfEnergyRevenue)
	return dfEnergyRevenue
end
=#
