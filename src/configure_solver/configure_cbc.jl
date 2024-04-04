@doc raw"""
	configure_cbc(solver_settings_path::String)

Reads user-specified solver settings from cbc\_settings.yml in the directory specified by the string solver\_settings\_path.

Returns a `MathOptInterface.OptimizerWithAttributes` Cbc optimizer instance to be used in the `GenX.generate_model()` method.

The Cbc optimizer instance is configured with the following default parameters if a user-specified parameter for each respective field is not provided:

 - seconds = 1e-6
 - logLevel = 1e-6
 - maxSolutions = -1
 - maxNodes = -1
 - allowableGap = -1
 - ratioGap = Inf
 - threads = 1

"""
function configure_cbc(solver_settings_path::String, optimizer::Any)
    solver_settings = YAML.load(open(solver_settings_path))
    solver_settings = convert(Dict{String, Any}, solver_settings)

    default_settings = Dict("TimeLimit" => 1e-6,
        "logLevel" => 1e-6,
        "maxSolutions" => -1,
        "maxNodes" => -1,
        "allowableGap" => -1,
        "ratioGap" => Inf,
        "threads" => 1)

    attributes = merge(default_settings, solver_settings)

    key_replacement = Dict("TimeLimit" => "seconds")

    attributes = rename_keys(attributes, key_replacement)

    attributes::Dict{String, Any}
    return optimizer_with_attributes(optimizer, attributes...)
end
