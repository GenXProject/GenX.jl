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

	# Create a NetRevenue dataframe
 	dfNetRevenue = DataFrame(region = dfGen[!,:region], Resource = inputs["RESOURCES"], zone = dfGen[!,:Zone], Cluster = dfGen[!,:cluster], R_ID = dfGen[!,:R_ID])

	# Add investment cost to the dataframe
	dfNetRevenue.Inv_cost_MW = dfGen[!,:Inv_Cost_per_MWyr] .* dfCap[1:G,:NewCap]
	dfNetRevenue.Inv_cost_MWh = dfGen[!,:Inv_Cost_per_MWhyr] .* dfCap[1:G,:NewEnergyCap]
	if setup["ParameterScale"] == 1
		dfNetRevenue.Inv_cost_MWh *= ModelScalingFactor # converting Million US$ to US$
		dfNetRevenue.Inv_cost_MW *= ModelScalingFactor # converting Million US$ to US$
	end

	# Add operations and maintenance cost to the dataframe
	dfNetRevenue.Fixed_OM_cost_MW = dfGen[!,:Fixed_OM_Cost_per_MWyr] .* dfCap[1:G,:EndCap]
 	dfNetRevenue.Fixed_OM_cost_MWh = dfGen[!,:Fixed_OM_Cost_per_MWhyr] .* dfCap[1:G,:EndEnergyCap]
 	dfNetRevenue.Var_OM_cost_out = (dfGen[!,:Var_OM_Cost_per_MWh]) .* dfPower[1:G,:AnnualSum]
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

	# Add VRE-STORAGE module (parameter scaling??)
	if setup["VreStor"]==1
		dfGen_VRE_STOR = inputs["dfGen_VRE_STOR"]
		VRE_STOR = inputs["VRE_STOR"]
		dfNetRevenueVRESTOR = DataFrame(region = dfGen_VRE_STOR[!,:region], Resource = inputs["RESOURCES_VRE_STOR"], zone = dfGen_VRE_STOR[!,:Zone], Cluster = dfGen_VRE_STOR[!,:cluster], R_ID = dfGen_VRE_STOR[!,:R_ID])
		dfNetRevenueVRESTOR.Inv_cost_MW = dfGen_VRE_STOR[!,:Inv_Cost_VRE_per_MWyr] .* value.(EP[:vCAP_VRE]) + dfGen_VRE_STOR[!,:Inv_Cost_GRID_per_MWyr] .* value.(EP[:vGRIDCAP])
		dfNetRevenueVRESTOR.Inv_cost_MWh = dfGen_VRE_STOR[!,:Inv_Cost_per_MWhyr] .* value.(EP[:vCAPSTORAGE_VRE_STOR])
		dfNetRevenueVRESTOR.Fixed_OM_cost_MW = dfGen_VRE_STOR[!,:Fixed_OM_VRE_Cost_per_MWyr] .* value.(EP[:eTotalCap_VRE]) + dfGen_VRE_STOR[!,:Fixed_OM_GRID_Cost_per_MWyr] .* value.(EP[:eTotalCap_GRID])
		dfNetRevenueVRESTOR.Fixed_OM_cost_MWh = dfGen_VRE_STOR[!,:Fixed_OM_Cost_per_MWhyr] .* value.(EP[:eTotalCap_STOR])
		dfNetRevenueVRESTOR.Var_OM_cost_out = (dfGen_VRE_STOR[!,:Var_OM_Cost_per_MWh]) .* dfPower[(G+1):end-1,:AnnualSum]
		dfNetRevenueVRESTOR[!,:Fuel_cost] .= 0.0
		dfNetRevenueVRESTOR[!,:Var_OM_cost_in] .= 0.0
		dfNetRevenueVRESTOR[!,:StartCost] .= 0.0
		dfNetRevenueVRESTOR[!,:EmissionsCost] .= 0.0

		# Charge costs
		dfNetRevenueVRESTOR.Charge_cost = zeros(nrow(dfNetRevenueVRESTOR))
		if has_duals(EP) == 1
			dfNetRevenueVRESTOR.Charge_cost = dfChargingcost[G+1:G+VRE_STOR,:AnnualSum] # Unit is confirmed to be US$
		end

		# Energy Revenue
		dfNetRevenueVRESTOR.EnergyRevenue = zeros(nrow(dfNetRevenueVRESTOR))
		dfNetRevenueVRESTOR.SubsidyRevenue = zeros(nrow(dfNetRevenueVRESTOR))
		if setup["EnergyShareRequirement"] > 0 && has_duals(EP) == 1 # The unit is confirmed to be $
			dfNetRevenueVRESTOR.EnergyRevenue = dfEnergyRevenue[G+1:G+VRE_STOR,:AnnualSum]
			dfNetRevenueVRESTOR.SubsidyRevenue = dfSubRevenue[G+1:G+VRE_STOR,:SubsidyRevenue] # Unit is confirmed to be US$
		end
		# Add capacity revenue to the dataframe
		dfNetRevenueVRESTOR.ReserveMarginRevenue = zeros(nrow(dfNetRevenueVRESTOR))
		if setup["CapacityReserveMargin"] > 0 && has_duals(EP) == 1 # The unit is confirmed to be $
			dfNetRevenueVRESTOR.ReserveMarginRevenue = dfResRevenue[G+1:G+VRE_STOR,:AnnualSum]
		end
		
		# Add ESR revenue to the dataframe
		dfNetRevenueVRESTOR.ESRRevenue = zeros(nrow(dfNetRevenueVRESTOR))
		if setup["EnergyShareRequirement"] > 0 && has_duals(EP) == 1 # The unit is confirmed to be $
			dfNetRevenue.ESRRevenue = dfESRRev[G+1:G+VRE_STOR,:AnnualSum]
		end

		# Add regional technology subsidy revenue to the dataframe
		dfNetRevenueVRESTOR.RegSubsidyRevenue = zeros(nrow(dfNetRevenueVRESTOR))
		if setup["MinCapReq"] >= 1 && has_duals(EP) == 1 # The unit is confirmed to be US$
			dfNetRevenueVRESTOR.RegSubsidyRevenue = dfRegSubRevenue[G+1:G+VRE_STOR,:SubsidyRevenue]
		end

		dfNetRevenue = vcat(dfNetRevenue, dfNetRevenueVRESTOR)
	end

	dfNetRevenue.Revenue = dfNetRevenue.EnergyRevenue .+ dfNetRevenue.SubsidyRevenue .+ dfNetRevenue.ReserveMarginRevenue .+ dfNetRevenue.ESRRevenue .+ dfNetRevenue.RegSubsidyRevenue
	dfNetRevenue.Cost = dfNetRevenue.Inv_cost_MW .+ dfNetRevenue.Inv_cost_MWh .+ dfNetRevenue.Fixed_OM_cost_MW .+ dfNetRevenue.Fixed_OM_cost_MWh .+ dfNetRevenue.Var_OM_cost_out .+ dfNetRevenue.Var_OM_cost_in .+ dfNetRevenue.Fuel_cost .+ dfNetRevenue.Charge_cost .+ dfNetRevenue.EmissionsCost .+ dfNetRevenue.StartCost
	dfNetRevenue.Profit = dfNetRevenue.Revenue .- dfNetRevenue.Cost

	CSV.write(joinpath(path, "NetRevenue.csv"), dfNetRevenue)
end
