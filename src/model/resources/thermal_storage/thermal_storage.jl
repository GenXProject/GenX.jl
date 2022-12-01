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

function by_rid_df(rid::Integer, sym::Symbol, df::DataFrame)
	return df[df.R_ID .== rid, sym][]
end

function by_rid_df(rid::Vector{Int}, sym::Symbol, df::DataFrame)
	indices = [findall(x -> x == y, df.R_ID)[] for y in rid]
	return df[indices, sym]
end

function get_fus(inputs::Dict)::Vector{Int}
	dfTS = inputs["dfTS"]
	dfTS[dfTS.FUS.>=1,:R_ID]
end

function get_nonfus(inputs::Dict)::Vector{Int}
	dfTS = inputs["dfTS"]
	dfTS[dfTS.FUS.==0,:R_ID]
end

function get_maintenance(inputs::Dict)::Vector{Int}
	dfTS = inputs["dfTS"]
	if "MAINT" in names(dfTS)
		FUS = get_fus(inputs)
		intersect(FUS, dfTS[dfTS.MAINT.>0, :R_ID])
	else
		Vector{Int}[]
	end
end

function get_maintenance_with_formulation(inputs::Dict, form::Int)::Vector{Int}
	MAINTENANCE = get_maintenance(inputs)
	if !isempty(MAINTENANCE)
		dfTS = inputs["dfTS"]
		intersect(MAINTENANCE, dfTS[dfTS.MAINT.==form, :R_ID])
	else
		Vector{Int}[]
	end
end

function get_yearly_maintenance(inputs::Dict)::Vector{Int}
	YEARLY_MAINT = 1
	get_maintenance_with_formulation(inputs, YEARLY_MAINT)
end

function get_usage_based_maintenance(inputs::Dict)::Vector{Int}
	USAGE_BASED_MAINT = 2
	get_maintenance_with_formulation(inputs, USAGE_BASED_MAINT)
end

function get_nonmaintenance(inputs::Dict)::Vector{Int}
	FUS = get_fus(inputs)
	MAINT = get_maintenance(inputs)
	setdiff(FUS, MAINT)
end

function split_LDS_and_nonLDS(df::DataFrame, inputs::Dict, setup::Dict)
	TS = inputs["TS"]
	if setup["OperationWrapping"] == 1
		TS_and_LDS = intersect(TS, df[df.LDS.==1,:R_ID])
		TS_and_nonLDS = intersect(TS, df[df.LDS.!=1,:R_ID])
	else
		TS_and_LDS = Int[]
		TS_and_nonLDS = TS
	end
	TS_and_LDS, TS_and_nonLDS
end

