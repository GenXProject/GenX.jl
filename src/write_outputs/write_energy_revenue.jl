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
	write_energy_revenue(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing energy revenue from the different generation technologies.
"""
function write_energy_revenue(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]
	G = inputs["G"] + (setup["VreStor"]==1 ? inputs["VRE_STOR"] : 0)    # Number of resources (generators, storage, DR, co-located resources, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
	FLEX = inputs["FLEX"]
	NONFLEX = setdiff(collect(1:G), FLEX)
	dfEnergyRevenue = DataFrame(Region = dfGen.region, Resource = inputs["RESOURCES"], Zone = dfGen.Zone, Cluster = dfGen.cluster, AnnualSum = Array{Float64}(undef, G),)
	energyrevenue = zeros(G, T)
	energyrevenue[NONFLEX, :] = value.(EP[:vP][NONFLEX, :]) .* transpose(dual.(EP[:cPowerBalance]) ./ inputs["omega"])[dfGen[NONFLEX, :Zone], :]
	if !isempty(FLEX)
		energyrevenue[FLEX, :] = value.(EP[:vCHARGE_FLEX][FLEX, :]).data .* transpose(dual.(EP[:cPowerBalance]) ./ inputs["omega"])[dfGen[FLEX, :Zone], :]
	end
	if setup["VreStor"] == 1
		VRE_STOR = G+1:G
		VRE_STOR_ = inputs["VRE_STOR"]
		dfGen_VRE_STOR = inputs["dfGen_VRE_STOR"]
		energyrevenue[VRE_STOR, :] .= (value.(EP[:vP_DC]).data) .* transpose(dual.(EP[:cPowerBalance]) ./ inputs["omega"])[dfGen_VRE_STOR[VRE_STOR_, :Zone], :]
	end
	if setup["ParameterScale"] == 1
		energyrevenue *= ModelScalingFactor^2
	end
	dfEnergyRevenue.AnnualSum .= energyrevenue * inputs["omega"]
	CSV.write(joinpath(path, "EnergyRevenue.csv"), dfEnergyRevenue)
	return dfEnergyRevenue
end
