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
	function write_multi_stage_network_expansion(outpath::String, settings_d::Dict)

This function writes the file network\_expansion\_multi\_stage.csv to the Results directory. This file contains new transmission capacities for each modeled transmission line for the first and all subsequent model stages.

inputs:

  * outpath – String which represents the path to the Results directory.
  * settings\_d - Dictionary containing settings dictionary configured in the multi-stage settings file multi\_stage\_settings.yml.
"""
function write_multi_stage_network_expansion(outpath::String, settings_d::Dict)
    # [To Be Completed] Should include discounted NE costs and capacities for each model period as well as initial and intermediate capacity sums.
    num_stages = settings_d["NumStages"] # Total number of investment planning stages
    trans_capacities_d = Dict()

    for p in 1:num_stages
        inpath = joinpath(outpath, "Results_p$p")
        trans_capacities_d[p] = DataFrame(CSV.File(joinpath(inpath, "network_expansion.csv"), header=true), copycols=true)
    end

    # Set first column of output DataFrame as line IDs
    df_trans_cap = DataFrame(Line=trans_capacities_d[1][!, :Line])

    # Store new transmission capacities for all stages
    for p in 1:num_stages
        df_trans_cap[!, Symbol("New_Trans_Capacity_p$p")] = trans_capacities_d[p][!, :New_Trans_Capacity]
    end

    CSV.write(joinpath(outpath, "network_expansion_multi_stage.csv"), df_trans_cap)
end
