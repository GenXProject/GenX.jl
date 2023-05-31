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
    fuel!(EP::Model, inputs::Dict, setup::Dict)
    this module calculate the fuel consumption and the fuel cost
"""

function fuel!(EP::Model, inputs::Dict, setup::Dict)
    println("Fuel Module")
    dfGen = inputs["dfGen"]
    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones
    G = inputs["G"]
    THERM_COMMIT = inputs["THERM_COMMIT"]
	THERM_NO_COMMIT = inputs["THERM_NO_COMMIT"]
	THERM_ALL = inputs["THERM_ALL"]

    FUEL = length(inputs["fuels"])
    # create variable for fuel consumption for output
    # two variables for two fuel types respectively
    @variable(EP, vFuel[y in 1:G, t = 1:T] >= 0)   # unit: mmBtu or kmmbtu
    @variable(EP, vFuel2[y in THERM_ALL, t = 1:T] >= 0)   # fuel 2 is only allowed for thermal generators

    ### Expressions ####
    # Fuel consumed on start-up (MMBTU or kMMBTU (scaled)) 
    # if unit commitment is modelled
    @expression(EP, eStartFuel[y in 1:G, t = 1:T],
        if y in THERM_COMMIT
            (dfGen[y,:Cap_Size] * EP[:vSTART][y, t] * 
                dfGen[y,:Start_Fuel_MMBTU_per_MW])
        else
            1*EP[:vZERO]
        end)

    @expression(EP, ePlantFuel[y in 1:G, t = 1:T], 
        (EP[:vFuel][y, t] + EP[:eStartFuel][y, t]))

    @expression(EP, ePlantFuel2[y in 1:G, t = 1:T], 
        if y in THERM_ALL
            EP[:vFuel2][y, t]
        else
            1*EP[:vZERO]
        end)
    
    @expression(EP, ePlantFuelConsumptionYear[y in 1:G], 
        sum(inputs["omega"][t] * EP[:ePlantFuel][y, t] for t in 1:T))
    @expression(EP, ePlantFuel2ConsumptionYear[y in THERM_ALL], 
        sum(inputs["omega"][t] * EP[:ePlantFuel2][y, t] for t in 1:T))
    
    @expression(EP, eFuelConsumption[f in 1:FUEL, t in 1:T],
        sum(EP[:ePlantFuel][y, t] 
            for y in dfGen[dfGen[!,:Fuel] .== string(inputs["fuels"][f]) ,:R_ID]))
    @expression(EP, eFuel2Consumption[f in 1:FUEL, t in 1:T],
        sum(EP[:ePlantFuel2][y, t] 
            for y in dfGen[dfGen[!,:Fuel2] .== string(inputs["fuels"][f]) ,:R_ID]))

    @expression(EP, eFuelConsumptionYear[f in 1:FUEL],
        sum(inputs["omega"][t] * EP[:eFuelConsumption][f, t] for t in 1:T))
     @expression(EP, eFuel2ConsumptionYear[f in 1:FUEL],
        sum(inputs["omega"][t] * EP[:eFuel2Consumption][f, t] for t in 1:T))

    # fuel_cost is in $/MMBTU (k$/MMBTU or M$/kMMBTU if scaled)
    # vFuel is MMBTU (or kMMBTU if scaled)
    # therefore eCFuel_out is $ or Million$)
    @expression(EP, eCFuel_out[y = 1:G, t = 1:T], 
        (inputs["fuel_costs"][dfGen[y,:Fuel]][t] * EP[:ePlantFuel][y, t]))
     @expression(EP, eCFuel2_out[y in THERM_ALL, t = 1:T], 
        (inputs["fuel_costs"][dfGen[y,:Fuel2]][t] * EP[:ePlantFuel2][y, t]))

    # plant level total fuel cost for output
    # merge fuel 1 and fuel 2 at this point

    @expression(EP, ePlantCFuel1Out[y = 1:G], 
        sum(inputs["omega"][t] * EP[:eCFuel_out][y, t] for t in 1:T))
    @expression(EP, ePlantCFuel2Out[y in THERM_ALL], 
        sum(inputs["omega"][t] * EP[:eCFuel2_out][y, t] for t in 1:T))
    @expression(EP, ePlantCFuelOut[y = 1:G], 
        if y in THERM_ALL
            sum(inputs["omega"][t] * EP[:eCFuel_out][y, t] for t in 1:T) + sum(inputs["omega"][t] * EP[:eCFuel2_out][y, t] for t in 1:T)
        else
            sum(inputs["omega"][t] * EP[:eCFuel_out][y, t] for t in 1:T)
        end)
    
    # zonal level total fuel cost for output
    @expression(EP, eTotalCFuelOut, sum(EP[:ePlantCFuelOut][y] for y in 1:G))
    add_to_expression!(EP[:eObj], EP[:eTotalCFuelOut])
 
    @expression(EP,eFuelBlending[y=1:G,t=1:T],
        if y in THERM_ALL
            if setup["PieceWiseHeatRate"]==1
                EP[:vFuel2][y, t]
            else
                EP[:vFuel][y, t]*dfGen[y, :Heat_Rate2_MMBTU_per_MWh] + EP[:vFuel2][y, t]*dfGen[y, :Heat_Rate_MMBTU_per_MWh] - EP[:vP][y, t]*dfGen[y, :Heat_Rate2_MMBTU_per_MWh]*dfGen[y, :Heat_Rate_MMBTU_per_MWh]
            end
        else
            # no second fuel used for non-thermal units
            EP[:vFuel][y,t] - EP[:vP][y,t]*dfGen[y, :Heat_Rate_MMBTU_per_MWh]
        end
    )
    @expression(EP,eFuelSwapping[y=1:G,t=1:T],
        if y in THERM_ALL && setup["PieceWiseHeatRate"]!=1 && dfGen[y, :Heat_Rate_MMBTU_per_MWh]>0 && dfGen[y, :Heat_Rate2_MMBTU_per_MWh]==0

            EP[:vFuel][y, t] - EP[:vP][y, t]*dfGen[y, :Heat_Rate_MMBTU_per_MWh]

        elseif y in THERM_ALL && setup["PieceWiseHeatRate"]!=1 && dfGen[y, :Heat_Rate_MMBTU_per_MWh]==0 && dfGen[y, :Heat_Rate2_MMBTU_per_MWh]>0

            EP[:vFuel2][y, t] - EP[:vP][y, t]*dfGen[y, :Heat_Rate2_MMBTU_per_MWh]

        elseif y in THERM_ALL && setup["PieceWiseHeatRate"]!=1 && dfGen[y, :Heat_Rate_MMBTU_per_MWh]==0 && dfGen[y, :Heat_Rate2_MMBTU_per_MWh]==0

            EP[:vFuel2][y, t] + EP[:vFuel][y, t]
            
        else
            EP[:vZERO]
        end
    )

    ### Constraint ###   
    @constraint(EP, cFuelBlend[y=1:G, t = 1:T], eFuelBlending[y,t] == 0)

    @constraint(EP, cFuelSwap[y=1:G, t = 1:T], eFuelSwapping[y,t] == 0)

    if !isempty(THERM_ALL)
        # Add constraints on heat input from fuel 2 (EPA cofiring requirements)
	    # fuel2/heat rate >= min_cofire_level * total power
        @constraint(EP, MinCofire[y in THERM_ALL, t = 1:T], 
            EP[:vFuel2][y, t] >= EP[:vP][y, t] * dfGen[y, :Min_Cofire_Level] * dfGen[y, :Heat_Rate2_MMBTU_per_MWh])
    end

    if !isempty(THERM_COMMIT)
        if setup["PieceWiseHeatRate"] == 1
            # Piecewise heat rate UC only for starup?
            @constraint(EP, First_segement[y in THERM_COMMIT, t = 1:T],
                EP[:vFuel][y, t] + EP[:vFuel2][y, t] >= (EP[:vP][y, t] * dfGen[!, :Slope1][y] + 
                    EP[:vCOMMIT][y, t] * dfGen[!, :Intercept1][y]))
            @constraint(EP, Second_segement[y in THERM_COMMIT, t = 1:T],
                EP[:vFuel][y, t] + EP[:vFuel2][y, t] >= (EP[:vP][y, t] * dfGen[!, :Slope2][y] + 
                    EP[:vCOMMIT][y, t] * dfGen[!, :Intercept2][y]))
            @constraint(EP, Third_segement[y in THERM_COMMIT, t = 1:T],
                EP[:vFuel][y, t] + EP[:vFuel2][y, t] >= (EP[:vP][y, t] * dfGen[!, :Slope3][y] + 
                    EP[:vCOMMIT][y, t] * dfGen[!, :Intercept3][y]))
        end
    end


    return EP
end
