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
	write_net_revenue(path::AbstractString, inputs::Dict, setup::Dict, EP::Model, 
    dfCap::DataFrame, dfESRRev::DataFrame, dfResRevenue::DataFrame, 
    dfChargingcost::DataFrame, dfPower::DataFrame, dfEnergyRevenue::DataFrame, 
    dfSubRevenue::DataFrame, dfRegSubRevenue::DataFrame)

Function for writing net revenue of different generation technologies.
"""
function write_net_revenue(path::AbstractString, inputs::Dict, setup::Dict, EP::Model, 
    dfCap::DataFrame, dfESRRev::DataFrame, dfResRevenue::DataFrame, 
    dfChargingcost::DataFrame, dfPower::DataFrame, dfEnergyRevenue::DataFrame, 
    dfSubRevenue::DataFrame, dfRegSubRevenue::DataFrame, dfCO2MassCapCost::DataFrame, 
    dfCO2LoadRateCapCost::DataFrame, dfCO2GenRateCapCost::DataFrame, dfCO2TaxCost::DataFrame)

	dfGen = inputs["dfGen"]
	T = inputs["T"]     			# Number of time steps (hours)
	Z = inputs["Z"]     			# Number of zones
	G = inputs["G"]     			# Number of generators
	COMMIT = inputs["COMMIT"]		# Thermal units for unit commitment
	STOR_ALL = inputs["STOR_ALL"]
	STOR_ASYMMETRIC = inputs["STOR_ASYMMETRIC"]
    FLEX = inputs["FLEX"]

	# Create a NetRevenue dataframe
 	dfNetRevenue = DataFrame(region = dfGen[!,:region], 
        Resource = inputs["RESOURCES"], 
        zone = dfGen[!,:Zone], 
        Cluster = dfGen[!,:cluster], 
        R_ID = dfGen[!,:R_ID],
        Revenue = zeros(G),
        Cost = zeros(G),
        Profit = zeros(G))

    # Add investment cost to the dataframe
    dfNetRevenue.Inv_cost_MW = value.(EP[:eCInvCap])
    if !isempty(STOR_ASYMMETRIC)
        dfNetRevenue.Inv_cost_MW[STOR_ASYMMETRIC] .+= value.(EP[:eCInvChargeCap][STOR_ASYMMETRIC]).data
    end
    if setup["ParameterScale"] == 1
        dfNetRevenue.Inv_cost_MW *= ModelScalingFactor^2 # converting Million US$ to US$
    end
    dfNetRevenue.Inv_cost_MW = round.(dfNetRevenue.Inv_cost_MW, digits = 2)
    dfNetRevenue.Cost .+= dfNetRevenue.Inv_cost_MW

	dfNetRevenue.Inv_cost_MWh = zeros(nrow(dfNetRevenue))
    if !isempty(STOR_ALL)
        dfNetRevenue.Inv_cost_MWh[STOR_ALL] .= value.(EP[:eCInvEnergyCap][STOR_ALL]).data
    end
    if setup["ParameterScale"] == 1
        dfNetRevenue.Inv_cost_MWh *= ModelScalingFactor^2 # converting Million US$ to US$
    end
    dfNetRevenue.Inv_cost_MWh = round.(dfNetRevenue.Inv_cost_MWh, digits = 2)
    dfNetRevenue.Cost .+= dfNetRevenue.Inv_cost_MWh

	# Add operations and maintenance cost to the dataframe
	dfNetRevenue.Fixed_OM_cost_MW = value.(EP[:eCFOMCap])
    if !isempty(STOR_ASYMMETRIC)
        dfNetRevenue.Fixed_OM_cost_MW[STOR_ASYMMETRIC] .+= value.(EP[:eCFOMChargeCap][STOR_ASYMMETRIC]).data
    end
    if setup["ParameterScale"] == 1
        dfNetRevenue.Fixed_OM_cost_MW *= ModelScalingFactor^2 # converting Million US$ to US$
    end
    dfNetRevenue.Fixed_OM_cost_MW = round.(dfNetRevenue.Fixed_OM_cost_MW, digits = 2)
    dfNetRevenue.Cost .+= dfNetRevenue.Fixed_OM_cost_MW

	dfNetRevenue.Fixed_OM_cost_MWh = zeros(nrow(dfNetRevenue))
    if !isempty(STOR_ALL)
        dfNetRevenue.Fixed_OM_cost_MWh[STOR_ALL] .= value.(EP[:eCFOMEnergyCap][STOR_ALL]).data
    end
    if setup["ParameterScale"] == 1
        dfNetRevenue.Fixed_OM_cost_MWh *= ModelScalingFactor^2 # converting Million US$ to US$
    end
    dfNetRevenue.Fixed_OM_cost_MWh = round.(dfNetRevenue.Fixed_OM_cost_MWh, digits = 2)
    dfNetRevenue.Cost .+= dfNetRevenue.Fixed_OM_cost_MWh

	dfNetRevenue.Var_OM_cost_out = value.(EP[:ePlantCVOMOut])
    if setup["ParameterScale"] == 1
        dfNetRevenue.Var_OM_cost_out *= ModelScalingFactor^2 # converting Million US$ to US$
    end
    dfNetRevenue.Var_OM_cost_out = round.(dfNetRevenue.Var_OM_cost_out, digits = 2)
    dfNetRevenue.Cost .+= dfNetRevenue.Var_OM_cost_out

    # Add fuel cost to the dataframe
    dfNetRevenue.Fuel_cost = value.(EP[:ePlantCFuelOut])
    if setup["ParameterScale"] == 1
        dfNetRevenue.Fuel_cost *= ModelScalingFactor^2 # converting Million US$ to US$
    end
    dfNetRevenue.Fuel_cost = round.(dfNetRevenue.Fuel_cost, digits = 2)
    dfNetRevenue.Cost .+= dfNetRevenue.Fuel_cost

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
    dfNetRevenue.Var_OM_cost_in = round.(dfNetRevenue.Var_OM_cost_in, digits = 2)
    dfNetRevenue.Cost .+= dfNetRevenue.Var_OM_cost_in

    # Add start-up cost to the dataframe
    dfNetRevenue.StartCost = zeros(nrow(dfNetRevenue))
    if setup["UCommit"] >= 1 && !isempty(COMMIT)
        # if you don't use vec, dimension won't match
        dfNetRevenue.StartCost[COMMIT] .= value.(EP[:ePlantCStart][COMMIT]).data
        if setup["ParameterScale"] == 1
            dfNetRevenue.StartCost *= ModelScalingFactor^2 # converting Million US$ to US$
        end
    end
    dfNetRevenue.StartCost = round.(dfNetRevenue.StartCost, digits = 2)
    dfNetRevenue.Cost .+= dfNetRevenue.StartCost

    # Add charge cost to the dataframe
    dfNetRevenue.Charge_cost = zeros(nrow(dfNetRevenue))
    if has_duals(EP) == 1
        dfNetRevenue.Charge_cost = dfChargingcost[!, :AnnualSum] # Unit is confirmed to be US$
    end
    dfNetRevenue.Charge_cost = round.(dfNetRevenue.Charge_cost, digits = 2)
    dfNetRevenue.Cost .+= dfNetRevenue.Charge_cost

	# Add energy revenue to the dataframe
	dfNetRevenue.EnergyRevenue = zeros(nrow(dfNetRevenue))
    if has_duals(EP) == 1
        dfNetRevenue.EnergyRevenue = dfEnergyRevenue[!,:AnnualSum] # Unit is confirmed to be US$
    end
    dfNetRevenue.EnergyRevenue = round.(dfNetRevenue.EnergyRevenue, digits = 2)
    dfNetRevenue.Revenue .+= dfNetRevenue.EnergyRevenue

    # Add subsidy revenue to the dataframe
	dfNetRevenue.SubsidyRevenue = zeros(nrow(dfNetRevenue))
	if has_duals(EP) == 1
	 	dfNetRevenue.SubsidyRevenue = dfSubRevenue[!,:SubsidyRevenue] # Unit is confirmed to be US$
	end
    dfNetRevenue.SubsidyRevenue = round.(dfNetRevenue.SubsidyRevenue, digits = 2)
    dfNetRevenue.Revenue .+= dfNetRevenue.SubsidyRevenue

    # Add capacity revenue to the dataframe, aka capacity market
    dfNetRevenue.ReserveMarginRevenue = zeros(nrow(dfNetRevenue))
    if setup["CapacityReserveMargin"] == 1 && has_duals(EP) == 1 # The unit is confirmed to be $
        dfNetRevenue.ReserveMarginRevenue += dfResRevenue.AnnualSum
    end
    dfNetRevenue.ReserveMarginRevenue = round.(dfNetRevenue.ReserveMarginRevenue, digits = 2)
    dfNetRevenue.Revenue .+= dfNetRevenue.ReserveMarginRevenue

    # Add RPS/CES revenue to the dataframe
    dfNetRevenue.ESRRevenue = zeros(nrow(dfNetRevenue))
    if setup["EnergyShareRequirement"] == 1 && has_duals(EP) == 1 # The unit is confirmed to be $
        dfNetRevenue.ESRRevenue += dfESRRev.AnnualSum
    end
    dfNetRevenue.ESRRevenue = round.(dfNetRevenue.ESRRevenue, digits = 2)
    dfNetRevenue.Revenue .+= dfNetRevenue.ESRRevenue
    
	# Calculate emissions cost
	dfNetRevenue.EmissionsCost = zeros(nrow(dfNetRevenue))
    if setup["CO2Cap"] == 1 && has_duals(EP) == 1
        dfNetRevenue.EmissionsCost += dfCO2MassCapCost.AnnualSum
    end
    if setup["CO2LoadRateCap"] == 1 && has_duals(EP) == 1
        dfNetRevenue.EmissionsCost += dfCO2LoadRateCapCost.AnnualSum
    end
    if setup["CO2GenRateCap"] == 1 && has_duals(EP) == 1
        dfNetRevenue.EmissionsCost += dfCO2GenRateCapCost.AnnualSum
    end
    if setup["CO2Tax"] == 1
        dfNetRevenue.EmissionsCost += dfCO2TaxCost.AnnualSum
    end
    dfNetRevenue.EmissionsCost = round.(dfNetRevenue.EmissionsCost, digits = 2)
    dfNetRevenue.Cost .+= dfNetRevenue.EmissionsCost
    
	# Add CO2 Capture cost and Credit to the dataframe
	dfNetRevenue.CO2Credit = zeros(nrow(dfNetRevenue))
	dfNetRevenue.SequestrationCost = zeros(nrow(dfNetRevenue))
	if setup["CO2Capture"] == 1
		dfNetRevenue.SequestrationCost .+= value.(EP[:ePlantCCO2Sequestration])
		if setup["CO2Credit"] == 1
			dfNetRevenue.CO2Credit .+= value.(EP[:ePlantCCO2Credit])
		end
		if setup["ParameterScale"] == 1
			dfNetRevenue.SequestrationCost *= ModelScalingFactor^2
			dfNetRevenue.CO2Credit *= ModelScalingFactor^2
		end
	end
    dfNetRevenue.SequestrationCost = round.(dfNetRevenue.SequestrationCost, digits = 2)
    dfNetRevenue.CO2Credit = round.(dfNetRevenue.CO2Credit, digits = 2)
    dfNetRevenue.Cost .+= dfNetRevenue.SequestrationCost
    dfNetRevenue.Revenue .+= dfNetRevenue.CO2Credit
	
    # Add energy credit
    dfNetRevenue.EnergyCredit = zeros(nrow(dfNetRevenue))
    if setup["EnergyCredit"] == 1
        dfNetRevenue.EnergyCredit .+= value.(EP[:eCEnergyCreditPlantTotal])
        if setup["ParameterScale"] == 1
            dfNetRevenue.EnergyCredit *= ModelScalingFactor^2
        end
    end
    dfNetRevenue.EnergyCredit = round.(dfNetRevenue.EnergyCredit, digits = 2)
    dfNetRevenue.Revenue .+= dfNetRevenue.EnergyCredit

    # Add Investment Credit
    dfNetRevenue.InvestmentCredit = zeros(nrow(dfNetRevenue))
    if setup["InvestmentCredit"] == 1
        dfNetRevenue.InvestmentCredit .+= value.(EP[:eCPlantTotalInvCredit])
        if setup["ParameterScale"] == 1
            dfNetRevenue.InvestmentCredit *= ModelScalingFactor^2
        end
    end
    dfNetRevenue.InvestmentCredit = round.(dfNetRevenue.InvestmentCredit, digits = 2)
    dfNetRevenue.Revenue .+= dfNetRevenue.InvestmentCredit
    
    # Add regional technology subsidy revenue to the dataframe, aka min cap
    dfNetRevenue.RegSubsidyRevenue = zeros(nrow(dfNetRevenue))
    if setup["MinCapReq"] == 1 && has_duals(EP) == 1 # The unit is confirmed to be US$
        dfNetRevenue.RegSubsidyRevenue .+= dfRegSubRevenue.SubsidyRevenue
    end
    dfNetRevenue.RegSubsidyRevenue = round.(dfNetRevenue.RegSubsidyRevenue, digits = 2)
    dfNetRevenue.Revenue .+= dfNetRevenue.RegSubsidyRevenue
    
    # Calculate the Net
    dfNetRevenue.Profit = dfNetRevenue.Revenue .- dfNetRevenue.Cost

	CSV.write(joinpath(path, "NetRevenue.csv"), dfNetRevenue)
end
