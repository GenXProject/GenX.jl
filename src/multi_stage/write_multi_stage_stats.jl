"""
GenX: An Configurable Capacity Expansion Model
Copyright (C) 2021,  Massachusetts Institute of Technology
This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
A complete copy of the GNU General Public License v2 (GPLv2) is available
in LICENSE.txt.  Users uncompressing this from an archive may not have
received this license file.  If not, see <http://www.gnu.org/licenses/>.
"""

@doc raw"""
	function write_multi_stage_stats(outpath::String, stats_d::Dict)

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
    df_stats = DataFrame(Iteration_Number=iteration_count_a,
        Seconds=times_a,
        Upper_Bound=upper_bounds_a,
        Lower_Bound=lower_bounds_a,
        Relative_Gap=realtive_gap_a)

    CSV.write(joinpath(outpath, "stats_multi_stage.csv"), df_stats)

end
