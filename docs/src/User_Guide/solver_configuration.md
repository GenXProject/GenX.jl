# Solver Configuration

To define and solve the optimization problems, GenX relies on [JuMP](https://jump.dev/JuMP.jl/stable/), a domain-specific modeling language for mathematical optimization written in Julia, and on a variety of open-source and commercial solvers. GenX supports the following solvers:

- [Cbc](https://github.com/coin-or/Cbc) (open-source)
- [Clp](https://github.com/coin-or/Clp) (open-source)
- [CPLEX](https://www.ibm.com/analytics/cplex-optimizer) (commercial)
- [Gurobi](https://www.gurobi.com/) (commercial)
- [HiGHS](https://highs.dev/) (open-source)
- [SCIP](https://scip.zib.de/) (open-source)

Solver related settings parameters are specified in the appropriate .yml file (e.g. `highs_settings.yml`, `gurobi_settings.yml`, etc.), which should be located in the `settings` folder inside the current working directory (the same `settings` folder where `genx_settings.yml` is located). Settings are specific to each solver. Check the `Example_Systems` folder for examples of solver settings files and parameters. 

!!! note "Note"
    GenX supplies default settings for most solver settings in the various solver-specific functions found in the `src/configure_solver/` directory.
    To overwrite default settings, you can specify the below Solver specific settings.

The following table summarizes the solver settings parameters and their default/possible values. 
!!! tip "Tip"
    Since each solver has its own set of parameters names, together with a description of the parameter, the table provides a reference to the the corresponding solver specific parameter name. 

#### Solver settings parameters**

|**Settings Parameter** | **Description**|
|:----------------------|:---------------|
|Method | Algorithm used to solve continuous models or the root node of a MIP model. Generally, barrier method provides the fastest run times for real-world problem set.|
|| **CPLEX**: CPX\_PARAM\_LPMETHOD - Default = 0; See [link](https://www.ibm.com/docs/en/icos/22.1.1?topic=parameters-algorithm-continuous-linear-problems) for more specifications.|
|| **Gurobi**: Method - Default = -1; See [link](https://www.gurobi.com/documentation/8.1/refman/method.html) for more specifications.|
|| **clp**: SolveType - Default = 5; See [link](https://www.coin-or.org/Doxygen/Clp/classClpSolve.html) for more specifications.|
|| **HiGHS**: Method - Default = "choose"; See [link](https://ergo-code.github.io/HiGHS/dev/options/definitions/) for more specifications.|
|BarConvTol | Convergence tolerance for barrier algorithm.|
|| **CPLEX**: CPX\_PARAM\_BAREPCOMP - Default = 1e-8; See [link](https://www.ibm.com/docs/en/icos/22.1.1?topic=parameters-convergence-tolerance-lp-qp-problems) for more specifications.|
|| **Gurobi**: BarConvTol - Default = 1e-8; See [link](https://www.gurobi.com/documentation/8.1/refman/barconvtol.html) for more specifications.|
|Feasib\_Tol | All constraints must be satisfied as per this tolerance. Note that this tolerance is absolute.|
|| **CPLEX**: CPX\_PARAM\_EPRHS - Default = 1e-6; See [link](https://www.ibm.com/docs/en/icos/22.1.1?topic=parameters-feasibility-tolerance) for more specifications.|
|| **Gurobi**: FeasibilityTol - Default = 1e-6; See [link](https://www.gurobi.com/documentation/9.1/refman/feasibilitytol.html) for more specifications.|
|| **clp**: PrimalTolerance - Default = 1e-7; See [link](https://www.coin-or.org/Clp/userguide/clpuserguide.html) for more specifications.|
|| **clp**: DualTolerance - Default = 1e-7; See [link](https://www.coin-or.org/Clp/userguide/clpuserguide.html) for more specifications.|
|Optimal\_Tol | Reduced costs must all be smaller than Optimal\_Tol in the improving direction in order for a model to be declared optimal.|
|| **CPLEX**: CPX\_PARAM\_EPOPT - Default = 1e-6; See [link](https://www.ibm.com/docs/en/icos/22.1.1?topic=parameters-optimality-tolerance) for more specifications.|
|| **Gurobi**: OptimalityTol - Default = 1e-6; See [link](https://www.gurobi.com/documentation/8.1/refman/optimalitytol.html) for more specifications.|
|Pre\_Solve | Controls the presolve level.|
|| **Gurobi**: Presolve - Default = -1; See [link](https://www.gurobi.com/documentation/8.1/refman/presolve.html) for more specifications.|
|| **clp**: PresolveType - Default = 5; See [link](https://www.coin-or.org/Doxygen/Clp/classClpSolve.html) for more specifications.|
|Crossover | Determines the crossover strategy used to transform the interior solution produced by barrier algorithm into a basic solution.|
|| **CPLEX**: CPX\_PARAM\_SOLUTIONTYPE - Default = 2; See [link](https://www.ibm.com/docs/en/icos/22.1.1?topic=parameters-optimality-tolerance) for more specifications.|
|| **Gurobi**: Crossover - Default = 0; See [link](https://www.gurobi.com/documentation/9.1/refman/crossover.html#:~:text=Use%20value%200%20to%20disable,interior%20solution%20computed%20by%20barrier.) for more specifications.|
|NumericFocus | Controls the degree to which the code attempts to detect and manage numerical issues.|
|| **CPLEX**: CPX\_PARAM\_NUMERICALEMPHASIS - Default = 0; See [link](https://www.ibm.com/docs/en/icos/22.1.1?topic=parameters-numerical-precision-emphasis) for more specifications.|
|| **Gurobi**: NumericFocus - Default = 0; See [link](https://www.gurobi.com/documentation/9.1/refman/numericfocus.html) for more specifications.|
|TimeLimit | Time limit to terminate the solution algorithm, model could also terminate if it reaches MIPGap before this time.|
|| **CPLEX**: CPX\_PARAM\_TILIM- Default = 1e+75; See [link](https://www.ibm.com/docs/en/icos/22.1.1?topic=parameters-optimizer-time-limit-in-seconds) for more specifications.|
|| **Gurobi**: TimeLimit - Default = infinity; See [link](https://www.gurobi.com/documentation/9.1/refman/timelimit.html) for more specifications.|
|| **clp**: MaximumSeconds - Default = -1; See [link](https://www.coin-or.org/Doxygen/Clp/classClpModel.html) for more specifications.|
|MIPGap | Optimality gap in case of mixed-integer program.|
|| **CPLEX**: CPX\_PARAM\_EPGAP- Default = 1e-4; See [link](https://www.ibm.com/docs/en/icos/22.1.1?topic=parameters-relative-mip-gap-tolerance) for more specifications.|
|| **Gurobi**: MIPGap - Default = 1e-4; See [link](https://www.gurobi.com/documentation/9.1/refman/mipgap2.html) for more specifications.|
|DualObjectiveLimit | When using dual simplex (where the objective is monotonically changing), terminate when the objective exceeds this limit.|
|| **clp**: DualObjectiveLimit - Default = 1e308; See [link](https://www.coin-or.org/Doxygen/Clp/classClpModel.html) for more specifications.|
|MaximumIterations | Terminate after performing this number of simplex iterations.|
|| **clp**: MaximumIterations - Default = 2147483647; See [link](https://www.coin-or.org/Doxygen/Clp/classClpModel.html) for more specifications.|
|LogLevel | Set to 1, 2, 3, or 4 for increasing output. Set to 0 to disable output.|
|| **clp**: logLevel - Default = 1; See [link](https://www.coin-or.org/Doxygen/Clp/classClpModel.html) for more specifications.|
|| **cbc**: logLevel - Default = 1; See [link](https://www.coin-or.org/Doxygen/Cbc/classCbcModel.html#a244a08213674ce52ddcf33ab4ff53380a185d42e67d2c4cb7b79914c0ed322b5f) for more specifications.|
|InfeasibleReturn | Set to 1 to return as soon as the problem is found to be infeasible (by default, an infeasibility proof is computed as well).|
|| **clp**: InfeasibleReturn - Default = 0; See [link](https://www.coin-or.org/Doxygen/Clp/classClpModel.html) for more specifications.|
|Scaling | Sets or unsets scaling; 0 -off, 1 equilibrium, 2 geometric, 3 auto, 4 dynamic(later).|
|| **clp**: Scaling - Default = 3; See [link](https://www.coin-or.org/Doxygen/Clp/classClpModel.html) for more specifications.|
|Perturbation | Perturbs problem; Switch on perturbation (50), automatic (100), don't try perturbing (102).|
|| **clp**: Perturbation - Default = 3; See [link](https://www.coin-or.org/Doxygen/Clp/classClpModel.html) for more specifications.|
|maxSolutions | Terminate after this many feasible solutions have been found.|
|| **cbc**: maxSolutions - Default = -1; See [link](https://www.coin-or.org/Doxygen/Cbc/classCbcModel.html#a244a08213674ce52ddcf33ab4ff53380a185d42e67d2c4cb7b79914c0ed322b5f) for more specifications.|
|maxNodes | Terminate after this many branch-and-bound nodes have been evaluated|
|| **cbc**: maxNodes - Default = -1; See [link](https://www.coin-or.org/Doxygen/Cbc/classCbcModel.html#a244a08213674ce52ddcf33ab4ff53380a185d42e67d2c4cb7b79914c0ed322b5f) for more specifications.|
| allowableGap | Terminate after optimality gap is less than this value (on an absolute scale)|
|| **cbc**: allowableGap - Default = -1; See [link](https://www.coin-or.org/Doxygen/Cbc/classCbcModel.html#a244a08213674ce52ddcf33ab4ff53380a185d42e67d2c4cb7b79914c0ed322b5f) for more specifications.|
|ratioGap | Terminate after optimality gap is smaller than this relative fraction.|
|| **cbc**: ratioGap - Default = Inf; See [link](https://www.coin-or.org/Doxygen/Cbc/classCbcModel.html#a244a08213674ce52ddcf33ab4ff53380a185d42e67d2c4cb7b79914c0ed322b5f) for more specifications.|
|threads | Set the number of threads to use for parallel branch & bound.|
|| **cbc**: threads - Default = 1; See [link](https://www.coin-or.org/Doxygen/Cbc/classCbcModel.html#a244a08213674ce52ddcf33ab4ff53380a185d42e67d2c4cb7b79914c0ed322b5f) for more specifications.|
