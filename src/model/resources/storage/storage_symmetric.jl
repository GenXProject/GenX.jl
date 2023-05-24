@doc raw"""
	storage_symmetric!(EP::Model, inputs::Dict, setup::Dict)

Sets up variables and constraints specific to storage resources with symmetric charge and discharge capacities. See ```storage()``` in ```storage.jl``` for description of constraints.
"""
function storage_symmetric!(EP::Model, inputs::Dict, setup::Dict)
	# Set up additional variables, constraints, and expressions associated with storage resources with symmetric charge & discharge capacity
	# (e.g. most electrochemical batteries that use same components for charge & discharge)
	# STOR = 1 corresponds to storage with distinct power and energy capacity decisions but symmetric charge/discharge power ratings

	println("Storage Resources with Symmetric Charge/Discharge Capacity Module")

	dfGen = inputs["dfGen"]
	Reserves = setup["Reserves"]

	T = inputs["T"]     # Number of time steps (hours)

	STOR_SYMMETRIC = inputs["STOR_SYMMETRIC"]

	### Constraints ###

	# Storage discharge and charge power (and reserve contribution) related constraints for symmetric storage resources:
	if Reserves == 1
		storage_symmetric_reserves!(EP, inputs)
	else
		@constraints(EP, begin
			# Maximum charging rate (including virtual charging to move energy held in reserve back to available storage) must be less than symmetric power rating
			[y in STOR_SYMMETRIC, t in 1:T], EP[:vCHARGE][y,t] + EP[:vCAPCONTRSTOR_VCHARGE][y,t] <= EP[:eTotalCap][y]

			# Max simultaneous charge and discharge cannot be greater than capacity
			[y in STOR_SYMMETRIC, t in 1:T], EP[:vP][y,t]+EP[:vCHARGE][y,t] <= EP[:eTotalCap][y]
		end)
	end

end

@doc raw"""
	storage_symmetric_reserves!(EP::Model, inputs::Dict)

Sets up variables and constraints specific to storage resources with symmetric charge and discharge capacities when reserves are modeled. See ```storage()``` in ```storage.jl``` for description of constraints.
"""
function storage_symmetric_reserves!(EP::Model, inputs::Dict)

	dfGen = inputs["dfGen"]
	T = inputs["T"]

	STOR_SYMMETRIC = inputs["STOR_SYMMETRIC"]

	STOR_SYM_REG_RSV = intersect(STOR_SYMMETRIC, inputs["REG"], inputs["RSV"]) # Set of symmetric storage resources with both REG and RSV reserves

	STOR_SYM_REG = intersect(STOR_SYMMETRIC, inputs["REG"]) # Set of symmetric storage resources with REG reserves
	STOR_SYM_RSV = intersect(STOR_SYMMETRIC, inputs["RSV"]) # Set of symmetric storage resources with RSV reserves

	STOR_SYM_NO_RES = setdiff(STOR_SYMMETRIC, STOR_SYM_REG, STOR_SYM_RSV) # Set of symmetric storage resources with no reserves

	STOR_SYM_REG_ONLY = setdiff(STOR_SYM_REG, STOR_SYM_RSV) # Set of symmetric storage resources only with REG reserves
	STOR_SYM_RSV_ONLY = setdiff(STOR_SYM_RSV, STOR_SYM_REG) # Set of symmetric storage resources only with RSV reserves

	if !isempty(STOR_SYM_REG_RSV)
		# Storage units charging can charge faster to provide reserves down and charge slower to provide reserves up
		@constraints(EP, begin
			# Maximum charging rate plus contribution to regulation down must be less than symmetric power rating
			[y in STOR_SYM_REG_RSV, t in 1:T], EP[:vCHARGE][y,t]+EP[:vREG_charge][y,t] <= EP[:eTotalCap][y]

			# Max simultaneous charge and discharge rates cannot be greater than symmetric charge/discharge capacity
			[y in STOR_SYM_REG_RSV, t in 1:T], EP[:vP][y,t]+EP[:vREG_discharge][y,t]+EP[:vRSV_discharge][y,t]+EP[:vCHARGE][y,t]+EP[:vREG_charge][y,t] <= EP[:eTotalCap][y]
		end)
	end

	if !isempty(STOR_SYM_REG_ONLY)
		# Storage units charging can charge faster to provide reserves down and charge slower to provide reserves up
		@constraints(EP, begin
			# Maximum charging rate plus contribution to regulation down must be less than symmetric power rating
			[y in STOR_SYM_REG_ONLY, t in 1:T], EP[:vCHARGE][y,t]+EP[:vREG_charge][y,t] <= EP[:eTotalCap][y]

			# Max simultaneous charge and discharge rates cannot be greater than symmetric charge/discharge capacity
			[y in STOR_SYM_REG_ONLY, t in 1:T], EP[:vP][y,t]+EP[:vREG_discharge][y,t]+EP[:vCHARGE][y,t]+EP[:vREG_charge][y,t] <= EP[:eTotalCap][y]
		end)
	end

	if !isempty(STOR_SYM_RSV_ONLY)
		# Storage units charging can charge faster to provide reserves down and charge slower to provide reserves up
		@constraints(EP, begin
			# Maximum charging rate must be less than symmetric power rating
			[y in STOR_SYM_RSV_ONLY, t in 1:T], EP[:vCHARGE][y,t] <= EP[:eTotalCap][y]

			# Max simultaneous charge and discharge rates cannot be greater than symmetric charge/discharge capacity
			[y in STOR_SYM_RSV_ONLY, t in 1:T], EP[:vP][y,t]+EP[:vRSV_discharge][y,t]+EP[:vCHARGE][y,t] <= EP[:eTotalCap][y]
		end)
	end

	if !isempty(STOR_SYM_NO_RES)
		@constraints(EP, begin
			# Maximum charging rate must be less than symmetric power rating
			[y in STOR_SYM_NO_RES, t in 1:T], EP[:vCHARGE][y,t] <= EP[:eTotalCap][y]

			# Max simultaneous charge and discharge cannot be greater than capacity
			[y in STOR_SYM_NO_RES, t in 1:T], EP[:vP][y,t]+EP[:vCHARGE][y,t] <= EP[:eTotalCap][y]
		end)
	end

end
