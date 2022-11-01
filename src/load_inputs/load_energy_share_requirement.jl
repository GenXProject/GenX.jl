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
    filename = "Energy_share_requirement.csv"
    df = DataFrame(CSV.File(joinpath(path, filename), header=true), copycols=true)

    f = s -> startswith(s, "ESR")
    columns = names(df)
    first_col = findfirst(f, columns)
    last_col = findlast(f, columns)

    inputs["dfESR"] = Matrix{Float64}(df[:, first_col:last_col])
    inputs["nESR"] = count(f, columns)

    println(filename * " Successfully Read!")
end
