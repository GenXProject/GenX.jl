@doc raw"""
	configure_cplex(solver_settings_path::String)

Reads user-specified solver settings from cplex\_settings.yml in the directory specified by the string solver\_settings\_path.

Returns a MathOptInterface OptimizerWithAttributes CPLEX optimizer instance to be used in the GenX.generate_model() method.

The CPLEX optimizer instance is configured with the following default parameters if a user-specified parameter for each respective field is not provided:

 - CPX\_PARAM\_EPRHS = 1e-6 (Constraint (primal) feasibility tolerances. See https://www.ibm.com/support/knowledgecenter/en/SSSA5P_12.5.1/ilog.odms.cplex.help/CPLEX/Parameters/topics/EpRHS.html)
 - CPX\_PARAM\_EPOPT = 1e-4 (Dual feasibility tolerances. See https://www.ibm.com/support/knowledgecenter/en/SSSA5P_12.5.1/ilog.odms.cplex.help/CPLEX/Parameters/topics/EpOpt.html)
 - CPX\_PARAM\_AGGFILL = 10 (Allowed fill during presolve aggregation. See https://www.ibm.com/support/knowledgecenter/en/SSSA5P_12.5.1/ilog.odms.cplex.help/CPLEX/Parameters/topics/AggFill.html)
 - CPX\_PARAM\_PREDUAL = 0 (Decides whether presolve should pass the primal or dual linear programming problem to the LP optimization algorithm. See https://www.ibm.com/support/knowledgecenter/en/SSSA5P_12.5.1/ilog.odms.cplex.help/CPLEX/Parameters/topics/PreDual.html)
 - CPX\_PARAM\_TILIM = 1e+75	(Limits total time solver. See https://www.ibm.com/support/knowledgecenter/en/SSSA5P_12.5.1/ilog.odms.cplex.help/CPLEX/Parameters/topics/TiLim.html)
 - CPX\_PARAM\_EPGAP = 1e-4	(Relative (p.u. of optimal) mixed integer optimality tolerance for MIP problems (ignored otherwise). See https://www.ibm.com/support/knowledgecenter/en/SSSA5P_12.5.1/ilog.odms.cplex.help/CPLEX/Parameters/topics/EpGap.html)
 - CPX\_PARAM\_LPMETHOD = 0 (Algorithm used to solve continuous models (including MIP root relaxation). See https://www.ibm.com/support/knowledgecenter/de/SSSA5P_12.7.0/ilog.odms.cplex.help/CPLEX/Parameters/topics/LPMETHOD.html)
 - CPX\_PARAM\_BAREPCOMP = 1e-8 (Barrier convergence tolerance (determines when barrier terminates). See https://www.ibm.com/support/knowledgecenter/en/SSSA5P_12.5.1/ilog.odms.cplex.help/CPLEX/Parameters/topics/BarEpComp.html)
 - CPX\_PARAM\_NUMERICALEMPHASIS = 0 (Numerical precision emphasis. See https://www.ibm.com/support/knowledgecenter/en/SSSA5P_12.5.1/ilog.odms.cplex.help/CPLEX/Parameters/topics/NumericalEmphasis.html)
 - CPX\_PARAM\_BAROBJRNG = 1e+75 (Sets the maximum absolute value of the objective function. See https://www.ibm.com/support/knowledgecenter/en/SSSA5P_12.5.1/ilog.odms.cplex.help/CPLEX/Parameters/topics/BarObjRng.html)
 - CPX\_PARAM\_SOLUTIONTYPE = 2 (Solution type for LP or QP. See https://www.ibm.com/support/knowledgecenter/hr/SSSA5P_12.8.0/ilog.odms.cplex.help/CPLEX/Parameters/topics/SolutionType.html)

"""
function configure_cplex(solver_settings_path::String)

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
                            "SolutionType" => 2,
                           )


    attributes = merge(default_settings, solver_settings)

    key_replacement = Dict(
         "Feasib_Tol" => "CPX_PARAM_EPRHS",
         "Optimal_Tol" => "CPX_PARAM_EPOPT",
         "AggFill" => "CPX_PARAM_AGGFILL",
         "PreDual" => "CPX_PARAM_PREDUAL",
         "TimeLimit" => "CPX_PARAM_TILIM",
         "MIPGap" => "CPX_PARAM_EPGAP",
         "Method" => "CPX_PARAM_LPMETHOD",
         "BarConvTol" => "CPX_PARAM_BAREPCOMP",
         "NumericFocus" => "CPX_PARAM_NUMERICALEMPHASIS",
         "BarObjRng" => "CPX_PARAM_BAROBJRNG",
         "SolutionType" => "CPX_PARAM_SOLUTIONTYPE",
    )
    attributes = rename_keys(attributes, key_replacement)

    attributes::Dict{String, Any}
    return optimizer_with_attributes(CPLEX.Optimizer, attributes...)
end
