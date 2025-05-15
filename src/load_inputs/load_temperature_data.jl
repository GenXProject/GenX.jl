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

    inputs["pAmbientTemp"] = transpose(Matrix{Float64}(temperature[1:inputs["T"],
        2:(inputs["Z"] + 1)]))

    println(filename * " Successfully Read!")

end