@doc raw"""
    thermal_storage(EP::Model, inputs::Dict, setup::Dict)

"""
function thermal_storage(EP::Model, inputs::Dict, setup::Dict)

	println("Thermal Storage Module")

	dfGen = inputs["dfGen"]

	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
	Z = inputs["Z"]     # Number of zones

	START_SUBPERIODS = inputs["START_SUBPERIODS"]
	INTERIOR_SUBPERIODS = inputs["INTERIOR_SUBPERIODS"]
	hours_per_subperiod = inputs["hours_per_subperiod"]

	# Load thermal storage inputs
	TS = inputs["TS"]
	dfTS = inputs["dfTS"]

	by_rid(rid, sym) = by_rid_df(rid, sym, dfTS)

	@variables(EP, begin
	# Thermal core variables
	vCP[y in TS, t = 1:T] >= 0 		#thermal core power for resource y at timestep t
	vCCAP[y in TS] >= 0  			#thermal core capacity for resource y

	# Thermal storage variables
	vTS[y in TS, t = 1:T] >= 0		#thermal storage state of charge for resource y at timestep t
	vTSCAP[y in TS] >= 0			#thermal storage energy capacity for resource y
	end)

	### THERMAL CORE CONSTRAINTS ###
	# Core power output must be <= installed capacity, including hourly capacity factors
	@constraint(EP, cCPMax[y in TS, t=1:T], vCP[y,t] <= vCCAP[y]*inputs["pP_Max"][y,t])
	# Total installed capacity is less than specified maximum limit
	those_with_max_cap = dfTS[dfTS.Max_Cap_MW_th.>0, :R_ID]
	@constraint(EP, cCCAPMax[y in those_with_max_cap], vCCAP[y] <= by_rid(y, :Max_Cap_MW_th))

	# Variable cost of core operation
	# Variable cost at timestep t for thermal core y
	@expression(EP, eCVar_Core[y in TS, t=1:T], inputs["omega"][t] * by_rid(y, :Var_OM_Cost_per_MWh_th) * vCP[y,t])
	# Variable cost from all thermal cores at timestep t)
	@expression(EP, eTotalCVarCoreT[t=1:T], sum(eCVar_Core[y,t] for y in TS))
	# Total variable cost for all thermal cores
	@expression(EP, eTotalCVarCore, sum(eTotalCVarCoreT[t] for t in 1:T))
	EP[:eObj] += eTotalCVarCore


	# Core investment costs
	# fixed cost for thermal core y
	@expression(EP, eCFixed_Core[y in TS], by_rid(y,:Fixed_Cost_per_MW_th) * vCCAP[y])
	# total fixed costs for all thermal cores
	@expression(EP, eTotalCFixedCore, sum(eCFixed_Core[y] for y in TS))
	EP[:eObj] += eTotalCFixedCore

	### THERMAL STORAGE CONSTRAINTS ###
	# Storage state of charge must be <= installed capacity
	@constraint(EP, cTSMax[y in TS, t=1:T], vTS[y,t] <= vTSCAP[y])

	# thermal state of charge balance for interior timesteps:
	# (previous SOC) - (discharge to turbines) - (turbine startup energy use) + (core power output) - (self discharge)
	@constraint(EP, cTSocBalInterior[t in INTERIOR_SUBPERIODS, y in TS], (
		vTS[y,t] == vTS[y,t-1]
		- (1 / dfGen[y, :Eff_Down] * EP[:vP][y,t])
		- (1 / dfGen[y, :Eff_Down] * dfGen[y, :Start_Fuel_MMBTU_per_MW] * dfGen[y,:Cap_Size] * EP[:vSTART][y,t])
		+ (dfGen[y,:Eff_Up] * vCP[y,t])
		- (dfGen[y,:Self_Disch] * vTS[y,t-1]))
	)

	# TODO: perhaps avoid recomputing these; instead use sets TS_LONG_DURATION, etc
	TS_and_LDS, TS_and_nonLDS = split_LDS_and_nonLDS(dfGen, inputs, setup)

	@constraint(EP, cTSoCBalStart[t in START_SUBPERIODS, y in TS_and_nonLDS],(
	 vTS[y,t] == vTS[y, t + hours_per_subperiod - 1]
		- (1 / dfGen[y, :Eff_Down] * EP[:vP][y,t])
		- (1 / dfGen[y, :Eff_Down] * dfGen[y, :Start_Fuel_MMBTU_per_MW] * dfGen[y, :Cap_Size] * EP[:vSTART][y,t])
		+ (dfGen[y, :Eff_Up] * vCP[y,t]) - (dfGen[y, :Self_Disch] * vTS[y,t + hours_per_subperiod - 1])
		))

	if !isempty(TS_and_LDS)
		REP_PERIOD = inputs["REP_PERIOD"]  # Number of representative periods

		dfPeriodMap = inputs["Period_Map"] # Dataframe that maps modeled periods to representative periods
		NPeriods = nrow(dfPeriodMap) # Number of modeled periods

		MODELED_PERIODS_INDEX = 1:NPeriods
		REP_PERIODS_INDEX = MODELED_PERIODS_INDEX[dfPeriodMap.Rep_Period .== MODELED_PERIODS_INDEX]

		@variable(EP, vTSOCw[y in TS_and_LDS, n in MODELED_PERIODS_INDEX] >= 0)

		# Build up in storage inventory over each representative period w
		# Build up inventory can be positive or negative
		@variable(EP, vdTSOC[y in TS_and_LDS, w=1:REP_PERIOD])
		# Note: tw_min = hours_per_subperiod*(w-1)+1; tw_max = hours_per_subperiod*w
		@constraint(EP, cThermSoCBalLongDurationStorageStart[w=1:REP_PERIOD, y in TS_and_LDS], (
				vTS[y,hours_per_subperiod * (w - 1) + 1] ==
						   (1 - dfGen[y, :Self_Disch]) * (vTS[y, hours_per_subperiod * w] - vdTSOC[y,w])
						 - (1 / dfGen[y, :Eff_Down] * EP[:vP][y, hours_per_subperiod * (w - 1) + 1])
						 - (1 / dfGen[y, :Eff_Down] * dfGen[y,:Start_Fuel_MMBTU_per_MW] * dfGen[y,:Cap_Size] * EP[:vSTART][y,hours_per_subperiod * (w - 1) + 1])
					 + (dfGen[y, :Eff_Up] * vCP[y,hours_per_subperiod * (w - 1) + 1])
					 ))

		# Storage at beginning of period w = storage at beginning of period w-1 + storage built up in period w (after n representative periods)
		## Multiply storage build up term from prior period with corresponding weight
		@constraint(EP, cThermSoCBalLongDurationStorageInterior[y in TS_and_LDS, r in MODELED_PERIODS_INDEX[1:(end-1)]],
						vTSOCw[y,r+1] == vTSOCw[y,r] + vdTSOC[y,dfPeriodMap[r,:Rep_Period_Index]])

		## Last period is linked to first period
		@constraint(EP, cThermSoCBalLongDurationStorageEnd[y in TS_and_LDS, r in MODELED_PERIODS_INDEX[end]],
						vTSOCw[y,1] == vTSOCw[y,r] + vdTSOC[y,dfPeriodMap[r,:Rep_Period_Index]])

		# Storage at beginning of each modeled period cannot exceed installed energy capacity
		@constraint(EP, cThermSoCBalLongDurationStorageUpper[y in TS_and_LDS, r in MODELED_PERIODS_INDEX],
						vTSOCw[y,r] <= vTSCAP[y])

		# Initial storage level for representative periods must also adhere to sub-period storage inventory balance
		# Initial storage = Final storage - change in storage inventory across representative period
		@constraint(EP, cThermSoCBalLongDurationStorageSub[y in TS_and_LDS, r in REP_PERIODS_INDEX],
						vTSOCw[y,r] == vTS[y,hours_per_subperiod*dfPeriodMap[r,:Rep_Period_Index]] - vdTSOC[y,dfPeriodMap[r,:Rep_Period_Index]])

	end

	# Thermal storage investment costs
	# Fixed costs for thermal storage y
	@expression(EP, eCFixed_TS[y in TS], by_rid(y,:Fixed_Cost_per_MWh_th) * vTSCAP[y])
	# Total fixed costs for all thermal storage
	@expression(EP, eTotalCFixedTS, sum(eCFixed_TS[y] for y in TS))
	EP[:eObj] += eTotalCFixedTS

	# Parameter Fixing Constraints
	# Fixed ratio of gross generator capacity to core equivalent gross electric power
	@constraint(EP, cCPRatMax[y in dfTS[dfTS.Max_Generator_Core_Power_Ratio.>0,:R_ID]],
				vCCAP[y] * dfGen[y,:Eff_Down] * by_rid(y,:Max_Generator_Core_Power_Ratio) >=
				EP[:vCAP][y] * dfGen[y,:Cap_Size])
	@constraint(EP, cCPRatMin[y in dfTS[dfTS.Min_Generator_Core_Power_Ratio.>0,:R_ID]],
				vCCAP[y] * dfGen[y,:Eff_Down] * by_rid(y,:Min_Generator_Core_Power_Ratio) <=
				EP[:vCAP][y] * dfGen[y,:Cap_Size])
	# Limits on storage duration
	@constraint(EP, cTSMinDur[y in TS], vTSCAP[y] >= dfGen[y,:Min_Duration] * vCCAP[y])
	@constraint(EP, cTSMaxDur[y in TS], vTSCAP[y] <= dfGen[y,:Max_Duration] * vCCAP[y])

	### FUSION CONSTRAINTS ###
	FUS =  get_fus(inputs)

	# TODO: define expressions & constraints for NONFUS
	NONFUS =  get_nonfus(inputs)

	# Use fusion constraints if thermal cores tagged 'FUS' are present
	if !isempty(FUS)
		fusion_constraints!(EP, inputs, setup)
	end

