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
	load_co2_credit(setup::Dict, path::AbstractString, inputs_co2_credit::Dict)

Function for reading input parameters related to tax credit for captured CO$_2$ 
"""
function load_co2_credit(setup::Dict, path::AbstractString, inputs_co2_credit::Dict)

    inputs_co2_credit["dfCO2Credit"] = DataFrame(CSV.File(joinpath(path, "CO2_credit.csv"), header = true), copycols = true)
    inputs_co2_credit["dfCO2Credit"][!, :CO2Credit] = convert(Array{Float64}, inputs_co2_credit["dfCO2Credit"][!, :CO2Credit])

    # scale parameters if ModelScalingFactor is applied 
    # convert the unit from $/ton to Million$/kton
    if setup["ParameterScale"] == 1
        inputs_co2_credit["dfCO2Credit"][!, :CO2Credit] ./= ModelScalingFactor
    end

    println("CO2_credit.csv Successfully Read!")
    return inputs_co2_credit
end
