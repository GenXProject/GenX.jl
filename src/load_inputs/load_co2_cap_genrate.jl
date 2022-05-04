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
	load_co2_generation_side_emission_rate_cap(setup::Dict, path::AbstractString, sep::AbstractString, inputs_co2::Dict)

Function for reading input parameters related to CO$_2$ generation-side emission rate cap constraints
"""
function load_co2_generation_side_emission_rate_cap(setup::Dict, path::AbstractString, inputs_co2::Dict)
    # Definition of Cap requirements by zone (as Max Mtons per MWh)
    inputs_co2["dfCO2Cap_GenRate"] = DataFrame(CSV.File(joinpath(path, "CO2_genrate_cap.csv"), header = true), copycols = true)

    # determine the number of caps
    cap = count(s -> startswith(String(s), "CO_2_Cap_Zone"), names(inputs_co2["dfCO2Cap_GenRate"]))
    inputs_co2["NCO2GenRateCap"] = cap

    # read in zone-cap membership
    first_col = findall(s -> s == "CO_2_Cap_Zone_1", names(inputs_co2["dfCO2Cap_GenRate"]))[1]
    last_col = findall(s -> s == "CO_2_Cap_Zone_$cap", names(inputs_co2["dfCO2Cap_GenRate"]))[1]
    inputs_co2["dfCO2GenRateCapZones"] = Matrix{Float64}(inputs_co2["dfCO2Cap_GenRate"][:, first_col:last_col])

    # read in CO2 emissions cap in metric tons/MWh, with or without Scaling, the unit of emission cap (load rate) are both ton/MWh.
    first_col = findall(s -> s == "CO_2_Max_GenRate_1", names(inputs_co2["dfCO2Cap_GenRate"]))[1]
    last_col = findall(s -> s == "CO_2_Max_GenRate_$cap", names(inputs_co2["dfCO2Cap_GenRate"]))[1]
    inputs_co2["dfMaxCO2GenRate"] = Matrix{Float64}(inputs_co2["dfCO2Cap_GenRate"][:, first_col:last_col])

    println("CO2_genrate_cap.csv Successfully Read!")
    return inputs_co2
end
