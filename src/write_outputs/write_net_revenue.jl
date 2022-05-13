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
	STOR_ASYMMETRIC = inputs["STOR_ASYMMETRIC"]

	# Create a NetRevenue dataframe
 	dfNetRevenue = DataFrame(region = dfGen[!,:region], Resource = inputs["RESOURCES"], zone = dfGen[!,:Zone], Cluster = dfGen[!,:cluster], R_ID = dfGen[!,:R_ID])

    # Add investment cost to the dataframe
    dfNetRevenue.Inv_cost_MW = value.(EP[:eCInvCap])
    if !isempty(STOR_ASYMMETRIC)
        dfNetRevenue.Inv_cost_MW[STOR_ASYMMETRIC] .+= value.(EP[:eCInvChargeCap][STOR_ASYMMETRIC]).data
    end
    if setup["ParameterScale"] == 1
        dfNetRevenue.Inv_cost_MW *= ModelScalingFactor^2 # converting Million US$ to US$
    end

	dfNetRevenue.Inv_cost_MWh = zeros(nrow(dfNetRevenue))
    if !isempty(STOR_ALL)
        dfNetRevenue.Inv_cost_MWh[STOR_ALL] .= value.(EP[:eCInvEnergyCap][STOR_ALL]).data
    end
    if setup["ParameterScale"] == 1
        dfNetRevenue.Inv_cost_MWh *= ModelScalingFactor^2 # converting Million US$ to US$
    end

	# Add operations and maintenance cost to the dataframe
	dfNetRevenue.Fixed_OM_cost_MW = value.(EP[:eCFOMCap])
    if !isempty(STOR_ASYMMETRIC)
        dfNetRevenue.Fixed_OM_cost_MW[STOR_ASYMMETRIC] .+= value.(EP[:eCFOMChargeCap][STOR_ASYMMETRIC]).data
    end
    if setup["ParameterScale"] == 1
        dfNetRevenue.Fixed_OM_cost_MW *= ModelScalingFactor^2 # converting Million US$ to US$
    end

	dfNetRevenue.Fixed_OM_cost_MWh = zeros(nrow(dfNetRevenue))
    if !isempty(STOR_ALL)
        dfNetRevenue.Fixed_OM_cost_MWh[STOR_ALL] .= value.(EP[:eCFOMEnergyCap][STOR_ALL]).data
    end
    if setup["ParameterScale"] == 1
        dfNetRevenue.Fixed_OM_cost_MWh *= ModelScalingFactor^2 # converting Million US$ to US$
    end

	dfNetRevenue.Var_OM_cost_out = value.(EP[:ePlantCVOMOut])
    if setup["ParameterScale"] == 1
        dfNetRevenue.Var_OM_cost_out *= ModelScalingFactor^2 # converting Million US$ to US$
    end

    # Add fuel cost to the dataframe
    dfNetRevenue.Fuel_cost = value.(EP[:ePlantCFuelOut])
    if setup["ParameterScale"] == 1
        dfNetRevenue.Fuel_cost *= ModelScalingFactor^2 # converting Million US$ to US$
    end

    # Add storage cost to the dataframe
    dfNetRevenue.Var_OM_cost_in = zeros(nrow(dfNetRevenue))
    if !isempty(STOR_ALL)
        dfNetRevenue.Var_OM_cost_in[STOR_ALL] .= value.(EP[:ePlantCVarIn][STOR_ALL]).data
    end
    if !isempty(FLEX)
        dfNetRevenue.Var_OM_cost_in[FLEX] .= value.(EP[:ePlantCVarFlexIn][FLEX]).data
    end
    if setup["ParameterScale"] == 1
        dfNetRevenue.Var_OM_cost_in *= ModelScalingFactor^2 # converting Million US$ to US$
    end	

    # Add start-up cost to the dataframe
    dfNetRevenue.StartCost = zeros(nrow(dfNetRevenue))
    if setup["UCommit"] >= 1 && !isempty(COMMIT)
        # if you don't use vec, dimension won't match
        dfNetRevenue.StartCost[COMMIT] .= value.(EP[:ePlantCStart][COMMIT]).data
        if setup["ParameterScale"] == 1
            dfNetRevenue.StartCost *= ModelScalingFactor^2 # converting Million US$ to US$
        end
    end

    # Add charge cost to the dataframe
    dfNetRevenue.Charge_cost = zeros(nrow(dfNetRevenue))
    if has_duals(EP) == 1
        dfNetRevenue.Charge_cost = dfChargingcost[!, :AnnualSum] # Unit is confirmed to be US$
    end

	# Add energy and subsidy revenue to the dataframe
	dfNetRevenue.EnergyRevenue = zeros(nrow(dfNetRevenue))
	dfNetRevenue.SubsidyRevenue = zeros(nrow(dfNetRevenue))
	if has_duals(EP) == 1
		dfNetRevenue.EnergyRevenue = dfEnergyRevenue[!,:AnnualSum] # Unit is confirmed to be US$
	 	dfNetRevenue.SubsidyRevenue = dfSubRevenue[!,:SubsidyRevenue] # Unit is confirmed to be US$
	end

    # Add capacity revenue to the dataframe
    dfNetRevenue.ReserveMarginRevenue = zeros(nrow(dfNetRevenue))
    if setup["CapacityReserveMargin"] == 1 && has_duals(EP) == 1 # The unit is confirmed to be $
        dfNetRevenue.ReserveMarginRevenue += dfResRevenue.AnnualSum
    end

    # Add RPS/CES revenue to the dataframe
    dfNetRevenue.ESRRevenue = zeros(nrow(dfNetRevenue))
    if setup["EnergyShareRequirement"] == 1 && has_duals(EP) == 1 # The unit is confirmed to be $
        dfNetRevenue.ESRRevenue += dfESRRev.AnnualSum
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

	# Add CO2 Capture cost and Credit to the dataframe
	# dfNetRevenue.CO2Credit = zeros(nrow(dfNetRevenue))
	dfNetRevenue.SequestrationCost = zeros(nrow(dfNetRevenue))
	if setup["CO2Capture"] == 1
		dfNetRevenue.SequestrationCost .+= value.(EP[:ePlantCCO2Sequestration])
		# if setup["CO2Credit"] == 1
		# 	dfNetRevenue.CO2Credit .-= value.(EP[:ePlantCCO2Credit]) # note that the expression is a negative number
		# end
		if setup["ParameterScale"] == 1
			dfNetRevenue.SequestrationCost *= ModelScalingFactor^2
			# dfNetRevenue.CO2Credit *= ModelScalingFactor^2
		end
	end
	
    # Add regional technology subsidy revenue to the dataframe
    dfNetRevenue.RegSubsidyRevenue = zeros(nrow(dfNetRevenue))
    if setup["MinCapReq"] == 1 && has_duals(EP) == 1 # The unit is confirmed to be US$
        dfNetRevenue.RegSubsidyRevenue .+= dfRegSubRevenue.SubsidyRevenue
    end

	dfNetRevenue.Revenue = dfNetRevenue.EnergyRevenue .+ dfNetRevenue.SubsidyRevenue .+ dfNetRevenue.ReserveMarginRevenue .+ dfNetRevenue.ESRRevenue .+ dfNetRevenue.RegSubsidyRevenue
	dfNetRevenue.Cost = dfNetRevenue.Inv_cost_MW .+ dfNetRevenue.Inv_cost_MWh .+ dfNetRevenue.Fixed_OM_cost_MW .+ dfNetRevenue.Fixed_OM_cost_MWh .+ dfNetRevenue.Var_OM_cost_out .+ dfNetRevenue.Var_OM_cost_in .+ dfNetRevenue.Fuel_cost .+ dfNetRevenue.Charge_cost .+ dfNetRevenue.EmissionsCost .+ dfNetRevenue.StartCost .+ dfNetRevenue.SequestrationCost
	dfNetRevenue.Profit = dfNetRevenue.Revenue .- dfNetRevenue.Cost

	CSV.write(joinpath(path, "NetRevenue.csv"), dfNetRevenue)
end
