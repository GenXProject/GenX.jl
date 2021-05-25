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
