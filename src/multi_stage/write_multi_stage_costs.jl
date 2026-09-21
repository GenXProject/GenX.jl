@doc raw"""
	write_multi_stage_costs(outpath::String, settings_d::Dict)

Writes `costs_multi_stage.csv` and `costs_undiscounted_multi_stage.csv` to the
Results directory, stacking each stage's `Total` column side by side.

The per-stage files written by [`write_costs`](@ref) are already expressed in
their final terms, so this function applies no further scaling. Summing a row
across the stage columns of `costs_multi_stage.csv` therefore gives the cost
over the whole modeling horizon, in present value at the start of the horizon.

  * `costs_multi_stage.csv` – discounted to the start of the horizon; under
    perfect foresight the `cTotal` row sums to the cost of the solution the
    algorithm converged on.
  * `costs_undiscounted_multi_stage.csv` – cash flows over each stage, with no
    time value.

Under myopic foresight both files include the investment annuities that fall
beyond the stage being solved. The myopic objective charges only a single year
of each annuity, so those payments are added back here; without that the two
foresight modes would not be comparable.

inputs:

  * outpath – String which represents the path to the Results directory.
  * settings\_d - Dictionary containing settings dictionary configured in the multi-stage settings file multi\_stage\_settings.yml.
  * stats\_d - Optional dictionary of dual dynamic programming bounds. When given, a warning is issued if the algorithm stopped above its convergence tolerance, since the reported costs then describe the final forward pass rather than an optimal trajectory.
"""
function write_multi_stage_costs(outpath::String, settings_d::Dict;
        stats_d::Union{Dict, Nothing} = nothing)
    num_stages = settings_d["NumStages"]
    warn_if_not_converged(settings_d, stats_d)

    for (stage_file, summary_file) in [
        ("costs.csv", "costs_multi_stage.csv"),
        ("costs_undiscounted.csv", "costs_undiscounted_multi_stage.csv")]
        paths = [joinpath(outpath, "results_p$p", stage_file) for p in 1:num_stages]
        present = isfile.(paths)
        # None present is normal: cost output can be switched off entirely.
        # Some present is not, and silently writing no summary would hide it.
        if !all(present)
            any(present) && @warn "Not writing $summary_file: $stage_file is " *
                  "missing for stage(s) $(findall(.!present)) but present for " *
                  "the others."
            continue
        end

        costs_d = [load_dataframe(f) for f in paths]
        df_costs = DataFrame(Costs = costs_d[1][!, :Costs])
        for p in 1:num_stages
            df_costs[!, Symbol("TotalCosts_p$p")] = costs_d[p][!, :Total]
        end
        CSV.write(joinpath(outpath, summary_file), df_costs)
    end
end

"""
    warn_if_not_converged(settings_d::Dict, stats_d::Union{Dict, Nothing})

Warn when dual dynamic programming stopped before closing the optimality gap.

`run_ddp` returns the models it has when it hits its iteration limit, and the
stage costs are then reported the same way as for a converged run. They
describe the last forward pass rather than an optimal trajectory, so summing
them across stages does not give the cost of an optimal plan.
"""
function warn_if_not_converged(settings_d::Dict, stats_d::Union{Dict, Nothing})
    stats_d === nothing && return nothing
    get(settings_d, "Myopic", 0) == 0 || return nothing
    ub = get(stats_d, "UPPER_BOUNDS", nothing)
    lb = get(stats_d, "LOWER_BOUNDS", nothing)
    (ub === nothing || lb === nothing || isempty(ub) || isempty(lb)) && return nothing

    # The same test run_ddp loops on, applied to the bounds it finished with.
    gap = (last(ub) - last(lb)) / last(lb)
    if gap > settings_d["ConvergenceTolerance"]
        @warn "Dual dynamic programming stopped with a relative gap of " *
              "$(round(gap, sigdigits = 3)), above the ConvergenceTolerance " *
              "of $(settings_d["ConvergenceTolerance"]). The reported " *
              "multi-stage costs describe the final forward pass, not an " *
              "optimal trajectory."
    end
    return nothing
end
