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
"""
function write_multi_stage_costs(outpath::String, settings_d::Dict)
    num_stages = settings_d["NumStages"]

    for (stage_file, summary_file) in [
        ("costs.csv", "costs_multi_stage.csv"),
        ("costs_undiscounted.csv", "costs_undiscounted_multi_stage.csv")]
        paths = [joinpath(outpath, "results_p$p", stage_file) for p in 1:num_stages]
        all(isfile, paths) || continue

        costs_d = [load_dataframe(f) for f in paths]
        df_costs = DataFrame(Costs = costs_d[1][!, :Costs])
        for p in 1:num_stages
            df_costs[!, Symbol("TotalCosts_p$p")] = costs_d[p][!, :Total]
        end
        CSV.write(joinpath(outpath, summary_file), df_costs)
    end
end
