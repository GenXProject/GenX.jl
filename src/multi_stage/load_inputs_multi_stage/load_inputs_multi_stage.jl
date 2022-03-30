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
	load_inputs_multi_stage(setup::Dict,path::AbstractString)

Loads multi-stage data inputs from multiple input .csv files in path directory and stores variables in a Dict (dictionary) object for use in generate_model() function

inputs:

  * setup - dict object containing setup parameters
  * path - string path to working directory

returns: Dict (dictionary) object containing all data inputs
"""
function load_inputs_multi_stage(setup::Dict,path::AbstractString)

	## Use appropriate directory separator depending on Mac or Windows config
	if Sys.isunix()
		sep = "/"
    elseif Sys.iswindows()
		sep = "\U005c"
    else
        sep = "/"
	end

	## Read input files
	println("Reading multi-stage Input CSV Files")

	## Declare Dict (dictionary) object used to store parameters
	inputs_multi_stage = Dict()

	println("multi-stage CSV Files Successfully Read In From $path$sep")

	return inputs_multi_stage
end
