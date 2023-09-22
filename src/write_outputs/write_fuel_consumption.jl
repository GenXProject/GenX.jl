
@doc raw"""
    write_fuel_consumption(path::AbstractString, inputs::Dict, setup::Dict, EP::Model). 
Write fuel consumption of each power plant. 
"""
function write_fuel_consumption(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

	write_fuel_consumption_plant(path::AbstractString,inputs::Dict, setup::Dict, EP::Model)
	write_fuel_consumption_ts(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
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

	if !isempty(MULTI_FUELS)
		dfPlantFuel.Multi_Fuels = dfGen[HAS_FUEL, :MULTI_FUELS]
		for i = 1:inputs["MAX_NUM_FUELS"]
			tempannualsum_fuel_heat_multi_generation = zeros(length(HAS_FUEL))
			tempannualsum_fuel_heat_multi_start = zeros(length(HAS_FUEL))
			tempannualsum_fuel_heat_multi_total = zeros(length(HAS_FUEL))
			tempannualsum_fuel_cost_multi = zeros(length(HAS_FUEL))
			for g in MULTI_FUELS
				tempannualsum_fuel_heat_multi_generation[g] = value.(EP[:ePlantFuelConsumptionYear_multi_generation][g,i])
				tempannualsum_fuel_heat_multi_start[g] = value.(EP[:ePlantFuelConsumptionYear_multi_start][g,i])
				tempannualsum_fuel_heat_multi_total[g] = value.(EP[:ePlantFuelConsumptionYear_multi][g,i])
				tempannualsum_fuel_cost_multi[g] = value.(EP[:ePlantCFuelOut_multi][g,i]) + value.(EP[:ePlantCFuelOut_multi_start][g,i])
			end
			if setup["ParameterScale"] == 1
				tempannualsum_fuel_heat_multi_generation *= ModelScalingFactor 
				tempannualsum_fuel_heat_multi_start *= ModelScalingFactor
				tempannualsum_fuel_heat_multi_total *= ModelScalingFactor
				tempannualsum_fuel_cost_multi *= ModelScalingFactor^2 
			end

			dfPlantFuel[!, inputs["FUEL_COLS"][i]] = dfGen[!, inputs["FUEL_COLS"][i]]
			dfPlantFuel[!, Symbol(string(inputs["FUEL_COLS"][i],"_AnnualSum_Fuel_HeatInput_Generation"))] = tempannualsum_fuel_heat_multi_generation
			dfPlantFuel[!, Symbol(string(inputs["FUEL_COLS"][i],"_AnnualSum_Fuel_HeatInput_Start"))] = tempannualsum_fuel_heat_multi_start
			dfPlantFuel[!, Symbol(string(inputs["FUEL_COLS"][i],"_AnnualSum_Fuel_HeatInput_Total"))] = tempannualsum_fuel_heat_multi_total
			dfPlantFuel[!, Symbol(string(inputs["FUEL_COLS"][i],"_AnnualSum_Fuel_Cost"))] = tempannualsum_fuel_cost_multi
		end
	end
	
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
