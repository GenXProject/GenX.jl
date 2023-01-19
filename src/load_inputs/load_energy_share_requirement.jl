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
    load_energy_share_requirement!(setup::Dict, path::AbstractString, inputs::Dict)

Read input parameters related to mimimum energy share requirement constraints
(e.g. renewable portfolio standard or clean electricity standard policies)
"""
function load_energy_share_requirement!(setup::Dict, path::AbstractString, inputs::Dict)
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    filename = "Energy_share_requirement_slack.csv"
    if isfile(joinpath(path, filename))
        df = load_dataframe(joinpath(path, filename))
        inputs["dfESR_slack"] = df
        inputs["dfESR_slack"][!,:PriceCap] ./= scale_factor # million $/GWh if scaled, $/MWh if not scaled
    end 
    
    filename = "Energy_share_requirement.csv"
    df = load_dataframe(joinpath(path, filename))
    mat = extract_matrix_from_dataframe(df, "ESR")
    inputs["dfESR"] = mat
    inputs["nESR"] = size(mat, 2)

    println(filename * " Successfully Read!")
end
