@doc raw"""
	configure_scip(solver_settings_path::String)

Reads user-specified solver settings from scip\_settings.yml in the directory specified by the string solver\_settings\_path.

Returns a `MathOptInterface.OptimizerWithAttributes` SCIP optimizer instance to be used in the `GenX.generate_model()` method.

The SCIP optimizer instance is configured with the following default parameters if a user-specified parameter for each respective field is not provided:

 - Dispverblevel = 0
 - limitsgap = 0.05

"""
function configure_scip(solver_settings_path::String, optimizer::Any)
    solver_settings = YAML.load(open(solver_settings_path))
    solver_settings = convert(Dict{String, Any}, solver_settings)

    default_settings = Dict("Dispverblevel" => 0,
        "limitsgap" => 0.05)
    attributes = merge(default_settings, solver_settings)

    key_replacement = Dict("Dispverblevel" => "display_verblevel",
        "limitsgap" => "limits_gap")

    attributes = rename_keys(attributes, key_replacement)

    attributes::Dict{String, Any}
    return optimizer_with_attributes(optimizer, attributes...)
end
