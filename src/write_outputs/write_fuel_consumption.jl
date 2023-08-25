
@doc raw"""
    write_fuel_consumption(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	write fuel consumption of each power plant. 
"""
function write_fuel_consumption(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]
	G = inputs["G"]
	T = inputs["T"]     # Number of time steps (hours)


	# Fuel consumption by each resource
	dfPlantFuel = DataFrame(Resource = inputs["RESOURCES"], 
		Fuel = dfGen[!, :Fuel], 
		Zone = dfGen[!,:Zone], 
		AnnualSum = zeros(G))
	tempannualsum = value.(EP[:ePlantCFuelOut]) + value.(EP[:ePlantCFuelStart])
    if setup["ParameterScale"] == 1
        tempannualsum *= ModelScalingFactor # kMMBTU to MMBTU
    end
    tempannualsum = round.(tempannualsum, digits = 2)
    dfPlantFuel.AnnualSum .+= tempannualsum
    CSV.write(joinpath(path, "FuelConsumption_plant.csv"), dfPlantFuel)

	# Fuel consumption by each resource per time step
	dfPlantFuel_TS = DataFrame(Resource = inputs["RESOURCES"])
	tempts = value.(EP[:vFuel] + EP[:eStartFuel])
    if setup["ParameterScale"] == 1
        tempts *= ModelScalingFactor # kMMBTU to MMBTU
    end
    tempts = round.(tempts, digits = 2)
	dfPlantFuel_TS = hcat(dfPlantFuel_TS,
		DataFrame(tempts, [Symbol("t$t") for t in 1:T]))
    CSV.write(joinpath(path, "FuelConsumption_plant_ts.csv"), 
		dftranspose(dfPlantFuel_TS, false), writeheader=false)

	# types of fuel
	fuel_types = inputs["fuels"]
	fuel_number = length(fuel_types) 
	dfFuel = DataFrame(Fuel = fuel_types, 
		AnnualSum = zeros(fuel_number))
	tempannualsum = value.(EP[:eFuelConsumptionYear])
    if setup["ParameterScale"] == 1
        tempannualsum *= ModelScalingFactor # kMMBTU to MMBTU
    end
    tempannualsum = round.(tempannualsum, digits = 2)
	dfFuel.AnnualSum .+= tempannualsum
 	CSV.write(joinpath(path,"FuelConsumption.csv"), dfFuel)
end
