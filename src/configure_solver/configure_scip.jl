"""
GenX: An Configurable Capacity Expansion Model
Copyright (C) 2021,  Massachusetts Institute of Technology
This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
A complete copy of the GNU General Public License v2 (GPLv2) is available
in LICENSE.txt.  Users uncompressing this from an archive may not have
received this license file.  If not, see <http://www.gnu.org/licenses/>.
"""

@doc raw"""
	configure_scip(solver_settings_path::String)

Reads user-specified solver settings from scip\_settings.yml in the directory specified by the string solver\_settings\_path.

Returns a MathOptInterface OptimizerWithAttributes SCIP optimizer instance to be used in the GenX.generate_model() method.

The SCIP optimizer instance is configured with the following default parameters if a user-specified parameter for each respective field is not provided:

 - Dispverblevel = 0
 - limitsgap = 0.05

"""
function configure_scip(solver_settings_path::String, optimizer::Any)

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

    attributes = rename_keys(attributes, key_replacement)

    attributes::Dict{String, Any}
	return optimizer_with_attributes(optimizer, attributes...)
end
