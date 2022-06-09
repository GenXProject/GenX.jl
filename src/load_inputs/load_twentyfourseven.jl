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
	load_twentyfourseven(setup::Dict, path::AbstractString, inputs_tfs::Dict)

Function for reading input parameters related to 24-7 constraints
"""
function load_twentyfourseven(setup::Dict, path::AbstractString, inputs_tfs::Dict)
    inputs_tfs["TFS"] = DataFrame(CSV.File(joinpath(path, "RPSH.csv"), header = true), copycols = true)
    if setup["ParameterScale"] == 1
        inputs_tfs["TFS"][!,:Penalty] ./= ModelScalingFactor
    end    
    # determine the number of TFS requirement
    NumberofTFS = size(collect(inputs_tfs["TFS"][:, :Policy_ID]), 1)
    inputs_tfs["NumberofTFS"] = NumberofTFS
    println("RPSH.csv Successfully Read!")

    tfs_load_in = DataFrame(CSV.File(joinpath(path, "RPSH_Load_data.csv"), header = true), copycols = true)
    first_col = findall(s -> s == "Load_MW_RPSH_1", names(tfs_load_in))[1]
    last_col = findall(s -> s == "Load_MW_RPSH_$NumberofTFS", names(tfs_load_in))[1]
    inputs_tfs["TFS_Load"] = Matrix{Float64}(tfs_load_in[:, first_col:last_col])
    
    if setup["ParameterScale"] == 1
        inputs_tfs["TFS_Load"] = inputs_tfs["TFS_Load"]/ModelScalingFactor
    end

    println("RPSH_Load_data.csv Successfully Read!")

    tfs_dirtiness_in = DataFrame(CSV.File(joinpath(path, "RPSH_SFDT.csv"), header = true), copycols = true)
    first_col = findall(s -> s == "RPSH_SFDT_1", names(tfs_dirtiness_in))[1]
    last_col = findall(s -> s == "RPSH_SFDT_$NumberofTFS", names(tfs_dirtiness_in))[1]
    inputs_tfs["TFS_SFDT"] = Matrix{Float64}(tfs_dirtiness_in[:, first_col:last_col])
    println("RPSH_SFDT.csv Successfully Read!")

    if (NumberofTFS) > 1
        inputs_tfs["TFS_Network"] = DataFrame(CSV.File(joinpath(path, "RPSH_Network.csv"), header = true), copycols = true)
        NumberofTFSPath = size(collect(inputs_tfs["TFS_Network"][:, :RPSH_PathID]), 1)
        inputs_tfs["NumberofTFSPath"] = NumberofTFSPath
        if setup["ParameterScale"] == 1
            inputs_tfs["TFS_Network"][:, :MaxFlow_Forward] = inputs_tfs["TFS_Network"][:, :MaxFlow_Forward] ./ ModelScalingFactor
            inputs_tfs["TFS_Network"][:, :MaxFlow_Backward] = inputs_tfs["TFS_Network"][:, :MaxFlow_Backward] ./ ModelScalingFactor
            inputs_tfs["TFS_Network"][:, :HurdleRate_Forward] = inputs_tfs["TFS_Network"][:, :HurdleRate_Forward] ./ ModelScalingFactor
            inputs_tfs["TFS_Network"][:, :HurdleRate_Backward] = inputs_tfs["TFS_Network"][:, :HurdleRate_Backward] ./ ModelScalingFactor
        end        
        println("RPSH_Network.csv Successfully Read!")
    end

    return inputs_tfs
end