return EP
end

function fusion_max_cap_constraint!(EP::Model, inputs::Dict, setup::Dict)

	dfGen = inputs["dfGen"]

	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)

	dfTS = inputs["dfTS"]
	by_rid(rid, sym) = by_rid_df(rid, sym, dfTS)

	FUS =  get_fus(inputs)

	#System-wide installed capacity is less than a specified maximum limit
	has_max_up = dfTS[by_rid(FUS, :Max_Up) .> 0, :R_ID]

	active_frac = ones(G)
	avg_start_power = zeros(G)
	net_th_frac = ones(G)
	net_el_factor = zeros(G)

	active_frac[has_max_up] .= 1 .- by_rid(has_max_up,:Dwell_Time) ./ by_rid(has_max_up,:Max_Up)
	avg_start_power[has_max_up] .= by_rid(has_max_up,:Start_Energy) ./ by_rid(has_max_up,:Max_Up)
	net_th_frac[FUS] .= active_frac[FUS] .* (1 .- by_rid(FUS,:Recirc_Act)) .- by_rid(FUS,:Recirc_Pass) .- avg_start_power[FUS]
	net_el_factor[FUS] .= dfGen[FUS,:Eff_Down] .* net_th_frac[FUS]

	@expression(EP, eCAvgNetElectric[y in FUS], EP[:vCCAP][y] * net_el_factor[y])

	FIRST_ROW = 1
	system_max_cap_mwe_net = dfTS[FIRST_ROW, :System_Max_Cap_MWe_net]
	if system_max_cap_mwe_net >= 0
		@constraint(EP, cCSystemTot, sum(eCAvgNetElectric[FUS]) <= system_max_cap_mwe_net)
	end
