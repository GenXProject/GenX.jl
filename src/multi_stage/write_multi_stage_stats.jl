_get_multi_stage_stats_filename() = "stats_multi_stage.csv"
function _get_multi_stage_stats_header()
    ["Iteration_Number", "Seconds", "Upper_Bound", "Lower_Bound", "Relative_Gap"]
end

@doc raw"""
  write_multi_stage_stats(outpath::String, stats_d::Dict)

This function writes the file stats\_multi\_stage.csv. to the Results directory. This file contains the runtime, upper bound, lower bound, and relative optimality gap for each iteration of the DDP algorithm.

inputs:

  * outpath – String which represents the path to the Results directory.
  * stats\_d – Dictionary which contains the run time, upper bound, and lower bound of each DDP iteration.
"""
function write_multi_stage_stats(outpath::String, stats_d::Dict)
    filename = _get_multi_stage_stats_filename()

    # don't overwrite existing file
    isfile(joinpath(outpath, filename)) && return nothing

    times_a = stats_d["TIMES"] # Time (seconds) of each iteration
    upper_bounds_a = stats_d["UPPER_BOUNDS"] # Upper bound of each iteration
    lower_bounds_a = stats_d["LOWER_BOUNDS"] # Lower bound of each iteration

    # Create an array of numbers 1 through total number of iterations
    iteration_count_a = collect(1:length(times_a))

    realtive_gap_a = (upper_bounds_a .- lower_bounds_a) ./ lower_bounds_a

    # Construct dataframe where first column is iteration number, second is iteration time
    header = _get_multi_stage_stats_header()
    df_stats = DataFrame(header .=>
        [iteration_count_a, times_a, upper_bounds_a, lower_bounds_a, realtive_gap_a])

    CSV.write(joinpath(outpath, filename), df_stats)
    return nothing
end

@doc raw"""
    create_multi_stage_stats_file(outpath::String)

Create an empty CSV file in the specified output directory with the filename `stats_multi_stage.csv`. 
The file contains the columns defined in `_get_multi_stage_stats_header()`.
The function first generates the filename and header using `_get_multi_stage_stats_filename()` and 
`_get_multi_stage_stats_header()` respectively. It then creates a DataFrame with column names as headers and 
writes it into a CSV file in the specified output directory.

# Arguments
- `outpath::String`: The output directory where the statistics file will be written.

# Returns
- Nothing. A CSV file is written to the `outpath`.
"""
function create_multi_stage_stats_file(outpath::String)
    filename = _get_multi_stage_stats_filename()
    header = _get_multi_stage_stats_header()
    df_stats = DataFrame([col_name => Float64[] for col_name in header])
    CSV.write(joinpath(outpath, filename), df_stats)
end

@doc raw"""
    update_multi_stage_stats_file(outpath::String, ic::Int64, upper_bound::Float64, lower_bound::Float64, iteration_time::Float64; new_row::Bool=false)

Update a multi-stage statistics file.

# Arguments
- `outpath::String`: The output directory where the statistics file will be written.
- `ic::Int64`: The iteration count.
- `upper_bound::Float64`: The upper bound value.
- `lower_bound::Float64`: The lower bound value.
- `iteration_time::Float64`: The iteration time value.
- `new_row::Bool=false`: Optional argument to determine whether to append a new row (if true) or update the current row (if false).

The function first checks if the file exists. If it does not, it creates a new one. 
Then, it reads the statistics from the existing file into a DataFrame. 
It calculates the relative gap based on the upper and lower bounds, and either appends a new row or updates the current row based on the `new_row` argument. 
Finally, it writes the updated DataFrame back to the file.

# Returns
- Nothing. A CSV file is updated or created at the `outpath`.
"""
function update_multi_stage_stats_file(outpath::String, ic::Int64, upper_bound::Float64,
        lower_bound::Float64, iteration_time::Float64; new_row::Bool = false)
    filename = _get_multi_stage_stats_filename()

    # If the file does not exist, create it
    if !isfile(joinpath(outpath, filename))
        create_multi_stage_stats_file(outpath)
    end

    df_stats = CSV.read(joinpath(outpath, filename), DataFrame, types = Float64)

    relative_gap = (upper_bound - lower_bound) / lower_bound

    new_values = [ic, iteration_time, upper_bound, lower_bound, relative_gap]

    # If new_row is true, append the new values to the end of the dataframe
    # otherwise, update the row at index ic
    new_row ? push!(df_stats, new_values) : (df_stats[ic, :] = new_values)

    CSV.write(joinpath(outpath, filename), df_stats)
    return nothing
end
