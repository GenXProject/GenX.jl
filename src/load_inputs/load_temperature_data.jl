@doc raw"""
	load_generators_variability!(setup::Dict, path::AbstractString, inputs::Dict)

Read input parameters related to hourly maximum capacity factors for generators, storage, and flexible demand resources
"""
function load_ambient_temperature!(setup::Dict, path::AbstractString, inputs::Dict)

    # Hourly capacity factors
    TDR_directory = joinpath(path, setup["TimeDomainReductionFolder"])
    # if TDR is used, my_dir = TDR_directory, else my_dir = "system"
    my_dir = get_systemfiles_path(setup, TDR_directory, path)

    filename = "Ambient_temperature_data.csv"
    temperature = load_dataframe(joinpath(my_dir, filename))

    expected_timesteps = inputs["T"]
    available_timesteps = nrow(temperature)
    expected_columns = inputs["Z"] + 1 # Time_Index + one column per zone
    available_columns = ncol(temperature)

    if available_columns < expected_columns
        error("""Critical error in time series construction:
                 $filename has fewer columns than expected.

                 Expected columns:   $expected_columns (Time_Index + $(inputs["Z"]) zone columns)
                 Available columns:  $available_columns

                 Ensure $filename includes Time_Index and one ambient temperature column per zone
                 using the naming pattern Ambient_temperature_z1, Ambient_temperature_z2, ...
              """)
    end

    if available_timesteps < expected_timesteps
        error("""Critical error in time series construction:
                 $filename has fewer rows than Demand_data.csv.

                 Expected timesteps:   $expected_timesteps
                     (set by Time_Index in Demand_data.csv)
                 Available timesteps:  $available_timesteps
                     (rows in $filename)

                 All hourly input files must have matching time bases. If using 52 weeks,
                 provide 8736 rows consistently across Demand_data.csv, Generators_variability.csv,
                 Fuels_data.csv, Computing_demand_data.csv (if enabled), and $filename.
                 Note: TimeDomainReduction WeightTotal does not set input row counts.
              """)
    elseif available_timesteps > expected_timesteps
        @warn("$filename has more rows than Demand_data.csv; truncating to $expected_timesteps rows to match the model time basis.")
    end

    inputs["pAmbientTemp"] = transpose(Matrix{Float64}(temperature[1:expected_timesteps,
        2:(inputs["Z"] + 1)]))

    println(filename * " Successfully Read!")

end