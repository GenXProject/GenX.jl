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

This function creates expression to account for total fuel consumption (e.g., coal, natural gas, hydrogen, etc). It also has the capability to model the piece-wise fuel consumption in part load (if data is available)

***** Expressions ******

The fuel consumption for power generation $vFuel_{y,t}$ is determined by power generation ($vP_{y,t}$) mutiplied by the corresponding heat rate ($Hear\_Rate_y$). 

The fuel costs for power generation and start fuel for a plant $y$ at time $t$, denoted by $eCFuelOut_{y,t}$ and $eFuelStart$, is determined by fuel consumption ($vFuel_{y,t}$ and $eStartFuel$) multiplied by the fuel costs (\$/MMBTU)

From above formulations, thermal generators are expected to have the same fuel consumption per generating 1 MWh electricity, regardless of the operating mode. However, thermal generators tend to have decreased efficiency when operating at part load, leading to higher fuel consumption per generating the same amount of electricity. To have more precise representation of fuel consumption at part load, the piecewise-linear fitting of heat input can be introduced. 

```math
\begin{aligned}
vFuel_{y,t} >= vP_{y,t} * h_{y,x} + U_{g,t}* f_{y,x}
\hspace{1cm} \forall y \in G, \forall t \in T, \forall x \in X
\end{aligned}
```
Where $h_{y,x}$ represents incremental heat rate of a thermal generator $y$ in segment $x$ [MMBTU/MWh] and $f_{y,x}$ represents intercept of fuel consumption of a thermal generator $y$ in segment $x$ [MMBUT], and $U_{y,t}$ represents the commit status of a thermal generator $y$ at time $t$. We include at most three segements to represent the piecewise heat consumption. 

Since fuel consumption has a positive value, the optimization will optimize the fuel consumption by enforcing the inequity to equal to the highest piecewise segment. When the power output is zero, the commitment variable $U_{g,t}$ will bring the intercept to be zero such that the fuel consumption is zero when thermal units are offline.

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

    # fuel_cost is in $/MMBTU (M$/billion BTU if scaled)
    # vFuel and eStartFuel is MMBTU (or billion BTU if scaled)
    # Therefore eCFuel_start or eCFuel_out is $ or Million$)
    # Separately track the start up fuel and fuel consumption for power generation
    
    # Start up fuel cost
    @expression(EP, eCFuelStart[y = 1:G, t = 1:T], 
        (inputs["fuel_costs"][dfGen[y,:Fuel]][t] * EP[:eStartFuel][y, t]))
    # plant level start-up fuel cost for output
    @expression(EP, ePlantCFuelStart[y = 1:G], 
        sum(inputs["omega"][t] * EP[:eCFuelStart][y, t] for t in 1:T))
    # zonal level total fuel cost for output
    @expression(EP, eZonalCFuelStart[z = 1:Z], EP[:vZERO] + 
        sum(EP[:ePlantCFuelStart][y] for y in dfGen[dfGen[!, :Zone].==z, :R_ID]))

    # Fuel cost for power generation
    @expression(EP, eCFuelOut[y = 1:G, t = 1:T], 
        (inputs["fuel_costs"][dfGen[y,:Fuel]][t] * EP[:vFuel][y, t]))
    # plant level start-up fuel cost for output
    @expression(EP, ePlantCFuelOut[y = 1:G], 
        sum(inputs["omega"][t] * EP[:eCFuelOut][y, t] for t in 1:T))
    # zonal level total fuel cost for output
    @expression(EP, eZonalCFuelOut[z = 1:Z], EP[:vZERO] + 
        sum(EP[:ePlantCFuelOut][y] for y in dfGen[dfGen[!, :Zone].==z, :R_ID]))


    # system level total fuel cost for output
    @expression(EP, eTotalCFuelOut, sum(eZonalCFuelOut[z] for z in 1:Z))
    @expression(EP, eTotalCFuelStart, sum(eZonalCFuelStart[z] for z in 1:Z))


    add_to_expression!(EP[:eObj], EP[:eTotalCFuelOut] + EP[:eTotalCFuelStart])

    #fuel consumption (MMBTU or Billion BTU)
    @expression(EP, eFuelConsumption[f in 1:FUEL, t in 1:T],
        sum(EP[:vFuel][y, t] + EP[:eStartFuel][y,t]
            for y in dfGen[dfGen[!,:Fuel] .== string(inputs["fuels"][f]) ,:R_ID]))
                
    @expression(EP, eFuelConsumptionYear[f in 1:FUEL],
        sum(inputs["omega"][t] * EP[:eFuelConsumption][f, t] for t in 1:T))

    
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
