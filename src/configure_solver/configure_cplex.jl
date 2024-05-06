@doc raw"""
	configure_cplex(solver_settings_path::String)

Reads user-specified solver settings from `cplex_settings.yml` in the directory specified by the string `solver_settings_path`.

Returns a `MathOptInterface.OptimizerWithAttributes` CPLEX optimizer instance.

The optimizer instance is configured with the following default parameters if a user-specified parameter for each respective field is not provided:

* `Feasib_Tol`,

  sets [CPX\_PARAM\_EPRHS](https://www.ibm.com/docs/en/cofz/12.9.0?topic=parameters-solution-type-lp-qp).
  Control the primal feasibility tolerance.
  Default is `1e-6`.

* `Optimal_Tol`,

   sets [`CPX_PARAM_EPOPT`](https://www.ibm.com/docs/en/cofz/12.9.0?topic=parameters-optimality-tolerance).
   Control the optimality tolerance.
   Default is `1e-4`.

* `AggFill`,

   sets [`CPX_PARAM_AGGFILL`](https://www.ibm.com/docs/en/cofz/12.9.0?topic=parameters-preprocessing-aggregator-fill).
   Control the allowed fill during presolve aggregation.
   Default is `10`.

* `PreDual`,

  sets [`CPX_PARAM_PREDUAL`](https://www.ibm.com/docs/en/cofz/12.9.0?topic=parameters-presolve-dual-setting).
  Decides whether presolve should pass the primal or dual linear programming problem to the LP optimization algorithm.
  Default is `0`.

* `TimeLimit`,

  sets [`CPX_PARAM_TILIM`](https://www.ibm.com/docs/en/cofz/12.9.0?topic=parameters-optimizer-time-limit-in-seconds).
  Limits total solver time.
  Default is `1e+75`.

* `MIPGap`,

  sets [`CPX_PARAM_EPGAP`](https://www.ibm.com/docs/en/cofz/12.9.0?topic=parameters-relative-mip-gap-tolerance)
  Relative (p.u. of optimal) mixed integer optimality tolerance for MIP problems (ignored otherwise).
  Default is `1e-3`.

* `Method`,

  sets [`CPX_PARAM_LPMETHOD`](https://www.ibm.com/docs/en/cofz/12.9.0?topic=optimizers-using-parallel-in-component-libraries).
  Algorithm used to solve continuous models (including MIP root relaxation)
  Default is `0`.

* `BarConvTol`,

  sets [`CPX_PARAM_BAREPCOMP`](https://www.ibm.com/docs/en/cofz/12.9.0?topic=parameters-convergence-tolerance-lp-qp-problems).
  Barrier convergence tolerance (determines when barrier terminates).
  Default is `1e-8`.

* `NumericFocus`,

  sets [`CPX_PARAM_NUMERICALEMPHASIS`](https://www.ibm.com/docs/en/cofz/12.9.0?topic=parameters-numerical-precision-emphasis).
  Numerical precision emphasis.
  Default is `0`.

* `BarObjRng`,

  sets [`CPX_PARAM_BAROBJRNG`](https://www.ibm.com/docs/en/cofz/12.9.0?topic=parameters-barrier-objective-range).
  The maximum absolute value of the objective function.
  Default is `1e+75`.

* `SolutionType`,

  sets [`CPX_PARAM_SOLUTIONTYPE`](https://www.ibm.com/docs/en/cofz/12.9.0?topic=parameters-solution-type-lp-qp).
  Solution type for LP or QP.
  Default is `2`.

The optimizer instance is configured with the following default parameters if a user-specified parameter for each respective field is not provided:

Any other attributes in the settings file (which typically start with `CPX_PARAM_`) will also be passed to the solver.
"""
function configure_cplex(solver_settings_path::String, optimizer::Any)
    solver_settings = YAML.load(open(solver_settings_path))
    solver_settings = convert(Dict{String, Any}, solver_settings)

    default_settings = Dict("Feasib_Tol" => 1e-6,
        "Optimal_Tol" => 1e-4,
        "AggFill" => 10,
        "PreDual" => 0,
        "TimeLimit" => 1e+75,
        "MIPGap" => 1e-3,
        "Method" => 0,
        "BarConvTol" => 1e-8,
        "NumericFocus" => 0,
        "BarObjRng" => 1e+75,
        "SolutionType" => 2)

    attributes = merge(default_settings, solver_settings)

    key_replacement = Dict("Feasib_Tol" => "CPX_PARAM_EPRHS",
        "Optimal_Tol" => "CPX_PARAM_EPOPT",
        "AggFill" => "CPX_PARAM_AGGFILL",
        "PreDual" => "CPX_PARAM_PREDUAL",
        "TimeLimit" => "CPX_PARAM_TILIM",
        "MIPGap" => "CPX_PARAM_EPGAP",
        "Method" => "CPX_PARAM_LPMETHOD",
        "Pre_Solve" => "CPX_PARAM_PREIND", # https://www.ibm.com/docs/en/icos/12.8.0.0?topic=parameters-presolve-switch
        "BarConvTol" => "CPX_PARAM_BAREPCOMP",
        "NumericFocus" => "CPX_PARAM_NUMERICALEMPHASIS",
        "BarObjRng" => "CPX_PARAM_BAROBJRNG",
        "SolutionType" => "CPX_PARAM_SOLUTIONTYPE")
    attributes = rename_keys(attributes, key_replacement)

    attributes::Dict{String, Any}
    return optimizer_with_attributes(optimizer, attributes...)
end
