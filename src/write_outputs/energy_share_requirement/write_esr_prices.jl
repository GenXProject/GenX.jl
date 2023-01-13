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

function write_esr_prices(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfESR = DataFrame(ESR_Constraint = inputs["dfESR_slack"][!,:ESR_Constraint], 
						ESR_Price = convert(Array{Float64}, dual.(EP[:cESRShare])),
						ESR_AnnualSlack = convert(Array{Float64}, value.(EP[:vESRSlack])),
						ESR_AnnualPenalty = convert(Array{Float64}, value.(EP[:eCESRSlack])))
	if setup["ParameterScale"] == 1
		dfESR[!,:ESR_Price] *= ModelScalingFactor # Converting MillionUS$/GWh to US$/MWh
		dfESR[!,:ESR_AnnualSlack] *= ModelScalingFactor # Converting GWh to MWh
		dfESR[!,:ESR_AnnualPenalty] *= (ModelScalingFactor^2) # Converting MillionUSD to USD
	end
	CSV.write(joinpath(path, "ESR_prices_penalty.csv"), dfESR)
	return dfESR
end
