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
    write_settings(outpath::AbstractString, settings_d::Dict)

Function for writing the multi-stage settings file to the output path for future reference.
"""
function write_settings(outpath::AbstractString, settings_d::Dict)
    multi_stage_settings_d = settings_d["MultiStageSettingsDict"]
    YAML.write_file(joinpath(outpath, "genx_settings.yml"), settings_d)
    YAML.write_file(joinpath(outpath, "multi_stage_settings.yml"), multi_stage_settings_d)
end
