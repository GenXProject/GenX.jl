@doc raw""" 
    co2!(EP::Model, inputs::Dict)

This function creates expression to account for CO2 emissions and captured and sequestrated 
CO2 from thermal generators. It also has the capability to model the negative CO2 emissions 
from bioenergy with carbon capture and storage. 

***** Expressions *****

For thermal generators which use fuels with CO2 as a combustion product 
(e.g., coal, natural gas, and biomass), the net CO2 emission to the environment is a function 
of fuel consumption, CO2 capture fraction, and whether the feedstock is biomass. 
Biomass (e.g., wastes or agriculture residues) derived energy is typically considered to be 
carbon-neutral because the carbon in the biomass originates from the atmosphere. 
When bioenergy is coupled with carbon capture and storage (CCS), it yields negative emissions.
If users want to represent delicated biomass, then in Generators_data.csv, it requires a column 
called "Biomass" (boolean, 1 or 0), which represents if a generator $y$ uses biomass or not.
The CO2 emissions from such a generator should be zero without CCS and negative with CCS.
The CO2 emissions from the generator $y$ at time $t$, is determined by total fuel 
consumption (MMBTU) multiplied by the CO2 content of the fuel (t CO2/MMBTU), and by 
(1 - Biomass [0 or 1] - CO2 capture fraction [a fraction, between 0 - 1]). 
The CO2 capture fraction could be differernt during the steady-state and startup event 
(generally startup events have lower CO2 capture fraction), so we use distinct CO2 capture fraction 
to determine the emissions. 
In short, the CO2 emissions depend on total CO2 content from fuel consumption,
the CO2 capture fraction, and whether the generators use biomass.

```math
\begin{aligned}
eEmissionsByPlant_{g,t} = (1-Biomass_y-  CO2\_Capture\_Fraction_y) * vFuel_{y,t}  * CO2_{content} + (1-Biomass_y-  CO2\_Capture\_Fraction\_Startup_y) * eStartFuel_{y,t} * CO2_{content} 
\hspace{1cm} \forall y \in G, \forall t \in T, Biomass_y \in {{0,1}}
\end{aligned}
```

Where $Biomass_y$ represents a binary variable that determines if the generator $y$ 
uses biomass (Biomass = 1) or not (Biomass = 0), $CO2\_Capture\_Fraction_y$ represents a 
fraction (between 0 - 1) for CO2 capture rate.
In addition to CO2 emissions, for generators with non-zero CO2 capture rate, we also 
determine the amount of CO2 being captured and sequestrated. The CO2 emissions from the 
generator $y$ at time $t$, denoted by $eEmissionsCaptureByPlant_{g,t}$, is determined by 
total fuel consumption (MMBTU) multiplied by the $CO_2$ content of the fuel (t CO2/MMBTU), 
then times CO2 capture rate. 

```math
\begin{aligned}
eEmissionsCaptureByPlant_{g,t} = CO2\_Capture\_Fraction_y * vFuel_{y,t}  * CO2_{content} +  CO2\_Capture\_Fraction\_Startup_y *  eStartFuel_{y,t} * CO2_{content}
\hspace{1cm} \forall y \in G, \forall t \in T
\end{aligned}
```

"""
function co2!(EP::Model, inputs::Dict)

    println("CO2 Module")

    dfGen = inputs["dfGen"]
    G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones
    fuel_CO2 = inputs["fuel_CO2"] # CO2 content of fuel (t CO2/MMBTU or ktCO2/Billion BTU)
    ### Expressions ###
    # CO2 emissions from power plants in "Generators_data.csv"
    # if all the CO2 capture fraction from generator data are zeros, the CO2 emissions from thermal generators are determined by fuel consumptiono times CO2 content per MMBTU 
    if all(dfGen.CO2_Capture_Fraction .==0)
        @expression(EP, eEmissionsByPlant[y=1:G, t=1:T], 
            ((1-dfGen[y, :Biomass]) *(EP[:vFuel][y, t] + EP[:eStartFuel][y, t]) * fuel_CO2[dfGen[y,:Fuel]]))
    else 
        @info "Using the CO2 module to determine the CO2 emissions of CCS-equipped plants"
        # The CO2_Capture_Fraction refers to the CO2 capture rate of CCS equiped power plants at a steady state 
        # The CO2_Capture_Fraction_Startup refers to the CO2 capture rate of CCS equiped power plants during the startup event
        @expression(EP, eEmissionsByPlant[y=1:G, t=1:T],
            (1-dfGen[y, :Biomass] - dfGen[y, :CO2_Capture_Fraction]) * EP[:vFuel][y, t]  * fuel_CO2[dfGen[y,:Fuel]]+
            (1-dfGen[y, :Biomass] - dfGen[y, :CO2_Capture_Fraction_Startup]) * EP[:eStartFuel][y, t] * fuel_CO2[dfGen[y,:Fuel]])
        
        # CO2 captured from power plants in "Generators_data.csv"
        @expression(EP, eEmissionsCaptureByPlant[y=1:G, t=1:T],
            dfGen[y, :CO2_Capture_Fraction] * EP[:vFuel][y, t] * fuel_CO2[dfGen[y,:Fuel]]+
            dfGen[y, :CO2_Capture_Fraction_Startup] * EP[:eStartFuel][y, t] * fuel_CO2[dfGen[y,:Fuel]])

        
        #************************************* 
        @expression(EP, eEmissionsCaptureByPlantYear[y=1:G], 
            sum(inputs["omega"][t] * eEmissionsCaptureByPlant[y, t] 
                for t in 1:T))
        @expression(EP, eEmissionsCaptureByZone[z=1:Z, t=1:T], 
            sum(eEmissionsCaptureByPlant[y, t] 
                for y in dfGen[dfGen[!, :Zone].==z, :R_ID]))
        @expression(EP, eEmissionsCaptureByZoneYear[z=1:Z], 
            sum(eEmissionsCaptureByPlantYear[y] 
                for y in dfGen[dfGen[!, :Zone].==z, :R_ID]))
        #*************************************
    
        # add CO2 sequestration cost to objective function
        # when scale factor is on tCO2/MWh = > kt CO2/GWh
        @expression(EP, ePlantCCO2Sequestration[y=1:G], 
            sum(inputs["omega"][t] * eEmissionsCaptureByPlant[y, t] * 
                dfGen[y, :CCS_Disposal_Cost_per_Metric_Ton] for t in 1:T))
    
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
