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

@doc raw"""
    load_process_variability!(filepath::AbstractString, all_resources::Vector{T},
            inputs::Dict, maxpower_key::String) where {T <: AbstractString}

Load and process variability data for different VRE_storage components.

This function reads a CSV file specified by `filepath`, containing variability 
data for different VRE_storage components. The function then sets the variability
to zero for resources not in the file, selects the resources in the order of
`all_resources`, and stores the maximum power output and variability of each
energy resource in the `inputs` dictionary.

# Arguments
- `filepath::AbstractString`: Path to the CSV file with variability data.
- `all_resources::Vector{T}`: Vector containing all the energy resources.
- `inputs::Dict`: Dictionary to store input data.
- `maxpower_key::String`: Identifier for the key for the maximum power 
output in the `inputs` dict.
"""
function load_process_variability!(filepath::AbstractString, all_resources::Vector{T},
        inputs::Dict, maxpower_key::String) where {T <: AbstractString}
    vre_stor = load_dataframe(filepath)

    # Set variability to zero for resources not in the file
    ensure_column_zeros!(vre_stor, all_resources)

    # select the resources in the order of all_resources
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
