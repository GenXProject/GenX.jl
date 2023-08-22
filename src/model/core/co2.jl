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

co2!(EP::Model, inputs::Dict)

This function creates expression to account for $CO_2$ emissions and captured and sequestrated $CO_2$ from thermal generators. It also has the capability to model the negative CO2 emissions from bioenergy with carbon capture and storage. This module will displace the emissions module. 

** Expressions **

For thermal generators that use fuels that contain $CO_2$ content (e.g., coal, natural gas, and biomass), the $CO_2$ emissions are a function of fuel consumption, CO2 capture rate, and whether the feedstock is biomass. Biomass (e.g., wastes or agriculture resides) derived energy is typically considered to be carbon-neutral because the carbon in the biomass is originated from the atmosphere. When bioenergy is coupled with carbon capture and storage (CCS), it creates negative emissions.

Here we create a column called Biomass in the Generator data file (1 or 0), which determines if a generator $g$ uses biomass or not. The CO2 emissions from a generator should be zero without CCS and negative with CCS.

The CO2 emissions from the generator $g$ at time $t$, denoted by $eEmissionsByPlant_{g,t}$, is determined by total fuel consumption (MMBTU, including startup fuel) multiplied by the $CO_2$ content of the fuel (t CO2/MMBTU), then times (1 - Biomass - CO2 capture rate).  In short, the CO2 emissions depend on total CO2 content from fuel consumption, the CO2 capture rate, and whether the generators use biomass.

```math
\begin{aligned}
$eEmissionsByPlant_{g,t}$ = (1-$Biomass_y$- $CO2CaptureRate_y$) * ($vFuel_{y,t}$ + $eStartFuel_{y,t}$) * $CO2_{content}$  
\hspace{1cm} \forall g \in \matchal{G}, \forall t \in \matchal{T}, $Biomass_y$ \in {{0,1}}
\end{aligned}
```
Where $Biomass_y$ represents a binary variable that determines if the generator $y$ uses biomass (Biomass = 1) or not (Biomass = 0), $CO2CaptureRate_y$ represents a fraction (between 0 - 1) for $CO_2$ capture rate. 

In addition to CO2 emissions, for generators with non-zero CO2 capture rate, we also determine the amount of CO2 being captured and sequestrated. The CO2 emissions from the generator $g$ at time $t$, denoted by $eEmissionsCaptureByPlant_{g,t}$, is determined by total fuel consumption (MMBTU, including startup fuel) multiplied by the $CO_2$ content of the fuel (t CO2/MMBTU), then times  CO2 capture rate.

```math
\begin{aligned}
$eEmissionsCaptureByPlant_{g,t}$ = $CO2CaptureRate_y$ * ($vFuel_{y,t}$ + $eStartFuel_{y,t}$) * $CO2_{content}$  
\hspace{1cm} \forall g \in \matchal{G}, \forall t \in \matchal{T}
\end{aligned}
```


"""
function co2!(EP::Model, inputs::Dict)

    println("C02 Module")

    dfGen = inputs["dfGen"]
    G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones
    
    dfGen.Biomass = "Biomass" in names(dfGen) ? dfGen.Biomass : zeros(Int, nrow(dfGen))
    dfGen.CO2_Capture_Rate = "CO2_Capture_Rate" in names(dfGen) ? dfGen.CO2_Capture_Rate : zeros(Int, nrow(dfGen))
    
    ### Expressions ###
    # CO2 emissions from power plants in "Generator_data.csv"
    # if all the CO2 capture rates from generator data are zeros, the CO2 emissions from thermal generators are determined by fuel consumptiono times CO2 content per MMBTU 
    if all(x -> x == 0, dfGen.CO2_Capture_Rate)
        @expression(EP, eEmissionsByPlant[y=1:G, t=1:T], 
            ((1-dfGen.Biomass[y]) *(EP[:vFuel][y, t] + EP[:eStartFuel][y, t]) * inputs["fuel_CO2"][dfGen[y,:Fuel]]))
    else 
        @expression(EP, eEmissionsByPlant[y=1:G, t=1:T],
            ((1-dfGen.Biomass[y]) - dfGen[!, :CO2_Capture_Rate][y]) * 
            ((EP[:vFuel][y, t] + EP[:eStartFuel][y, t]) * 
                inputs["fuel_CO2"][dfGen[y,:Fuel]]))
        
        # CO2  captured from power plants in "Generator_data.csv"
        @expression(EP, eEmissionsCaptureByPlant[y=1:G, t=1:T],
            (dfGen[!, :CO2_Capture_Rate][y]) * 
            ((EP[:vFuel][y, t] + EP[:eStartFuel][y, t]) * 
                inputs["fuel_CO2"][dfGen[y,:Fuel]]))

        
        #************************************* not sure why do we need those expressions.
        @expression(EP, eEmissionsCaptureByPlantYear[y=1:G], 
            sum(inputs["omega"][t] * eEmissionsCaptureByPlant[y, t] 
                for t in 1:T))
        @expression(EP, eEmissionsCaptureByZone[z=1:Z, t=1:T], 
            sum(eEmissionsCaptureByPlant[y, t] 
                for y in dfGen[(dfGen[!, :Zone].==z), :R_ID]))
        @expression(EP, eEmissionsCaptureByZoneYear[z=1:Z], 
            sum(eEmissionsCaptureByPlantYear[y] 
                for y in dfGen[(dfGen[!, :Zone].==z), :R_ID]))
        #*************************************
    
        # add CO2 sequestration cost to objective function
        # when scale factor is on tCO2/MWh = > kt CO2/GWh
        @expression(EP, ePlantCCO2Sequestration[y=1:G], 
            sum(inputs["omega"][t] * eEmissionsCaptureByPlant[y, t] * 
                dfGen[y, :CO2_Capture_Cost_per_Metric_Ton] for t in 1:T))
    
        @expression(EP, eZonalCCO2Sequestration[z=1:Z], 
            sum(ePlantCCO2Sequestration[y] 
                for y in dfGen[(dfGen[!, :Zone].==z), :R_ID]))
    
        @expression(EP, eTotaleCCO2Sequestration, 
            sum(eZonalCCO2Sequestration[z] for z in 1:Z))
    
        add_to_expression!(EP[:eObj], EP[:eTotaleCCO2Sequestration])
    end

    @expression(EP, eEmissionsByPlantYear[y = 1:G], 
        sum(inputs["omega"][t] * eEmissionsByPlant[y, t] for t in 1:T))

    @expression(EP, eEmissionsByZone[z = 1:Z, t = 1:T], 
        sum(eEmissionsByPlant[y, t] for y in dfGen[(dfGen[!, :Zone].==z), :R_ID]))

    @expression(EP, eEmissionsByZoneYear[z = 1:Z], 
        sum(inputs["omega"][t] * eEmissionsByZone[z, t] for t in 1:T))


    return EP

end
