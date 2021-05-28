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
    configure_cbc(solver_settings_path::String)

This is th Cbc Configuration
"""

function configure_cbc(solver_settings_path::String)

	solver_settings = YAML.load(open(solver_settings_path))

	# Optional solver parameters ############################################
	Myseconds = 1e-6
		if(haskey(solver_settings, "seconds")) Myseconds = solver_settings["seconds"] end
	MylogLevel = 1e-6
		if(haskey(solver_settings, "logLevel")) MylogLevel = solver_settings["logLevel"] end
	MymaxSolutions = -1
		if(haskey(solver_settings, "maxSolutions")) MymaxSolutions = solver_settings["maxSolutions"] end
	MymaxNodes = -1
		if(haskey(solver_settings, "maxNodes")) MymaxNodes = solver_settings["maxNodes"] end
	MyallowableGap = -1
		if(haskey(solver_settings, "allowableGap")) MyallowableGap = solver_settings["allowableGap"] end
	MyratioGap = Inf
		if(haskey(solver_settings, "ratioGap")) MyratioGap = solver_settings["ratioGap"] end
	Mythreads = 1e-4
		if(haskey(solver_settings, "threads")) MyMIPGap = solver_settings["threads"] end
	########################################################################

	OPTIMIZER = optimizer_with_attributes(Cbc.Optimizer,
		"seconds" => Myseconds,
		"logLevel" => MylogLevel,
		"maxSolutions" => MymaxSolutions,
		"maxNodes" => MymaxNodes,
		"allowableGap" => MyallowableGap,
		"ratioGap" => MyratioGap,
		"threads" => Mythreads
	)

	return OPTIMIZER
end
