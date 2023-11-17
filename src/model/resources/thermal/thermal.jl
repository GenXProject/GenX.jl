@doc raw"""
	thermal!(EP::Model, inputs::Dict, setup::Dict)
The thermal module creates decision variables, expressions, and constraints related to thermal power plants e.g. coal, oil or natural gas steam plants, natural gas combined cycle and combustion turbine plants, nuclear, hydrogen combustion etc.
This module uses the following 'helper' functions in separate files: ```thermal_commit()``` for thermal resources subject to unit commitment decisions and constraints (if any) and ```thermal_no_commit()``` for thermal resources not subject to unit commitment (if any).
"""
function thermal!(EP::Model, inputs::Dict, setup::Dict)
	dfGen = inputs["dfGen"]

	T = inputs["T"]     # Number of time steps (hours)
	Z = inputs["Z"]     # Number of zones

	THERM_COMMIT = inputs["THERM_COMMIT"]
	THERM_NO_COMMIT = inputs["THERM_NO_COMMIT"]
	THERM_ALL = inputs["THERM_ALL"]

	dfGen = inputs["dfGen"]

	if !isempty(THERM_COMMIT)
		thermal_commit!(EP, inputs, setup)
	end

	if !isempty(THERM_NO_COMMIT)
		thermal_no_commit!(EP, inputs, setup)
	end

end
