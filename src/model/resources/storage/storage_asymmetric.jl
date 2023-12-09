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
	storage_asymmetric!(EP::Model, inputs::Dict, setup::Dict)

Sets up variables and constraints specific to storage resources with asymmetric charge and discharge capacities. See ```storage()``` in ```storage.jl``` for description of constraints.
"""
function storage_asymmetric!(EP::Model, inputs::Dict, setup::Dict)
	# Set up additional variables, constraints, and expressions associated with storage resources with asymmetric charge & discharge capacity
	# (e.g. most chemical, thermal, and mechanical storage options with distinct charge & discharge components/processes)
	# STOR = 2 corresponds to storage with distinct power and energy capacity decisions and distinct charge and discharge power capacity decisions/ratings

	println("Storage Resources with Asmymetric Charge/Discharge Capacity Module")

	dfGen = inputs["dfGen"]
	Reserves = setup["Reserves"]
	CapacityReserveMargin = setup["CapacityReserveMargin"]

	T = inputs["T"]     # Number of time steps (hours)

	STOR_ASYMMETRIC = inputs["STOR_ASYMMETRIC"]

	### Constraints ###
	# Storage discharge and charge power (and reserve contribution) related constraints for symmetric storage resources:
	if Reserves == 1
		storage_asymmetric_reserves!(EP, inputs, setup)
	else
		if CapacityReserveMargin > 0
			# Maximum charging rate (including virtual charging to move energy held in reserve back to available storage) must be less than charge power rating
			@constraint(EP, [y in STOR_ASYMMETRIC, t in 1:T], EP[:vCHARGE][y,t] + EP[:vCAPRES_charge][y,t] <= EP[:eTotalCapCharge][y])
		else
			# Maximum charging rate (including virtual charging to move energy held in reserve back to available storage) must be less than charge power rating
			@constraint(EP, [y in STOR_ASYMMETRIC, t in 1:T], EP[:vCHARGE][y,t] <= EP[:eTotalCapCharge][y])
		end
	end

end

@doc raw"""
	storage_asymmetric_reserves!(EP::Model, inputs::Dict)

Sets up variables and constraints specific to storage resources with asymmetric charge and discharge capacities when reserves are modeled. See ```storage()``` in ```storage.jl``` for description of constraints.
"""
function storage_asymmetric_reserves!(EP::Model, inputs::Dict, setup::Dict)

	T = inputs["T"]
	CapacityReserveMargin = setup["CapacityReserveMargin"] > 0

	STOR_ASYMMETRIC = inputs["STOR_ASYMMETRIC"]
	RETRO_CREAT = inputs["RETRO"] # Set of all resources being created

	hours_per_subperiod = inputs["hours_per_subperiod"] #total number of hours per subperiod
	START_SUBPERIODS = inputs["START_SUBPERIODS"]
	INTERIOR_SUBPERIODS = inputs["INTERIOR_SUBPERIODS"]

	STOR_ASYM_RETRO = intersect(STOR_ASYMMETRIC, RETRO_CREAT) # Set of asymmetric storage resources 
	STOR_ASYM_REG = intersect(STOR_ASYMMETRIC, inputs["REG"]) # Set of asymmetric storage resources with REG reserves

    vCHARGE = EP[:vCHARGE]
    vREG_charge = EP[:vREG_charge]
    eTotalCapCharge = EP[:eTotalCapCharge]

	if !isempty(STOR_ASYM_RETRO)
		@constraints(EP, begin
		# Storage units charging can charge faster to provide reserves down and charge slower to provide reserves up
		# Maximum charging rate plus contribution to regulation down must be less than charge power rating
		#[y in STOR_ASYM_RETRO, t in START_SUBPERIODS], EP[:vP][y,t]-EP[:vP][y,(t+hours_per_subperiod-1)] <= dfGen[y,:Ramp_Up_Percentage]*EP[:eTotalCap][y]

		# Interior Hours
		[y in STOR_ASYM_RETRO, t in INTERIOR_SUBPERIODS], EP[:vP][y,t]-EP[:vP][y,t-1] <= dfGen[y,:Ramp_Up_Percentage]*EP[:eTotalCap][y]

		## Maximum ramp down between consecutive hours
		# Start Hours: Links last time step with first time step, ensuring position in hour 1 is within eligible ramp of final hour position
		#[y in STOR_ASYM_RETRO, t in START_SUBPERIODS], EP[:vP][y,(t+hours_per_subperiod-1)] - EP[:vP][y,t] <= dfGen[y,:Ramp_Dn_Percentage]*EP[:eTotalCap][y]

		# Interior Hours
		[y in STOR_ASYM_RETRO, t in INTERIOR_SUBPERIODS], EP[:vP][y,t-1] - EP[:vP][y,t] <= dfGen[y,:Ramp_Dn_Percentage]*EP[:eTotalCap][y]
		end)
	end

end
