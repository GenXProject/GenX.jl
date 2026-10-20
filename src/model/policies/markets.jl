@doc raw"""
    markets!(EP::AbstractModel, inputs::Dict, setup::Dict)

This module represents electricity transactions between a zone and an external wholesale market.
Market zones ``z \in \mathcal{M}`` can buy electricity from the market (imports) and sell
electricity to the market (exports) at exogenous hourly prices. Market transactions can be used
to represent, for example, unspecified imports from resources outside the modeled balancing area.

**Decision variables**

- ``\Pi^{Mkt}_{z,t} \geq 0``: electricity bought from the market (imports) in zone ``z`` at time ``t`` (`vMBUY`)
- ``\Theta^{Mkt}_{z,t} \geq 0``: electricity sold to the market (exports) in zone ``z`` at time ``t`` (`vMSELL`)
- ``\nu^{Mkt}_{z,t}``: market direction variable (`vMACTIVE`), binary when mutual exclusivity is enforced

**Transaction limits**

Imports and exports are bounded by zonal transaction limits ``\overline{\Pi}^{Mkt}_{z}`` and
``\overline{\Theta}^{Mkt}_{z}`` (from `Zones_markets.csv`). When `MarketDualFlow = 1`, imports and
exports may occur simultaneously:

```math
\begin{aligned}
    & 0 \leq \Pi^{Mkt}_{z,t} \leq \overline{\Pi}^{Mkt}_{z} & \quad \forall z \in \mathcal{M}, t \in \mathcal{T} \\
    & 0 \leq \Theta^{Mkt}_{z,t} \leq \overline{\Theta}^{Mkt}_{z} & \quad \forall z \in \mathcal{M}, t \in \mathcal{T}
\end{aligned}
```

When `MarketDualFlow = 0`, a binary variable ``\nu^{Mkt}_{z,t} \in \{0,1\}`` enforces that a zone
either imports or exports in each time step, but not both:

```math
\begin{aligned}
    & \Pi^{Mkt}_{z,t} \leq \overline{\Pi}^{Mkt}_{z} \, \nu^{Mkt}_{z,t} & \quad \forall z \in \mathcal{M}, t \in \mathcal{T} \\
    & \Theta^{Mkt}_{z,t} \leq \overline{\Theta}^{Mkt}_{z} \, (1 - \nu^{Mkt}_{z,t}) & \quad \forall z \in \mathcal{M}, t \in \mathcal{T}
\end{aligned}
```

Note that this option makes the model a mixed-integer program.

**Export limit based on local generation**

To prevent unrealistic arbitrage, such as reselling electricity bought from the market, exports
cannot exceed the total net generation of resources located in the zone, ``G_z``
(`eTotalGenerationByZone`):

```math
\begin{aligned}
    & \Theta^{Mkt}_{z,t} \leq \sum_{y \in G_z} \Theta_{y,t} & \quad \forall z \in \mathcal{M}, t \in \mathcal{T}
\end{aligned}
```

Here ``\Theta_{y,t}`` is the net output of resource ``y``. Storage, VRE-STOR, and Allam cycle
resources contribute discharge net of charging, and fusion resources contribute output net of
parasitic load. 

**Power balance**

Imports are added to the zonal power balance as a source of electricity, and exports as an
additional use:

```math
\begin{aligned}
    & \text{ePowerBalance}_{z,t} \mathrel{+}= \Pi^{Mkt}_{z,t} - \Theta^{Mkt}_{z,t} & \quad \forall z \in \mathcal{M}, t \in \mathcal{T}
\end{aligned}
```

**CO``_2`` emissions**

Emissions from imported electricity are assigned to the importing zone, using an hourly emission
rate ``\epsilon^{Mkt,CO_2}_{z,t}`` in tCO``_2``/MWh (from `Market_emissions.csv`):

```math
\begin{aligned}
    & E^{Mkt,CO_2}_{z,t} = \epsilon^{Mkt,CO_2}_{z,t} \, \Pi^{Mkt}_{z,t} & \quad \forall z \in \mathcal{M}, t \in \mathcal{T}
\end{aligned}
```

These emissions are added to `eTotalEmissionsByZone` and count toward any CO``_2`` cap, so imported
electricity is subject to the same emissions accounting as in-zone generation. Exports are not
credited, because their emissions are already counted at the generating resources.

**Objective function**

The cost of imports and the revenue from exports, at hourly buy prices ``\pi^{buy}_{z,t}`` and sell
prices ``\pi^{sell}_{z,t}`` (from `Market_price.csv`), are added to the objective function,
weighted by the time-step weights ``\omega_t``:

```math
\begin{aligned}
    & \sum_{z \in \mathcal{M}} \sum_{t \in \mathcal{T}} \omega_t \left( \pi^{buy}_{z,t} \, \Pi^{Mkt}_{z,t} - \pi^{sell}_{z,t} \, \Theta^{Mkt}_{z,t} \right)
\end{aligned}
```
"""

