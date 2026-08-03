@doc raw"""
	write_status(path::AbstractString, inputs::Dict, EP::Model)

Function for writing the final solve status of the optimization problem solved.
"""
function write_status(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

    # https://jump.dev/MathOptInterface.jl/v0.9.10/apireference/#MathOptInterface.TerminationStatusCode
    status = termination_status(EP)
    has_solution = has_values(EP)
    objval = has_solution ? objective_value(EP) : missing

    # Note: Gurobi excludes constants from solver reported objective function value - MIPGap calculated may be erroneous
    if (setup["UCommit"] == 0 || setup["UCommit"] == 2)
        dfStatus = DataFrame(Status = status, Solve = inputs["solve_time"],
            Objval = objval)
    else
        objbound = has_solution ? objective_bound(EP) : missing
        final_mip_gap = has_solution ? (objval - objbound) / objval : missing
        dfStatus = DataFrame(Status = status,
            Objval = objval, Objbound = objbound,
            FinalMIPGap = final_mip_gap)
    end
    CSV.write(joinpath(path, "status.csv"), dfStatus)
end

@doc raw"""
	write_status_benders(path::AbstractString, inputs::Dict, setup::Dict, benders_results::NamedTuple)

Function for writing the final status of a Benders decomposition run.

Unlike the monolithic case, there is no single JuMP model whose `termination_status` describes
the run: the planning problem is repeatedly re-solved and only the algorithm's bounds describe
how the decomposition terminated.  The status is therefore derived from the Benders bounds and
the stopping criteria in `setup`:

  - `MOI.OPTIMAL` if the final relative gap `(UB - LB) / |LB|` is within `setup[:ConvTol]`
  - `MOI.TIME_LIMIT` if the elapsed CPU time reached `setup[:MaxCpuTime]`
  - `MOI.ITERATION_LIMIT` if the iteration count reached `setup[:MaxIter]`
  - `MOI.OTHER_LIMIT` otherwise (terminated for some other reason without converging)

`Objval` is the best upper bound (the cost of the incumbent planning solution plus the
operational cost it implies), and `Objbound` is the final lower bound.
"""
function write_status_benders(path::AbstractString, inputs::Dict, setup::Dict,
    benders_results::NamedTuple)

    LB_hist = benders_results.LB_hist
    UB_hist = benders_results.UB_hist
    cpu_time = benders_results.cpu_time
    gap_hist = haskey(benders_results, :gap_hist) ? benders_results.gap_hist :
               (UB_hist .- LB_hist) ./ abs.(LB_hist)

    conv_tol = get(setup, :ConvTol, 1e-3)
    max_cpu_time = get(setup, :MaxCpuTime, Inf)
    max_iter = get(setup, :MaxIter, Inf)

    if isempty(gap_hist)
        # No completed iteration: nothing to judge convergence on.
        status = MOI.OTHER_ERROR
        objval = missing
        objbound = missing
        final_gap = missing
        solve_time = get(inputs, "solve_time", missing)
    else
        objval = UB_hist[end]
        objbound = LB_hist[end]
        final_gap = gap_hist[end]
        solve_time = isempty(cpu_time) ? get(inputs, "solve_time", missing) : cpu_time[end]

        # The loop runs k = 0:MaxIter, so length(gap_hist) == MaxIter + 1 means the
        # iteration limit was hit.
        status = if final_gap <= conv_tol
            MOI.OPTIMAL
        elseif !isempty(cpu_time) && cpu_time[end] >= max_cpu_time
            MOI.TIME_LIMIT
        elseif length(gap_hist) >= max_iter
            MOI.ITERATION_LIMIT
        else
            MOI.OTHER_LIMIT
        end
    end

    dfStatus = DataFrame(Status = status,
        Solve = solve_time,
        Objval = objval,
        Objbound = objbound,
        FinalGap = final_gap)
    CSV.write(joinpath(path, "status.csv"), dfStatus)
    return nothing
end
