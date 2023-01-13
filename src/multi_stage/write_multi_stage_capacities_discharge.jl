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
	function write_multi_stage_capacities_discharge(outpath::String, settings_d::Dict)

This function writes the file capacities\_multi\_stage.csv to the Results directory. This file contains starting resource capacities from the first model stage and end resource capacities for the first and all subsequent model stages.

inputs:

  * outpath – String which represents the path to the Results directory.
  * settings\_d - Dictionary containing settings dictionary configured in the multi-stage settings file multi\_stage\_settings.yml.
"""
function write_multi_stage_capacities_discharge(outpath::String, settings_d::Dict)

    num_stages = settings_d["NumStages"] # Total number of investment planning stages
    capacities_d = Dict()

    for p in 1:num_stages
        inpath = joinpath(outpath, "Results_p$p")
        capacities_d[p] = load_dataframe(joinpath(inpath, "capacity.csv"))
    end

    # Set first column of DataFrame as resource names from the first stage
    df_cap = DataFrame(Resource=capacities_d[1][!, :Resource], Zone=capacities_d[1][!, :Zone])

    # Store starting capacities from the first stage
    df_cap[!, Symbol("StartCap_p1")] = capacities_d[1][!, :StartCap]

    # Store end capacities for all stages
    for p in 1:num_stages
        df_cap[!, Symbol("EndCap_p$p")] = capacities_d[p][!, :EndCap]
    end

    CSV.write(joinpath(outpath, "capacities_multi_stage.csv"), df_cap)

end
