function load_resources_data!(setup::Dict, path::AbstractString, inputs_gen::Dict, fuel_costs::Dict, fuel_CO2::Dict)
    if isfile(joinpath(path, "Generators_data.csv"))
        Base.depwarn(
            "The `Generators_data.csv` file will be deprecated in a future release. " *
            "Please use the new interface for generators creation, and see the documentation for additional details.",
            :load_resources_data!, force=true)
        load_generators_data!(setup, path, inputs_gen, fuel_costs, fuel_CO2)
    else
        # load all the resources data
    end
    return nothing
end