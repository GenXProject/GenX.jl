# DC-OPF and Transmission Expansion

GenX can represent the transmission network in two ways, and can expand it in two ways (note that if the problem has no transmission network, then it is run as a "copper plate"). This page
explains both, how they interact, and the modeling traps to avoid when they are combined. Note that the user must set `NetworkExpansion = 1` to enable these expansion capabilities. In addition, we refer to any expansion or new build as "network expansion" in the documentation.

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
the Benders transport hot-start described in [Section 6](#6-benders-decomposition-with-dc-opf-and-expansion).

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
If there is existing capacity defined in the network CSV, this is treated as its own line which cannot have continuous expansion. Lines marked with `Discrete_Build = 1` are not able to expand continuously. A corridor cannot be both continuously reinforced and
discretely expanded. If `Line_Max_Reinforcement_MW` is not an integer multiple of
`New_Line_Cap_Size_MW`, GenX warns and rounds down.

**Symmetry breaking for discrete new lines.** Parallel candidate lines on the same corridor (i.e., generated from the same line of the `Network.csv`) are identical, so any subset of
size $k$ is an equivalent solution — a degeneracy that could slow down branch-and-bound. GenX
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


## 4. The five corridor scenarios in `Network.csv`

Every corridor you can express falls into one of five cases. The cases are determined by
three columns — `Line_Max_Flow_MW` (does a line exist today?), `Line_Max_Reinforcement_MW` (may it
grow, and by how much?), and `Discrete_Build` (does it grow continuously or in whole circuits?).
Assume `NetworkExpansion: 1` throughout, and `DiscreteInvestments: 1` for the discrete cases.

| # | Scenario | `Line_Max_Flow_MW` | `Line_Max_Reinforcement_MW` | `Discrete_Build` | `New_Line_Cap_Size_MW` |
|:--|:--|:--|:--|:--|:--|
| 1 | Existing line, no expansion | `100` | `-1` | `0` | — |
| 2 | Existing line, continuous expansion | `100` | `300` | `0` | — |
| 3 | Existing line, discrete expansion | `100` | `300` | `1` | `100` |
| 4 | New corridor, continuous expansion ⚠️ | `0` | `300` | `0` | — |
| 5 | New corridor, discrete expansion | `0` | `300` | `1` | `100` |

The key to reading this table is that **eligibility for continuous expansion is
`Line_Max_Reinforcement_MW >= 0`**. Any negative value (`-1` by convention) prevents any expansion.

### 1. Existing line, no expansion

`Line_Max_Flow_MW = 100`, `Line_Max_Reinforcement_MW = -1`.

The line is fixed at 100 MW and no investment variable is created

(Setting `Line_Max_Reinforcement_MW = 0` instead gives the same physical result, but still creates a
`vNEW_TRANS_CAP` variable with an upper bound of zero. Use `-1` to keep it out of the model.)

### 2. Existing line, continuous expansion

`Line_Max_Flow_MW = 100`, `Line_Max_Reinforcement_MW = 300`, `Discrete_Build = 0`.

The line gets a continuous variable $\bigtriangleup\varphi^{cap}_{l} \in [0, 300]$, so its capacity
is $100 + \bigtriangleup\varphi^{cap}_{l} \in [100, 400]$ MW. If `DC_OPF = 1`, the
angle limit constraint is always active. When `DC_OPF = 1`, this can be thought of as reconductoring an existing corridor.

### 3. Existing line, discrete expansion

`Line_Max_Flow_MW = 100`, `Line_Max_Reinforcement_MW = 300`, `Discrete_Build = 1`,
`New_Line_Cap_Size_MW = 100`.

Internally, GenX rewrites this row into four separate lines:

| Internal row | Capacity | Role |
|:--|:--|:--|
| residual existing | 100 MW fixed | `FIXED_LINE` — real line, angle limit always on |
| candidate 1 | 0 or 100 MW | `DISCRETE_BUILD_LINE`, binary $x_1$ |
| candidate 2 | 0 or 100 MW | `DISCRETE_BUILD_LINE`, binary $x_2$ |
| candidate 3 | 0 or 100 MW | `DISCRETE_BUILD_LINE`, binary $x_3$ |

$\lfloor 300 / 100 \rfloor = 3$ candidate lines are created. Total corridor capacity is therefore
$100 + 100\sum_i x_i$, i.e. one of {100, 200, 300, 400} MW — the same range as scenario 2, but
reachable only in whole 100 MW circuits, where each new line has identical data to the existing line (e.g., susceptance, costs). The residual existing row has its
`Line_Max_Reinforcement_MW` internally set to `-1`, so it receives **no** continuous reinforcement:
the 300 MW budget is spent entirely on the discrete candidates. Symmetry breaking forces
$x_1 \geq x_2 \geq x_3$.

### 4. New corridor, continuous expansion ⚠️

`Line_Max_Flow_MW = 0`, `Line_Max_Reinforcement_MW = 300`, `Discrete_Build = 0`.

Capacity is $0 + \bigtriangleup\varphi^{cap}_{l} \in [0, 300]$ MW. Under the **transport model this is
perfectly fine** and is the normal way to offer a greenfield corridor.

Under **DC-OPF it can overconstrain line angle limits** because ts coupling and angle limit are on in
every hour regardless of what is built. If the optimizer builds nothing, then
$|\Phi_{l,t}| \leq \varphi^{cap}_{l} = 0$ forces $\Phi_{l,t} = 0$, and the coupling
$\Phi_{l,t} = \mathcal{B}_l \Delta\theta_{l,t}$ then forces $\Delta\theta_{l,t} = 0$: the two zones
are pinned to *identical phase angles*, as though joined by a zero-impedance tie that carries no
power. That is a fictitious constraint on the rest of the meshed network, and it can distort flows
throughout the model. It is recommended to use discrete new line corridors in this case instead.

### 5. New corridor, discrete expansion

`Line_Max_Flow_MW = 0`, `Line_Max_Reinforcement_MW = 300`, `Discrete_Build = 1`,
`New_Line_Cap_Size_MW = 100`.

When `DC_OPF = `, this avoids the challenge of unintentionally enforced angle limits:

| Internal row | Capacity | Role |
|:--|:--|:--|
| residual existing | 0 MW | `PHANTOM_LINE` — **no** coupling, **no** angle limit |
| candidate 1–3 | 0 or 100 MW each | `DISCRETE_BUILD_LINE`, binary $x_i$ |

Because the residual row has zero capacity, is not expandable, and is not itself a candidate, GenX
classifies it as a *phantom* line and exempts it from both the flow–angle coupling and the angle
limit. That is precisely what prevents the scenario-4 failure: nothing pins $\Delta\theta$ while the
corridor is unbuilt. The candidate lines carry build-gated coupling and angle limits, so the corridor
imposes DC-OPF physics exactly when — and only when — at least one circuit is actually built.

## 5. Warnings and recommended usage

!!! warning "Greenfield corridors under DC-OPF should be discrete builds"
    This is scenario 4 vs. scenario 5 above.

    If a corridor has **no existing line** (`Line_Max_Flow_MW = 0`) and you expand it with
    **continuous** reinforcement under `DC_OPF: 1`, the corridor's angle-difference limit
    is enforced *for all hours regardless of whether any capacity is built*. Their flow–angle coupling and their
    $\pm\Delta\theta^{\max}_{l}$ angle limit are always on. So a line that does not exist still
    constrains the phase angles of the two zones it would have connected.

    Continuous reinforcement can still be applied under DC-OPF for corridors that already have an existing line.

!!! warning "Choose `BigM` carefully"
    With `Bilinear_DC_OPF: 0`, `BigM` must be large enough that it does not create an unintended constraint if a line is not built since $\mathcal{B}_l \Delta\theta_l$ is constrained by $M_l$ in this case. However, its size can impact numerical performance of both the monolithic and Benders solves. The default (`10 × New_Line_Cap_Size_MW`) is a heuristic, not a guarantee. A `BigM` that is too small can silently cut off valid solutions; one that is too large
    can make the MILP slow.

!!! note "`DiscreteInvestments` makes the model a MILP"
    Binary line builds (and integer resource builds) result in a MILP instead of an LP and can increase solution time. Consider using Benders decomposition if the model struggles with tractability, and/or set a consider what `MIPGap` your problem requires.

## 6. Benders decomposition with DC-OPF and expansion

Under Benders, the line-build decisions ($x_l$, $\bigtriangleup\varphi^{cap}_{l}$) live in the
planning problem while the DC-OPF angle constraints live in the operational subproblems. The subproblems can be infeasible for many early planning solutions (an unbuilt network cannot serve demand), and the discrete nature of the problem can result in long solves times and weak cuts.

GenX provides four settings in `benders_settings.yml` to assist with tractability. They are described in
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
by first solving its LP relaxation to convergence before restoring integrality. These ideas are outlined in the manuscript available [here](https://arxiv.org/abs/2603.29867).

A complete worked example is `example_systems/12_IEEE_9_bus_DC_OPF_expansion`.
