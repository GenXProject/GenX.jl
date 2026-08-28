# Core

## Discharge
```@autodocs
Modules = [GenX]
Pages = ["discharge.jl"]
```

## Non-served Energy
```@autodocs
Modules = [GenX]
Pages = ["non_served_energy.jl"]
```

## Operational Reserves
```@autodocs
Modules = [GenX]
Pages = ["operational_reserves.jl"]
```

## Transmission
This section covers the three transmission modules, whose docstrings follow below:

- `transmission!` — line flows, flow limits, and losses.
- `investment_transmission!` — transmission expansion: continuous line reinforcement
  (`vNEW_TRANS_CAP`) and, when `DiscreteInvestments = 1`, discrete fixed-size new lines with binary
  build decisions (`vNEW_TRANS_LINES`). `discrete_build_symmetry!` breaks the symmetry between
  identical parallel candidate lines.
- `dcopf_transmission!` — the linearized DC power-flow constraints relating line flows to zonal
  voltage phase angles, including the build-gated formulation applied to discrete candidate lines.

See [DC-OPF and Transmission Expansion](@ref) for a user-facing discussion of the two expansion
mechanisms, how they interact with DC-OPF, and how to choose between them.

```@autodocs
Modules = [GenX]
Pages = ["transmission.jl"]
```

## Unit Commitment
```@autodocs
Modules = [GenX]
Pages = ["ucommit.jl"]
```
## CO2
```@autodocs
Modules = [GenX]
Pages = ["co2.jl"]
```

## Fuel
```@autodocs
Modules = [GenX]
Pages = ["fuel.jl"]
```
