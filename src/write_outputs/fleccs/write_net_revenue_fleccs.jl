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
	write_net_revenue(path::AbstractString, inputs::Dict, setup::Dict, EP::Model, dfCap_FLECCS::DataFrame, dfESRRev::DataFrame, dfResRevenue::DataFrame, dfChargingcost::DataFrame, dfPower::DataFrame, dfEnergyRevenue::DataFrame, dfSubRevenue::DataFrame, dfRegSubRevenue::DataFrame)

Function for writing net revenue of different generation technologies.
"""
function write_net_revenue_fleccs(path::AbstractString, inputs::Dict, setup::Dict, EP::Model, dfCap_FLECCS::DataFrame,dfResRevenue_FLECCS::DataFrame, dfPower_FLECCS::DataFrame ,dfEnergyRevenue_FLECCS::DataFrame)
	dfGen_ccs = inputs["dfGen_ccs"]
	T = inputs["T"]     			# Number of time steps (hours)
	Z = inputs["Z"]     			# Number of zones
	dfGen_ccs = inputs["dfGen_ccs"]
	G_F = inputs["G_F"]
	N_F = inputs["N_F"]
	N = length(N_F)
	COMMIT_ccs = inputs["COMMIT_CCS"]

	# Create a NetRevenue dataframe
 	dfNetRevenueFLECCS = DataFrame(Resource = dfGen_ccs[!,"Resource"], zone = dfGen_ccs[!,:Zone], R_ID = dfGen_ccs[!,:R_ID])

	# Add investment cost to the dataframe
	dfNetRevenueFLECCS.Inv_cost= dfGen_ccs[!,:Inv_Cost_per_Unityr] .* dfCap_FLECCS[1:end-1,:NewCap]
	
	if setup["ParameterScale"] == 1
		dfNetRevenueFLECCS.Inv_cost= dfNetRevenueFLECCS.Inv_cost* (ModelScalingFactor) # converting Million US$ to US$
	end


	# Add operations and maintenance cost to the dataframe
	dfNetRevenueFLECCS.Fixed_OM_cost = dfGen_ccs[!,:Fixed_OM_Cost_per_Unityr] .* dfCap_FLECCS[1:end-1,:EndCap]
 	dfNetRevenueFLECCS.Var_OM_cost = (dfGen_ccs[!,:Var_OM_Cost_per_Unit]) .* dfPower_FLECCS[1:end,:AnnualSum]
	
	
	if setup["ParameterScale"] == 1
		dfNetRevenueFLECCS.Fixed_OM_cost = dfNetRevenueFLECCS.Fixed_OM_cost_per_Unityr * (ModelScalingFactor) # converting Million US$ to US$
		dfNetRevenueFLECCS.Var_OM_cost = dfNetRevenueFLECCS.Var_OM_Cost_per_Unit * (ModelScalingFactor) # converting Million US$ to US$
	end


	# Add fuel cost to the dataframe, fuel cost is added to the first subcomponent.
	dfNetRevenueFLECCS.Fuel_cost = zeros(size(dfNetRevenueFLECCS, 1))
	# right now we just have 1 fleccs technology in a single zone, leave it for simplicity
	for i in 1:G_F
		dfNetRevenueFLECCS.Fuel_cost[i] = sum(getvalue.(EP[:eCVar_fuel])[i,:].* inputs["omega"])
	end


	if setup["ParameterScale"] == 1
	    dfNetRevenueFLECCS.Fuel_cost = dfNetRevenueFLECCS.Fuel_cost * (ModelScalingFactor^2) # converting Million US$ to US$
	end


	# Add start-up cost to the dataframe
	dfNetRevenueFLECCS.StartCost = zeros(size(dfNetRevenueFLECCS, 1))
	if (setup["UCommit"]>=1)
		for y in 1:G_F
			for i in COMMIT_ccs #dfGen_ccs[!,:R_ID]
				dfNetRevenueFLECCS.StartCost[i] = sum(value.(EP[:eCStart_FLECCS])[y,i,:])
			end
		end
	end



	if setup["ParameterScale"] == 1
		dfNetRevenueFLECCS.StartCost = dfNetRevenueFLECCS.StartCost * (ModelScalingFactor^2) # converting Million US$ to US$
	end



	# Add energy and subsidy revenue to the dataframe
	dfNetRevenueFLECCS.EnergyRevenue = zeros(size(dfNetRevenueFLECCS, 1))

	if has_duals(EP) == 1
		for y in 1:G_F
		    dfNetRevenueFLECCS.EnergyRevenue[inputs["BOP_id"]] = dfEnergyRevenue_FLECCS[!,:AnnualSum][y] # Unit is confirmed to be US$
	    end
	end




	# Add capacity revenue to the dataframe
	dfNetRevenueFLECCS.ReserveMarginRevenue = zeros(size(dfNetRevenueFLECCS, 1))
	if setup["CapacityReserveMargin"] > 0 && has_duals(EP) == 1 # The unit is confirmed to be $
		for y in 1:G_F
		    dfNetRevenueFLECCS.ReserveMarginRevenue[inputs["BOP_id"]] = dfResRevenue_FLECCS[!,:AnnualSum][y]
		end
	end

	
	# Calculate emissions cost
	dfNetRevenueFLECCS.EmissionsCost = zeros(size(dfNetRevenueFLECCS, 1))
 	if setup["CO2Tax"] >=1 && has_duals(EP) == 1
		for z in 1:Z
			for y in 1:G_F
		        dfNetRevenueFLECCS.EmissionsCost[y] =   inputs["dfCO2Tax"][!,"CO2Tax"][z]*sum(value.(EP[:eEmissionsByPlantFLECCS][y,t])* inputs["omega"][t] for t in 1:T) 
			end
		end

		if setup["ParameterScale"] == 1
			dfNetRevenueFLECCS[!,:EmissionsCost] = dfNetRevenueFLECCS[!,:EmissionsCost] * (ModelScalingFactor^2) # converting Million US$ to US$
		end
	end

	total = DataFrame(Resource = "FLECCS systems", zone = "n/a", R_ID = "n/a", Inv_cost = sum(dfNetRevenueFLECCS[!,:Inv_cost]),
	Fixed_OM_cost = sum(dfNetRevenueFLECCS[!,:Fixed_OM_cost]), Var_OM_cost = sum(dfNetRevenueFLECCS[!,:Var_OM_cost]),
	Fuel_cost = sum(dfNetRevenueFLECCS[!,:Fuel_cost]),StartCost =sum(dfNetRevenueFLECCS[!,:StartCost]),
	EnergyRevenue = sum(dfNetRevenueFLECCS[!,:EnergyRevenue]),ReserveMarginRevenue = sum(dfNetRevenueFLECCS[!,:ReserveMarginRevenue]),
	EmissionsCost= sum(dfNetRevenueFLECCS[!,:EmissionsCost]))

	dfNetRevenueFLECCS2 = vcat(dfNetRevenueFLECCS,total)




	dfNetRevenueFLECCS2.Revenue =	dfNetRevenueFLECCS2.EnergyRevenue +  dfNetRevenueFLECCS2.ReserveMarginRevenue
	dfNetRevenueFLECCS2.Cost =  dfNetRevenueFLECCS2.Inv_cost  + dfNetRevenueFLECCS2.Fixed_OM_cost + dfNetRevenueFLECCS2.Var_OM_cost + dfNetRevenueFLECCS2.Fuel_cost +  dfNetRevenueFLECCS2.EmissionsCost + dfNetRevenueFLECCS2.StartCost
	#dfNetRevenueFLECCS.Cost = dfNetRevenueFLECCS.Inv_cost+ dfNetRevenueFLECCS.Inv_cost_Unith + dfNetRevenueFLECCS.Fixed_OM_cost_per_Unityr + dfNetRevenueFLECCS.Fixed_OM_cost_per_Unityrh + dfNetRevenueFLECCS.Var_OM_Cost_per_Unit + dfNetRevenueFLECCS.Var_OM_cost_in + dfNetRevenueFLECCS.Fuel_cost + dfNetRevenueFLECCS.Charge_cost + dfNetRevenueFLECCS.EmissionsCost + dfNetRevenueFLECCS.StartCost
	dfNetRevenueFLECCS2.Profit = 	dfNetRevenueFLECCS2.Revenue - dfNetRevenueFLECCS2.Cost

	CSV.write(joinpath(path, "NetRevenue_FLECCS.csv"), dfNetRevenueFLECCS2)
end
