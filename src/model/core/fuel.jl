
@doc raw"""
    fuel!(EP::Model, inputs::Dict, setup::Dict)

This function creates expressions to account for total fuel consumption (e.g., coal, 
natural gas, hydrogen, etc). It also has the capability to model heat rates that are
a function of load via a piecewise-linear approximation.

***** Expressions ******
Users have two options to model the fuel consumption as a function of power generation: 
(1). Use a constant heat rate, regardless of the minimum load or maximum load; and 
(2). Use the PiecewiseFuelUsage-related parameters to model the fuel consumption via a 
piecewise-linear approximation of the heat rate curves. By using this option, users can represent 
the fact that most generators have a decreasing heat rate as a function of load.

(1). Constant heat rate. 
The fuel consumption for power generation $vFuel_{y,t}$ is determined by power generation 
($vP_{y,t}$) mutiplied by the corresponding heat rate ($Heat\_Rate_y$). 
The fuel costs for power generation and start fuel for a plant $y$ at time $t$, 
denoted by $eCFuelOut_{y,t}$ and $eFuelStart$, are determined by fuel consumption ($vFuel_{y,t}$ 
and $eStartFuel$) multiplied by the fuel costs (\$/MMBTU)
(2). Piecewise-linear approximation
With this formulation, the heat rate of generators becomes a function of load.
In reality this relationship takes a nonlinear form, but we model it
through a piecewise-linear approximation:

```math
\begin{aligned}
vFuel_{y,t} >= vP_{y,t} * h_{y,x} + U_{g,t}* f_{y,x}
\hspace{1cm} \forall y \in G, \forall t \in T, \forall x \in X
\end{aligned}
```
Where $h_{y,x}$ represents the heat rate slope for generator $y$ in segment $x$ [MMBTU/MWh],
 $f_{y,x}$ represents the heat rate intercept (MMBTU) for a generator $y$ in segment $x$ [MMBTU],
and $U_{y,t}$ represents the commitment status of a generator $y$ at time $t$. These parameters
are optional inputs to the resource .csv files. 
When Unit commitment is on, if a user provides slope and intercept, the standard heat rate 
(i.e., Heat_Rate_MMBTU_per_MWh) will not be used. When unit commitment is off, the model will 
always use the standard heat rate.
The user should determine the slope and intercept parameters based on the Cap_Size of the plant. 
For example, when a plant is operating at the full load (i.e., power output equal to the Cap_Size),
the fuel usage determined by the effective segment divided by Cap_Size should be equal to the 
heat rate at full-load.

Since fuel consumption and fuel costs are postive, the optimization will force the fuel usage
to be equal to the highest fuel usage segment for any given value of vP.
When the power output is zero, the commitment variable $U_{g,t}$ will bring the intercept 
to be zero such that the fuel consumption is zero when thermal units are offline.

In order to run piecewise fuel consumption module,
the unit commitment must be turned on (UC = 1 or 2), and users should provide PWFU_Slope_* and 
PWFU_Intercept_* for at least one segment. 

To enable resources to use multiple fuels during both startup and normal operational processes, three additional variables were added: 
fuel $i$ consumption by plant $y$ at time $t$ ($vMulFuel_{y,i,t}$); startup fuel consumption for single-fuel plants ($vStartFuel_{y,t}$); and startup fuel consumption for multi-fuel plants ($vMulStartFuel_{y,i,t}$). By making startup fuel consumption variables, the model can choose the startup fuel to meet the constraints.    
    
For plants using multiple fuels:
    
During startup, heat input from multiple startup fuels are equal to startup fuel requirements in plant $y$ at time $t$: $StartFuelMMBTUperMW$ $\times$ $Capsize$.
```math
\begin{aligned}
\sum_{i \in \mathcal{I} } vMulStartFuels_{y, i, t}= CapSize_{y} \times StartFuelMMBTUperMW_{y} \times vSTART_{y,t}
\end{aligned}
```
During normal operation, the sum of fuel consumptions from multiple fuels dividing by the correspnding heat rates, respectively, is equal to $vPower$ in plant $y$ at time $t$. 
```math
\begin{aligned}
\sum_{i \in \mathcal{I} } \frac{vMulFuels_{y, i, t}} {HeatRate_{i,y} } = vPower_{y,t}
\end{aligned}
```
There are also constraints on how much heat input each fuel can provide, which are specified by $MinCofire$ and $MaxCofire$.
```math
\begin{aligned}
vMulFuels_{y, i, t} >= vPower_{y,t} \times MinCofire_{i}
\end{aligned}   
\begin{aligned}
vMulFuels_{y, i, t} <= vPower_{y,t} \times MaxCofire_{i}
\end{aligned}
```
"""
function fuel!(EP::Model, inputs::Dict, setup::Dict)
    println("Fuel Module")
    gen = inputs["RESOURCES"]

    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones
    G = inputs["G"]
    THERM_COMMIT = inputs["THERM_COMMIT"]
    HAS_FUEL = inputs["HAS_FUEL"]
    MULTI_FUELS = inputs["MULTI_FUELS"]
    SINGLE_FUEL = inputs["SINGLE_FUEL"]

    fuels = inputs["fuels"]
    fuel_costs = inputs["fuel_costs"]
    omega = inputs["omega"]

    NUM_FUEL = length(fuels)

    # create variable for fuel consumption for output
    # for resources that only use a single fuel
    @variable(EP, vFuel[y in SINGLE_FUEL, t = 1:T]>=0)
    @variable(EP, vStartFuel[y in SINGLE_FUEL, t = 1:T]>=0)

    # for resources that use multi fuels
    # vMulFuels[y, f, t]: y - resource ID; f - fuel ID; t: time
    if !isempty(MULTI_FUELS)
        max_fuels = inputs["MAX_NUM_FUELS"]
        heat_rates = inputs["HEAT_RATES"]
        min_cofire = inputs["MIN_COFIRE"]
        max_cofire = inputs["MAX_COFIRE"]
        min_cofire_start = inputs["MIN_COFIRE_START"]
        max_cofire_start = inputs["MAX_COFIRE_START"]

        COFIRE_MAX = [findall(g -> max_cofire_cols(g, tag = i) < 1, gen[MULTI_FUELS])
                      for i in 1:max_fuels]
        COFIRE_MAX_START = [findall(g -> max_cofire_start_cols(g, tag = i) < 1,
                                gen[MULTI_FUELS]) for i in 1:max_fuels]
        COFIRE_MIN = [findall(g -> min_cofire_cols(g, tag = i) > 0, gen[MULTI_FUELS])
                      for i in 1:max_fuels]
        COFIRE_MIN_START = [findall(g -> min_cofire_start_cols(g, tag = i) > 0,
                                gen[MULTI_FUELS]) for i in 1:max_fuels]

        @variable(EP, vMulFuels[y in MULTI_FUELS, i = 1:max_fuels, t = 1:T]>=0)
        @variable(EP, vMulStartFuels[y in MULTI_FUELS, i = 1:max_fuels, t = 1:T]>=0)
    end

    ### Expressions ####
    # Fuel consumed on start-up (MMBTU or kMMBTU (scaled)) 
    # if unit commitment is modelled
    @expression(EP, eStartFuel[y in 1:G, t = 1:T],
        if y in THERM_COMMIT
            (cap_size(gen[y]) * EP[:vSTART][y, t] *
             start_fuel_mmbtu_per_mw(gen[y]))
        else
            0
        end)

    # time-series fuel consumption by plant 
    @expression(EP, ePlantFuel_generation[y in 1:G, t = 1:T],
        if y in SINGLE_FUEL   # for single fuel plants
            EP[:vFuel][y, t]
        else # for multi fuel plants
            sum(EP[:vMulFuels][y, i, t] for i in 1:max_fuels)
        end)
    @expression(EP, ePlantFuel_start[y in 1:G, t = 1:T],
        if y in SINGLE_FUEL   # for single fuel plants
            EP[:vStartFuel][y, t]
        else # for multi fuel plants
            sum(EP[:vMulStartFuels][y, i, t] for i in 1:max_fuels)
        end)

    # for multi-fuel resources
    # annual fuel consumption by plant and fuel type
    if !isempty(MULTI_FUELS)
        @expression(EP,
            ePlantFuelConsumptionYear_multi_generation[y in MULTI_FUELS, i in 1:max_fuels],
            sum(omega[t] * EP[:vMulFuels][y, i, t] for t in 1:T))
        @expression(EP,
            ePlantFuelConsumptionYear_multi_start[y in MULTI_FUELS, i in 1:max_fuels],
            sum(omega[t] * EP[:vMulStartFuels][y, i, t] for t in 1:T))
        @expression(EP, ePlantFuelConsumptionYear_multi[y in MULTI_FUELS, i in 1:max_fuels],
            EP[:ePlantFuelConsumptionYear_multi_generation][y,
                i]+EP[:ePlantFuelConsumptionYear_multi_start][y, i])
    end
    # fuel_cost is in $/MMBTU (M$/billion BTU if scaled)
    # vFuel and eStartFuel is MMBTU (or billion BTU if scaled)
    # eCFuel_start or eCFuel_out is $ or Million$

    # Start up fuel cost
    # for multi-fuel resources
    if !isempty(MULTI_FUELS)
        # time-series fuel consumption costs by plant and fuel type during startup
        @expression(EP, eCFuelOut_multi_start[y in MULTI_FUELS, i in 1:max_fuels, t = 1:T],
            fuel_costs[fuel_cols(gen[y], tag = i)][t]*EP[:vMulStartFuels][y, i, t])
        # annual plant level fuel cost by fuel type during generation
        @expression(EP, ePlantCFuelOut_multi_start[y in MULTI_FUELS, i in 1:max_fuels],
            sum(omega[t] * EP[:eCFuelOut_multi_start][y, i, t] for t in 1:T))
    end

    @expression(EP, eCFuelStart[y = 1:G, t = 1:T],
        if y in SINGLE_FUEL
            (fuel_costs[fuel(gen[y])][t] * EP[:vStartFuel][y, t])
        else
            sum(EP[:eCFuelOut_multi_start][y, i, t] for i in 1:max_fuels)
        end)

    # plant level start-up fuel cost for output
    @expression(EP, ePlantCFuelStart[y = 1:G],
        sum(omega[t] * EP[:eCFuelStart][y, t] for t in 1:T))
    # zonal level total fuel cost for output
    @expression(EP, eZonalCFuelStart[z = 1:Z],
        sum(EP[:ePlantCFuelStart][y] for y in resources_in_zone_by_rid(gen, z)))

    # Fuel cost for power generation
    # for multi-fuel resources
    if !isempty(MULTI_FUELS)
        # time-series fuel consumption costs by plant and fuel type during generation
        @expression(EP, eCFuelOut_multi[y in MULTI_FUELS, i in 1:max_fuels, t = 1:T],
            fuel_costs[fuel_cols(gen[y], tag = i)][t]*EP[:vMulFuels][y, i, t])
        # annual plant level fuel cost by fuel type during generation
        @expression(EP, ePlantCFuelOut_multi[y in MULTI_FUELS, i in 1:max_fuels],
            sum(omega[t] * EP[:eCFuelOut_multi][y, i, t] for t in 1:T))
    end

    @expression(EP, eCFuelOut[y = 1:G, t = 1:T],
        if y in SINGLE_FUEL
            (fuel_costs[fuel(gen[y])][t] * EP[:vFuel][y, t])
        else
            sum(EP[:eCFuelOut_multi][y, i, t] for i in 1:max_fuels)
        end)
    # plant level start-up fuel cost for output
    @expression(EP, ePlantCFuelOut[y = 1:G],
        sum(omega[t] * EP[:eCFuelOut][y, t] for t in 1:T))
    # zonal level total fuel cost for output
    @expression(EP, eZonalCFuelOut[z = 1:Z],
        sum(EP[:ePlantCFuelOut][y] for y in resources_in_zone_by_rid(gen, z)))

    # system level total fuel cost for output
    @expression(EP, eTotalCFuelOut, sum(eZonalCFuelOut[z] for z in 1:Z))
    @expression(EP, eTotalCFuelStart, sum(eZonalCFuelStart[z] for z in 1:Z))

    add_to_expression!(EP[:eObj], EP[:eTotalCFuelOut] + EP[:eTotalCFuelStart])

    #fuel consumption (MMBTU or Billion BTU)
    # for multi-fuel resources
    if !isempty(MULTI_FUELS)
        @expression(EP, eFuelConsumption_multi[f in 1:NUM_FUEL, t in 1:T],
            sum((EP[:vMulFuels][y, i, t] + EP[:vMulStartFuels][y, i, t]) #i: fuel id 
            for i in 1:max_fuels,
            y in intersect(
                resource_id.(gen[fuel_cols.(gen, tag = i) .== string(fuels[f])]),
                MULTI_FUELS)))
    end

    @expression(EP, eFuelConsumption_single[f in 1:NUM_FUEL, t in 1:T],
        sum(EP[:vFuel][y, t] + EP[:eStartFuel][y, t]
        for y in intersect(resources_with_fuel(gen, fuels[f]), SINGLE_FUEL)))

    @expression(EP, eFuelConsumption[f in 1:NUM_FUEL, t in 1:T],
        if !isempty(MULTI_FUELS)
            eFuelConsumption_multi[f, t] + eFuelConsumption_single[f, t]
        else
            eFuelConsumption_single[f, t]
        end)

    @expression(EP, eFuelConsumptionYear[f in 1:NUM_FUEL],
        sum(omega[t] * EP[:eFuelConsumption][f, t] for t in 1:T))

    ### Constraint ###
    ### only apply constraint to generators with fuel type other than None

    @constraint(EP,
        cFuelCalculation_single[
            y in intersect(SINGLE_FUEL, setdiff(HAS_FUEL, THERM_COMMIT)),
            t = 1:T],
        EP[:vFuel][y, t] - EP[:vP][y, t] * heat_rate_mmbtu_per_mwh(gen[y])==0)

    if !isempty(MULTI_FUELS)
        @constraint(EP,
            cFuelCalculation_multi[
                y in intersect(MULTI_FUELS,
                    setdiff(HAS_FUEL, THERM_COMMIT)),
                t = 1:T],
            sum(EP[:vMulFuels][y, i, t] / heat_rates[i][y] for i in 1:max_fuels) -
            EP[:vP][y, t]==0)
    end

    if !isempty(THERM_COMMIT)
        # Only apply piecewise fuel consumption to thermal generators in THERM_COMMIT_PWFU set
        THERM_COMMIT_PWFU = inputs["THERM_COMMIT_PWFU"]
        # segemnt for piecewise fuel usage
        if !isempty(THERM_COMMIT_PWFU)
            segs = 1:inputs["PWFU_Num_Segments"]
            PWFU_data = inputs["PWFU_data"]
            slope_cols = inputs["slope_cols"]
            intercept_cols = inputs["intercept_cols"]
            segment_intercept(y, seg) = PWFU_data[y, intercept_cols[seg]]
            segment_slope(y, seg) = PWFU_data[y, slope_cols[seg]]
            # constraint for piecewise fuel consumption
            @constraint(EP,
                PiecewiseFuelUsage[y in THERM_COMMIT_PWFU, t = 1:T, seg in segs],
                EP[:vFuel][y,
                    t]>=(EP[:vP][y, t] * segment_slope(y, seg) +
                         EP[:vCOMMIT][y, t] * segment_intercept(y, seg)))
        end

        # constraint for fuel consumption at a constant heat rate 
        @constraint(EP,
            FuelCalculationCommit_single[
                y in intersect(setdiff(THERM_COMMIT,
                        THERM_COMMIT_PWFU),
                    SINGLE_FUEL),
                t = 1:T],
            EP[:vFuel][y, t] - EP[:vP][y, t] * heat_rate_mmbtu_per_mwh(gen[y])==0)
        if !isempty(MULTI_FUELS)
            @constraint(EP,
                FuelCalculationCommit_multi[
                    y in intersect(setdiff(THERM_COMMIT,
                            THERM_COMMIT_PWFU),
                        MULTI_FUELS),
                    t = 1:T],
                sum(EP[:vMulFuels][y, i, t] / heat_rates[i][y] for i in 1:max_fuels) -
                EP[:vP][y, t].==0)
        end
    end

    # constraints on start up fuel use
    @constraint(EP, cStartFuel_single[y in intersect(THERM_COMMIT, SINGLE_FUEL), t = 1:T],
        EP[:vStartFuel][y, t] -
        (cap_size(gen[y]) * EP[:vSTART][y, t] * start_fuel_mmbtu_per_mw(gen[y])).==0)
    if !isempty(MULTI_FUELS)
        @constraint(EP,
            cStartFuel_multi[y in intersect(THERM_COMMIT, MULTI_FUELS), t = 1:T],
            sum(EP[:vMulStartFuels][y, i, t] for i in 1:max_fuels) -
            (cap_size(gen[y]) * EP[:vSTART][y, t] * start_fuel_mmbtu_per_mw(gen[y])).==0)
    end

    # constraints on co-fire ratio of different fuels used by one generator
    # for example,
    # fuel2/heat rate >= min_cofire_level * total power 
    # fuel2/heat rate <= max_cofire_level * total power without retrofit
    if !isempty(MULTI_FUELS)
        for i in 1:max_fuels
            # during power generation
            # cofire constraints without the name due to the loop
            @constraint(EP, [y in intersect(MULTI_FUELS, COFIRE_MIN[i]), t = 1:T],
                EP[:vMulFuels][y,
                    i,
                    t]>=min_cofire[i][y] * EP[:ePlantFuel_generation][y, t])
            @constraint(EP, [y in intersect(MULTI_FUELS, COFIRE_MAX[i]), t = 1:T],
                EP[:vMulFuels][y,
                    i,
                    t]<=max_cofire[i][y] * EP[:ePlantFuel_generation][y, t])
            # startup
            @constraint(EP, [y in intersect(MULTI_FUELS, COFIRE_MIN_START[i]), t = 1:T],
                EP[:vMulStartFuels][y,
                    i,
                    t]>=min_cofire_start[i][y] * EP[:ePlantFuel_start][y, t])
            @constraint(EP, [y in intersect(MULTI_FUELS, COFIRE_MAX_START[i]), t = 1:T],
                EP[:vMulStartFuels][y,
                    i,
                    t]<=max_cofire_start[i][y] * EP[:ePlantFuel_start][y, t])
        end
    end

    return EP
end

function resources_with_fuel(rs::Vector{<:AbstractResource}, fuel_name::AbstractString)
    condition::BitVector = fuel.(rs) .== fuel_name
    return resource_id.(rs[condition])
end
