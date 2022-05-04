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
	write_net_revenue(path::AbstractString, inputs::Dict, setup::Dict, EP::Model, dfESRRev::DataFrame, dfResRevenue::DataFrame, dfChargingcost::DataFrame, dfEnergyRevenue::DataFrame, dfSubRevenue::DataFrame, dfRegSubRevenue::DataFrame, dfCO2MassCapCost::DataFrame, dfCO2LoadRateCapCost::DataFrame, dfCO2GenRateCapCost::DataFrame, dfCO2TaxCost::DataFrame, dfCO2CaptureCredit::DataFrame)

Function for writing net revenue of different generation technologies.
"""
function write_net_revenue(path::AbstractString, inputs::Dict, setup::Dict, EP::Model, dfESRRev::DataFrame, dfResRevenue::DataFrame, dfChargingcost::DataFrame, dfEnergyRevenue::DataFrame, dfSubRevenue::DataFrame, dfRegSubRevenue::DataFrame, dfCO2MassCapCost::DataFrame, dfCO2LoadRateCapCost::DataFrame, dfCO2GenRateCapCost::DataFrame, dfCO2TaxCost::DataFrame, dfCO2CaptureCredit::DataFrame)
    dfGen = inputs["dfGen"]
    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones
    G = inputs["G"]     # Number of generators
    COMMIT = inputs["COMMIT"]# Thermal units for unit commitment
    STOR_ALL = inputs["STOR_ALL"]
    # Create a NetRevenue dataframe
    dfNetRevenue = DataFrame(Region=dfGen[!, :region], Resource=inputs["RESOURCES"], Zone=dfGen[!, :Zone], Cluster=dfGen[!, :cluster])

    # Add investment cost to the dataframe
    dfNetRevenue.Inv_cost_MW = value.(EP[:eCInvCap])
    if setup["ParameterScale"] == 1
        dfNetRevenue.Inv_cost_MW *= ModelScalingFactor # converting Million US$ to US$
    end

    dfNetRevenue.Inv_cost_MWh = zeros(nrow(dfNetRevenue))
    if !isempty(STOR_ALL)
        dfNetRevenue.Inv_cost_MWh[STOR_ALL] .= value.(EP[:eCInvEnergyCap][STOR_ALL])
        if setup["ParameterScale"] == 1
            dfNetRevenue.Inv_cost_MWh *= ModelScalingFactor # converting Million US$ to US$
        end
    end

    # Add operations and maintenance cost to the dataframe
    dfNetRevenue.Fixed_OM_cost_MW = value.(EP[:eCFOMCap])
    if setup["ParameterScale"] == 1
        dfNetRevenue.Fixed_OM_cost_MW *= ModelScalingFactor
    end

    dfNetRevenue.Fixed_OM_cost_MWh = zeros(nrow(dfNetRevenue))
    if !isempty(STOR_ALL)
        dfNetRevenue.Fixed_OM_cost_MWh[STOR_ALL] .= value.(EP[:eCFOMEnergyCap][STOR_ALL])
        if setup["ParameterScale"] == 1
            dfNetRevenue.Fixed_OM_cost_MWh *= ModelScalingFactor
        end
    end

    dfNetRevenue.Var_OM_cost_out = value.(EP[:ePlantCVOMOut])
    if setup["ParameterScale"] == 1
        dfNetRevenue.Var_OM_cost_out *= ModelScalingFactor # converting Million US$ to US$
    end

    # Add fuel cost to the dataframe
    dfNetRevenue.Fuel_cost = value.(EP[:ePlantCFuelOut])
    if setup["ParameterScale"] == 1
        dfNetRevenue.Fuel_cost *= ModelScalingFactor^2 # converting Million US$ to US$
    end

    # Add storage cost to the dataframe
    dfNetRevenue.Var_OM_cost_in = zeros(nrow(dfNetRevenue))
    if !isempty(STOR_ALL)
        dfNetRevenue.Var_OM_cost_in[STOR_ALL] .= value.(EP[:ePlantCVarIn][STOR_ALL])
        if setup["ParameterScale"] == 1
            dfNetRevenue.Var_OM_cost_in *= ModelScalingFactor^2 # converting Million US$ to US$
        end
    end

    # Add start-up cost to the dataframe
    dfNetRevenue.StartCost = zeros(nrow(dfNetRevenue))
    if setup["UCommit"] >= 1 && !isempty(COMMIT)
        # if you don't use vec, dimension won't match
        dfNetRevenue.StartCost[COMMIT] .= value.(EP[:ePlantCStart][COMMIT])
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
        dfNetRevenue.EnergyRevenue = dfEnergyRevenue[!, :AnnualSum] # Unit is confirmed to be US$
        dfNetRevenue.SubsidyRevenue = dfSubRevenue[!, :SubsidyRevenue] # Unit is confirmed to be US$
    end

    # Add capacity revenue to the dataframe
    dfNetRevenue.ReserveMarginRevenue = zeros(nrow(dfNetRevenue))
    if haskey(setup, "CapacityReserveMargin")
        if setup["CapacityReserveMargin"] == 1 && has_duals(EP) == 1 # The unit is confirmed to be $
            dfNetRevenue.ReserveMarginRevenue += dfResRevenue.AnnualSum
        end
    end

    # Add RPS/CES revenue to the dataframe
    dfNetRevenue.ESRRevenue = zeros(nrow(dfNetRevenue))
    if haskey(setup, "EnergyShareRequirement")
        if setup["EnergyShareRequirement"] == 1 && has_duals(EP) == 1 # The unit is confirmed to be $
            dfNetRevenue.ESRRevenue += dfESRRev.AnnualSum
        end
    end

    # Add CO2 Cost to the dataframe
    dfNetRevenue.EmissionsCost = zeros(nrow(dfNetRevenue))
    if haskey(setup, "CO2Cap")
        if setup["CO2Cap"] == 1 && has_duals(EP) == 1
            dfNetRevenue.EmissionsCost .+= dfCO2MassCapCost.AnnualSum
        end
    end
    if haskey(setup, "CO2LoadRateCap")
        if setup["CO2LoadRateCap"] == 1 && has_duals(EP) == 1
            dfNetRevenue.EmissionsCost .+= dfCO2LoadRateCapCost.AnnualSum
        end
    end
    if haskey(setup, "CO2GenRateCap")
        if setup["CO2GenRateCap"] == 1 && has_duals(EP) == 1
            dfNetRevenue.EmissionsCost .+= dfCO2GenRateCapCost.AnnualSum
        end
    end
    if haskey(setup, "CO2Tax")
        if setup["CO2Tax"] == 1
            dfNetRevenue.EmissionsCost .+= dfCO2TaxCost.AnnualSum
        end
    end

    # Add CO2 Credit to the dataframe
    dfNetRevenue.CO2Credit = zeros(nrow(dfNetRevenue))
    if haskey(setup, "CO2Credit")
        if setup["CO2Credit"] == 1
            dfNetRevenue.CO2Credit .+= (-1) * dfCO2CaptureCredit.AnnualSum
        end
    end

    # Add CO2 Sequestration cost to the dataframe
    dfNetRevenue.SequestrationCost = zeros(nrow(dfNetRevenue))
    dfNetRevenue.SequestrationCost .+= value.(EP[:ePlantCCO2Sequestration])
    if setup["ParameterScale"] == 1
        dfNetRevenue.SequestrationCost *= ModelScalingFactor^2
    end

    # Add regional technology subsidy revenue to the dataframe
    dfNetRevenue.RegSubsidyRevenue = zeros(nrow(dfNetRevenue))
    if haskey(setup, "MinCapReq")
        if setup["MinCapReq"] >= 1 && has_duals(EP) == 1 # The unit is confirmed to be US$
            dfNetRevenue.RegSubsidyRevenue .+= dfRegSubRevenue.SubsidyRevenue
        end
    end

    dfNetRevenue.Revenue = dfNetRevenue.EnergyRevenue + dfNetRevenue.SubsidyRevenue + dfNetRevenue.ReserveMarginRevenue + dfNetRevenue.ESRRevenue + dfNetRevenue.RegSubsidyRevenue + dfNetRevenue.CO2Credit
    dfNetRevenue.Cost = dfNetRevenue.Inv_cost_MW + dfNetRevenue.Inv_cost_MWh + dfNetRevenue.Fixed_OM_cost_MW + dfNetRevenue.Fixed_OM_cost_MWh + dfNetRevenue.Var_OM_cost_out + dfNetRevenue.Var_OM_cost_in + dfNetRevenue.Fuel_cost + dfNetRevenue.Charge_cost + dfNetRevenue.EmissionsCost + dfNetRevenue.StartCost + dfNetRevenue.SequestrationCost
    dfNetRevenue.Profit = dfNetRevenue.Revenue - dfNetRevenue.Cost

    CSV.write(joinpath(path, "NetRevenue.csv"), dfNetRevenue)
end
