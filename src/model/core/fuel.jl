
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
are optional inputs to "Generators_data.csv".
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
"""

function fuel!(EP::Model, inputs::Dict, setup::Dict)
    println("Fuel Module")
    res =  inputs["RESOURCES"]

    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones
    G = inputs["G"]     
    HAS_FUEL = inputs["HAS_FUEL"]
    THERM_COMMIT = inputs["THERM_COMMIT"]
    fuels = inputs["fuels"]
    NUM_FUEL = length(fuels)

    # create variable for fuel consumption for output
    @variable(EP, vFuel[y in 1:G, t = 1:T] >= 0)
    
    ### Expressions ####
    # Fuel consumed on start-up (MMBTU or kMMBTU (scaled)) 
    # if unit commitment is modelled
    @expression(EP, eStartFuel[y in 1:G, t = 1:T],
        if y in THERM_COMMIT
            (cap_size(res[y]) * EP[:vSTART][y, t] * 
                start_fuel_mmbtu_per_mw(res[y]))
        else
            0
        end)

    # fuel_cost is in $/MMBTU (M$/billion BTU if scaled)
    # vFuel and eStartFuel is MMBTU (or billion BTU if scaled)
    # eCFuel_start or eCFuel_out is $ or Million$
    # Start up fuel cost
    @expression(EP, eCFuelStart[y = 1:G, t = 1:T], 
        (inputs["fuel_costs"][fuel(res[y])][t] * EP[:eStartFuel][y, t]))
    # plant level start-up fuel cost for output
    @expression(EP, ePlantCFuelStart[y = 1:G], 
        sum(inputs["omega"][t] * EP[:eCFuelStart][y, t] for t in 1:T))
    # zonal level total fuel cost for output
    @expression(EP, eZonalCFuelStart[z = 1:Z], 
        sum(EP[:ePlantCFuelStart][y] for y in resources_in_zone_by_rid(res,z)))

    # Fuel cost for power generation
    @expression(EP, eCFuelOut[y = 1:G, t = 1:T], 
        (inputs["fuel_costs"][fuel(res[y])][t] * EP[:vFuel][y, t]))
    # plant level start-up fuel cost for output
    @expression(EP, ePlantCFuelOut[y = 1:G], 
        sum(inputs["omega"][t] * EP[:eCFuelOut][y, t] for t in 1:T))
    # zonal level total fuel cost for output
    @expression(EP, eZonalCFuelOut[z = 1:Z], 
        sum(EP[:ePlantCFuelOut][y] for y in resources_in_zone_by_rid(res,z)))


    # system level total fuel cost for output
    @expression(EP, eTotalCFuelOut, sum(eZonalCFuelOut[z] for z in 1:Z))
    @expression(EP, eTotalCFuelStart, sum(eZonalCFuelStart[z] for z in 1:Z))


    add_to_expression!(EP[:eObj], EP[:eTotalCFuelOut] + EP[:eTotalCFuelStart])

    #fuel consumption (MMBTU or Billion BTU)
    @expression(EP, eFuelConsumption[f in 1:NUM_FUEL, t in 1:T],
        sum(EP[:vFuel][y, t] + EP[:eStartFuel][y,t]
            for y in resources_with_fuel(res, fuels[f])))
                
    @expression(EP, eFuelConsumptionYear[f in 1:NUM_FUEL],
        sum(inputs["omega"][t] * EP[:eFuelConsumption][f, t] for t in 1:T))

    
    ### Constraint ###
    ### only apply constraint to generators with fuel type other than None
    @constraint(EP, FuelCalculation[y in setdiff(HAS_FUEL, THERM_COMMIT), t = 1:T],
        EP[:vFuel][y, t] - EP[:vP][y, t] * heat_rate_mmbtu_per_mwh(res[y]) == 0)

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
            @constraint(EP, PiecewiseFuelUsage[y in THERM_COMMIT_PWFU, t = 1:T, seg in segs],
            EP[:vFuel][y, t] >= (EP[:vP][y, t] *  segment_slope(y, seg) + 
            EP[:vCOMMIT][y, t] * segment_intercept(y, seg)))
        end
        # constraint for fuel consumption at a constant heat rate 
        @constraint(EP, FuelCalculationCommit[y in setdiff(THERM_COMMIT,THERM_COMMIT_PWFU), t = 1:T],
            EP[:vFuel][y, t] - EP[:vP][y, t] * heat_rate_mmbtu_per_mwh(res[y]) == 0)
    end

    return EP
end


function resources_with_fuel(df::DataFrame, fuel::AbstractString)
    return df[df[!, :Fuel] .== fuel, :R_ID]
end

function resources_with_fuel(rs::Vector{AbstractResource}, fuel_name::AbstractString)
    condition::BitVector = fuel.(rs) .== fuel_name
    return resource_id.(rs[condition])
end

