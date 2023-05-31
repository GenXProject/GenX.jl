"""
GenX: An Configurable Capacity Expansion Model
Copyright (C) 2021,  Massachusetts Institute of Technology
This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
A complete copy of the GNU General Public License v2 (GPLv2) is available
in LICENSE.txt.  Users uncompressing this from an archive may not have
received this license file.  If not, see <http://www.gnu.org/licenses/>.
"""

@doc raw"""
	write fuel consumption of each power plant. 
"""
function write_fuel_consumption(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]
	G = inputs["G"]
	T = inputs["T"]     # Number of time steps (hours)
	THERM_ALL = inputs["THERM_ALL"]
	# Fuel consumption by each resource
	dfPlantFuel = DataFrame(Resource = inputs["RESOURCES"], 
		Zone = dfGen[!,:Zone], 
		Fuel = dfGen[!, :Fuel], 
		AnnualSum_Fuel_HeatInput = zeros(G),
		AnnualSum_Fuel_Cost = zeros(G),
		Fuel2 = dfGen[!, :Fuel2],
		AnnualSum_Fuel2_HeatInput = zeros(G),
		AnnualSum_Fuel2_Cost = zeros(G))
		
	tempannualsum_Fuel_heat = value.(EP[:ePlantFuelConsumptionYear])  
	tempannualsum_Fuel_cost = value.(EP[:ePlantCFuelOut])
	tempannualsum_fuel2_heat = zeros(G);
	tempannualsum_fuel2_heat[THERM_ALL] = value.(EP[:ePlantFuel2ConsumptionYear].data);
	tempannualsum_fuel2_cost = zeros(G);
	tempannualsum_fuel2_cost[THERM_ALL] = value.(EP[:ePlantCFuel2Out].data)

    if setup["ParameterScale"] == 1
        tempannualsum_Fuel_heat *= ModelScalingFactor # kMMBTU to MMBTU
		tempannualsum_fuel2_heat *= ModelScalingFactor 
		tempannualsum_Fuel_cost *= ModelScalingFactor * ModelScalingFactor # million $ to $ 
		tempannualsum_fuel2_cost *= ModelScalingFactor * ModelScalingFactor
    end
    tempannualsum_Fuel_heat = round.(tempannualsum_Fuel_heat, digits = 2)
	tempannualsum_Fuel_cost = round.(tempannualsum_Fuel_cost, digits = 2)
	tempannualsum_fuel2_heat = round.(tempannualsum_fuel2_heat, digits = 2)
	tempannualsum_fuel2_cost = round.(tempannualsum_fuel2_cost, digits = 2)

    dfPlantFuel.AnnualSum_Fuel_HeatInput = tempannualsum_Fuel_heat
	dfPlantFuel.AnnualSum_Fuel_Cost = tempannualsum_Fuel_cost
	dfPlantFuel.AnnualSum_Fuel2_HeatInput = tempannualsum_fuel2_heat
	dfPlantFuel.AnnualSum_Fuel2_Cost = tempannualsum_fuel2_cost

    CSV.write(joinpath(path, "FuelConsumption_plant.csv"), dfPlantFuel)

	# Fuel consumption by each resource per time step
	dfPlantFuel_TS = DataFrame(Resource = inputs["RESOURCES"])
	tempts = value.(EP[:ePlantFuel]) + value.(EP[:ePlantFuel2]) ## fuel consumption at mmbtu
    if setup["ParameterScale"] == 1
        tempts *= ModelScalingFactor # kMMBTU to MMBTU
    end
    tempts = round.(tempts, digits = 2)

	dfPlantFuel_TS = hcat(dfPlantFuel_TS,
		DataFrame(tempts, [Symbol("t$t") for t in 1:T]))
    CSV.write(joinpath(path, "FuelConsumption_plant_ts.csv"), 
		dftranspose(dfPlantFuel_TS, false), writeheader=false)



	# # types of fuel
	# fuel_types = inputs["fuels"]
	# fuel_number = length(fuel_types) 
	# dfFuel = DataFrame(Fuel = fuel_types, 
	# 	AnnualSum_mmbtu = zeros(fuel_number))
	# tempannualsum = value.(EP[:eFuelConsumptionYear]) + value.(EP[:eFuel2ConsumptionYear])
    # if setup["ParameterScale"] == 1
    #     tempannualsum *= ModelScalingFactor # kMMBTU to MMBTU
    # end
    # tempannualsum = round.(tempannualsum, digits = 2)
	# dfFuel.AnnualSum_mmbtu .+= tempannualsum
 	# CSV.write(joinpath(path,"FuelConsumption.csv"), dfFuel)
end
