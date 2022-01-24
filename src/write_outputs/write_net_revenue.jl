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
	write_net_revenue(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model, dfCap::DataFrame, dfESRRev::DataFrame, dfResRevenue::DataFrame, dfChargingcost::DataFrame, dfPower::DataFrame, dfEnergyRevenue::DataFrame, dfSubRevenue::DataFrame, dfRegSubRevenue::DataFrame)

Function for writing net revenue of different generation technologies.
"""
function write_net_revenue(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model, dfCap::DataFrame, dfESRRev::DataFrame, dfResRevenue::DataFrame, dfChargingcost::DataFrame, dfPower::DataFrame, dfEnergyRevenue::DataFrame, dfSubRevenue::DataFrame, dfRegSubRevenue::DataFrame, dfCO2MassCapCost::DataFrame, dfCO2LoadRateCapCost::DataFrame, dfCO2GenRateCapCost::DataFrame, dfCO2TaxCost::DataFrame, dfCO2CaptureCredit::DataFrame)
    dfGen = inputs["dfGen"]
    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones
    G = inputs["G"]     # Number of generators
    COMMIT = inputs["COMMIT"]# Thermal units for unit commitment
    STOR_ALL = inputs["STOR_ALL"]
    # Create a NetRevenue dataframe
    dfNetRevenue = DataFrame(Region = dfGen[!, :region], Resource = inputs["RESOURCES"], Zone = dfGen[!, :Zone], Cluster = dfGen[!, :cluster])

    # Add investment cost to the dataframe
    dfNetRevenue.Inv_cost_MW = dfGen[!, :Inv_Cost_per_MWyr] .* dfCap[1:end-1, :NewCap]
    dfNetRevenue.Inv_cost_MWh = dfGen[!, :Inv_Cost_per_MWhyr] .* dfCap[1:end-1, :NewEnergyCap]
    if setup["ParameterScale"] == 1
        dfNetRevenue.Inv_cost_MWh = dfNetRevenue.Inv_cost_MWh * (ModelScalingFactor) # converting Million US$ to US$
        dfNetRevenue.Inv_cost_MW = dfNetRevenue.Inv_cost_MW * (ModelScalingFactor) # converting Million US$ to US$
    end

    # Add operations and maintenance cost to the dataframe
    dfNetRevenue.Fixed_OM_cost_MW = dfGen[!, :Fixed_OM_Cost_per_MWyr] .* dfCap[1:end-1, :EndCap]
    dfNetRevenue.Fixed_OM_cost_MWh = dfGen[!, :Fixed_OM_Cost_per_MWhyr] .* dfCap[1:end-1, :EndEnergyCap]
    dfNetRevenue.Var_OM_cost_out = (dfGen[!, :Var_OM_Cost_per_MWh]) .* dfPower[1:end-1, :AnnualSum]
    if setup["ParameterScale"] == 1
        dfNetRevenue.Fixed_OM_cost_MW = dfNetRevenue.Fixed_OM_cost_MW * (ModelScalingFactor) # converting Million US$ to US$
        dfNetRevenue.Fixed_OM_cost_MWh = dfNetRevenue.Fixed_OM_cost_MWh * (ModelScalingFactor) # converting Million US$ to US$
        dfNetRevenue.Var_OM_cost_out = dfNetRevenue.Var_OM_cost_out * (ModelScalingFactor) # converting Million US$ to US$
    end

    # Add fuel cost to the dataframe
    if v"1.3" <= VERSION < v"1.4"
        dfNetRevenue[!, :Fuel_cost] .= 0.0
    elseif v"1.4" <= VERSION < v"1.7"
        dfNetRevenue.Fuel_cost = zeros(size(dfNetRevenue, 1))
    end
    # for i in 1:G
    #     dfNetRevenue.Fuel_cost[i] = sum(inputs["C_Fuel_per_MWh"][i, :] .* inputs["omega"] .* value.(EP[:vP])[i, :])
    # end
    dfNetRevenue.Fuel_cost .= (inputs["C_Fuel_per_MWh"] .* value.(EP[:vP])) * inputs["omega"]
    if setup["ParameterScale"] == 1
        dfNetRevenue.Fuel_cost = dfNetRevenue.Fuel_cost * (ModelScalingFactor^2) # converting Million US$ to US$
    end

    # Add storage cost to the dataframe
    if v"1.3" <= VERSION < v"1.4"
        dfNetRevenue[!, :Var_OM_cost_in] .= 0.0
    elseif v"1.4" <= VERSION < v"1.7"
        dfNetRevenue.Var_OM_cost_in = zeros(size(dfNetRevenue, 1))
    end

    # for y in inputs["STOR_ALL"]
    #     dfNetRevenue.Var_OM_cost_in[y] = dfGen[y, :Var_OM_Cost_per_MWh_In] * sum(inputs["omega"] .* value.(EP[:vCHARGE])[y, :])
    # end
    if !isempty(STOR_ALL)
        dfNetRevenue.Var_OM_cost_in[STOR_ALL] .= dfGen[STOR_ALL, :Var_OM_Cost_per_MWh_In] .* ((value.(EP[:vCHARGE][STOR_ALL,:]).data) * inputs["omega"])
    end
    if setup["ParameterScale"] == 1
        dfNetRevenue.Var_OM_cost_in = dfNetRevenue.Var_OM_cost_in * (ModelScalingFactor^2) # converting Million US$ to US$
    end
    # Add start-up cost to the dataframe
    if v"1.3" <= VERSION < v"1.4"
        dfNetRevenue[!, :StartCost] .= 0.0
    elseif v"1.4" <= VERSION < v"1.7"
        dfNetRevenue.StartCost = zeros(size(dfNetRevenue, 1))
    end
    if (setup["UCommit"] >= 1)
        # for y in COMMIT #dfGen[!,:R_ID]
        #     dfNetRevenue.StartCost[y] = sum(value.(EP[:eCStart])[y, :])
        # end
        if !isempty(COMMIT)
            # print(value.(EP[:eCStart][COMMIT, :]).data)
            dfNetRevenue.StartCost[COMMIT] .= vec(sum(value.(EP[:eCStart][COMMIT, :]).data, dims = 2)) # if you don't use vec, dimension won't match
        end

    end
    if setup["ParameterScale"] == 1
        dfNetRevenue.StartCost = dfNetRevenue.StartCost * (ModelScalingFactor^2) # converting Million US$ to US$
    end
    # Add charge cost to the dataframe
    if v"1.3" <= VERSION < v"1.4"
        dfNetRevenue[!, :Charge_cost] .= 0.0
    elseif v"1.4" <= VERSION < v"1.7"
        dfNetRevenue.Charge_cost = zeros(size(dfNetRevenue, 1))
    end
    if has_duals(EP) == 1
        dfNetRevenue.Charge_cost = dfChargingcost[!, :AnnualSum] # Unit is confirmed to be US$
    end

    # Add energy and subsidy revenue to the dataframe
    if v"1.3" <= VERSION < v"1.4"
        dfNetRevenue[!, :EnergyRevenue] .= 0.0
        dfNetRevenue[!, :SubsidyRevenue] .= 0.0
    elseif v"1.4" <= VERSION < v"1.7"
        dfNetRevenue.EnergyRevenue = zeros(size(dfNetRevenue, 1))
        dfNetRevenue.SubsidyRevenue = zeros(size(dfNetRevenue, 1))
    end
    if has_duals(EP) == 1
        dfNetRevenue.EnergyRevenue = dfEnergyRevenue[!, :AnnualSum] # Unit is confirmed to be US$
        dfNetRevenue.SubsidyRevenue = dfSubRevenue[!, :SubsidyRevenue] # Unit is confirmed to be US$
    end

    # Add capacity revenue to the dataframe
    if v"1.3" <= VERSION < v"1.4"
        dfNetRevenue[!, :ReserveMarginRevenue] .= 0.0
    elseif v"1.4" <= VERSION < v"1.7"
        dfNetRevenue.ReserveMarginRevenue = zeros(size(dfNetRevenue, 1))
    end
    if setup["CapacityReserveMargin"] > 0 && has_duals(EP) == 1 # The unit is confirmed to be $
        dfNetRevenue.ReserveMarginRevenue = dfResRevenue[!, :AnnualSum]
    end

    # Add RPS/CES revenue to the dataframe
    if v"1.3" <= VERSION < v"1.4"
        dfNetRevenue[!, :ESRRevenue] .= 0.0
    elseif v"1.4" <= VERSION < v"1.7"
        dfNetRevenue.ESRRevenue = zeros(size(dfNetRevenue, 1))
    end
    if setup["EnergyShareRequirement"] > 0 && has_duals(EP) == 1 # The unit is confirmed to be $
        dfNetRevenue.ESRRevenue = dfESRRev[!, :AnnualSum]
    end

    # Calculate emissions cost
    if v"1.3" <= VERSION < v"1.4"
        dfNetRevenue[!, :EmissionsCost] .= 0.0
    elseif v"1.4" <= VERSION < v"1.7"
        dfNetRevenue.EmissionsCost = zeros(G)
    end
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
    if setup["CO2Credit"] == 1
        dfNetRevenue.EmissionsCost += dfCO2CaptureCredit.AnnualSum
    end
    if setup["ParameterScale"] == 1
        dfNetRevenue.EmissionsCost += value.(EP[:ePlantCCO2Sequestration]) * (ModelScalingFactor^2)
    else
        dfNetRevenue.EmissionsCost += value.(EP[:ePlantCCO2Sequestration])
    end


    # Add regional technology subsidy revenue to the dataframe
    if v"1.3" <= VERSION < v"1.4"
        dfNetRevenue[!, :RegSubsidyRevenue] .= 0.0
    elseif v"1.4" <= VERSION < v"1.7"
        dfNetRevenue.RegSubsidyRevenue = zeros(size(dfNetRevenue, 1))
    end
    if setup["MinCapReq"] >= 1 && has_duals(EP) == 1 # The unit is confirmed to be US$
        dfNetRevenue.RegSubsidyRevenue = dfRegSubRevenue[!, :SubsidyRevenue]
    end

    dfNetRevenue.Revenue = dfNetRevenue.EnergyRevenue + dfNetRevenue.SubsidyRevenue + dfNetRevenue.ReserveMarginRevenue + dfNetRevenue.ESRRevenue + dfNetRevenue.RegSubsidyRevenue
    dfNetRevenue.Cost = dfNetRevenue.Inv_cost_MW + dfNetRevenue.Inv_cost_MWh + dfNetRevenue.Fixed_OM_cost_MW + dfNetRevenue.Fixed_OM_cost_MWh + dfNetRevenue.Var_OM_cost_out + dfNetRevenue.Var_OM_cost_in + dfNetRevenue.Fuel_cost + dfNetRevenue.Charge_cost + dfNetRevenue.EmissionsCost + dfNetRevenue.StartCost
    #dfNetRevenue.Cost = dfNetRevenue.Inv_cost_MW + dfNetRevenue.Inv_cost_MWh + dfNetRevenue.Fixed_OM_cost_MW + dfNetRevenue.Fixed_OM_cost_MWh + dfNetRevenue.Var_OM_cost_out + dfNetRevenue.Var_OM_cost_in + dfNetRevenue.Fuel_cost + dfNetRevenue.Charge_cost + dfNetRevenue.EmissionsCost + dfNetRevenue.StartCost
    dfNetRevenue.Profit = dfNetRevenue.Revenue - dfNetRevenue.Cost

    CSV.write(string(path, sep, "NetRevenue.csv"), dfNetRevenue)
end
