@doc raw"""
	configure_scip(solver_settings_path::String)

Reads user-specified solver settings from scip\_settings.yml in the directory specified by the string solver\_settings\_path.

Returns a MathOptInterface OptimizerWithAttributes SCIP optimizer instance to be used in the GenX.generate_model() method.

The SCIP optimizer instance is configured with the following default parameters if a user-specified parameter for each respective field is not provided:

 - Dispverblevel = 0
 - limitsgap = 0.05

"""
function configure_scip(solver_settings_path::String)

	solver_settings = YAML.load(open(solver_settings_path))

	# Optional solver parameters ############################################
	Mydisplay_verblevel = 0
		if(haskey(solver_settings, "display_verblevel")) Mydisplay_verblevel = solver_settings["display_verblevel"] end
	Mylimits_gap = 0.05
		if(haskey(solver_settings, "limits_gap")) Mylimits_gap = solver_settings["limits_gap"] end
	########################################################################

	OPTIMIZER = optimizer_with_attributes(SCIP.Optimizer,
		#"display_verblevel" => Mydisplay_verblevel, 
		#"limits_gap" => Mylimits_gap
	)

	return OPTIMIZER
end
