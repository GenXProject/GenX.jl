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
	load_co2_load_side_emission_rate_cap(setup::Dict, path::AbstractString, sep::AbstractString, inputs_co2::Dict)

Function for reading input parameters related to CO$_2$ load-side emission rate cap constraints
"""
function load_co2_load_side_emission_rate_cap(setup::Dict, path::AbstractString, inputs_co2::Dict)
    inputs_co2["dfCO2Cap_LoadRate_slack"] = DataFrame(CSV.File(joinpath(path,"CO2_loadrate_cap_slack.csv"), header=true), copycols=true)
    if setup["ParameterScale"] == 1
		inputs_co2["dfCO2Cap_LoadRate_slack"][!,:PriceCap] ./= ModelScalingFactor #from $/ton to million$/kton.
	end
    inputs_co2["NCO2LoadRateCap"] = size(collect(skipmissing(inputs_co2["dfCO2Cap_LoadRate_slack"][!,:CO2_LoadRate_Constraint])),1)

    # Definition of Cap requirements by zone (as Max Mtons per MWh)
    inputs_co2["dfCO2Cap_LoadRate"] = DataFrame(CSV.File(joinpath(path, "CO2_loadrate_cap.csv"), header = true), copycols = true)

    println("CO2_loadrate_cap.csv Successfully Read!")
    return inputs_co2
end
