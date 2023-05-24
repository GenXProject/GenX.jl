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

	T = inputs["T"]     # Number of time steps (hours)

	STOR_ASYMMETRIC = inputs["STOR_ASYMMETRIC"]

	### Constraints ###

	# Storage discharge and charge power (and reserve contribution) related constraints for symmetric storage resources:
	if Reserves == 1
		storage_asymmetric_reserves!(EP, inputs)
	else
		# Maximum charging rate (including virtual charging to move energy held in reserve back to available storage) must be less than charge power rating
		@constraint(EP, [y in STOR_ASYMMETRIC, t in 1:T], EP[:vCHARGE][y,t] + EP[:vCAPCONTRSTOR_VCHARGE][y,t] <= EP[:eTotalCapCharge][y])
	end

end

@doc raw"""
	storage_asymmetric_reserves!(EP::Model, inputs::Dict)

Sets up variables and constraints specific to storage resources with asymmetric charge and discharge capacities when reserves are modeled. See ```storage()``` in ```storage.jl``` for description of constraints.
"""
function storage_asymmetric_reserves!(EP::Model, inputs::Dict)

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

end
