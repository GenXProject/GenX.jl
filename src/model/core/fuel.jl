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
    FUEL = length(inputs["fuels"])
    ALLGEN = collect(1:G)
    # create variable for fuel consumption for output
    @variable(EP, vFuel[y in 1:G, t = 1:T] >= 0)
    
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
    @expression(EP, ePlantFuelConsumptionYear[y in 1:G], 
        sum(inputs["omega"][t] * EP[:ePlantFuel][y, t] for t in 1:T))
    @expression(EP, eFuelConsumption[f in 1:FUEL, t in 1:T],
        sum(EP[:ePlantFuel][y, t] 
            for y in dfGen[dfGen[!,:Fuel] .== string(inputs["fuels"][f]) ,:R_ID]))
    @expression(EP, eFuelConsumptionYear[f in 1:FUEL],
        sum(inputs["omega"][t] * EP[:eFuelConsumption][f, t] for t in 1:T))
    # fuel_cost is in $/MMBTU (k$/MMBTU or M$/kMMBTU if scaled)
    # vFuel is MMBTU (or kMMBTU if scaled)
    # therefore eCFuel_out is $ or Million$)
    @expression(EP, eCFuel_out[y = 1:G, t = 1:T], 
        (inputs["fuel_costs"][dfGen[y,:Fuel]][t] * EP[:ePlantFuel][y, t]))
    # plant level total fuel cost for output
    @expression(EP, ePlantCFuelOut[y = 1:G], 
        sum(inputs["omega"][t] * EP[:eCFuel_out][y, t] for t in 1:T))
    # zonal level total fuel cost for output
    @expression(EP, eZonalCFuelOut[z = 1:Z], EP[:vZERO] + 
        sum(EP[:ePlantCFuelOut][y] for y in dfGen[dfGen[!, :Zone].==z, :R_ID]))
    # system level total fuel cost for output
    @expression(EP, eTotalCFuelOut, sum(eZonalCFuelOut[z] for z in 1:Z))
    add_to_expression!(EP[:eObj], EP[:eTotalCFuelOut])

    ### Constraint ###
    @constraint(EP, FuelCalculation[y in setdiff(ALLGEN, THERM_COMMIT), t = 1:T],
        EP[:vFuel][y, t] - EP[:vP][y, t] * dfGen[y, :Heat_Rate_MMBTU_per_MWh] == 0)
    if !isempty(THERM_COMMIT)
        if setup["PieceWiseHeatRate"] == 1
            # Piecewise heat rate UC
            @constraint(EP, First_segement[y in THERM_COMMIT, t = 1:T],
                EP[:vFuel][y, t] >= (EP[:vP][y, t] * dfGen[!, :Slope1][y] + 
                    EP[:vCOMMIT][y, t] * dfGen[!, :Intercept1][y]))
            @constraint(EP, Second_segement[y in THERM_COMMIT, t = 1:T],
                EP[:vFuel][y, t] >= (EP[:vP][y, t] * dfGen[!, :Slope2][y] + 
                    EP[:vCOMMIT][y, t] * dfGen[!, :Intercept2][y]))
            @constraint(EP, Third_segement[y in THERM_COMMIT, t = 1:T],
                EP[:vFuel][y, t] >= (EP[:vP][y, t] * dfGen[!, :Slope3][y] + 
                    EP[:vCOMMIT][y, t] * dfGen[!, :Intercept3][y]))
        else
            @constraint(EP, FuelCalculationCommit[y in THERM_COMMIT, t = 1:T],
                EP[:vFuel][y, t] - EP[:vP][y, t] * dfGen[y, :Heat_Rate_MMBTU_per_MWh] == 0)
        end
    end

    return EP
end
