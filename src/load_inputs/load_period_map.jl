@doc raw"""
	load_period_map!(setup::Dict, path::AbstractString, inputs::Dict)

Read input parameters related to mapping of representative time periods to full chronological time series
"""
function load_period_map!(setup::Dict, path::AbstractString, inputs::Dict)
    period_map = "Period_map.csv"
    data_directory = joinpath(path, setup["TimeDomainReductionFolder"])
    if setup["TimeDomainReduction"] == 1 && isfile(joinpath(data_directory, period_map))  # Use Time Domain Reduced data for GenX
        my_dir = data_directory
    else
        # If TDR is not used, then use the "system" directory specified in the setup
        my_dir = joinpath(path, setup["SystemFolder"])
    end
    file_path = joinpath(my_dir, period_map)
    inputs["Period_Map"] = load_dataframe(file_path)

    println(period_map * " Successfully Read!")
end
