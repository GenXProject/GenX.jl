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
	minimum_supply_mmbtu(EP::Model, inputs::Dict, setup::Dict)

 Fuel supply constraint.
 Can be used to constrain total annual fuel use by fuel type.
 Sum of fuel consumed by each resource using a constrained fuel type (dfFuels[:Minimum_Supply_MMBtu].>=0), must be larger than minimum fuel supply specified.

 The variable `Minimum_Supply_MMBTU` is provided in the first row of the `Fuels_data.csv` input file. If smaller than 0, no constraint will be added for the fuel.
"""
function minimum_supply_mmbtu(EP::Model, inputs::Dict, setup::Dict)

	println("Minimum Supply MMBTU Module")

	dfGen = inputs["dfGen"]
	#SEG = inputs["SEG"]  # Number of lines
	#G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
	#Z = inputs["Z"]     # Number of zones

	### Expressions ###

	### Constraints ###
	fuels_with_constraint = findall(x -> x>-0, inputs["Minimum_Supply_MMBTU"])
	C = Array{ConstraintRef}(undef, length(fuels_with_constraint))
	for i in 1:length(fuels_with_constraint)
		f = fuels_with_constraint[i]
		C[i] = @constraint(EP, sum(EP[:vP][y,t]*dfGen[!,:Heat_Rate_MMBTU_per_MWh][y] for y in dfGen[dfGen[!,:Fuel].==inputs["fuels"][f],:][!,:R_ID], t=1:T) >= inputs["Minimum_Supply_MMBTU"][f])
		set_name(C[i], "cMinFuelSupply"*string(f))
	end

	#@constraint(EP, cMinFuelSupply[1:length(fuels_with_constraint)], (for f in fuels_with_constraint sum(EP[:vP][y,t]*dfGen[!,:Heat_Rate_MMBTU_per_MWh][y] for y in dfGen[dfGen[!,:Fuel].==inputs["fuels"][f],:][!,:R_ID], t=1:T) <= inputs["Minimum_Supply_MMBTU"][f]))

	return EP

end

@doc raw"""
	maximum_supply_mmbtu(EP::Model, inputs::Dict, setup::Dict)

 Fuel supply constraint.
 Can be used to constrain total annual fuel use by fuel type or to create stepwise supply curve for resource constrained fuels (e.g. biofuels)
 Sum of fuel consumed by each resource using a contrained fuel type (dfFuels[:Maximum_Supply_MMBtu].>=0), must be less than maximum fuel supply specified.

 The variable `Maximum_Supply_MMBTU` is provided in the second row of the `Fuels_data.csv` input file. If smaller than 0, no constraint will be added for the fuel.
"""
function maximum_supply_mmbtu(EP::Model, inputs::Dict, setup::Dict)

	println("Maximum Supply MMBTU Module")

	dfGen = inputs["dfGen"]
	#SEG = inputs["SEG"]  # Number of lines
	#G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
	#Z = inputs["Z"]     # Number of zones

	### Expressions ###

	### Constraints ###
	fuels_with_constraint = findall(x -> x>-0, inputs["Maximum_Supply_MMBTU"])
	C = Array{ConstraintRef}(undef, length(fuels_with_constraint))
	for i in 1:length(fuels_with_constraint)
		f = fuels_with_constraint[i]
		C[i] = @constraint(EP, sum(EP[:vP][y,t]*dfGen[!,:Heat_Rate_MMBTU_per_MWh][y] for y in dfGen[dfGen[!,:Fuel].==inputs["fuels"][f],:][!,:R_ID], t=1:T) <= inputs["Maximum_Supply_MMBTU"][f])
		set_name(C[i], "cMaxFuelSupply"*string(f))
	end

	#@constraint(EP, cMaxFuelSupply[1:length(fuels_with_constraint)], (for f in fuels_with_constraint sum(EP[:vP][y,t]*dfGen[!,:Heat_Rate_MMBTU_per_MWh][y] for y in dfGen[dfGen[!,:Fuel].==inputs["fuels"][f],:][!,:R_ID], t=1:T) <= inputs["Maximum_Supply_MMBTU"][f]))

	return EP

end