end

@doc raw"""
    fusion_constraints!(EP::Model, inputs::Dict)

Apply fusion-core-specific constraints to the model.

"""
function fusion_constraints!(EP::Model, inputs::Dict, setup::Dict)

	T = inputs["T"]     # Number of time steps (hours)
	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	Z = inputs["Z"]     # Number of zones

	hours_per_subperiod = inputs["hours_per_subperiod"]

	dfTS = inputs["dfTS"]
	dfGen = inputs["dfGen"]

	by_rid(rid, sym) = by_rid_df(rid, sym, dfTS)

	FUS = get_fus(inputs)

	MAINTENANCE = get_maintenance(inputs)
	sanity_check_maintenance(MAINTENANCE, setup)

	fusion_max_cap_constraint!(EP, inputs, setup)

	# UC variables for the fusion core, analogous to standard UC
	@variables(EP, begin
		vFCOMMIT[y in FUS, t=1:T] >= 0 #core commitment status
		vFSTART[y in FUS, t=1:T] >= 0 #core startup
		vFSHUT[y in FUS, t=1:T] >= 0 #core shutdown
	end)

	#Declare core integer/binary variables if Integer_Commit is set to 1
	for y in FUS
		if by_rid(y, :Integer_Commit) == 1
			set_integer.(vFCOMMIT[y,:])
			set_integer.(vFSTART[y,:])
			set_integer.(vFSHUT[y,:])
			set_integer.(EP[:vCCAP][y])
		end
	end

	# Upper bounds on core commitment/start/shut, and optional maintenance variables
	@constraints(EP, begin
		[y in FUS, t=1:T], vFCOMMIT[y,t] <= EP[:vCCAP][y] / by_rid(y,:Cap_Size)
		[y in FUS, t=1:T], vFSTART[y,t] <= EP[:vCCAP][y] / by_rid(y,:Cap_Size)
		[y in FUS, t=1:T], vFSHUT[y,t] <= EP[:vCCAP][y] / by_rid(y,:Cap_Size)
	end)

	# Commitment state constraint linking startup and shutdown decisions
	# links commitment state in hour t with commitment state in
	# prior hour + sum of start up and shut down in current hour
	p = hours_per_subperiod
	@constraint(EP, [y in FUS, t in 1:T],
		vFCOMMIT[y,t] == vFCOMMIT[y, hoursbefore(p,t,1)] + vFSTART[y,t] - vFSHUT[y,t])

	# Minimum and maximum core power output
	@constraints(EP, begin
		# Minimum stable thermal power generated by core y at
		# hour y >= Min power of committed core
		[y in FUS, t=1:T], EP[:vCP][y,t] >= by_rid(y, :Min_Power) * by_rid(y, :Cap_Size) * vFCOMMIT[y,t]

		# Maximum thermal power generated by core y at hour y <= Max power of committed
		# core minus power lost from down time at startup
		[y in FUS, t=1:T], EP[:vCP][y,t] <= by_rid(y, :Cap_Size) * (vFCOMMIT[y,t] -
											by_rid(y, :Dwell_Time) * vFSTART[y,t])
	end)

	FINITE_STARTS = intersect(FUS, dfTS[dfTS.Max_Starts.>=0, :R_ID])

	#Limit on total core starts per year
	@constraint(EP, [y in FINITE_STARTS],
		sum(vFSTART[y,t]*inputs["omega"][t] for t in 1:T) <=
		by_rid(y, :Max_Starts) * EP[:vCCAP][y] / by_rid(y,:Cap_Size)
	)

	MAX_UPTIME = intersect(FUS, dfTS[dfTS.Max_Up.>0, :R_ID])
	# TODO: throw error if Max_Up == 0 since it's confusing & illdefined

	max_uptime = zeros(Int, G)
	max_uptime[MAX_UPTIME] .= by_rid(MAX_UPTIME, :Max_Up)

	# Core max uptime. If this parameter > 0,
	# the fusion core must be cycled at least every n hours.
	# Looks back over interior timesteps and ensures that a core cannot
	# be committed unless it has been started at some point in
	# the previous n timesteps
	@constraint(EP, [y in MAX_UPTIME, t in 1:T],
			vFCOMMIT[y,t] <= sum(vFSTART[y, hoursbefore(p, t, 0:(max_uptime[y]-1))]))

	# Maintenance constraints are optional, and are only activated when OperationWrapping is off.
	# This is to *prevent* these constraints when using TimeDomainReduction, since it would no longer
	# make sense to have contiguous many-week-long periods which only happen once per year.
	if !isempty(MAINTENANCE)
		maintenance_constraints!(EP, inputs, setup)
	else
		# Passive recirculating power, depending on built capacity
		@expression(EP, ePassiveRecircFus[y in FUS, t=1:T],
			EP[:vCCAP][y] * dfGen[y,:Eff_Down] * by_rid(y,:Recirc_Pass))
	end

	# Active recirculating power, depending on committed capacity
	@expression(EP, eActiveRecircFus[y in FUS, t=1:T],
		by_rid(y,:Cap_Size) * dfGen[y,:Eff_Down] * by_rid(y,:Recirc_Act) *
		(vFCOMMIT[y,t] - vFSTART[y,t] * by_rid(y,:Dwell_Time))
	)
	# Startup energy, taken from the grid every time the core starts up
	@expression(EP, eStartEnergyFus[y in FUS, t=1:T],
		by_rid(y,:Cap_Size) * vFSTART[y,t] * dfGen[y,:Eff_Down] * by_rid(y,:Start_Energy))
	#Total recirculating power at each timestep
	@expression(EP, eTotalRecircFus[y in FUS, t=1:T],
		EP[:ePassiveRecircFus][y,t] + eActiveRecircFus[y,t] + eStartEnergyFus[y,t])

	# Total recirculating power from fusion in each zone
	FUS_IN_ZONE = [intersect(FUS, dfTS[dfTS.Zone .== z, :R_ID]) for z in 1:Z]
	@expression(EP, ePowerBalanceRecircFus[t=1:T, z=1:Z],
		-sum(eTotalRecircFus[y,t] for y in FUS_IN_ZONE[z]))

	EP[:ePowerBalance] += ePowerBalanceRecircFus
