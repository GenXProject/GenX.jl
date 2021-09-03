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
    load_network_data_multi_period(setup::Dict, path::AbstractString, sep::AbstractString, inputs::Dict)

Loads multi-period network data inputs from Network_multi_period.csv in path directory and stores variables in a Dictionary object for use in generate_model() function

inputs:
  * setup - Dictonary object containing setup parameters
  * path - String path to working directory
  * sep – String which represents the file directory separator character.
  * inputs – Dictionary object which is the output of the load_input() method.

returns: Dictionary object containing multi-period network data inputs.
"""
function load_network_data_multi_period(setup::Dict, path::AbstractString, sep::AbstractString, inputs::Dict)

    # Network zones inputs and Network topology inputs
    network_mp = DataFrame(CSV.File(string(path,sep,"Network_multi_period.csv"), header=true), copycols=true)
    
    num_periods = setup["MultiPeriodSettingsDict"]["NumPeriods"]
    inputs["dfNetworkMultiPeriod"] = network_mp

    if setup["ParameterScale"] == 1
        for p in 1:num_periods
            inputs["pLine_Max_Flow_Possible_MW_p$p"] = network_mp[!,Symbol("Line_Max_Flow_Possible_MW_p$p")]/ModelScalingFactor # Convert to GW
        end
    end

    # To-Do: Error handling 
    # 1.) pLine_Max_Flow_Possible_MW must be monotonically increasing (greater than or equal to)

    println("Network_multi_period.csv Successfully Read!")

    return inputs
end
