# IEEE 9-BUS Test case (DC-OPF with Transmission Expansion)

This example demonstrates GenX's **DC optimal power flow (DC-OPF) combined with transmission
network expansion**, including *discrete (integer) line builds*. It is built on the same IEEE 9-bus
topology as example case `10_IEEE_9_bus_DC_OPF` — nine buses (zones), ten transmission corridors,
and three natural gas generators — but it is a **distinct case with different data and settings**,
described below. Do not assume the two produce the same results.

## How this case differs from case 10

Case 10 solves DC-OPF on a *fixed* network (`NetworkExpansion: 0`); it is a linear program whose only
capacity decisions are generator retirements. Case 12 turns on both network expansion and integer
investments, making it a **MILP** in which the transmission topology itself is a decision.

| Setting (`settings/genx_settings.yml`) | Case 10 | Case 12 |
|----------------------------------------|:-------:|:-------:|
| `DC_OPF`                               | 1       | 1       |
| `NetworkExpansion`                     | 0       | **1**   |
| `IntegerInvestments`                   | 0 (n/a) | **1**   |
| `WriteShadowPrices`                    | 1       | 0 (MILP)|

The **input data also differs** — this is not case 10 with a couple of flags flipped:

- **`system/Network.csv`** carries three extra columns used only by the integer-expansion path:
  `Integer_Build`, `New_Line_Cap_Size_MW`, and `BigM`. Existing line capacities are lower than in
  case 10 (mostly 100 MW, some 0), the per-line reinforcement limit is 300 MW (200 MW on line 5)
  rather than 500 MW, and the reinforcement cost is \$1,000/MW-yr rather than \$12,000/MW-yr — all
  chosen so that expansion is economic and both the continuous and discrete build paths are
  exercised.
- **`resources/Thermal.csv`** gives all three generators 350 MW of existing (retirement-only)
  capacity, versus 250/300/270 MW in case 10.
- **`system/Demand_data.csv`** uses higher zonal loads than case 10 (e.g. peak z9 = 150 MW vs
  125 MW), so the existing network cannot serve demand without reinforcement.

## Network expansion setup

The ten corridors split into two expansion modes:

- **Continuous reinforcement** — the six corridors with `Integer_Build = 0` (lines 1, 3, 5, 6, 9,
  10). Each may add any amount of capacity from 0 up to its `Line_Max_Reinforcement_MW` limit
  (300 MW, or 200 MW on line 5) through the standard `NetworkExpansion` variable.
- **Discrete / integer builds** — the **four** corridors flagged `Integer_Build = 1`: line 2
  (`BUS4_to_BUS5`), line 4 (`BUS3_to_BUS6`), line 7 (`BUS8_to_BUS2`), and line 8 (`BUS8_to_BUS9`).
  Each has `New_Line_Cap_Size_MW = 100`, so at load time GenX expands the corridor into up to
  `floor(300 / 100) = 3` parallel 100 MW candidate lines, each governed by a **binary** build
  variable (`vNEW_TRANS_LINES`). That is up to **12 discrete candidate lines** in total. Their
  flow–angle coupling is enforced with the big-M formulation (`Bilinear_DC_OPF` is left at its
  default of 0); the `BigM` column supplies the per-line relaxation constant.

### Starting line capacities

Not every corridor starts empty. Three corridors have `Line_Max_Flow_MW = 0` and therefore *must*
be built for power to flow across them: line 4 (`BUS3_to_BUS6`), line 5 (`BUS6_to_BUS7`), and line 9
(`BUS9_to_BUS4`). The remaining seven start at 100 MW. Note the distinction among the integer-build
corridors: only line 4 is greenfield (0 MW existing, a "phantom" residual line until a discrete line
is built); lines 2, 7, and 8 already carry 100 MW and expand discretely on top of that.

## Expected results

With the shipped data the model builds a mix of both expansion types (see
`results/network_expansion.csv`):

- **Discrete builds:** corridor 4 builds all three candidate lines (300 MW) and corridor 7 builds
  one (100 MW); corridors 2 and 8 build none.
- **Continuous reinforcement:** corridors 1, 3, 5, and 9 add roughly 154, 20, 186, and 173 MW.
- No new generation is built (generators are retirement-only); total network expansion cost is about
  \$934,000 of a \$2.32M total system cost.

These values confirm the integer-build path is genuinely exercised — at least one discrete line is
constructed — rather than the problem collapsing to pure continuous expansion.

## Running the case

To run the model, first navigate to the example directory:

- Using a Julia REPL:

```julia
julia> cd("example_systems/12_IEEE_9_bus_DC_OPF_expansion/")
```

- Using a terminal or command prompt:
```bash
$ cd example_systems/12_IEEE_9_bus_DC_OPF_expansion/
```

Next, ensure that your settings in `settings/genx_settings.yml` are correct (the default settings use
the solver `HiGHS`, which handles this MILP).

Once the settings are confirmed, run the model with the `Run.jl` script in the example directory:

- Using a Julia REPL (recommended)
```julia
julia> include("Run.jl")
```
- Using a terminal or command prompt:
```bash
$ julia Run.jl
```

Once the model has completed, results will write to the `results` directory.
