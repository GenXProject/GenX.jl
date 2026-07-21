## Benders Decomposition

Benders Decomposition is a powerful optimization technique used to solve large-scale problems by breaking them into a smaller master problem and one or more subproblems The master problem contains a set of "complicating variables" that, once fixed in the subproblems, makes the subproblems easier to solve. The algorithm works iteratively: it solves the master problem, fixes that solution in the subproblems, solves the subproblems, and then returns cuts (typically dual information) back to the master problem that refine the solution space. This process of passing information (primal and dual variables) between the master and subproblems continues until an upper and lower bound converge. For further details on Benders decomposition in capacity expansion models, please see this paper by [Jacobson et al.](https://pubsonline.informs.org/doi/abs/10.1287/ijoo.2023.0005) ([preprint](https://arxiv.org/abs/2302.10037)) or this paper by [Pecci and Jenkins](https://ieeexplore.ieee.org/abstract/document/10829583) ([preprint](https://arxiv.org/abs/2403.02559)). The mathematical formulation for the capacity expansion model and how it is decomposed is shown in more detail in the [Benders Decomposition Overview](@ref).

Benders decomposition can be especially useful when the problem can be decomposed with several independent subproblems. This is because the subproblems can each be solved in parallel after the master problem solve is complete. GenX exploits this ability by decomposing the problem in time and solving with representative time periods, such that the linking between time periods is only captured inside the master problem. This allows for each representative period to be solved independently in parallel during a single iteration of Benders. For this reason, it is generally advised that the user provide their data as representative periods or to use the time domain reduction capability of GenX, which automatically creates the representative periods for use in Benders.


Benders decomposition is accessed by setting `Benders: 1` in the `genx_settings.yml` file. In addition, the user must  planning problem and subproblem solver settings as `[solver_name]_benders_planning_settings.yml` and `[solver_name]__benders_subprob_settings.yml` as well as a settings files for Benders called `benders_settings.yml`. Internally, GenX calls [MacroEnergySolvers.jl](https://github.com/macroenergy/MacroEnergySolvers.jl/tree/main) to run the Benders algorithm. The settings which can be passed to the `benders_settings.yml` file are shown in the following table. 

|**Parameter** | **Allowed Values** |**Description**|
| :------------ | :-----------|:-----------|
| MaxIter | $\in \mathbb{Z}_+$ | Maximum number of Benders iterations
| MaxCpuTime | $\ge 0$ | Wall-clock time limit in seconds|
| ConvTol | $\in (0, 1]$|  Relative optimality-gap convergence tolerance (\|UB - LB\| / \|UB\| ≤ BD_ConvTol → converged) |
| StabParam | $\in [0, 1]$ | Level-set stabilisation parameter; 0.0 = disabled  |
| ThetaLB | $\in \mathbb{R}$ | Lower Bound on a subproblem objective; default is zero, but should be set to lower value if subproblems can have negative objectives |
| StabDynamic | $\{true, false\}$ | Dynamic (Magnanti–Wong / in-out) stabilisation; false = disabled |
| IntegerInvestment | $\{true, false\}$ | Investment variable type; false = continuous (LP relaxation), true = integer (MILP master problem)|
| Distributed | $\{true, false\}$ | Whether to distribute subproblems to remote workers. When `true` and `NWorkers > 1`, GenX will automatically launch the required worker processes. |
| NWorkers | $\in \mathbb{Z}_+$, $> 1$ | Number of Julia worker processes to use for parallel subproblem solving. Only used when `Distributed: true`. Must be greater than 1 to enable parallel execution. |
| ExpectFeasibleSubproblems | $\{true, false\}$ | # If true, skip feasibility cuts (assumes subproblems are always feasible); safe to leave false|

### Running Benders in Parallel

By default, GenX runs Benders with a single Julia process: all representative-period subproblems are solved sequentially on the main process. To enable parallel subproblem solving, set `Distributed: true` and `NWorkers: N` (where `N > 1`) in `benders_settings.yml`:

```yaml
Distributed: true
NWorkers: 4
```

When these settings are present, GenX will automatically launch the required number of worker processes before the Benders run begins. No changes to your run script are needed:

```julia
using GenX
using HiGHS

run_genx_case!("path/to/case", HiGHS.Optimizer)
```

If you prefer to manage workers manually (for example, when using a cluster scheduler), you can add workers yourself before calling `run_genx_case!`. GenX will detect that enough workers are already running and skip the automatic launch:

```julia
using Distributed
addprocs(4)
@everywhere using GenX
using HiGHS

run_genx_case!("path/to/case", HiGHS.Optimizer)
```

The number of workers should generally match (or be a divisor of) the number of representative periods so that each worker receives a roughly equal share of subproblems.

> **Note:** Parallel execution is enabled automatically whenever `Distributed.nworkers() > 1` at the time `run_genx_case!` is called, regardless of the `Distributed` or `NWorkers` settings. The automatic worker launch only fires when `Distributed: true` and `NWorkers > 1` and fewer workers than requested are currently running.

Note that the stabilization/regularization scheme used in MacroEnergySolvers.jl is turned on when StabParam is greater than zero. For the regularization scheme to work, the planning problem solver must use an interior point method without crossover. Stabilization is a process in Benders where the master problem can choose less extreme solutions that are on the interior of the feasible set (see [Pecci and Jenkins](https://ieeexplore.ieee.org/abstract/document/10829583)). A challenge of Benders is that, especially at early iterations, the master problem chooses solutions that result in high costs in the subproblems (e.g., at the first iteration, Benders typically chooses to build nothing in the planning level because it is trying to minimize cost without knowledge of the operations) which results in poor cuts. The stabilization scheme generally allows the master to choose solutions that are less extreme and can result in stronger cuts early on.


### Note on Convergence
How well Benders Decomposition solves a problem is dependent on many factors, and there are several ongoing research projects around the world to improve the performance of Benders Decomposition. There is no guarantee on the number of iterations it will take to reach a specific tolerance. Algorithm performance is driven by many things, and modeling decisions can strongly impact convergence speed. Generally speaking, Benders Decomposition may or may not outperform solving the monolithic problem, and it is generally best when the monolithic is becoming very slow or intractable to solve.