end

function maintenance_constraints!(EP::Model, inputs::Dict, setup::Dict)

	println("Fusion Core Maintenance Module")

	dfGen = inputs["dfGen"]

	T = inputs["T"]     # Number of time steps (hours)
	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)

	hours_per_subperiod = inputs["hours_per_subperiod"]

	by_rid(rid, sym) = by_rid_df(rid, sym, inputs["dfTS"])

	FUS = get_fus(inputs)
	MAINTENANCE = get_maintenance(inputs)
	YEARLY_MAINTENANCE = get_yearly_maintenance(inputs)
	USAGE_BASED_MAINTENANCE = get_usage_based_maintenance(inputs)

	NONMAINTENANCE = get_nonmaintenance(inputs)

	omega = inputs["omega"]

	# UC variables for fusion core maintenance
	@variables(EP, begin
		vFMDOWN[y in FUS, t=1:T] >= 0  # core maintenance status
		vFMSHUT[y in MAINTENANCE, t=1:T] >= 0  # core maintenance shutdown
	end)

	# No need to set integers for NONMAINTENANCE
	for y in MAINTENANCE
		if by_rid(y, :Integer_Commit) == 1
			set_integer.(vFMDOWN[y,:])
			set_integer.(vFMSHUT[y,:])
		end
	end

	# Upper bounds on optional maintenance variables
	@constraints(EP, begin
		[y in NONMAINTENANCE, t=1:T], vFMDOWN[y,t] == 0
		[y in MAINTENANCE, t=1:T], vFMDOWN[y,t] <= EP[:vCCAP][y] / by_rid(y,:Cap_Size)
		[y in MAINTENANCE, t=1:T], vFMSHUT[y,t] <= EP[:vCCAP][y] / by_rid(y,:Cap_Size)
	end)

	# Require plant to shut down during maintenance
	@constraint(EP, [y in MAINTENANCE, t=1:T],
		EP[:vCCAP][y] / by_rid(y,:Cap_Size) - EP[:vFCOMMIT][y,t] >= vFMDOWN[y,t])

	maint_dur = zeros(Int, G)
	maint_dur[MAINTENANCE] .= Int.(floor.(by_rid(MAINTENANCE, :Maintenance_Duration_Hours)))
	@constraint(EP, [y in MAINTENANCE, t in 1:T],
			EP[:vFMDOWN][y,t] == sum(EP[:vFMSHUT][y, hoursbefore(hours_per_subperiod, t, 0:(maint_dur[y]-1))]))

	@constraint(EP, [y in YEARLY_MAINTENANCE],
		sum(EP[:vFMSHUT][y,t]*omega[t] for t in 1:T) >= EP[:vCCAP][y] / by_rid(y,:Maintenance_Cadence_Years) / by_rid(y,:Cap_Size))
	@constraint(EP, [y in USAGE_BASED_MAINTENANCE],
		sum(EP[:vFMSHUT][y,t]*omega[t] for t in 1:T) >= sum(EP[:vCP][y,t]*omega[t] for t in 1:T) / by_rid(y,:Full_Power_Hours_Until_Maintenance) / by_rid(y,:Cap_Size))

	# Passive recirculating power, depending on built capacity
	@expression(EP, ePassiveRecircFus[y in FUS, t=1:T],
		(EP[:vCCAP][y] - by_rid(y,:Cap_Size) * EP[:vFMDOWN][y,t]) * dfGen[y,:Eff_Down] * by_rid(y,:Recirc_Pass))
end


function sanity_check_maintenance(MAINTENANCE::Vector{Int}, setup::Dict)
	ow = setup["OperationWrapping"]
	tdr = setup["TimeDomainReduction"]

	is_maint_reqs = !isempty(MAINTENANCE)
	if (ow > 0 || tdr > 0) && is_maint_reqs
		println("Resources ", MAINTENANCE, " have MAINT > 0,")
		println("but also OperationWrapping (", ow, ") or TimeDomainReduction (", tdr, ").")
		println("These are incompatible with a Maintenance requirement.")
		error("Incompatible GenX settings and maintenance requirements.")
	end
end