function markets!(EP::AbstractModel, inputs::Dict, setup::Dict)
    T   = inputs["T"]      # Number of time steps
    Z   = inputs["Z"]      # Total zones
    MZ  = inputs["MZ"]     # Market zones
    w   = inputs["omega"]  # Time weights (if any)

    ### Decision Variables ###
    @variable(EP, vMBUY[m in MZ, t=1:T] >= 0)   # Energy imported
    @variable(EP, vMSELL[m in MZ, t=1:T] >= 0)  # Energy exported

    # Market direction / exclusivity
    if setup["MarketDualFlow"] == 1
        # Relaxed: allow simultaneous buy & sell
        @variable(EP, 0 <= vMACTIVE[m in MZ, t=1:T] <= 1)
        @constraint(EP, [m in MZ, t in 1:T], vMBUY[m,t] <= inputs["Mrkt_Max_Buy"][m])
        @constraint(EP, [m in MZ, t in 1:T], vMSELL[m,t] <= inputs["Mrkt_Max_Sell"][m])
    else
        # Enforce mutual exclusivity with binary
        @variable(EP, vMACTIVE[m in MZ, t=1:T], Bin)
        @constraint(EP, [m in MZ, t in 1:T],
            vMBUY[m,t] <= inputs["Mrkt_Max_Buy"][m] * vMACTIVE[m,t])
        @constraint(EP, [m in MZ, t in 1:T],
            vMSELL[m,t] <= inputs["Mrkt_Max_Sell"][m] * (1 - vMACTIVE[m,t]))
    end

    # Market exports cannot exceed local generation
    @constraint(EP, [m in MZ, t in 1:T], EP[:eTotalGenerationByZone][m,t] >= vMSELL[m,t])

    ### Power Balance Update ###
    @expression(EP, eZonalNetMarkets[t=1:T, z=1:Z],
        z in MZ ? vMBUY[z,t] - vMSELL[z,t] : EP[:vZERO])
    add_similar_to_expression!(EP[:ePowerBalance], eZonalNetMarkets)

    ### Market CO₂ Emissions ###
    for m in MZ, t in 1:T
        add_term_to_expression!(EP[:eTotalEmissionsByZone][m,t],
            inputs["Market_CO2_tons_MWh"][m,t] * vMBUY[m,t])
    end

    ### Market Costs (Objective) ###
    MarketBuy  = inputs["Market_BuyPrices"]
    MarketSell = inputs["Market_SellPrices"]

     @expression(EP, eCMarketBuy[m in MZ],
        sum(MarketBuy[m,t]  * vMBUY[m,t]  * w[t] for t in 1:T))
        
    @expression(EP, eCMarketSell[m in MZ],
        -1*sum(MarketSell[m,t] * vMSELL[m,t] * w[t] for t in 1:T))

    @expression(EP, eTotalCMarketBuy, sum(eCMarketBuy[m] for m in MZ)) 
    @expression(EP, eTotalCMarketSell, sum(eCMarketSell[m] for m in MZ))

    add_to_expression!(EP[:eObj], eTotalCMarketBuy)
    add_to_expression!(EP[:eObj], eTotalCMarketSell)
end
