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
	discharge(EP::Model, inputs::Dict, EnergyShareRequirement::Int)
This module defines the power decision variable $\Theta_{y,t} \forall y \in \mathcal{G}, t \in \mathcal{T}$, representing energy injected into the grid by resource $y$ by at time period $t$.
This module additionally defines contributions to the objective function from variable costs of generation (variable O&M plus fuel cost) from all resources $y \in \mathcal{G}$ over all time periods $t \in \mathcal{T}$:
```math
\begin{aligned}
	Obj_{Var\_gen} =
	\sum_{y \in \mathcal{G} } \sum_{t \in \mathcal{T}}\omega_{t}\times(\pi^{VOM}_{y} + \pi^{FUEL}_{y})\times \Theta_{y,t}
\end{aligned}
```
"""
function discharge(EP::Model, inputs::Dict, setup::Dict)

    println("Discharge Module")

    dfGen = inputs["dfGen"]

    G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
    T = inputs["T"]     # Number of time steps
    Z = inputs["Z"]     # Number of zones
    ### Variables ###

    # Energy injected into the grid by resource "y" at hour "t"
    @variable(EP, vP[y = 1:G, t = 1:T] >= 0)

    ### Expressions ###

    ## Objective Function Expressions ##
    # if piecewiseheatrate option and ucommit commitment option are active, skip the fuel consumption
    if haskey(setup, "PieceWiseHeatRate")
        PieceWiseHeatRate = copy(setup["PieceWiseHeatRate"])
    else
        PieceWiseHeatRate = 0
    end
    if (PieceWiseHeatRate == 1) & (!isempty(inputs["THERM_COMMIT"]))
        inputs["C_Fuel_per_MWh"][inputs["THERM_COMMIT"], :] .= 0
    end
    # Variable costs of "generation" for resource "y" during hour "t" = variable O&M plus fuel cost
    # @expression(EP, eCVar_out[y = 1:G, t = 1:T], (inputs["omega"][t] * (dfGen[!, :Var_OM_Cost_per_MWh][y] + inputs["C_Fuel_per_MWh"][y, t]) * vP[y, t]))
    @expression(EP, eCVOM_out[y = 1:G, t = 1:T], (dfGen[!, :Var_OM_Cost_per_MWh][y] * vP[y, t]))
    @expression(EP, eCFuel_out[y = 1:G, t = 1:T], (inputs["C_Fuel_per_MWh"][y, t] * vP[y, t]))
    @expression(EP, eCVar_out[y = 1:G, t = 1:T], EP[:eCVOM_out][y, t] + EP[:eCFuel_out][y, t])
    #@expression(EP, eCVar_out[y=1:G,t=1:T], (round(inputs["omega"][t]*(dfGen[!,:Var_OM_Cost_per_MWh][y]+inputs["C_Fuel_per_MWh"][y,t]), digits=RD)*vP[y,t]))
    # Sum individual resource contributions to variable discharging costs to get total variable discharging costs
    # @expression(EP, eTotalCVarOutT[t = 1:T], sum(eCVar_out[y, t] for y in 1:G))
    # Sum to plant level
    # @expression(EP, ePlantCVarOut[y = 1:G], sum(eCVar_out[y, t] for t in 1:T))
    @expression(EP, ePlantCVOMOut[y = 1:G], sum(inputs["omega"][t] * EP[:eCVOM_out][y, t] for t in 1:T))
    @expression(EP, ePlantCFuelOut[y = 1:G], sum(inputs["omega"][t] * EP[:eCFuel_out][y, t] for t in 1:T))
    @expression(EP, ePlantCVarOut[y = 1:G], EP[:ePlantCVOMOut][y] + EP[:ePlantCFuelOut][y])
    # Sum to zonal level

    @expression(EP, eZonalCVOMOut[z = 1:Z], EP[:vZERO] + sum(EP[:ePlantCVOMOut][y] for y in dfGen[dfGen[!, :Zone].==z, :R_ID]))
    @expression(EP, eZonalCFuelOut[z = 1:Z], EP[:vZERO] + sum(EP[:ePlantCFuelOut][y] for y in dfGen[dfGen[!, :Zone].==z, :R_ID]))
    @expression(EP, eZonalCVarOut[z = 1:Z], EP[:vZERO] + sum(ePlantCVarOut[y] for y in dfGen[dfGen[!, :Zone].==z, :R_ID]))

    # Sum to system level
    @expression(EP, eTotalCFuelOut, sum(eZonalCFuelOut[z] for z in 1:Z))
    @expression(EP, eTotalCVOMOut, sum(eZonalCVOMOut[z] for z in 1:Z))
    @expression(EP, eTotalCVarOut, sum(eZonalCVarOut[z] for z in 1:Z))
    # Add total variable discharging cost contribution to the objective function
    EP[:eObj] += eTotalCVarOut


    return EP

end