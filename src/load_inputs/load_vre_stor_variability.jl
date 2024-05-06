@doc raw"""
	load_vre_stor_variability!(setup::Dict, path::AbstractString, inputs::Dict)

Read input parameters related to hourly maximum capacity factors for the solar PV 
	(DC capacity factors) component and wind (AC capacity factors) component of co-located
	generators
"""
function load_vre_stor_variability!(setup::Dict, path::AbstractString, inputs::Dict)

    # Hourly capacity factors
    TDR_directory = joinpath(path, setup["TimeDomainReductionFolder"])
    # if TDR is used, my_dir = TDR_directory, else my_dir = "system"
    my_dir = get_systemfiles_path(setup, TDR_directory, path)

    filename1 = "Vre_and_stor_solar_variability.csv"
    vre_stor_solar = load_dataframe(joinpath(my_dir, filename1))

    filename2 = "Vre_and_stor_wind_variability.csv"
    vre_stor_wind = load_dataframe(joinpath(my_dir, filename2))

    all_resources = inputs["RESOURCE_NAMES"]

    function ensure_column_zeros!(vre_stor_df, all_resources)
        existing_variability = names(vre_stor_df)
        for r in all_resources
            if r ∉ existing_variability
                ensure_column!(vre_stor_df, r, 0.0)
            end
        end
    end

    ensure_column_zeros!(vre_stor_solar, all_resources)
    ensure_column_zeros!(vre_stor_wind, all_resources)

    # Reorder DataFrame to R_ID order (order provided in Vre_and_stor_data.csv)
    select!(vre_stor_solar, [:Time_Index; Symbol.(all_resources)])
    select!(vre_stor_wind, [:Time_Index; Symbol.(all_resources)])

    # Maximum power output and variability of each energy resource
    inputs["pP_Max_Solar"] = transpose(Matrix{Float64}(vre_stor_solar[1:inputs["T"],
        2:(inputs["G"] + 1)]))
    inputs["pP_Max_Wind"] = transpose(Matrix{Float64}(vre_stor_wind[1:inputs["T"],
        2:(inputs["G"] + 1)]))

    println(filename1 * " Successfully Read!")
    println(filename2 * " Successfully Read!")
end
