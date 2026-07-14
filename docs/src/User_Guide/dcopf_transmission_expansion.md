# DC-OPF and Transmission Expansion

GenX can represent the transmission network in two ways, and can expand it in two ways (note that if the problem has no transmission network, then it is run as a "copper plate"). This page
explains both, how they interact, and the modeling traps to avoid when they are combined.

## 1. Transport Model vs. DC-OPF

By default (`DC_OPF: 0`) GenX uses a **transport ("pipe-flow") model**: each line carries a flow
$\Phi_{l,t}$ limited only by the line's available capacity,

```math
-\varphi^{cap}_{l} \leq \Phi_{l,t} \leq \varphi^{cap}_{l} \qquad \forall l \in \mathcal{L},\ \forall t \in \mathcal{T}
```

subject to the zonal power balance. Power flow between zones is only constrained by capacity limits and not by any other dynamics.

Setting `DC_OPF: 1` adds the linearized DC power-flow physics. A voltage phase angle
$\theta_{z,t}$ is introduced for each zone, flow on a line is pinned to the angle difference across
it, and the angle difference is itself bounded:

```math
\begin{aligned}
    & \Phi_{l,t} = \mathcal{B}_{l} \times \Big(\sum_{z \in \mathcal{Z}} \varphi^{map}_{l,z}\,\theta_{z,t}\Big) && \forall l \in \mathcal{L},\ \forall t \in \mathcal{T} \\
    & -\Delta\theta^{\max}_{l} \leq \sum_{z \in \mathcal{Z}} \varphi^{map}_{l,z}\,\theta_{z,t} \leq \Delta\theta^{\max}_{l} && \forall l \in \mathcal{L},\ \forall t \in \mathcal{T} \\
    & \theta_{1,t} = 0 && \forall t \in \mathcal{T}
\end{aligned}
```

where $\varphi^{map}_{l,z} \in \{-1, 0, 1\}$ is the network incidence matrix and zone 1 is the slack
(reference) bus. The line susceptance is computed from the input data as
$\mathcal{B}_{l} = \mathrm{kV}_l^2 / X_l$, with $X_l$ the line reactance in Ohms.

