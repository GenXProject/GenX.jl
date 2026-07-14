@doc raw"""
    dcopf_transmission!(EP::Model, inputs::Dict, setup::Dict)

Adds the DC optimal power flow (DC-OPF) constraints that relate line flows to the voltage phase
angles ``\theta_{z,t}`` of each zone. This function supports both a fixed transmission network and
**discrete integer transmission expansion** (when `NetworkExpansion` and `DiscreteInvestments` are
both active and discrete-build lines are present).

**Line sets.** The lines ``\mathcal{L}`` are partitioned into three disjoint sets:
- ``\mathcal{F}`` (`FIXED_LINES`) — physically-present lines that always satisfy the exact DC-OPF
  coupling. When there is no integer expansion this is all of ``\mathcal{L}``.
- ``\mathcal{B}`` (`DISCRETE_BUILD_LINES`) — candidate discrete lines, each with a binary build
  decision ``x_l \in \{0,1\}`` (`vNEW_TRANS_LINES`).
- ``\mathcal{P}`` (`PHANTOM_LINES`) — the zero-capacity residual rows of a from-zero (greenfield)
  discrete-build corridor. No physical line exists on them until a parallel discrete line is built.

Note that the flow magnitude limits ``|\Phi_{l,t}| \leq \varphi^{cap}_{l}`` are imposed in
`transmission!` (via `eAvail_Trans_Cap`) and are therefore not repeated here.

**Fixed lines** (``l \in \mathcal{F}``). The line flow equals the susceptance ``\mathcal{B}_{l}``
times the angle difference across the line, and the angle difference is bounded by
``\Delta\theta^{\max}_{l}``:
```math
\begin{aligned}
    & \Phi_{l,t}=\mathcal{B}_{l} \times \Big(\sum_{z\in \mathcal{Z}}{\varphi^{map}_{l,z} \times \theta_{z,t}}\Big) \quad && \forall l \in \mathcal{F}, \; \forall t  \in \mathcal{T}\\
    & -\Delta \theta^{\max}_{l} \leq \sum_{z\in \mathcal{Z}}{\varphi^{map}_{l,z} \times \theta_{z,t}} \leq \Delta \theta^{\max}_{l} \quad && \forall l \in \mathcal{F}, \; \forall t  \in \mathcal{T}\\
\end{aligned}
```

**Candidate (discrete-build) lines** (``l \in \mathcal{B}``). The flow–angle coupling on these lines
is imposed with one of two formulations, selected by the `Bilinear_DC_OPF` setting.

*Big-M relaxation* (`Bilinear_DC_OPF = 0`, the default). The coupling is relaxed through a big-M
(``M_{l}`` = `BigM`) so that it is only active when the line is built (``x_l = 1``); a build-gated
flow limit (``\overline{F}_{l}`` = `Line_Reinforcement_Cap_Size`) forces the flow to zero when the
line is not built:
```math
\begin{aligned}
    & -M_{l}\,(1-x_{l}) \leq \Phi_{l,t} - \mathcal{B}_{l} \times \Big(\sum_{z\in \mathcal{Z}}{\varphi^{map}_{l,z} \times \theta_{z,t}}\Big) \leq M_{l}\,(1-x_{l}) \quad && \forall l \in \mathcal{B}, \; \forall t  \in \mathcal{T}\\
    & -x_{l}\,\overline{F}_{l} \leq \Phi_{l,t} \leq x_{l}\,\overline{F}_{l} \quad && \forall l \in \mathcal{B}, \; \forall t  \in \mathcal{T}\\
\end{aligned}
```
This keeps the model mixed-integer *linear*, at the cost of introducing the big-M parameter
``M_{l}`` (which must be large enough not to bind when the line is built, yet tight enough to avoid
weakening the relaxation).

*Exact bilinear coupling* (`Bilinear_DC_OPF = 1`). The coupling is written directly as the product of
the binary build variable and the angle difference, so the flow is exactly the DC-OPF flow when the
line is built (``x_l = 1``) and identically zero when it is not (``x_l = 0``):
```math
\begin{aligned}
    & \Phi_{l,t}=\mathcal{B}_{l} \times \Big(\sum_{z\in \mathcal{Z}}{\varphi^{map}_{l,z} \times \theta_{z,t}}\Big) \times x_{l} \quad && \forall l \in \mathcal{B}, \; \forall t  \in \mathcal{T}\\
    & -\overline{F}_{l} \leq \Phi_{l,t} \leq \overline{F}_{l} \quad && \forall l \in \mathcal{B}, \; \forall t  \in \mathcal{T}\\
\end{aligned}
```
This avoids the big-M parameter entirely and gives a tighter, exact representation, but the
product ``\theta_{z,t}\,x_{l}`` makes the constraint bilinear (mixed-integer nonlinear), which
requires a solver capable of handling such constraints (e.g. a global MINLP solver, or Gurobi's
support for bilinear terms). Because the flow limit is already zeroed by the product, it need not be
build-gated.

The angle-difference limit for candidate lines is (in both formulations) build-gated, using a big-M
``M^{\theta}`` (`M_angle`, the sum of all line angle limits — an upper bound on any feasible network
angle difference). Because every parallel line on a corridor shares the same angle-difference
expression, building any one line activates the corridor's angle limit:
```math
\begin{aligned}
    & -\Delta \theta^{\max}_{l} - M^{\theta}\,(1-x_{l}) \leq \sum_{z\in \mathcal{Z}}{\varphi^{map}_{l,z} \times \theta_{z,t}} \leq \Delta \theta^{\max}_{l} + M^{\theta}\,(1-x_{l}) \quad && \forall l \in \mathcal{B}, \; \forall t  \in \mathcal{T}\\
\end{aligned}
```

**Phantom lines** (``l \in \mathcal{P}``) carry no coupling or angle constraint of their own — their
flow is held at zero by `transmission!`. Excluding them prevents a zero-capacity residual row from
pinning the corridor's angle difference (which would otherwise force any newly-built parallel line
to carry zero power). Because the phantom line shares its angle-difference expression with the
candidate lines on the same corridor, the build-gated candidate constraints above supply the
corridor's angle limit once a discrete line is built.

**Slack bus.** The reference voltage phase angle is fixed at zone 1:
```math
\begin{aligned}
\theta_{1,t} = 0 \quad \forall t  \in \mathcal{T}
\end{aligned}
```

**Build order (symmetry breaking).** For a group ``g`` of identical parallel candidate lines, builds
are ordered to remove degenerate (symmetric) solutions:
```math
\begin{aligned}
x_{g_{i-1}} \geq x_{g_{i}} \quad \forall i \geq 2
\end{aligned}
```

When there are no integer builds (`DiscreteInvestments = 0`, no discrete-build lines, or
`NetworkExpansion = 0`), ``\mathcal{B}`` and ``\mathcal{P}`` are empty, ``\mathcal{F} = \mathcal{L}``,
and the formulation reduces to the standard DC-OPF over all lines.
"""
function dcopf_transmission!(EP::Model, inputs::Dict, setup::Dict)
    println("DC-OPF Module")

    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones
    L = inputs["L"]     # Number of transmission lines

    DiscreteInvestments = setup["DiscreteInvestments"]
    NetworkExpansion = setup["NetworkExpansion"]

    ### Line sets ###

    # Discrete discrete-build (candidate) lines. Only populated when integer network expansion is
    # active; empty otherwise, so the plain DC-OPF path is unaffected.
    DISCRETE_BUILD_LINES = get(inputs, "DISCRETE_BUILD_LINES", Int[])
    discrete_build_expansion = length(DISCRETE_BUILD_LINES) > 0 && NetworkExpansion == 1

    # "Phantom" lines are the zero-capacity residual rows of a from-zero discrete-build corridor: they
    # have no existing capacity and are not eligible for continuous expansion, so no physical line
    # exists on them until a parallel discrete line is built. They are excluded from the
    # flow = coeff * angle-difference relation and from the angle-difference limits; otherwise their
    # forced-zero flow (from transmission!) would pin the corridor's angle difference and prevent any
    # newly-built parallel discrete line from carrying power. Only relevant for discrete-build
    # expansion; empty otherwise so the plain / continuous-expansion DC-OPF cases are unchanged.
    EXPANSION_LINES = get(inputs, "EXPANSION_LINES", Int[])
    PHANTOM_LINES = discrete_build_expansion ?
                    [l for l in 1:L
                     if inputs["pTrans_Max"][l] == 0 &&
                        !(l in EXPANSION_LINES) &&
                        !(l in DISCRETE_BUILD_LINES)] : Int[]

    # Fixed lines are the physically-present lines that always satisfy the exact DC-OPF coupling. In
    # the plain / continuous-expansion cases this is every line (1:L).
    FIXED_LINES = setdiff(1:L, DISCRETE_BUILD_LINES, PHANTOM_LINES)

    ### DC-OPF variables ###

    # Voltage angle variables of each zone "z" at hour "t"
    @variable(EP, vANGLE[z = 1:Z, t = 1:T])

    # Slack Bus angle limit
    @constraint(EP, cANGLE_SLACK[t = 1:T], vANGLE[1, t]==0)

    # Bus angle limits (except slack bus). Enforced unconditionally only on physically-present (fixed)
    # lines: candidate and phantom lines should not constrain the corridor's angle difference while
    # unbuilt. The angle limit for candidate (and from-zero/phantom) corridors is instead applied via
    # the build-gated big-M constraints below, so it takes effect once a line is built.
    @constraints(EP,
        begin
            cANGLE_ub[l in FIXED_LINES, t = 1:T],
            sum(inputs["pNet_Map"][l, z] * vANGLE[z, t] for z in 1:Z) <=
            inputs["Line_Angle_Limit"][l]
            cANGLE_lb[l in FIXED_LINES, t = 1:T],
            sum(inputs["pNet_Map"][l, z] * vANGLE[z, t] for z in 1:Z) >=
            -inputs["Line_Angle_Limit"][l]
        end)

    ### DC-OPF constraints ###
    # Flow magnitude limits (|vFLOW| <= eAvail_Trans_Cap) are already imposed for all lines in
    # transmission!, so they are not repeated here.

    # Exact power flow coupling on the fixed lines:: vFLOW = DC_OPF_coeff * (vANGLE difference).
    # (In the plain / continuous-expansion cases FIXED_LINES == 1:L.)
    @constraint(EP,
        cPOWER_FLOW_OPF[l in FIXED_LINES, t = 1:T],
        EP[:vFLOW][l, t]==inputs["pDC_OPF_coeff"][l] *
                sum(inputs["pNet_Map"][l, z] * vANGLE[z, t] for z in 1:Z))

    if discrete_build_expansion
        # Angle-difference limits on the candidate lines, enforced only when the line is built.
        # All parallel lines on a corridor share the same angle difference, so building any one of
        # them activates the corridor's limit. This is the ONLY angle limit for a from-zero (phantom)
        # corridor, whose residual row carries no angle constraint; for corridors with an existing
        # (fixed) residual it simply duplicates that row's always-on limit and is otherwise relaxed.
        # M_angle is the sum of all line angle limits, an upper bound on any feasible angle difference
        # across the network, so the constraint is non-binding when the line is not built.
        M_angle = sum(inputs["Line_Angle_Limit"])
        @constraints(EP,
            begin
                cANGLE_BUILD_ub[l in DISCRETE_BUILD_LINES, t = 1:T],
                sum(inputs["pNet_Map"][l, z] * vANGLE[z, t] for z in 1:Z) <=
                inputs["Line_Angle_Limit"][l] + M_angle * (1 - EP[:vNEW_TRANS_LINES][l])
                cANGLE_BUILD_lb[l in DISCRETE_BUILD_LINES, t = 1:T],
                sum(inputs["pNet_Map"][l, z] * vANGLE[z, t] for z in 1:Z) >=
                -inputs["Line_Angle_Limit"][l] - M_angle * (1 - EP[:vNEW_TRANS_LINES][l])
            end)

        if setup["Bilinear_DC_OPF"] == 1
            # Set DC_OPF constraints on the new (candidate) lines using a bilinear formulation
            @constraint(EP,
                cPOWER_FLOW_BUILD[l in DISCRETE_BUILD_LINES, t = 1:T],
                    EP[:vFLOW][l,t] == inputs["pDC_OPF_coeff"][l] *
                            sum(inputs["pNet_Map"][l, z] * vANGLE[z, t] for z in 1:Z) * EP[:vNEW_TRANS_LINES][l])

            # Set limits on new lines; Line_Reinforcement_Cap_Size serves as a big M constraint
            # if line is not built, vFLOW must be zero
            @constraints(EP,
                begin
                    cMaxFlow_out_new[l in DISCRETE_BUILD_LINES, t = 1:T], EP[:vFLOW][l, t] <= inputs["Line_Reinforcement_Cap_Size"][l]
                    cMaxFlow_in_new[l in DISCRETE_BUILD_LINES, t = 1:T], EP[:vFLOW][l, t] >= -inputs["Line_Reinforcement_Cap_Size"][l]
                end
            )
        else
            BigM = inputs["BigM"]
            # Set DC_OPF constraints on the new (candidate) lines via a big-M relaxation of the coupling.
            # If the line is not built (vNEW_TRANS_LINES == 0) the relation is relaxed and the flow is
            # forced to zero by cMaxFlow_*_new; if built, the exact coupling is enforced.
            @constraint(EP,
                cPOWER_FLOW_BUILD_FORWARD[l in DISCRETE_BUILD_LINES, t = 1:T],
                    EP[:vFLOW][l,t]-inputs["pDC_OPF_coeff"][l] *
                            sum(inputs["pNet_Map"][l, z] * vANGLE[z, t] for z in 1:Z) <= BigM[l]*(1-EP[:vNEW_TRANS_LINES][l]))
            @constraint(EP,
                cPOWER_FLOW_BUILD_REVERSE[l in DISCRETE_BUILD_LINES, t = 1:T],
                    EP[:vFLOW][l,t]-inputs["pDC_OPF_coeff"][l] *
                            sum(inputs["pNet_Map"][l, z] * vANGLE[z, t] for z in 1:Z) >= -BigM[l]*(1-EP[:vNEW_TRANS_LINES][l]))

            # Set limits on new lines; Line_Reinforcement_Cap_Size serves as a big M constraint
            # if line is not built, vFLOW must be zero
            @constraints(EP,
                begin
                    cMaxFlow_out_new[l in DISCRETE_BUILD_LINES, t = 1:T], EP[:vFLOW][l, t] <= EP[:vNEW_TRANS_LINES][l]*inputs["Line_Reinforcement_Cap_Size"][l]
                    cMaxFlow_in_new[l in DISCRETE_BUILD_LINES, t = 1:T], EP[:vFLOW][l, t] >= -EP[:vNEW_TRANS_LINES][l]*inputs["Line_Reinforcement_Cap_Size"][l]
                end
            )
        end
    end
end
