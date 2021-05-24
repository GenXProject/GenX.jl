@doc raw"""
	thermal(EP::Model, inputs::Dict, UCommit::Int, Reserves::Int)

The thermal module creates decision variables, expressions, and constraints related to thermal power plants e.g. coal, oil or natural gas steam plants, natural gas combined cycle and combustion turbine plants, nuclear, hydrogen combustion etc.

This module uses the following 'helper' functions in separate files: thermal_commit() for thermal resources subject to unit commitment decisions and constraints (if any) and thermal_no_commit() for thermal resources not subject to unit commitment (if any).
"""

function thermal(EP::Model, inputs::Dict, UCommit::Int, Reserves::Int)

	THERM_COMMIT = inputs["THERM_COMMIT"]
	THERM_NO_COMMIT = inputs["THERM_NO_COMMIT"]

	if !isempty(THERM_COMMIT)
		EP = thermal_commit(EP::Model, inputs::Dict, Reserves::Int)
	end

	if !isempty(THERM_NO_COMMIT)
		EP = thermal_no_commit(EP::Model, inputs::Dict, Reserves::Int)
	end

	return EP
end