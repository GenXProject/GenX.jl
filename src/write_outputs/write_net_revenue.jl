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

function write_net_revenue(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model, dfCap::DataFrame, dfESRRev::DataFrame, dfResRevenue::DataFrame, dfChargingcost::DataFrame, dfPower::DataFrame, dfEnergyRevenue::DataFrame, dfSubRevenue::DataFrame, dfRegSubRevenue::DataFrame)
	dfGen = inputs["dfGen"]
	T = inputs["T"]     			# Number of time steps (hours)
	Z = inputs["Z"]     			# Number of zones
	G = inputs["G"]     			# Number of generators
	COMMIT = inputs["COMMIT"]		# Thermal units for unit commitment

	# Create a NetRevenue dataframe
 	dfNetRevenue = DataFrame(region = dfGen[!,:region], Resource = inputs["RESOURCES"], zone = dfGen[!,:Zone], Cluster = dfGen[!,:cluster], R_ID = dfGen[!,:R_ID])

	# Add investment cost to the dataframe
	dfNetRevenue.Inv_cost_MW = dfGen[!,:Inv_Cost_per_MWyr] .* dfCap[1:end-1,:NewCap]
	dfNetRevenue.Inv_cost_MWh = dfGen[!,:Inv_Cost_per_MWhyr] .* dfCap[1:end-1,:NewEnergyCap]
	if setup["ParameterScale"] == 1
		dfNetRevenue.Inv_cost_MWh = dfNetRevenue.Inv_cost_MWh * (ModelScalingFactor^2) # converting Million US$ to US$
		dfNetRevenue.Inv_cost_MW = dfNetRevenue.Inv_cost_MW * (ModelScalingFactor^2) # converting Million US$ to US$
	end

	# Add operations and maintenance cost to the dataframe
	dfNetRevenue.Fixed_OM_cost_MW = dfGen[!,:Fixed_OM_Cost_per_MWyr] .* dfCap[1:end-1,:EndCap]
 	dfNetRevenue.Fixed_OM_cost_MWh = dfGen[!,:Fixed_OM_Cost_per_MWhyr] .* dfCap[1:end-1,:EndEnergyCap]
 	dfNetRevenue.Var_OM_cost_out = (dfGen[!,:Var_OM_Cost_per_MWh]) .* dfPower[1:end-1,:AnnualSum]
	if setup["ParameterScale"] == 1
		dfNetRevenue.Fixed_OM_cost_MW = dfNetRevenue.Fixed_OM_cost_MW * (ModelScalingFactor^2) # converting Million US$ to US$
		dfNetRevenue.Fixed_OM_cost_MWh = dfNetRevenue.Fixed_OM_cost_MWh * (ModelScalingFactor^2) # converting Million US$ to US$
		dfNetRevenue.Var_OM_cost_out = dfNetRevenue.Var_OM_cost_out * (ModelScalingFactor^2) # converting Million US$ to US$
	end

	# Add fuel cost to the dataframe
 	dfNetRevenue[!,:Fuel_cost] .= 0.0
	for i in 1:G
		dfNetRevenue.Fuel_cost[i] = sum(inputs["C_Fuel_per_MWh"][i,:] .* inputs["omega"] .* value.(EP[:vP])[i,:])
		if setup["ParameterScale"] == 1
			dfNetRevenue.Fuel_cost = dfNetRevenue.Fuel_cost * (ModelScalingFactor^2) # converting Million US$ to US$
		end
	end

	# Add storage cost to the dataframe
	dfNetRevenue[!,:Var_OM_cost_in] .= 0.0
 	for y in inputs["STOR_ALL"]
 		dfNetRevenue.Var_OM_cost_in[y] = dfGen[y,:Var_OM_Cost_per_MWh_In] * sum(value.(EP[:vCHARGE])[y,:])
		if setup["ParameterScale"] == 1
			dfNetRevenue.Var_OM_cost_in = dfNetRevenue.Var_OM_cost_in * (ModelScalingFactor^2) # converting Million US$ to US$
		end
 	end

	# Add start-up cost to the dataframe
	dfNetRevenue[!,:StartCost] .= 0.0
 	if (setup["UCommit"]>=1)
 		for y in COMMIT #dfGen[!,:R_ID]
 			dfNetRevenue.StartCost[y] = sum(value.(EP[:eCStart])[y,:])
 		end
		if setup["ParameterScale"] == 1
			dfNetRevenue.StartCost = dfNetRevenue.StartCost * (ModelScalingFactor^2) # converting Million US$ to US$
		end
 	end

	# Add charge cost to the dataframe
	dfNetRevenue[!,:Charge_cost] .= 0.0
	if has_duals(EP) == 1
		dfNetRevenue.Charge_cost = dfChargingcost[!,:AnnualSum] # Unit is confirmed to be US$
	end

	# Add energy and subsidy revenue to the dataframe
	dfNetRevenue[!,:EnergyRevenue] .= 0.0
	dfNetRevenue[!,:SubsidyRevenue] .= 0.0
	if has_duals(EP) == 1
		dfNetRevenue.EnergyRevenue = dfEnergyRevenue[!,:AnnualSum] # Unit is confirmed to be US$
	 	dfNetRevenue.SubsidyRevenue = dfSubRevenue[!,:SubsidyRevenue] # Unit is confirmed to be US$
	end

	# Add capacity revenue to the dataframe
	dfNetRevenue[!,:ReserveMarginRevenue] .= 0.0
 	if setup["CapacityReserveMargin"] > 0 && has_duals(EP) == 1 # The unit is confirmed to be $
 		dfNetRevenue.ReserveMarginRevenue = dfResRevenue[!,:AnnualSum]
 	end

	# Add RPS/CES revenue to the dataframe
	dfNetRevenue[!,:ESRRevenue] .= 0.0
 	if setup["EnergyShareRequirement"] > 0 && has_duals(EP) == 1 # The unit is confirmed to be $
 		dfNetRevenue.ESRRevenue = dfESRRev[!,:AnnualSum]
 	end

	# Calculate emissions cost
	dfNetRevenue[!,:EmissionsCost] .= 0.0
 	if setup["CO2Cap"] >=1 && has_duals(EP) == 1
 		for y in 1:G
			dfNetRevenue.EmissionsCost[y] = 0.0
			for cap in 1:inputs["NCO2Cap"]
 				if dfGen[y,:Zone] in findall(x->x==1, inputs["dfCO2CapZones"][:,cap])
					if setup["CO2Cap"]==1 # Mass-based
						# Cost = sum(sum(emissions of gen y * dual(CO2 constraint[cap]) for z in Z) for cap in setup["NCO2"])
						dfNetRevenue.EmissionsCost[y] += sum(value(EP[:eEmissionsByPlant][y,t]) * inputs["omega"][t] * (-1) * dual(EP[:cCO2Emissions_systemwide][cap])
							for t in 1:T)

					elseif setup["CO2Cap"]==2 # Demand + Rate-based
						# Cost = sum(sum(emissions for zone z * dual(CO2 constraint[cap]) for z in Z) for cap in setup["NCO2"])
						dfNetRevenue.EmissionsCost[y] += sum(value(EP[:eEmissionsByPlant][y,t]) * inputs["omega"][t] * (-1) * dual(EP[:cCO2Emissions_systemwide][cap])
							for t in 1:T)
					elseif setup["CO2Cap"]==3 # Generation + Rate-based
						if y in union(inputs["THERM_ALL"],inputs["VRE"], inputs["VRE"],inputs["MUST_RUN"],inputs["HYDRO_RES"])
							# Cost = sum( sum(emissions - generatio for zone z * MaxCO2Rate for zone z for z in Z) * dual(CO2 constraint[cap] for cap in setup["NCO2"])
							dfNetRevenue.EmissionsCost[y] += sum( (value(EP[:eEmissionsByPlant][y,t]) - (value(EP[:vP][y,t]) * inputs["dfMaxCO2Rate"][z,cap])) * inputs["omega"][t] * (-1) * dual(EP[:cCO2Emissions_systemwide][cap])
								for z=dfGen[y,:Zone], t in 1:T)
						end
					end
				end
			end
 		end
		if setup["ParameterScale"] == 1
			dfNetRevenue[!,:EmissionsCost] = dfNetRevenue[!,:EmissionsCost] * (ModelScalingFactor^2) # converting Million US$ to US$
		end
 	end

	# Add regional technology subsidy revenue to the dataframe
	dfNetRevenue[!,:RegSubsidyRevenue] .= 0.0
	if setup["MinCapReq"] >= 1 && has_duals(EP) == 1 # The unit is confirmed to be US$
		dfNetRevenue.RegSubsidyRevenue = dfRegSubRevenue[!,:SubsidyRevenue]
	end

	dfNetRevenue.Revenue =	dfNetRevenue.EnergyRevenue + dfNetRevenue.SubsidyRevenue + dfNetRevenue.ReserveMarginRevenue + dfNetRevenue.ESRRevenue + dfNetRevenue.RegSubsidyRevenue
	dfNetRevenue.Cost 	= 	dfNetRevenue.Fixed_OM_cost_MW + dfNetRevenue.Fixed_OM_cost_MWh + dfNetRevenue.Var_OM_cost_out + dfNetRevenue.Var_OM_cost_in + dfNetRevenue.Fuel_cost + dfNetRevenue.Charge_cost + dfNetRevenue.EmissionsCost + dfNetRevenue.StartCost
	dfNetRevenue.Profit = 	dfNetRevenue.Revenue - dfNetRevenue.Cost

	CSV.write(string(path,sep,"NetRevenue.csv"), dfNetRevenue)
end
