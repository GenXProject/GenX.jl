@doc raw"""
  write_multi_stage_stats(outpath::String, stats_d::Dict)

This function writes the file stats\_multi\_stage.csv. to the Results directory. This file contains the runtime, upper bound, lower bound, and relative optimality gap for each iteration of the DDP algorithm.

inputs:

  * outpath – String which represents the path to the Results directory.
  * stats\_d – Dictionary which contains the run time, upper bound, and lower bound of each DDP iteration.
"""
function write_multi_stage_stats(outpath::String, stats_d::Dict)
    times_a = stats_d["TIMES"] # Time (seconds) of each iteration
    upper_bounds_a = stats_d["UPPER_BOUNDS"] # Upper bound of each iteration
    lower_bounds_a = stats_d["LOWER_BOUNDS"] # Lower bound of each iteration

    # Create an array of numbers 1 through total number of iterations
    iteration_count_a = collect(1:length(times_a))

    realtive_gap_a = (upper_bounds_a .- lower_bounds_a) ./ lower_bounds_a

    # Construct dataframe where first column is iteration number, second is iteration time
    df_stats = DataFrame(Iteration_Number = iteration_count_a,
        Seconds = times_a,
        Upper_Bound = upper_bounds_a,
        Lower_Bound = lower_bounds_a,
        Relative_Gap = realtive_gap_a)

    CSV.write(joinpath(outpath, "stats_multi_stage.csv"), df_stats)
end
