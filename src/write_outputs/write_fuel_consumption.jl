
@doc raw"""
    write_fuel_consumption(path::AbstractString, inputs::Dict, setup::Dict, EP::Model). 
Write fuel consumption of each power plant. 
"""
function write_fuel_consumption(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

	write_fuel_consumption_plant(path::AbstractString,inputs::Dict, setup::Dict, EP::Model)
	if setup["WriteOutputs"] != "annual"
		write_fuel_consumption_ts(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	end
	write_fuel_consumption_tot(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
end

function write_fuel_consumption_plant(path::AbstractString,inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]
	G = inputs["G"]
	HAS_FUEL = inputs["HAS_FUEL"]
	# Fuel consumption cost by each resource, including start up fuel
	dfPlantFuel = DataFrame(Resource = inputs["RESOURCES"][HAS_FUEL], 
		Fuel = dfGen[HAS_FUEL, :Fuel], 
		Zone = dfGen[HAS_FUEL,:Zone], 
		AnnualSum = zeros(length(HAS_FUEL)))
	tempannualsum = value.(EP[:ePlantCFuelOut][HAS_FUEL]) + value.(EP[:ePlantCFuelStart][HAS_FUEL])

    if setup["ParameterScale"] == 1
        tempannualsum *= ModelScalingFactor^2 # 
    end
    dfPlantFuel.AnnualSum .+= tempannualsum
    CSV.write(joinpath(path, "Fuel_cost_plant.csv"), dfPlantFuel)
end


function write_fuel_consumption_ts(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	T = inputs["T"]     # Number of time steps (hours)
	HAS_FUEL = inputs["HAS_FUEL"]
	# Fuel consumption by each resource per time step, unit is MMBTU
	dfPlantFuel_TS = DataFrame(Resource = inputs["RESOURCES"][HAS_FUEL])
	tempts = value.(EP[:vFuel] + EP[:eStartFuel])[HAS_FUEL,:]
    if setup["ParameterScale"] == 1
        tempts *= ModelScalingFactor # kMMBTU to MMBTU
    end
	dfPlantFuel_TS = hcat(dfPlantFuel_TS,
		DataFrame(tempts, [Symbol("t$t") for t in 1:T]))
    CSV.write(joinpath(path, "FuelConsumption_plant_MMBTU.csv"), 
		dftranspose(dfPlantFuel_TS, false), writeheader=false)
end


function write_fuel_consumption_tot(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	# types of fuel
	fuel_types = inputs["fuels"]
	fuel_number = length(fuel_types) 
	dfFuel = DataFrame(Fuel = fuel_types, 
		AnnualSum = zeros(fuel_number))
	tempannualsum = value.(EP[:eFuelConsumptionYear])
    if setup["ParameterScale"] == 1
        tempannualsum *= ModelScalingFactor # billion MMBTU to MMBTU
    end
	dfFuel.AnnualSum .+= tempannualsum
 	CSV.write(joinpath(path,"FuelConsumption_total_MMBTU.csv"), dfFuel)
end
