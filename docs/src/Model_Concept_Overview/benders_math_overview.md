# Benders Decomposition Overview

Below we outline how Benders decomposes a capacity expansion model mathematically. For a broader overview of the Benders decomposition algorithm, see [Benders Decomposition](@ref).

## Mathematical Formulation

The standard capacity expansion problem that GenX solves can be formulated as a large, monolithic optimization problem. With Benders decomposition, this problem is restructured. The formulation below represents the full, undecomposed problem:

```math
\begin{aligned}
    \min \ & c_p^\top x_p + \sum_{w \in W} c_w^\top x_w & &(1) \\
    \textrm{s.t.}\ & A_w x_w + B_w x_p \le b_w, \quad & w  \in W &(2) \\
    & \sum_{w \in W} q_w \le d, \quad &&(3) \\
    & Q_w x_w \le q_w, \quad &  w  \in W &(4) \\
    & Dx_w \le f_w, \quad &  w  \in W &(5) \\
    & x_w \in \mathcal{X}_w, \quad &  w  \in W \\
    & x_p \in \mathcal{X}_p & 
\end{aligned}
```

### Variables

*   **$x_p$ (Planning Variables):** These are the master problem variables, often called "first-stage" or "investment" variables. In GenX, they represent long-term investment and retirement decisions for generation, storage, and transmission capacity.
*   **$x_w$ (Operational Variables):** These are the subproblem variables, often called "second-stage" or "operational" variables. They represent the operational decisions for a specific time slice $w$ (e.g., an hour, day, or week). Examples include the power output of each generator, charging/discharging of storage, and power flow on transmission lines.
*   **$q_w$ (Policy Variables):** These variables link policies across different operational time slices. For example, this could be the allocation of an annual $CO_2$ emissions budget to different weeks or months.

### Constraints

*   **(1) Objective Function:** The goal is to minimize the total system cost, which is the sum of planning/investment costs ($c_p^\top x_p$) and the operational costs over all time periods ($\sum_{w \in W} c_w^\top x_w$).
*   **(2) Linking Constraints:** These constraints connect the planning decisions to the operational decisions. For example, the maximum power output of a generator in any given hour is limited by the total installed capacity determined by the planning variables.
*   **(3) and (4) Policy Constraints:** These constraints enforce system-wide policies that couple the operational subproblems, such as annual emissions caps or renewable portfolio standards.
*   **(5) Operational Constraints:** These are constraints that are entirely contained within a single operational subperiod $w$. Examples include nodal power balance (generation = demand), transmission limits, and generator ramping limits.

## Master Problem and Subproblem Split

Benders decomposition splits the problem above into a master problem and multiple independent operational subproblems.

*   **The Master Problem:** Contains the planning variables ($x_p$) and policy variables ($q_w$). It approximates the operational costs using "Benders cuts," which are linear constraints derived from the subproblems' dual information. The master problem proposes an investment plan and passes it to the subproblems.

*   **The Subproblems:** There is one subproblem for each operational time slice $w \in W$. Each subproblem takes the investment plan from the master problem as fixed input and solves for the optimal operational decisions ($x_w$). If the subproblem is feasible, it returns cost information (dual variables) to the master problem to generate an "optimality cut." If it is infeasible, it returns information about the infeasibility (a dual ray) to generate a "feasibility cut."

This iterative process allows GenX to solve very large problems that would be intractable as a single, monolithic optimization. 