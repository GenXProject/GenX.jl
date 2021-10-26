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
    load_generators_data_multi_period(setup::Dict, path::AbstractString, sep::AbstractString, inputs::Dict)

Loads multi-period generators data inputs from Generators\_data\_multi\_period.csv files in path directory and stores variables in a Dictionary object for use in generate_model() function.

inputs:
  * setup - Dictonary object containing setup parameters
  * path - String path to working directory
  * sep – String which represents the file directory separator character.
  * inputs – Dictionary object which is the output of the load_input() method.

returns: Dictionary object containing multi-period generators data inputs.
"""
function load_generators_data_multi_period(setup::Dict, path::AbstractString, sep::AbstractString, inputs::Dict)
    # Generator related multi-period inputs
	gen_mp_in = DataFrame(CSV.File(string(path,sep,"Inputs_p1",sep,"Generators_data.csv"), header=true), copycols=true)

    num_periods = setup["MultiPeriodSettingsDict"]["NumPeriods"]

    # Store DataFrame of generators/resources multi-period input data for use in model
	inputs["dfGenMultiPeriod"] = gen_mp_in[!, [Symbol("Resource"), Symbol("Capital_Recovery_Period"), Symbol("Lifetime")]]
	inputs["dfGenMultiPeriod"][!,Symbol("Min_Retired_Cap_MW_p1")] = gen_mp_in[!,Symbol("Min_Retired_Cap_MW")]
	inputs["dfGenMultiPeriod"][!,Symbol("Min_Retired_Charge_Cap_MW_p1")] = gen_mp_in[!,Symbol("Min_Retired_Charge_Cap_MW")]
	inputs["dfGenMultiPeriod"][!,Symbol("Min_Retired_Energy_Cap_MW_p1")] = gen_mp_in[!,Symbol("Min_Retired_Energy_Cap_MW")]
	if setup["ParameterScale"] ==1  # Parameter scaling turned on - adjust values of subset of parameter values
		inputs["dfGenMultiPeriod"][!,Symbol("Min_Retired_Cap_MW_p1")] = inputs["dfGenMultiPeriod"][!,Symbol("Min_Retired_Cap_MW_p1")]/ModelScalingFactor # Convert to GW
		inputs["dfGenMultiPeriod"][!,Symbol("Min_Retired_Charge_Cap_MW_p1")] = inputs["dfGenMultiPeriod"][!,Symbol("Min_Retired_Charge_Cap_MW_p1")]/ModelScalingFactor # Convert to GW
		inputs["dfGenMultiPeriod"][!,Symbol("Min_Retired_Energy_Cap_MW_p1")] = inputs["dfGenMultiPeriod"][!,Symbol("Min_Retired_Energy_Cap_MW_p1")]/ModelScalingFactor # Convert to GW
	end

	for p in 2:num_periods
		gen_mp_in = DataFrame(CSV.File(string(path,sep,"Inputs_p$p",sep,"Generators_data.csv"), header=true), copycols=true)
		inputs["dfGenMultiPeriod"][!,Symbol("Min_Retired_Cap_MW_p$p")] = gen_mp_in[!,Symbol("Min_Retired_Cap_MW")]
		inputs["dfGenMultiPeriod"][!,Symbol("Min_Retired_Charge_Cap_MW_p$p")] = gen_mp_in[!,Symbol("Min_Retired_Charge_Cap_MW")]
		inputs["dfGenMultiPeriod"][!,Symbol("Min_Retired_Energy_Cap_MW_p$p")] = gen_mp_in[!,Symbol("Min_Retired_Energy_Cap_MW")]
		if setup["ParameterScale"] ==1  # Parameter scaling turned on - adjust values of subset of parameter values
			inputs["dfGenMultiPeriod"][!,Symbol("Min_Retired_Cap_MW_p$p")] = inputs["dfGenMultiPeriod"][!,Symbol("Min_Retired_Cap_MW_p$p")]/ModelScalingFactor # Convert to GW
			inputs["dfGenMultiPeriod"][!,Symbol("Min_Retired_Charge_Cap_MW_p$p")] = inputs["dfGenMultiPeriod"][!,Symbol("Min_Retired_Charge_Cap_MW_p$p")]/ModelScalingFactor # Convert to GW
			inputs["dfGenMultiPeriod"][!,Symbol("Min_Retired_Energy_Cap_MW_p$p")] = inputs["dfGenMultiPeriod"][!,Symbol("Min_Retired_Energy_Cap_MW_p$p")]/ModelScalingFactor # Convert to GW
		end
    end

    println("Generators_data_multi_period.csv Successfully Read!")

    return inputs
end
