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
	write_co2_cap(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for reporting carbon price associated with carbon cap constraints.

"""
function write_co2_cap(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    dfCO2Price = DataFrame(CO2_Cap = [Symbol("CO2_Cap_$cap") for cap = 1:inputs["NCO2Cap"]],
                            CO2_Price = (-1) * (dual.(EP[:cCO2Emissions_systemwide])))
    if setup["ParameterScale"] == 1
        dfCO2Price.CO2_Price .*= ModelScalingFactor # Convert Million$/kton to $/ton
    end
	if haskey(inputs, "dfCO2Cap_slack")
		dfCO2Price[!,:CO2_Mass_Slack] = convert(Array{Float64}, value.(EP[:vCO2Cap_slack]))
		dfCO2Price[!,:CO2_Penalty] = convert(Array{Float64}, value.(EP[:eCCO2Cap_slack]))
		if setup["ParameterScale"] == 1
            dfCO2Price.CO2_Mass_Slack .*= ModelScalingFactor # Convert ktons to tons
            dfCO2Price.CO2_Penalty .*= ModelScalingFactor^2 # Convert Million$ to $
		end
	end

    CSV.write(joinpath(path, "CO2_prices_and_penalties.csv"), dfCO2Price)

    return dfCO2Price
end