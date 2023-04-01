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

@doc raw"""Run the GenX time domain reduction on the given case folder

case - folder for the case
stage_id - possibly something to do with MultiStage
verbose - print extra outputs

This function overwrites the time-domain-reduced inputs if they already exist.

"""
function run_timedomainreduction!(case::AbstractString; stage_id=-99, verbose=false)
    settings_path = get_settings_path(case) #Settings YAML file path
    genx_settings = get_settings_path(case, "genx_settings.yml") #Settings YAML file path
    mysetup = configure_settings(genx_settings) # mysetup dictionary stores settings and GenX-specific parameters

    cluster_inputs(case, settings_path, mysetup, stage_id, verbose)
    return
end

