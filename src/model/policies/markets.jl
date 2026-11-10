@doc raw"""
    markets!(EP::AbstractModel, inputs::Dict, setup::Dict)

This module represents electricity transactions between a zone and an external wholesale market.
Market zones ``z \in \mathcal{M}`` can buy electricity from the market (imports) and sell
electricity to the market (exports) at exogenous hourly prices. Market transactions can be used
to represent, for example, unspecified imports from resources outside the modeled balancing area.

**Decision variables**

- ``\Pi^{Mkt}_{z,t} \geq 0``: electricity bought from the market (imports) in zone ``z`` at time ``t`` (`vMBUY`)
- ``\Theta^{Mkt}_{z,t} \geq 0``: electricity sold to the market (exports) in zone ``z`` at time ``t`` (`vMSELL`)
- ``\nu^{Mkt}_{z,t} \in \{0,1\}``: market direction variable (`vMACTIVE`), created only when
  `MarketDualFlow = 0`

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

**Export limit based on local generation and net imports**

To limit arbitrage against the market, exports cannot exceed the total net generation of
resources located in the zone, ``G_z`` (`eTotalGenerationByZone`), plus net imports from other
modeled zones over the transmission network, minus the zone's share of transmission losses:

```math
\begin{aligned}
    & \Theta^{Mkt}_{z,t} \leq \sum_{y \in G_z} \Theta_{y,t}
      - \sum_{l \in \mathcal{L}} \varphi^{map}_{l,z} \, \Phi_{l,t}
      - \frac{1}{2} \sum_{l \in \mathcal{L}} \lvert \varphi^{map}_{l,z} \rvert \, \beta_{l,t}(\cdot)
      & \quad \forall z \in \mathcal{M}, t \in \mathcal{T}
\end{aligned}
```

Here ``\Theta_{y,t}`` is the net output of resource ``y``. Storage, VRE-STOR, and Allam cycle
resources contribute discharge net of charging, and fusion resources contribute output net of
parasitic load. ``\Phi_{l,t}`` is the power flow on line ``l``, ``\varphi^{map}_{l,z}`` is the
line-to-zone network map (positive when flow on ``l`` leaves zone ``z``), and ``\beta_{l,t}(\cdot)``
are the losses on line ``l`` (see [`transmission!`](@ref)). The second term
(`eNet_Export_Flows`) is the net interzonal export from zone ``z``, so imports from other zones
increase the amount that can be sold to the market and exports to other zones reduce it. The third
term (`eLosses_By_Zone`) assigns half of each connected line's losses to the zone. In single-zone
cases, where there is no transmission network, these two terms are omitted.

How much this constraint restricts arbitrage depends on `MarketDualFlow`:

- With `MarketDualFlow = 0`, a zone cannot buy and sell in the same time step, so electricity
  bought from the market in a given hour cannot be resold to the market in that hour.
- With `MarketDualFlow = 1`, a zone may buy and sell in the same time step. The constraint limits
  the *volume* of sales, not their source. Because electricity bought from the market can serve
  local demand and free up local generation for sale, the zone can effectively resell market
  purchases, up to the amount set by the right-hand side above. This is only profitable when
  ``\pi^{sell}_{z,t} > \pi^{buy}_{z,t}``. Market prices are therefore expected to satisfy
  ``\pi^{sell}_{z,t} \leq \pi^{buy}_{z,t}`` in every zone and time step, in which case buying and
  selling in the same time step is never profitable and resale does not occur without the need
  for binary variables. This condition is not checked when the inputs are read.

!!! warning "Cross-zone market arbitrage"
    In multi-zone cases with more than one market zone, net imports from other zones count toward
    the sales limit. Electricity bought from the market in one zone can therefore be sent over the
    transmission network and sold to the market in another zone. This happens whenever the sell
    price in the receiving zone exceeds the buy price in the sending zone by more than the
    transmission losses, regardless of the `MarketDualFlow` setting. No check is applied to the
    input prices, so review market prices across zones if such flows are not intended.

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

    # Market exports cannot exceed local generation plus net interzonal imports, less losses
    if Z > 1
        @constraint(EP, [m in MZ, t in 1:T],
            EP[:eTotalGenerationByZone][m, t]
            - EP[:eNet_Export_Flows][m, t]
            - EP[:eLosses_By_Zone][m, t] >= vMSELL[m, t])
    else
        @constraint(EP, [m in MZ, t in 1:T],
            EP[:eTotalGenerationByZone][m, t] >= vMSELL[m, t])
    end

    ### Power Balance Update ###
    # Only market zones have vMBUY/vMSELL entries, so update their balances directly
    for m in MZ, t in 1:T
        add_to_expression!(EP[:ePowerBalance][t, m], vMBUY[m, t])
        add_to_expression!(EP[:ePowerBalance][t, m], -1.0, vMSELL[m, t])
    end

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
