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
	write_status(path::AbstractString, sep::AbstractString, inputs::Dict, EP::Model)

Function for writing the final solve status of the optimization problem solved
"""
function write_status(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)

	# https://jump.dev/MathOptInterface.jl/v0.9.10/apireference/#MathOptInterface.TerminationStatusCode
	status = termination_status(EP)

	# Note: Gurobi excludes constants from solver reported objective function value - MIPGap calculated may be erroneous
	if (setup["UCommit"] == 0 || setup["UCommit"] == 2)
		dfStatus = DataFrame(Status = status, Solve = inputs["solve_time"],
			Objval = objective_value(EP))
	else
		dfStatus = DataFrame(Status = status, Solve = inputs["solve_time"],
			Objval = objective_value(EP), Objbound= objective_bound(EP),FinalMIPGap =(objective_value(EP) -objective_bound(EP))/objective_value(EP) )
	end
	CSV.write(string(path,sep,"status.csv"),dfStatus)
end
