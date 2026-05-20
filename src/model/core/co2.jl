@doc raw""" 
    co2!(EP::Model, inputs::Dict)

This function creates expressions to account for CO2 emissions as well as captured and sequestrated 
CO2 from thermal generators. It also has the capability to model the negative CO2 emissions 
from bioenergy with carbon capture and storage. 

***** Expressions *****

For thermal generators which combust fuels (e.g., coal, natural gas, and biomass), the net CO2 
emission to the environment is a function of fuel consumption, CO2 emission factor, CO2 capture 
fraction, and whether the feedstock is biomass. Biomass is a factor in this equation because 
biomass generators are assumed to generate zero net CO2 emissions, or negative net CO2 emissions 
in the case that the CO2 they emit is captured and sequestered underground.

If a user wishes to represent a generator that combusts biomass, then in the resource .csv files,
the "Biomass" column (boolean, 1 or 0), which represents if a generator $y$ uses biomass or not, should be set to 1.
The CO2 emissions from such a generator will be assumed to be zero without CCS and negative with CCS.

The CO2 emissions from generator $y$ at time $t$ are determined by total fuel 
consumption (MMBTU) multiplied by the CO2 content of the fuel (tCO2/MMBTU), and by 
(1 - Biomass [0 or 1] - CO2 capture fraction [a fraction, between 0 - 1]). 
The CO2 capture fraction could be differernt during the steady-state and startup events
(generally startup events have a lower CO2 capture fraction), so we use distinct CO2 capture fractions
to determine the emissions. 
In short, the CO2 emissions for a generator depend on the CO2 emission factor from fuel combustion,
the CO2 capture fraction, and whether the generator uses biomass.

```math
\begin{aligned}
eEmissionsByPlant_{g,t} = (1-Biomass_y-  CO2\_Capture\_Fraction_y) * vFuel_{y,t}  * CO2_{content} + (1-Biomass_y-  CO2\_Capture\_Fraction\_Startup_y) * eStartFuel_{y,t} * CO2_{content} 
\hspace{1cm} \forall y \in G, \forall t \in T, Biomass_y \in {{0,1}}
\end{aligned}
```

Where $Biomass_y$ represents a binary variable (1 or 0) that determines if the generator $y$ 
uses biomass, and $CO2\_Capture\_Fraction_y$ represents a fraction for CO2 capture rate.

In addition to CO2 emissions, for generators with a non-zero CO2 capture rate, we also 
determine the amount of CO2 being captured and sequestered. The CO2 emissions from 
generator $y$ at time $t$, denoted by $eEmissionsCaptureByPlant_{g,t}$, are determined by 
total fuel consumption (MMBTU) multiplied by the $CO_2$ content of the fuel (tCO2/MMBTU), 
times CO2 capture rate. 

```math
\begin{aligned}
eEmissionsCaptureByPlant_{g,t} = CO2\_Capture\_Fraction_y * vFuel_{y,t}  * CO2_{content} +  CO2\_Capture\_Fraction\_Startup_y *  eStartFuel_{y,t} * CO2_{content}
\hspace{1cm} \forall y \in G, \forall t \in T
\end{aligned}
```

"""
function co2!(EP::Model, inputs::Dict)
    println("CO2 Module")

    gen = inputs["RESOURCES"]
    G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones
    MULTI_FUELS = inputs["MULTI_FUELS"]
    SINGLE_FUEL = inputs["SINGLE_FUEL"]
    CCS = inputs["CCS"]

    fuel_CO2 = inputs["fuel_CO2"] # CO2 content of fuel (t CO2/MMBTU or ktCO2/Billion BTU)
    omega = inputs["omega"]
    if !isempty(MULTI_FUELS)
        max_fuels = inputs["MAX_NUM_FUELS"]
    end

    ### Expressions ###
    # CO2 emissions from power plants in "Generators_data.csv"
    # If all the CO2 capture fractions from Generators_data are zeros, the CO2 emissions from thermal generators are determined by fuel consumption times CO2 content per MMBTU 

    if isempty(CCS)
        @expression(EP, eEmissionsByPlant[y = 1:G, t = 1:T],
            if y in SINGLE_FUEL
                ((1 - biomass(gen[y])) * (EP[:vFuel][y, t] + EP[:vStartFuel][y, t]) *
                 fuel_CO2[fuel(gen[y])])
            else
                sum(((1 - biomass(gen[y])) *
                     (EP[:vMulFuels][y, i, t] + EP[:vMulStartFuels][y, i, t]) *
                     fuel_CO2[fuel_cols(gen[y], tag = i)]) for i in 1:max_fuels)
            end)
    else
        @info "Using the CO2 module to determine the CO2 emissions of CCS-equipped plants"
        # CO2_Capture_Fraction refers to the CO2 capture rate of CCS equiped power plants at a steady state 
        # CO2_Capture_Fraction_Startup refers to the CO2 capture rate of CCS equiped power plants during startup events

        @expression(EP, eEmissionsByPlant[y = 1:G, t = 1:T],
            if y in SINGLE_FUEL
                (1 - biomass(gen[y]) - co2_capture_fraction(gen[y])) * EP[:vFuel][y, t] *
                fuel_CO2[fuel(gen[y])] +
                (1 - biomass(gen[y]) - co2_capture_fraction_startup(gen[y])) *
                EP[:eStartFuel][y, t] * fuel_CO2[fuel(gen[y])]
            else
                sum((1 - biomass(gen[y]) - co2_capture_fraction(gen[y])) *
                    EP[:vMulFuels][y, i, t] * fuel_CO2[fuel_cols(gen[y], tag = i)]
                for i in 1:max_fuels) +
                sum((1 - biomass(gen[y]) - co2_capture_fraction_startup(gen[y])) *
                    EP[:vMulStartFuels][y, i, t] * fuel_CO2[fuel_cols(gen[y], tag = i)]
                for i in 1:max_fuels)
            end)

        # CO2 captured from power plants in "Generators_data.csv"
        @expression(EP, eEmissionsCaptureByPlant[y in CCS, t = 1:T],
            if y in SINGLE_FUEL
                co2_capture_fraction(gen[y]) * EP[:vFuel][y, t] * fuel_CO2[fuel(gen[y])] +
                co2_capture_fraction_startup(gen[y]) * EP[:eStartFuel][y, t] *
                fuel_CO2[fuel(gen[y])]
            else
                sum(co2_capture_fraction(gen[y]) * EP[:vMulFuels][y, i, t] *
                    fuel_CO2[fuel_cols(gen[y], tag = i)] for i in 1:max_fuels) +
                sum(co2_capture_fraction_startup(gen[y]) * EP[:vMulStartFuels][y, i, t] *
                    fuel_CO2[fuel_cols(gen[y], tag = i)] for i in 1:max_fuels)
            end)

        @expression(EP, eEmissionsCaptureByPlantYear[y in CCS],
            sum(omega[t] * eEmissionsCaptureByPlant[y, t]
            for t in 1:T))
        # add CO2 sequestration cost to objective function
        # when scale factor is on tCO2/MWh = > kt CO2/GWh
        @expression(EP, ePlantCCO2Sequestration[y in CCS],
            sum(omega[t] * eEmissionsCaptureByPlant[y, t] *
                ccs_disposal_cost_per_metric_ton(gen[y]) for t in 1:T))

        @expression(EP, eZonalCCO2Sequestration[z = 1:Z],
            sum(ePlantCCO2Sequestration[y]
            for y in intersect(resources_in_zone_by_rid(gen, z), CCS)))

        @expression(EP, eTotaleCCO2Sequestration,
            sum(eZonalCCO2Sequestration[z] for z in 1:Z))

        add_to_expression!(EP[:eObj], EP[:eTotaleCCO2Sequestration])
    end

    # emissions by zone
    @expression(EP, eEmissionsByZone[z = 1:Z, t = 1:T],
        sum(eEmissionsByPlant[y, t] for y in resources_in_zone_by_rid(gen, z)))
    return EP
end