Because DC-OPF constrains *how* power flows rather than just how much, a DC-OPF solution is always at
least as expensive as the transport solution on the same system. That relationship is exploited by
the Benders transport hot-start described in [Section 5](#5-benders-decomposition-with-dc-opf-and-expansion).

### Required `Network.csv` Columns when `DC_OPF: 1`

| Column | Description |
|:--|:--|
| `Line_Voltage_kV` | Line voltage in kV. |
| `Line_Reactance_Ohms` | Line reactance in Ohms. Susceptance is derived as $\mathrm{kV}^2/X$. |
| `Angle_Limit_Rad` | Maximum angle difference $\Delta\theta^{\max}_{l}$ across the line, in radians. |

## 2. Two Kinds of Expansion

`NetworkExpansion: 1` turns on transmission expansion. GenX supports two mutually
mechanisms, chosen and mutually exclusive **per line** via the `Discrete_Build` column of `Network.csv`.

### Continuous Reinforcement (`Discrete_Build = 0`)

The classic GenX behavior. Each eligible line gets a continuous variable
$\bigtriangleup\varphi^{cap}_{l} \in [0, \overline{\bigtriangleup\varphi^{cap}_{l}}]$ (`vNEW_TRANS_CAP`)
that adds MW to the existing capacity of that line:

```math
\varphi^{cap}_{l} = \overline{\varphi^{cap}_{l}} + \bigtriangleup\varphi^{cap}_{l}, \qquad \bigtriangleup\varphi^{cap}_{l} \leq \overline{\bigtriangleup\varphi^{cap}_{l}}
```

This represents *reinforcing an existing corridor* — restringing, reconductoring, upgrading terminal
equipment — and is a linear decision. The set of eligible lines is those with `Line_Max_Reinforcement_MW >= 0`.

### Discrete New Lines (`Discrete_Build = 1`)

Set `DiscreteInvestments: 1` in `genx_settings.yml` and mark a corridor with `Discrete_Build = 1`.
GenX then represents expansion on that corridor as one or more **fixed-size new lines**, each with a
binary build decision $x_l \in \{0,1\}$ (`vNEW_TRANS_LINES`) and each contributing
`New_Line_Cap_Size_MW` of capacity when built:

```math
\varphi^{cap}_{l} = \overline{\varphi^{cap}_{l}} + x_{l} \times \overline{F}_{l}
```

This represents *building physical new circuits*, where you either build a new line or you do not. A new circuit changes the corridor's electrical properties discretely rather than continuously.

**How the corridor is expanded at load time.** Internally when GenX calls `load_network_data!`, a corridor flagged
`Discrete_Build = 1` is rewritten into several rows before the model is built, such that each discrete new addition is added to the internal data as a new line. The number of new lines is the floor of the maximum reinforcement value divied by the new line capacity size:

```
n_new = floor(Line_Max_Reinforcement_MW / New_Line_Cap_Size_MW)
```

new-line rows are emitted, each a full copy of the corridor (same `Start_Zone`/`End_Zone`, same
reactance, same angle limit, same cost) but with `Line_Max_Flow_MW = 0` and
`Line_Max_Reinforcement_MW = New_Line_Cap_Size_MW`. The original row is kept as the *residual
existing line*: it keeps its `Line_Max_Flow_MW`, has `Discrete_Build` reset to `0`, and has
`Line_Max_Reinforcement_MW` set to `-1` so it is excluded from `EXPANSION_LINES` and receives no
continuous reinforcement variable.

The consequence is worth stating plainly: **`Line_Max_Reinforcement_MW` on a discrete corridor is
consumed entirely by the discrete lines.** A corridor cannot be both continuously reinforced and
discretely expanded. If `Line_Max_Reinforcement_MW` is not an integer multiple of
`New_Line_Cap_Size_MW`, GenX warns and rounds down.

Because each discrete new line becomes its own row, it gets its own `vFLOW`, its own row in
`pNet_Map`, and its own row in the transmission outputs. `inputs["LINE_MAP_ORIGINAL"]` maps expanded
line indices back to the original CSV corridor, and the output writers use it to fold results back to
user-facing corridors.

**Symmetry breaking.** Parallel candidate lines on the same corridor are identical, so any subset of
size $k$ is an equivalent solution — a degeneracy that badly slows down branch-and-bound. GenX
imposes a build order on each group of more than one identical candidate line
(`DISCRETE_BUILD_LINE_GROUPS`):

```math
x_{g_{i-1}} \geq x_{g_{i}} \qquad \forall i \geq 2
```

### Required `Network.csv` columns when `DiscreteInvestments: 1`

| Column | Description |
|:--|:--|
| `Discrete_Build` | `0`/`1`. `1` = this corridor hosts discrete fixed-size new lines. |
| `New_Line_Cap_Size_MW` | MW capacity of each discrete new line. Required (errors if missing). |
| `BigM` | Big-M for the flow–angle coupling on candidate lines. Only used when `DC_OPF: 1` and `Bilinear_DC_OPF: 0`. Defaults to `10 × New_Line_Cap_Size_MW` if absent. |

`DiscreteInvestments: 1` also enables integer capacity builds for *resources*, via a `Discrete_Build`
column in the resource CSVs (e.g. `Thermal.csv`). GenX warns for each input file that is missing the
column when the setting is on.

## 3. Combining DC-OPF with discrete builds

This is where the two features interact, and it is the reason discrete builds exist.

Under DC-OPF, an unbuilt candidate line must not impose any physics. GenX partitions the lines into
three disjoint sets and treats each differently:

| Set | What it is | Flow–angle coupling | Angle limit |
|:--|:--|:--|:--|
| `FIXED_LINES` | Physically present lines | Exact, always on | Always on |
| `DISCRETE_BUILD_LINES` | Candidate lines with binary $x_l$ | Build-gated | Build-gated |
| `PHANTOM_LINES` | Zero-capacity residual row of a greenfield discrete corridor | None | None |

For a candidate line, the angle-difference limit is relaxed by a big-M when the line is not built,
so it only binds once something is actually built on the corridor:

```math
-\Delta\theta^{\max}_{l} - M^{\theta}(1 - x_{l}) \leq \sum_{z \in \mathcal{Z}} \varphi^{map}_{l,z}\,\theta_{z,t} \leq \Delta\theta^{\max}_{l} + M^{\theta}(1 - x_{l})
```

The flow–angle coupling itself has two formulations, selected with `Bilinear_DC_OPF`:

**`Bilinear_DC_OPF: 0` (default) — big-M relaxation.** The coupling is relaxed by $M_l$ (the `BigM`
column) when the line is unbuilt, and the flow is separately forced to zero:

```math
\begin{aligned}
    & -M_{l}(1 - x_{l}) \leq \Phi_{l,t} - \mathcal{B}_{l}\Big(\sum_{z \in \mathcal{Z}} \varphi^{map}_{l,z}\,\theta_{z,t}\Big) \leq M_{l}(1 - x_{l}) \\
    & -x_{l}\overline{F}_{l} \leq \Phi_{l,t} \leq x_{l}\overline{F}_{l}
\end{aligned}
```

The model stays a MILP. The price is the big-M: too small and it wrongly constrains a built line, too
large and it weakens the LP relaxation and slows the solve.

**`Bilinear_DC_OPF: 1` — exact bilinear coupling.** The coupling is written as the literal product of
the build variable and the angle difference:

```math
\Phi_{l,t} = \mathcal{B}_{l} \Big(\sum_{z \in \mathcal{Z}} \varphi^{map}_{l,z}\,\theta_{z,t}\Big) \times x_{l}
```

This is exact and needs no big-M, but the model becomes mixed-integer **nonlinear**, and requires a
solver that handles bilinear terms (e.g. Gurobi). Setting `Bilinear_DC_OPF: 1` with `DC_OPF: 0` is
contradictory; GenX warns and forces `DC_OPF: 1`.

## 4. Warnings and recommended usage

!!! warning "Greenfield corridors under DC-OPF should be discrete builds"
    If a corridor has **no existing line** (`Line_Max_Flow_MW = 0`) and you expand it with
    **continuous** reinforcement under `DC_OPF: 1`, the corridor's angle-difference limit
    is enforced *for all hours regardless of whether any capacity is built*. Continuous
    expansion lines are `FIXED_LINES`: their flow–angle coupling and their
    $\pm\Delta\theta^{\max}_{l}$ angle limit are always on. So a line that does not exist still
    constrains the phase angles of the two zones it would have connected — an entirely fictitious
    constraint that can distort flows across the rest of the network and, in a meshed system, make
    the model infeasible or silently more expensive.

    **Recommendation:** any new corridor built from zero under DC-OPF should use
    `Discrete_Build = 1`. Discrete candidate lines have build-gated angle limits, so an unbuilt
    corridor imposes nothing. This is also why `PHANTOM_LINES` exists: the zero-capacity residual row
    of a greenfield discrete corridor is deliberately excluded from both the coupling and the angle
    limit, so it cannot pin the corridor's angle difference and choke a newly-built parallel line down
    to zero flow.

    Continuous reinforcement remains perfectly appropriate under DC-OPF for corridors that
    **already have an existing line** — the physics are real in that case, and the angle limit should
    be on.

!!! warning "Discrete builds do not change the corridor's susceptance"
    Building a parallel circuit on a real corridor halves its effective reactance. GenX does **not**
    model this: each discrete line carries its own flow with its own (unchanged) susceptance, and the
    corridor's aggregate behavior is the sum of the parallel lines' flows. This is the standard
    linear-DC approximation used in transmission expansion planning, but it means the model does not
    capture the reactance change from adding circuits to an existing corridor.

!!! warning "Choose `BigM` carefully"
    With `Bilinear_DC_OPF: 0`, `BigM` must be large enough to be non-binding when the line *is* built
    ($M_l$ must exceed the largest possible value of $|\Phi_{l,t} - \mathcal{B}_l \Delta\theta_l|$)
    and as small as possible otherwise. The default (`10 × New_Line_Cap_Size_MW`) is a heuristic, not
    a guarantee. A `BigM` that is too small silently cuts off valid solutions; one that is too large
    makes the MILP slow. If a discrete corridor is never built despite looking economic, suspect
    `BigM` first.

!!! note "`DiscreteInvestments` makes the model a MILP"
    Binary line builds (and integer resource builds) turn what may have been an LP into a MILP.
    Expect substantially longer solve times, and set a sensible `MIPGap` in your solver settings.

## 5. Benders decomposition with DC-OPF and expansion

Under Benders, the line-build decisions ($x_l$, $\bigtriangleup\varphi^{cap}_{l}$) live in the
planning problem while the DC-OPF angle constraints live in the operational subproblems. This is a
hard combination: the subproblems are infeasible for many early planning solutions (an unbuilt
network cannot serve demand), and the master is a MILP.

GenX provides four settings in `benders_settings.yml` to make it tractable. They are described in
detail on the [Benders Decomposition](@ref) page; in summary:

| Setting | Effect |
|:--|:--|
| `RunTransportModel` | Solve the transport relaxation first and reuse its cuts. |
| `LPTransportHotstart` | LP-relax the planning problem's integer variables for the transport pass. |
| `LPDCOPFHotstart` | LP-relax the planning problem's integer variables for the DC-OPF pass. |
| `RegularizationPostHotstart` | Keep level-set regularization on after the hot-start passes. |

The key idea is that the **transport model is a relaxation of DC-OPF on the same system**. Cuts
generated against transport subproblems are therefore valid underestimators of the DC-OPF recourse
cost, so GenX can solve the (much easier) transport problem first, keep the accumulated cuts as a
warm start, then switch the subproblems to DC-OPF and continue. Each pass is additionally hot-started
by first solving its LP relaxation to convergence before restoring integrality.

A complete worked example is `example_systems/12_IEEE_9_bus_DC_OPF_expansion`.
