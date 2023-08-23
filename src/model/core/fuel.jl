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
	THERM_ALL = inputs["THERM_ALL"]
    MULTI_FUELS = inputs["MULTI_FUELS"]
    SINGLE_FUEL = inputs["SINGLE_FUEL"]

    FUEL = length(inputs["fuels"])
    # create variable for fuel consumption for output

    # unit: mmBtu or kmmbtu
    # for resources that only use a single fuel
    @variable(EP, vFuel[y in SINGLE_FUEL, t = 1:T] >= 0)   
    @variable(EP, vStartFuel[y in SINGLE_FUEL, t = 1:T] >= 0)   

    # for resources that use multi fuels
    # vMulFuels[y, f, t]: y - resource ID; f - fuel ID; t: time
    @variable(EP, vMulFuels[y in MULTI_FUELS, i = 1:inputs["MAX_NUM_FUELS"], t = 1:T] >= 0) 
    @variable(EP, vMulStartFuels[y in MULTI_FUELS, i = 1:inputs["MAX_NUM_FUELS"], t = 1:T] >= 0)   

    ### Expressions ####

    # time-series fuel consumption by plant and fuel type
    @expression(EP, ePlantFuel_multi[y in MULTI_FUELS, i in 1:inputs["MAX_NUM_FUELS"], t = 1:T],
        (EP[:vMulFuels][y, i, t] + EP[:vMulStartFuels][y, i, t])
        ) 
    # annual fuel consumption by plant and fuel type
    @expression(EP, ePlantFuelConsumptionYear_multi[y in MULTI_FUELS, i in 1:inputs["MAX_NUM_FUELS"]], 
        sum(inputs["omega"][t] * EP[:ePlantFuel_multi][y, i, t] for t in 1:T))


    # time-series fuel consumption by plant 
    @expression(EP, ePlantFuel[y in 1:G, t = 1:T],
        if y in SINGLE_FUEL   # for single fuel plants
            (EP[:vFuel][y, t] + EP[:vStartFuel][y, t])
        else # for multi fuel plants
            sum((EP[:vMulFuels][y, i, t] + EP[:vMulStartFuels][y, i, t]) for i in 1:inputs["MAX_NUM_FUELS"]) 
        end)  
    # annual fuel consumption by plant
    @expression(EP, ePlantFuelConsumptionYear[y in 1:G], 
        sum(inputs["omega"][t] * EP[:ePlantFuel][y, t] for t in 1:T))

    
    # time-series consumption by fuel type
    # single fuel
    @expression(EP, eFuelConsumption_single[f in 1:FUEL, t in 1:T],
        sum(EP[:ePlantFuel][y, t]  for y in intersect(dfGen[dfGen[!,:Fuel] .== string(inputs["fuels"][f]) ,:R_ID], SINGLE_FUEL))
        )
        
    # multi fuels
    @expression(EP, eFuelConsumption_multi[f in 1:FUEL, t in 1:T],
        sum((EP[:vMulFuels][y, i, t] + EP[:vMulStartFuels][y, i, t]) #i: fuel id 
            for i in 1:inputs["MAX_NUM_FUELS"], 
                y in intersect(dfGen[dfGen[!,inputs["FUEL_COLS"][i]] .== string(inputs["fuels"][f]) ,:R_ID], MULTI_FUELS))
        )
 
    @expression(EP, eFuelConsumption[f in 1:FUEL, t in 1:T],
        eFuelConsumption_multi[f, t] + eFuelConsumption_single[f,t])

    @expression(EP, eFuelConsumptionYear[f in 1:FUEL],
        sum(inputs["omega"][t] * EP[:eFuelConsumption][f, t] for t in 1:T))


    # fuel_cost is in $/MMBTU (k$/MMBTU or M$/kMMBTU if scaled)
    # vFuel is MMBTU (or kMMBTU if scaled)
    # therefore eCFuel_out is $ or Million$)

    # start up cost
    @expression(EP, eCFuelStart[y = 1:G, t = 1:T], 
        if y in SINGLE_FUEL
            (inputs["fuel_costs"][dfGen[y,:Fuel]][t] * EP[:vStartFuel][y, t])
        else
            sum(EP[:vMulStartFuels][y, i, t] for i in 1:inputs["MAX_NUM_FUELS"])
        end)
    # plant level start-up fuel cost for output
    @expression(EP, ePlantCFuelStart[y = 1:G], 
        sum(inputs["omega"][t] * EP[:eCFuelStart][y, t] for t in 1:T))
    # zonal level total fuel cost for output
    @expression(EP, eZonalCFuelStart[z = 1:Z], EP[:vZERO] + 
        sum(EP[:ePlantCFuelStart][y] for y in dfGen[dfGen[!, :Zone].==z, :R_ID]))


    # time-series fuel consumption by plant and fuel type
    @expression(EP, eCFuel_out_multi[y in MULTI_FUELS , i in 1:inputs["MAX_NUM_FUELS"], t = 1:T], 
        inputs["fuel_costs"][dfGen[y,inputs["FUEL_COLS"][i]]][t]*(EP[:vMulFuels][y, i, t]+EP[:vMulStartFuels][y, i, t])
        )

    # annual plant level fuel cost by fuel type
    @expression(EP, ePlantCFuelOut_multi[y in MULTI_FUELS, i in 1:inputs["MAX_NUM_FUELS"]], 
        sum(inputs["omega"][t] * EP[:eCFuel_out_multi][y, i, t] for t in 1:T))


    # time-series fuel consumption at each plant
    @expression(EP, eCFuel_out[y = 1:G, t = 1:T], 
        if y in SINGLE_FUEL
            inputs["fuel_costs"][dfGen[y,:Fuel]][t] * EP[:ePlantFuel][y, t]
        else
            sum(inputs["fuel_costs"][dfGen[y,inputs["FUEL_COLS"][i]]][t]*(EP[:vMulFuels][y, i, t]) for i in 1:inputs["MAX_NUM_FUELS"] )
        end)

    # annual plant level total fuel cost for output
    @expression(EP, ePlantCFuelOut[y = 1:G], 
        sum(inputs["omega"][t] * EP[:eCFuel_out][y, t] for t in 1:T))
    
    # zonal level total fuel cost for output
    @expression(EP, eTotalCFuelOut, sum(EP[:ePlantCFuelOut][y] for y in 1:G))
    @expression(EP, eTotalCFuelStart, sum(EP[:eZonalCFuelStart][z] for z in 1:Z))

    add_to_expression!(EP[:eObj], EP[:eTotalCFuelOut] + EP[:eTotalCFuelStart])
        
    

    ## check this with Filippo
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
    @constraint(EP, cFuelSwap[y=1:G, t = 1:T], eFuelSwapping[y,t] == 0)

    ### Constraint ###   
    # power ouput
    @constraint(EP, cFuelCalculation_single[y in intersect(SINGLE_FUEL,setdiff(collect(1:G), THERM_COMMIT)), t = 1:T],
            EP[:vFuel][y, t] - EP[:vP][y, t] * dfGen[y, :Heat_Rate_MMBTU_per_MWh] == 0
            )
    @constraint(EP, cFuelCalculation_multi[y in intersect(MULTI_FUELS,setdiff(collect(1:G), THERM_COMMIT)), t = 1:T],
            sum(EP[:vMulFuels][y, i, t]/inputs["HEAT_RATES"][i][y] for i in 1:inputs["MAX_NUM_FUELS"]) - EP[:vP][y, t] == 0 
        )

    if !isempty(THERM_COMMIT)
        if setup["PieceWiseHeatRate"] == 1
            # multi fuel is not included here
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
            @constraint(EP, cFuelCalculationCommit_single[y in intersect(THERM_COMMIT, SINGLE_FUEL), t = 1:T],
                  EP[:vFuel][y, t] - EP[:vP][y, t] * dfGen[y, :Heat_Rate_MMBTU_per_MWh] .== 0
            )
            @constraint(EP, FuelCalculationCommit_multi[y in intersect(MULTI_FUELS, THERM_COMMIT), t = 1:T],
                sum(EP[:vMulFuels][y, i, t]/inputs["HEAT_RATES"][i][y] for i in 1:inputs["MAX_NUM_FUELS"]) - EP[:vP][y, t] .== 0 
            )
        end
    end

    # start up fuel use
    @expression(EP, cStartFuel_single[y in intersect(THERM_COMMIT, SINGLE_FUEL), t = 1:T],
        EP[:vStartFuel][y, t] - (dfGen[y,:Cap_Size] * EP[:vSTART][y, t] * dfGen[y,:Start_Fuel_MMBTU_per_MW]) .== 0
        )

    @expression(EP, cStartFuel_multi[y in intersect(THERM_COMMIT, MULTI_FUELS), t = 1:T],
        sum(EP[:vMulStartFuels][y, i, t] for i in 1:inputs["MAX_NUM_FUELS"]) - (dfGen[y,:Cap_Size] * EP[:vSTART][y, t] * dfGen[y,:Start_Fuel_MMBTU_per_MW]) .== 0
        )

    # cofire 
    if !isempty(MULTI_FUELS)
        # Add constraints on heat input from fuels (EPA cofiring requirements)
        # for example,
	    # fuel2/heat rate >= min_cofire_level * total power 
        # fuel2/heat rate <= max_cofire_level * total power without retrofit

        @constraint(EP, cMinCofire[y in MULTI_FUELS, i in 1:inputs["MAX_NUM_FUELS"], t = 1:T], 
            EP[:vMulFuels][y, i, t] >= EP[:vP][y, t] * inputs["MIN_COFIRE"][i][y] * inputs["HEAT_RATES"][i][y]
            )
        @constraint(EP, cMaxCofire[y in MULTI_FUELS, i in 1:inputs["MAX_NUM_FUELS"], t = 1:T], 
            EP[:vMulFuels][y, i, t] <= EP[:vP][y, t] * inputs["MAX_COFIRE"][i][y] * inputs["HEAT_RATES"][i][y]
            )
    end



    return EP
end