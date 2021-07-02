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
	storage_asymmetric(EP::Model, inputs::Dict, Reserves::Int)

Sets up variables and constraints specific to storage resources with asymmetric charge and discharge capacities. See ```storage()``` in ```storage.jl``` for description of constraints.
"""
function storage_asymmetric(EP::Model, inputs::Dict, Reserves::Int)
	# Set up additional variables, constraints, and expressions associated with storage resources with asymmetric charge & discharge capacity
	# (e.g. most chemical, thermal, and mechanical storage options with distinct charge & discharge components/processes)
	# STOR = 2 corresponds to storage with distinct power and energy capacity decisions and distinct charge and discharge power capacity decisions/ratings

	#println("Storage Resources with Asmymetric Charge/Discharge Capacity Module")

	dfGen = inputs["dfGen"]

	T = inputs["T"]     # Number of time steps (hours)

	STOR_ASYMMETRIC = inputs["STOR_ASYMMETRIC"]

	### Constraints ###

	# Storage discharge and charge power (and reserve contribution) related constraints for symmetric storage resources:
	if Reserves == 1
		EP = storage_asymmetric_reserves(EP, inputs)
	else
		# Maximum charging rate must be less than charge power rating
		@constraint(EP, [y in STOR_ASYMMETRIC, t in 1:T], EP[:vCHARGE][y,t] <= EP[:eTotalCapCharge][y])
	end

	return EP
end

@doc raw"""
	storage_asymmetric_reserves(EP::Model, inputs::Dict)

Sets up variables and constraints specific to storage resources with asymmetric charge and discharge capacities when reserves are modeled. See ```storage()``` in ```storage.jl``` for description of constraints.
"""
function storage_asymmetric_reserves(EP::Model, inputs::Dict)

	dfGen = inputs["dfGen"]
	T = inputs["T"]

	STOR_ASYMMETRIC = inputs["STOR_ASYMMETRIC"]

	STOR_ASYM_REG = intersect(STOR_ASYMMETRIC, inputs["REG"]) # Set of asymmetric storage resources with REG reserves
	STOR_ASYM_NO_REG = setdiff(STOR_ASYMMETRIC, STOR_ASYM_REG) # Set of asymmetric storage resources without REG reserves

	if !isempty(STOR_ASYM_REG)
		# Storage units charging can charge faster to provide reserves down and charge slower to provide reserves up
		# Maximum charging rate plus contribution to regulation down must be less than charge power rating
		@constraint(EP, [y in STOR_ASYM_REG, t in 1:T], EP[:vCHARGE][y,t]+EP[:vREG_charge][y,t] <= EP[:eTotalCapCharge][y])
	else
		# Storage units charging can charge faster to provide reserves down and charge slower to provide reserves up
		# Maximum charging rate plus contribution to regulation down must be less than charge power rating
		@constraint(EP, [y in STOR_ASYM_NO_REG, t in 1:T], EP[:vCHARGE][y,t] <= EP[:eTotalCapCharge][y])
	end

	return EP
end
