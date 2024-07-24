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

    # Resource names
    all_resources = inputs["RESOURCE_NAMES"]

    # SOLAR VARIABILITY
    if !isempty(inputs["VS_SOLAR"])
        filename = "Vre_and_stor_solar_variability.csv"
        filepath = joinpath(my_dir, filename)
        load_process_variability!(filepath, all_resources, inputs, "Solar")
    end

    # WIND VARIABILITY
    if !isempty(inputs["VS_WIND"])
        filename = "Vre_and_stor_wind_variability.csv"
        filepath = joinpath(my_dir, filename)
        load_process_variability!(filepath, all_resources, inputs, "Wind")
    end

    return nothing
end

function load_process_variability!(filepath::AbstractString, all_resources::Vector{T},
        inputs::Dict, maxpower_key::String) where {T <: AbstractString}
    vre_stor = load_dataframe(filepath)

    # Set variability to zero for resources not in the file
    ensure_column_zeros!(vre_stor, all_resources)

    # Reorder DataFrame to R_ID order (order provided in Vre_and_stor_data.csv)
    select!(vre_stor, [:Time_Index; Symbol.(all_resources)])

    # Maximum power output and variability of each energy resource
    inputs["pP_Max" * "_" * maxpower_key] = transpose(Matrix{Float64}(vre_stor[
        1:inputs["T"], 2:(inputs["G"] + 1)]))

    println(filepath * " Successfully Read!")
end

function ensure_column_zeros!(vre_stor_df, all_resources)
    existing_variability = names(vre_stor_df)
    for r in all_resources
        if r ∉ existing_variability
            ensure_column!(vre_stor_df, r, 0.0)
        end
    end
end
