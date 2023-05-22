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


	# Fuel consumption by each resource
	dfPlantFuel = DataFrame(Resource = inputs["RESOURCES"], 
		Fuel1 = dfGen[!, :Fuel1], 
		Fuel2 = dfGen[!, :Fuel2], 
		Zone = dfGen[!,:Zone], 
		AnnualSum = zeros(G))
	tempannualsum = value.(EP[:ePlantCFuelOut])  ## fuel costs intead of consumption
    if setup["ParameterScale"] == 1
        tempannualsum *= ModelScalingFactor # kMMBTU to MMBTU
    end
    tempannualsum = round.(tempannualsum, digits = 2)
    dfPlantFuel.AnnualSum .+= tempannualsum
    CSV.write(joinpath(path, "FuelConsumption_plant.csv"), dfPlantFuel)

	# Fuel consumption by each resource per time step
	dfPlantFuel_TS = DataFrame(Resource = inputs["RESOURCES"])
	tempts = value.(EP[:ePlantFuel1]) + value.(EP[:ePlantFuel2]) ## fuel consumption at mmbtu
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
	tempannualsum = value.(EP[:eFuel1ConsumptionYear]) + value.(EP[:eFuel2ConsumptionYear])
    if setup["ParameterScale"] == 1
        tempannualsum *= ModelScalingFactor # kMMBTU to MMBTU
    end
    tempannualsum = round.(tempannualsum, digits = 2)
	dfFuel.AnnualSum .+= tempannualsum
 	CSV.write(joinpath(path,"FuelConsumption.csv"), dfFuel)
end
