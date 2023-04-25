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
	write_net_revenue(path::AbstractString, inputs::Dict, setup::Dict, EP::Model, dfCap::DataFrame, dfESRRev::DataFrame, dfResRevenue::DataFrame, dfChargingcost::DataFrame, dfPower::DataFrame, dfEnergyRevenue::DataFrame, dfSubRevenue::DataFrame, dfRegSubRevenue::DataFrame)

Function for writing net revenue of different generation technologies.
"""
function write_net_revenue(path::AbstractString, inputs::Dict, setup::Dict, EP::Model, dfCap::DataFrame, dfESRRev::DataFrame, dfResRevenue::DataFrame, dfChargingcost::DataFrame, dfPower::DataFrame, dfEnergyRevenue::DataFrame, dfSubRevenue::DataFrame, dfRegSubRevenue::DataFrame)
	dfGen = inputs["dfGen"]
	T = inputs["T"]     			# Number of time steps (hours)
	Z = inputs["Z"]     			# Number of zones
	G = inputs["G"]     			# Number of generators
	COMMIT = inputs["COMMIT"]		# Thermal units for unit commitment
	STOR_ALL = inputs["STOR_ALL"]
	VRE_STOR = inputs["VRE_STOR"]
	dfVRE_STOR = inputs["dfVRE_STOR"]
	if !isempty(VRE_STOR)
		SOLAR = inputs["VS_SOLAR"]
		WIND = inputs["VS_WIND"]
		DC = inputs["VS_DC"]
		STOR = inputs["VS_STOR"]
		# Should read in charge asymmetric capacities
	end

	# Create a NetRevenue dataframe
 	dfNetRevenue = DataFrame(region = dfGen[!,:region], Resource = inputs["RESOURCES"], zone = dfGen[!,:Zone], Cluster = dfGen[!,:cluster], R_ID = dfGen[!,:R_ID])

	# Add investment cost to the dataframe
	dfNetRevenue.Inv_cost_MW = dfGen[!,:Inv_Cost_per_MWyr] .* dfCap[1:G,:NewCap]
	dfNetRevenue.Inv_cost_MWh = dfGen[!,:Inv_Cost_per_MWhyr] .* dfCap[1:G,:NewEnergyCap]
	if !isempty(VRE_STOR)
		# Doesn't include charge capacities
		if !isempty(SOLAR)
			dfNetRevenue.Inv_cost_MW[SOLAR] += dfVRE_STOR[(dfVRE_STOR.SOLAR.!=0),:Inv_Cost_Solar_per_MWyr] .* value.(EP[:vSOLARCAP]).data
		end
		if !isempty(DC)
			dfNetRevenue.Inv_cost_MW[DC] += dfVRE_STOR[((dfVRE_STOR.SOLAR.!=0) .| (dfVRE_STOR.STOR_DC_DISCHARGE.>=1) .| (dfVRE_STOR.STOR_DC_CHARGE.>=1)),:Inv_Cost_Inverter_per_MWyr] .* value.(EP[:vDCCAP]).data
		end	
		if !isempty(WIND)
			dfNetRevenue.Inv_cost_MW[WIND] += dfVRE_STOR[(dfVRE_STOR.WIND.!=0),:Inv_Cost_Wind_per_MWyr] .* value.(EP[:vWINDCAP]).data
		end	
	end
	if setup["ParameterScale"] == 1
		dfNetRevenue.Inv_cost_MWh *= ModelScalingFactor # converting Million US$ to US$
		dfNetRevenue.Inv_cost_MW *= ModelScalingFactor # converting Million US$ to US$
	end

	# Add operations and maintenance cost to the dataframe
	dfNetRevenue.Fixed_OM_cost_MW = dfGen[!,:Fixed_OM_Cost_per_MWyr] .* dfCap[1:G,:EndCap]
 	dfNetRevenue.Fixed_OM_cost_MWh = dfGen[!,:Fixed_OM_Cost_per_MWhyr] .* dfCap[1:G,:EndEnergyCap]
 	dfNetRevenue.Var_OM_cost_out = (dfGen[!,:Var_OM_Cost_per_MWh]) .* dfPower[1:G,:AnnualSum]
	if !isempty(VRE_STOR)
		if !isempty(SOLAR)
			dfNetRevenue.Fixed_OM_cost_MW[SOLAR] += dfVRE_STOR[(dfVRE_STOR.SOLAR.!=0),:Fixed_OM_Solar_Cost_per_MWyr] .* value.(EP[:eTotalCap_SOLAR]).data
			dfNetRevenue.Var_OM_cost_out[SOLAR] += dfVRE_STOR[(dfVRE_STOR.SOLAR.!=0),:Var_OM_Cost_per_MWh_Solar] .* (value.(EP[:vP_SOLAR][SOLAR, :]).data .* dfVRE_STOR[(dfVRE_STOR.SOLAR.!=0),:EtaInverter] * inputs["omega"])
		end
		if !isempty(WIND)
			dfNetRevenue.Fixed_OM_cost_MW[WIND] += dfVRE_STOR[(dfVRE_STOR.WIND.!=0),:Fixed_OM_Wind_Cost_per_MWyr] .* value.(EP[:eTotalCap_WIND]).data
			dfNetRevenue.Var_OM_cost_out[WIND] += dfVRE_STOR[(dfVRE_STOR.WIND.!=0),:Var_OM_Cost_per_MWh_Wind] .* (value.(EP[:vP_WIND][WIND, :]).data * inputs["omega"])
		end	
		if !isempty(DC)
			dfNetRevenue.Fixed_OM_cost_MW[DC] += dfVRE_STOR[((dfVRE_STOR.SOLAR.!=0) .| (dfVRE_STOR.STOR_DC_DISCHARGE.>=1) .| (dfVRE_STOR.STOR_DC_CHARGE.>=1)),:Fixed_OM_Inverter_Cost_per_MWyr] .* value.(EP[:eTotalCap_DC]).data
		end	
	end
	if setup["ParameterScale"] == 1
		dfNetRevenue.Fixed_OM_cost_MW *= ModelScalingFactor # converting Million US$ to US$
		dfNetRevenue.Fixed_OM_cost_MWh *= ModelScalingFactor # converting Million US$ to US$
		dfNetRevenue.Var_OM_cost_out *= ModelScalingFactor # converting Million US$ to US$
	end

	# Add fuel cost to the dataframe
	dfNetRevenue.Fuel_cost = (inputs["C_Fuel_per_MWh"] .* value.(EP[:vP])) * inputs["omega"]
	if setup["ParameterScale"] == 1
		dfNetRevenue.Fuel_cost *= ModelScalingFactor^2 # converting Million US$ to US$
	end

	# Add storage cost to the dataframe
	dfNetRevenue.Var_OM_cost_in = zeros(nrow(dfNetRevenue))
	if !isempty(STOR_ALL)
		dfNetRevenue.Var_OM_cost_in[STOR_ALL] = dfGen[STOR_ALL,:Var_OM_Cost_per_MWh_In] .* ((value.(EP[:vCHARGE][STOR_ALL,:]).data) * inputs["omega"])
 	end
	# need to add for storage VRE-storage resources
	if setup["ParameterScale"] == 1
		dfNetRevenue.Var_OM_cost_in *= ModelScalingFactor^2 # converting Million US$ to US$
	end
	# Add start-up cost to the dataframe
	dfNetRevenue.StartCost = zeros(nrow(dfNetRevenue))
	if setup["UCommit"]>=1 && !isempty(COMMIT)
		# if you don't use vec, dimension won't match
		dfNetRevenue.StartCost[COMMIT] .= vec(sum(value.(EP[:eCStart][COMMIT, :]).data, dims = 2))
 	end
	if setup["ParameterScale"] == 1
		dfNetRevenue.StartCost *= ModelScalingFactor^2 # converting Million US$ to US$
	end
	# Add charge cost to the dataframe
	dfNetRevenue.Charge_cost = zeros(nrow(dfNetRevenue))
	if has_duals(EP) == 1
		dfNetRevenue.Charge_cost = dfChargingcost[1:G,:AnnualSum] # Unit is confirmed to be US$
	end

	# Add energy and subsidy revenue to the dataframe
	dfNetRevenue.EnergyRevenue = zeros(nrow(dfNetRevenue))
	dfNetRevenue.SubsidyRevenue = zeros(nrow(dfNetRevenue))
	if has_duals(EP) == 1
		dfNetRevenue.EnergyRevenue = dfEnergyRevenue[1:G,:AnnualSum] # Unit is confirmed to be US$
	 	dfNetRevenue.SubsidyRevenue = dfSubRevenue[1:G,:SubsidyRevenue] # Unit is confirmed to be US$
	end

	# Add capacity revenue to the dataframe
	dfNetRevenue.ReserveMarginRevenue = zeros(nrow(dfNetRevenue))
 	if setup["CapacityReserveMargin"] > 0 && has_duals(EP) == 1 # The unit is confirmed to be $
 		dfNetRevenue.ReserveMarginRevenue = dfResRevenue[1:G,:AnnualSum]
 	end

	# Add RPS/CES revenue to the dataframe
	dfNetRevenue.ESRRevenue = zeros(nrow(dfNetRevenue))
 	if setup["EnergyShareRequirement"] > 0 && has_duals(EP) == 1 # The unit is confirmed to be $
 		dfNetRevenue.ESRRevenue = dfESRRev[1:G,:AnnualSum]
 	end

	# Calculate emissions cost
	dfNetRevenue.EmissionsCost = zeros(nrow(dfNetRevenue))
	if setup["CO2Cap"] >=1 && has_duals(EP) == 1
		for cap in 1:inputs["NCO2Cap"]
			co2_cap_dual = dual(EP[:cCO2Emissions_systemwide][cap])
			CO2ZONES = findall(x->x==1, inputs["dfCO2CapZones"][:,cap])
			GEN_IN_ZONE = dfGen[[y in CO2ZONES for y in dfGen[:, :Zone]], :R_ID]
			if setup["CO2Cap"]==1 # Mass-based
				# Cost = sum(sum(emissions of gen y * dual(CO2 constraint[cap]) for z in Z) for cap in setup["NCO2"])
				temp_vec = value.(EP[:eEmissionsByPlant][GEN_IN_ZONE, :]) * inputs["omega"]
				dfNetRevenue.EmissionsCost[GEN_IN_ZONE] += - co2_cap_dual * temp_vec
			elseif setup["CO2Cap"]==2 # Demand + Rate-based
				# Cost = sum(sum(emissions for zone z * dual(CO2 constraint[cap]) for z in Z) for cap in setup["NCO2"])
				temp_vec = value.(EP[:eEmissionsByPlant][GEN_IN_ZONE, :]) * inputs["omega"]
				dfNetRevenue.EmissionsCost[GEN_IN_ZONE] += - co2_cap_dual * temp_vec
			elseif setup["CO2Cap"]==3 # Generation + Rate-based
				SET_WITH_MAXCO2RATE = union(inputs["THERM_ALL"],inputs["VRE"], inputs["VRE"],inputs["MUST_RUN"],inputs["HYDRO_RES"])
				Y = intersect(GEN_IN_ZONE, SET_WITH_MAXCO2RATE)
				temp_vec = (value.(EP[:eEmissionsByPlant][Y,:]) - (value.(EP[:vP][Y,:]) .* inputs["dfMaxCO2Rate"][dfGen[Y, :Zone], cap])) * inputs["omega"]
				dfNetRevenue.EmissionsCost[Y] += - co2_cap_dual * temp_vec
			end
		end
		if setup["ParameterScale"] == 1
			dfNetRevenue.EmissionsCost *= ModelScalingFactor^2 # converting Million US$ to US$
		end
	end

	# Add regional technology subsidy revenue to the dataframe
	dfNetRevenue.RegSubsidyRevenue = zeros(nrow(dfNetRevenue))
	if setup["MinCapReq"] >= 1 && has_duals(EP) == 1 # The unit is confirmed to be US$
		dfNetRevenue.RegSubsidyRevenue = dfRegSubRevenue[1:G,:SubsidyRevenue]
	end

	dfNetRevenue.Revenue = dfNetRevenue.EnergyRevenue .+ dfNetRevenue.SubsidyRevenue .+ dfNetRevenue.ReserveMarginRevenue .+ dfNetRevenue.ESRRevenue .+ dfNetRevenue.RegSubsidyRevenue
	dfNetRevenue.Cost = dfNetRevenue.Inv_cost_MW .+ dfNetRevenue.Inv_cost_MWh .+ dfNetRevenue.Fixed_OM_cost_MW .+ dfNetRevenue.Fixed_OM_cost_MWh .+ dfNetRevenue.Var_OM_cost_out .+ dfNetRevenue.Var_OM_cost_in .+ dfNetRevenue.Fuel_cost .+ dfNetRevenue.Charge_cost .+ dfNetRevenue.EmissionsCost .+ dfNetRevenue.StartCost
	dfNetRevenue.Profit = dfNetRevenue.Revenue .- dfNetRevenue.Cost

	CSV.write(joinpath(path, "NetRevenue.csv"), dfNetRevenue)
end
