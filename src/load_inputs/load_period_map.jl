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
	load_period_map(setup::Dict,path::AbstractString, inputs::Dict)

Function for reading input parameters related to mapping of representative time periods to full chronological time series
"""
function load_period_map(setup::Dict,path::AbstractString, inputs::Dict)
	data_directory = joinpath(path, setup["TimeDomainReductionFolder"])
	if setup["TimeDomainReduction"] == 1  && isfile(joinpath(data_directory,"Period_map.csv"))  # Use Time Domain Reduced data for GenX
		inputs["Period_Map"] = DataFrame(CSV.File(joinpath(data_directory,"Period_map.csv"), header=true), copycols=true)
	else
		inputs["Period_Map"] = DataFrame(CSV.File(joinpath(path,"Period_map.csv"), header=true), copycols=true)
	end

	println("Period_map.csv Successfully Read!")

	return inputs
end
