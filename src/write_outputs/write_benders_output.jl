@doc raw"""
	write_benders_output(benders_results, outpath, setup, inputs, planning_problem, subproblems)

Write all Benders decomposition outputs to `outpath`.

Orchestrates the full output pipeline: convergence history, capacity, network expansion,
policy requirements, costs, operational time series (power, charge, storage, curtailment,
NSE, power balance, emissions, fuel consumption, transmission), capacity factors,
shadow-price-based outputs (LMPs, reliability prices, storage duals, energy revenue,
charging costs), unit commitment decisions, and planning problem duals.  Each output
is guarded by the corresponding key in `setup["WriteOutputsSettingsDict"]`; outputs
default to enabled when the key is absent.

If the planning problem has no solver values (e.g. the algorithm did not converge),
only the status file and convergence CSV are written and the function returns early.
"""
function write_benders_output(benders_results::NamedTuple, outpath::AbstractString, setup::Dict, inputs::Dict, planning_problem::Model, subproblems::Union{Vector{Dict{Any, Any}},DistributedArrays.DArray})
	output_settings_d = get(setup, "WriteOutputsSettingsDict", Dict{String, Bool}())
	if setup["OutputFullTimeSeries"] == 1
		mkpath(joinpath(outpath, setup["OutputFullTimeSeriesFolder"]))
	end

	write_settings_file(outpath, setup)
	write_system_env_summary(outpath)
	if get(output_settings_d, "WriteStatus", true)
		write_status(outpath, inputs, setup, planning_problem)
	end
	LB_hist = benders_results.LB_hist
	UB_hist = benders_results.UB_hist
	cpu_time = benders_results.cpu_time
	gap_hist = haskey(benders_results, :gap_hist) ? benders_results.gap_hist : (UB_hist .- LB_hist) ./ LB_hist
	dfConv = DataFrame(Iter = 1:length(LB_hist), CPU_Time = cpu_time, LB = LB_hist, UB = UB_hist, Gap = gap_hist)
	if haskey(benders_results, :termination_status)
		dfConv.Status = vcat([string(benders_results.termination_status)], fill("", max(length(LB_hist) - 1, 0)))
	end
	
	@warn """
	Planning-problem dual outputs (subsidy revenue, CO2 cap prices) are not written for Benders.
	These shadow prices from the incumbent planning solution may not be reliably recoverable
	from the master problem. If you have questions or comments regarding this, please open an issue.
	"""

	# Planning (first-stage) outputs are read directly from the incumbent solution
	# (benders_results.planning_sol) rather than from the planning-problem model state. They
	# are written before the has_values gate and are correct regardless of the model's
	# post-Benders solve status. Dual-based planning outputs (min/max capacity requirement,
	# subsidy revenue, CO2 cap prices) are intentionally not written for Benders: their shadow
	# prices are not available from planning_sol and are not reliably recoverable from the
	# cut-laden master problem.
	if get(output_settings_d, "WriteCapacity", true) || get(output_settings_d, "WriteNetRevenue", true)
		elapsed_time_capacity = @elapsed dfCap = write_capacity_benders(outpath, inputs, setup, planning_problem, benders_results.planning_sol)
		println("Time elapsed for writing capacity is")
		println(elapsed_time_capacity)
	end

	if inputs["Z"] > 1
		if setup["NetworkExpansion"] == 1 && get(output_settings_d, "WriteNWExpansion", true)
			elapsed_time_expansion = @elapsed write_nw_expansion_benders(outpath, inputs, setup, planning_problem, benders_results.planning_sol)
			println("Time elapsed for writing network expansion is")
			println(elapsed_time_expansion)
		end
	end

	if !has_values(planning_problem)
		if get(output_settings_d, "WriteStatus", true)
			write_status(outpath, inputs, setup, planning_problem)
		end
		# Operational costs require solved subproblems, which are not collected on this path;
		# write the first-stage-only cost breakdown so a cost file still exists.
		if get(output_settings_d, "WriteCosts", true)
			write_planning_problem_costs(outpath, inputs, setup, benders_results, planning_problem)
		end
		@warn "Benders planning problem has no solver values in the model object; skipping detailed (operational) output files. Use benders_results fields for algorithm diagnostics."
		return nothing
	end

	#TODO: Check that Benders converged;

    CSV.write(joinpath(outpath, "benders_convergence.csv"),dfConv)

	benders_bundle = collect_benders_output_bundle(inputs, setup, subproblems)

	# Full cost breakdown (first-stage from planning_sol + operational from the subproblem bundle).
	if get(output_settings_d, "WriteCosts", true)
		write_planning_problem_costs(outpath, inputs, setup, benders_results, planning_problem, benders_bundle)
	end

	if get(output_settings_d, "WriteCO2", true)
		write_co2_emissions_plant(outpath, inputs, setup, benders_bundle.emissions_plant)
	end

	if get(output_settings_d, "WritePower", true) || get(output_settings_d, "WriteNetRevenue", true)
		write_power(outpath, inputs, setup, benders_bundle.power)
	end

	if get(output_settings_d, "WriteCharge", true)
		write_charge(outpath, inputs, setup, benders_bundle.charge, benders_bundle.charge_ids)
	end

	if get(output_settings_d, "WriteStorage", true)
		write_storage_benders(outpath, inputs, setup, benders_bundle.storage, benders_bundle.storage_ids)
	end

	if get(output_settings_d, "WriteCurtailment", true)
		write_curtailment_benders(outpath, inputs, setup, benders_bundle.curtailment)
	end

	if get(output_settings_d, "WriteNSE", true)
		write_nse_benders(outpath, inputs, setup, benders_bundle.nse)
	end

	if get(output_settings_d, "WritePowerBalance", true)
		write_power_balance_benders(outpath, inputs, setup, benders_bundle)
	end

	if get(output_settings_d, "WriteEmissions", true)
		write_emissions_benders(outpath, inputs, setup, benders_bundle.emissions_zone)
	end

	if get(output_settings_d, "WriteFuelConsumption", true)
		write_fuel_consumption_benders(outpath, inputs, setup, benders_bundle)
	end

	if inputs["Z"] > 1
		if get(output_settings_d, "WriteTransmissionFlows", true)
			write_transmission_flows_benders(outpath, inputs, setup, benders_bundle.flow)
		end

		if get(output_settings_d, "WriteTransmissionLosses", true)
			write_transmission_losses_benders(outpath, inputs, setup, benders_bundle.tlosses)
		end
	end

	# Time weights
	if get(output_settings_d, "WriteTimeWeights", true)
		elapsed = @elapsed write_time_weights(outpath, inputs)
		println("Time elapsed for writing time weights is")
		println(elapsed)
	end

	# Capacity factor
	if get(output_settings_d, "WriteCapacityFactor", true)
		elapsed = @elapsed write_capacityfactor_benders(outpath, inputs, setup, benders_bundle, planning_problem)
		println("Time elapsed for writing capacity factor is")
		println(elapsed)
	end

	# Shadow-price-based outputs (subproblem LMP duals required)
	if benders_bundle.has_subproblem_duals
		if get(output_settings_d, "WritePrice", true)
			elapsed = @elapsed write_price_benders(outpath, inputs, setup, benders_bundle.price)
			println("Time elapsed for writing prices is")
			println(elapsed)
		end
		if get(output_settings_d, "WriteReliability", true)
			elapsed = @elapsed write_reliability_benders(outpath, inputs, setup, benders_bundle.reliability)
			println("Time elapsed for writing reliability is")
			println(elapsed)
		end
		if !isempty(inputs["STOR_ALL"]) && get(output_settings_d, "WriteStorageDual", true)
			elapsed = @elapsed write_storagedual_benders(outpath, inputs, setup, benders_bundle.storagedual)
			println("Time elapsed for writing storage balance duals is")
			println(elapsed)
		end
		if setup["MultiStage"] == 0
			if get(output_settings_d, "WriteEnergyRevenue", true)
				elapsed = @elapsed write_energy_revenue_benders(outpath, inputs, setup, benders_bundle)
				println("Time elapsed for writing energy revenue is")
				println(elapsed)
			end
			if get(output_settings_d, "WriteChargingCost", true)
				elapsed = @elapsed write_charging_cost_benders(outpath, inputs, setup, benders_bundle)
				println("Time elapsed for writing charging cost is")
				println(elapsed)
			end
		end
	end

	# Unit commitment outputs
	if setup["UCommit"] >= 1 && !isempty(inputs["COMMIT"])
		if get(output_settings_d, "WriteCommit", true) && !isempty(benders_bundle.commit)
			elapsed = @elapsed write_ucommit_benders(outpath, inputs, setup, benders_bundle.commit, "commit")
			println("Time elapsed for writing commitment is")
			println(elapsed)
		end
		if get(output_settings_d, "WriteStart", true) && !isempty(benders_bundle.start_up)
			elapsed = @elapsed write_ucommit_benders(outpath, inputs, setup, benders_bundle.start_up, "start")
			println("Time elapsed for writing startup is")
			println(elapsed)
		end
		if get(output_settings_d, "WriteShutdown", true) && !isempty(benders_bundle.shut_down)
			elapsed = @elapsed write_ucommit_benders(outpath, inputs, setup, benders_bundle.shut_down, "shutdown")
			println("Time elapsed for writing shutdown is")
			println(elapsed)
		end
	end
end

@doc raw"""
	write_nw_expansion_benders(path, inputs, setup, planning_problem, planning_sol)

Write `network_expansion.csv` for a Benders run using the incumbent planning solution.

Transmission reinforcement (`vNEW_TRANS_CAP`) is a first-stage variable, so its value is read
from `planning_sol` by substituting the incumbent variable values into the planning-problem
variable (`value(v -> planning_sol.values[name(v)], ...)`) — no solved model state required.
Mirrors the monolithic `write_nw_expansion`.
"""
function write_nw_expansion_benders(path::AbstractString, inputs::Dict, setup::Dict,
	planning_problem::Model, planning_sol::NamedTuple)
	L = inputs["L"]

	pv(x) = value(v -> planning_sol.values[name(v)], x)

	transcap = zeros(L)
	for i in 1:L
		if i in inputs["EXPANSION_LINES"]
			transcap[i] = pv(planning_problem[:vNEW_TRANS_CAP][i])
		end
	end

	dfTransCap = DataFrame(Line = 1:L,
		New_Trans_Capacity = convert(Array{Float64}, transcap),
		Cost_Trans_Capacity = convert(Array{Float64},
			transcap .* inputs["pC_Line_Reinforcement"]))

	if setup["ParameterScale"] == 1
		dfTransCap.New_Trans_Capacity *= ModelScalingFactor       # GW to MW
		dfTransCap.Cost_Trans_Capacity *= ModelScalingFactor^2    # MUSD to USD
	end

	CSV.write(joinpath(path, "network_expansion.csv"), dfTransCap)
	return nothing
end

@doc raw"""
	write_capacity_benders(path, inputs, setup, planning_problem, planning_sol)

Write `capacity.csv` for a Benders run using the incumbent planning solution directly.

Capacity quantities are evaluated by substituting the best-incumbent variable values from
`planning_sol.values` into the planning-problem variables and capacity expressions
(`value(v -> planning_sol.values[name(v)], ...)`), so the output reflects the same
first-stage solution as the dispatch outputs regardless of the planning-problem model's
post-Benders solve state. This mirrors the monolithic `write_capacity` column-for-column
except that `CapacityConstraintDual` is omitted: that column is a shadow price, which is not
available from `planning_sol` (and is not reliably recoverable from the cut-laden master).
It can be reintroduced once a trustworthy planning dual is available.
"""
function write_capacity_benders(path::AbstractString, inputs::Dict, setup::Dict,
	planning_problem::Model, planning_sol::NamedTuple)
	gen = inputs["RESOURCES"]
	G = inputs["G"]

	sco2turbine = 1
	ALLAM_CYCLE_LOX = inputs["ALLAM_CYCLE_LOX"]
	COMMIT_Allam = setup["UCommit"] > 0 ? ALLAM_CYCLE_LOX : Int[]

	# Evaluate a planning variable or expression at the incumbent solution by substituting
	# variable values from planning_sol. No solved model state is required.
	pv(x) = value(v -> planning_sol.values[name(v)], x)

	# Capacity decisions (discharge)
	capdischarge = zeros(size(inputs["RESOURCE_NAMES"]))
	for i in inputs["NEW_CAP"]
		if i in inputs["COMMIT"]
			capdischarge[i] = pv(planning_problem[:vCAP][i]) * cap_size(gen[i])
		elseif i in COMMIT_Allam
			capdischarge[i] = pv(planning_problem[:vCAP_AllamCycleLOX][i, sco2turbine]) * inputs["allam_dict"][i, "cap_size"][sco2turbine]
		elseif i in ALLAM_CYCLE_LOX
			capdischarge[i] = pv(planning_problem[:vCAP_AllamCycleLOX][i, sco2turbine])
		else
			capdischarge[i] = pv(planning_problem[:vCAP][i])
		end
	end

	retcapdischarge = zeros(size(inputs["RESOURCE_NAMES"]))
	for i in inputs["RET_CAP"]
		if i in inputs["COMMIT"]
			retcapdischarge[i] = pv(planning_problem[:vRETCAP][i]) * cap_size(gen[i])
		elseif i in COMMIT_Allam
			retcapdischarge[i] = pv(planning_problem[:vRETCAP_AllamCycleLOX][i, sco2turbine]) * inputs["allam_dict"][i, "cap_size"][sco2turbine]
		elseif i in ALLAM_CYCLE_LOX
			retcapdischarge[i] = pv(planning_problem[:vRETCAP_AllamCycleLOX][i, sco2turbine])
		else
			retcapdischarge[i] = pv(planning_problem[:vRETCAP][i])
		end
	end

	retrocapdischarge = zeros(size(inputs["RESOURCE_NAMES"]))
	for i in inputs["RETROFIT_CAP"]
		if i in inputs["COMMIT"]
			retrocapdischarge[i] = pv(planning_problem[:vRETROFITCAP][i]) * cap_size(gen[i])
		else
			retrocapdischarge[i] = pv(planning_problem[:vRETROFITCAP][i])
		end
	end

	# CapacityConstraintDual intentionally omitted for Benders (see docstring).

	capcharge = zeros(size(inputs["RESOURCE_NAMES"]))
	retcapcharge = zeros(size(inputs["RESOURCE_NAMES"]))
	existingcapcharge = zeros(size(inputs["RESOURCE_NAMES"]))
	for i in inputs["STOR_ASYMMETRIC"]
		if i in inputs["NEW_CAP_CHARGE"]
			capcharge[i] = pv(planning_problem[:vCAPCHARGE][i])
		end
		if i in inputs["RET_CAP_CHARGE"]
			retcapcharge[i] = pv(planning_problem[:vRETCAPCHARGE][i])
		end
		existingcapcharge[i] = existing_charge_cap_mw(gen[i])
	end

	capenergy = zeros(size(inputs["RESOURCE_NAMES"]))
	retcapenergy = zeros(size(inputs["RESOURCE_NAMES"]))
	existingcapenergy = zeros(size(inputs["RESOURCE_NAMES"]))
	for i in inputs["STOR_ALL"]
		if i in inputs["NEW_CAP_ENERGY"]
			capenergy[i] = pv(planning_problem[:vCAPENERGY][i])
		end
		if i in inputs["RET_CAP_ENERGY"]
			retcapenergy[i] = pv(planning_problem[:vRETCAPENERGY][i])
		end
		existingcapenergy[i] = existing_cap_mwh(gen[i])
	end
	if !isempty(inputs["VRE_STOR"])
		for i in inputs["VS_STOR"]
			if i in inputs["NEW_CAP_STOR"]
				capenergy[i] = pv(planning_problem[:vCAPENERGY_VS][i])
			end
			if i in inputs["RET_CAP_STOR"]
				retcapenergy[i] = pv(planning_problem[:vRETCAPENERGY_VS][i])
			end
			existingcapenergy[i] = existing_cap_mwh(gen[i])
		end
	end

	startcap = existing_cap_mw.(gen)
	endcap = [pv(planning_problem[:eTotalCap][y]) for y in 1:G]

	# Allam cycle LOX uses the sCO2 turbine existing/total capacity
	for y in ALLAM_CYCLE_LOX
		startcap[y] = pv(planning_problem[:eExistingCap_AllamCycleLOX][y, sco2turbine])
		endcap[y] = pv(planning_problem[:eTotalCap_AllamcycleLOX][y, sco2turbine])
	end

	dfCap = DataFrame(Resource = inputs["RESOURCE_NAMES"],
		Zone = zone_id.(gen),
		Retrofit_Id = retrofit_id.(gen),
		StartCap = startcap[:],
		RetCap = retcapdischarge[:],
		RetroCap = retrocapdischarge[:],
		NewCap = capdischarge[:],
		EndCap = endcap[:],
		StartEnergyCap = existingcapenergy[:],
		RetEnergyCap = retcapenergy[:],
		NewEnergyCap = capenergy[:],
		EndEnergyCap = existingcapenergy[:] - retcapenergy[:] + capenergy[:],
		StartChargeCap = existingcapcharge[:],
		RetChargeCap = retcapcharge[:],
		NewChargeCap = capcharge[:],
		EndChargeCap = existingcapcharge[:] - retcapcharge[:] + capcharge[:])
	if setup["ParameterScale"] == 1
		dfCap.StartCap = dfCap.StartCap * ModelScalingFactor
		dfCap.RetCap = dfCap.RetCap * ModelScalingFactor
		dfCap.RetroCap = dfCap.RetroCap * ModelScalingFactor
		dfCap.NewCap = dfCap.NewCap * ModelScalingFactor
		dfCap.EndCap = dfCap.EndCap * ModelScalingFactor
		dfCap.StartEnergyCap = dfCap.StartEnergyCap * ModelScalingFactor
		dfCap.RetEnergyCap = dfCap.RetEnergyCap * ModelScalingFactor
		dfCap.NewEnergyCap = dfCap.NewEnergyCap * ModelScalingFactor
		dfCap.EndEnergyCap = dfCap.EndEnergyCap * ModelScalingFactor
		dfCap.StartChargeCap = dfCap.StartChargeCap * ModelScalingFactor
		dfCap.RetChargeCap = dfCap.RetChargeCap * ModelScalingFactor
		dfCap.NewChargeCap = dfCap.NewChargeCap * ModelScalingFactor
		dfCap.EndChargeCap = dfCap.EndChargeCap * ModelScalingFactor
	end
	total = DataFrame(Resource = "Total", Zone = "n/a", Retrofit_Id = "n/a",
		StartCap = sum(dfCap[!, :StartCap]), RetCap = sum(dfCap[!, :RetCap]),
		NewCap = sum(dfCap[!, :NewCap]), EndCap = sum(dfCap[!, :EndCap]),
		RetroCap = sum(dfCap[!, :RetroCap]),
		StartEnergyCap = sum(dfCap[!, :StartEnergyCap]),
		RetEnergyCap = sum(dfCap[!, :RetEnergyCap]),
		NewEnergyCap = sum(dfCap[!, :NewEnergyCap]),
		EndEnergyCap = sum(dfCap[!, :EndEnergyCap]),
		StartChargeCap = sum(dfCap[!, :StartChargeCap]),
		RetChargeCap = sum(dfCap[!, :RetChargeCap]),
		NewChargeCap = sum(dfCap[!, :NewChargeCap]),
		EndChargeCap = sum(dfCap[!, :EndChargeCap]))

	dfCap = vcat(dfCap, total)
	CSV.write(joinpath(path, "capacity.csv"), dfCap)
	return dfCap
end

@doc raw"""
	write_co2_emissions_plant(path, inputs, setup, emissions_plant)

Write per-plant annual CO2 emissions to `emissions_plant.csv`.

`emissions_plant` is a `(G × T)` matrix of unscaled emissions values.  Scale factor is
applied before computing the annual weighted sum.  Time-series columns are written when
`setup["WriteOutputs"] != "annual"`.
"""
function write_co2_emissions_plant(path::AbstractString,
	inputs::Dict,
	setup::Dict,
	emissions_plant::Array)

	gen = inputs["RESOURCES"]  # Resources (objects)
	resources = inputs["RESOURCE_NAMES"] # Resource names
	zones = zone_id.(gen)

	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)

	weight = inputs["omega"]
	scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

	emissions_plant *= scale_factor

	df = DataFrame(Resource = resources,
		Zone = zones,
		AnnualSum = zeros(G))
	df.AnnualSum .= emissions_plant * weight

	write_temporal_data(df, emissions_plant, path, setup, "emissions_plant")
	return nothing
end


@doc raw"""
	write_power(path, inputs, setup, power)

Write per-resource power output to `power.csv`.

`power` is a `(G × T)` matrix of unscaled dispatch values.  The scale factor is applied,
annual weighted sums are computed, and time-series columns are included when
`setup["WriteOutputs"] != "annual"`.
"""
function write_power(path::AbstractString, inputs::Dict, setup::Dict, power::Matrix)
    gen = inputs["RESOURCES"]   # Resources (objects)
    resources = inputs["RESOURCE_NAMES"]    # Resource names
    zones = zone_id.(gen)

    G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
    T = inputs["T"]     # Number of time steps (hours)
    
    weight = inputs["omega"]
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    # Power injected by each resource in each time step
    power *= scale_factor

    df = DataFrame(Resource = resources,
        Zone = zones,
        AnnualSum = zeros(G))
    df.AnnualSum .= power * weight

    write_temporal_data(df, power, path, setup, "power")
    return df
end

@doc raw"""
	write_charge(path, inputs, setup, charge, charge_ids)

Write charging power to `charge.csv` for the subset of resources indexed by `charge_ids`.

`charge` is a `(length(charge_ids) × T)` matrix of unscaled values.
"""
function write_charge(path::AbstractString, inputs::Dict, setup::Dict, charge::Matrix, charge_ids::Vector{Int})
    gen = inputs["RESOURCES"]   # Resources (objects) 
    resources = inputs["RESOURCE_NAMES"]    # Resource names
    zones = zone_id.(gen)

    weight = inputs["omega"]
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

	charge *= scale_factor

    df = DataFrame(Resource = resources[charge_ids],
        Zone = zones[charge_ids])
    df.AnnualSum = charge * weight

    write_temporal_data(df, charge, path, setup, "charge")
    return nothing
end

@doc raw"""
	write_storage_benders(path, inputs, setup, stored, stored_ids)

Write state-of-charge values to `storage.csv` for resources indexed by `stored_ids`.

`stored` is a `(length(stored_ids) × T)` matrix of unscaled state-of-charge values.
"""
function write_storage_benders(path::AbstractString, inputs::Dict, setup::Dict, stored::Matrix, stored_ids::Vector{Int})
	gen = inputs["RESOURCES"]
	resources = inputs["RESOURCE_NAMES"]
	zones = zone_id.(gen)

	weight = inputs["omega"]
	scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

	stored *= scale_factor

	df = DataFrame(Resource = resources[stored_ids],
		Zone = zones[stored_ids])
	df.AnnualSum = stored * weight

	write_temporal_data(df, stored, path, setup, "storage")
	return nothing
end

@doc raw"""
	write_curtailment_benders(path, inputs, setup, curtailment)

Write VRE curtailment to `curtailment.csv`.

`curtailment` is a `(G × T)` matrix of unscaled curtailment values (available generation
minus dispatched generation for VRE resources, zero for others).
"""
function write_curtailment_benders(path::AbstractString, inputs::Dict, setup::Dict, curtailment::Matrix)
	gen = inputs["RESOURCES"]
	resources = inputs["RESOURCE_NAMES"]
	zones = zone_id.(gen)

	G = inputs["G"]
	weight = inputs["omega"]
	scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

	curtailment *= scale_factor

	df = DataFrame(Resource = resources,
		Zone = zones,
		AnnualSum = zeros(G))
	df.AnnualSum = curtailment * weight

	write_temporal_data(df, curtailment, path, setup, "curtailment")
	return nothing
end

@doc raw"""
	write_nse_benders(path, inputs, setup, nse)

Write non-served energy (NSE) by segment and zone to `nse.csv`.

`nse` is a `(SEG*Z × T)` matrix laid out as segments cycling within zones.
Annual or time-series output is selected by `setup["WriteOutputs"]`.
"""
function write_nse_benders(path::AbstractString, inputs::Dict, setup::Dict, nse::Matrix)
	T = inputs["T"]
	Z = inputs["Z"]
	SEG = inputs["SEG"]

	# Match the monolithic writer: convert model units (GW under ParameterScale) to MW.
	scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
	nse = nse .* scale_factor

	dfNse = DataFrame(Segment = repeat(1:SEG, outer = Z),
		Zone = repeat(1:Z, inner = SEG),
		AnnualSum = zeros(SEG * Z))
	dfNse.AnnualSum .= nse * inputs["omega"]

	if setup["WriteOutputs"] == "annual"
		total = DataFrame(["Total" 0 sum(dfNse[!, :AnnualSum])],
			[:Segment, :Zone, :AnnualSum])
		dfNse = vcat(dfNse, total)
		CSV.write(joinpath(path, "nse.csv"), dfNse)
	else
		dfNse = hcat(dfNse, DataFrame(nse, :auto))
		auxNew_Names = [Symbol("Segment");
						Symbol("Zone");
						Symbol("AnnualSum");
						[Symbol("t$t") for t in 1:T]]
		rename!(dfNse, auxNew_Names)

		total = DataFrame(["Total" 0 sum(dfNse[!, :AnnualSum]) fill(0.0, (1, T))], :auto)
		total[:, 4:(T + 3)] .= sum(nse, dims = 1)
		rename!(total, auxNew_Names)
		dfNse = vcat(dfNse, total)

		CSV.write(joinpath(path, "nse.csv"), dftranspose(dfNse, false), writeheader = false)

		if setup["OutputFullTimeSeries"] == 1 && setup["TimeDomainReduction"] == 1
			write_full_time_series_reconstruction(path, setup, dfNse, "nse")
			@info("Writing Full Time Series for NSE")
		end
	end
	return nothing
end

@doc raw"""
	write_power_balance_benders(path, inputs, setup, benders_bundle)

Write the zonal power balance decomposition to `power_balance.csv`.

Assembles the `(Lcomp*Z × T)` power-balance matrix from the operational time series
stored in `benders_bundle`, covering generation, storage discharge/charge, flexible
demand, NSE, transmission net exports and losses, demand, and optional electrolyzer,
VRE-storage, and fusion components.
"""
function write_power_balance_benders(path::AbstractString, inputs::Dict, setup::Dict, benders_bundle::NamedTuple)
	gen = inputs["RESOURCES"]
	T = inputs["T"]
	Z = inputs["Z"]
	SEG = inputs["SEG"]
	THERM_ALL = inputs["THERM_ALL"]
	VRE = inputs["VRE"]
	MUST_RUN = inputs["MUST_RUN"]
	HYDRO_RES = inputs["HYDRO_RES"]
	STOR_ALL = inputs["STOR_ALL"]
	FLEX = inputs["FLEX"]
	ALLAM_CYCLE_LOX = inputs["ALLAM_CYCLE_LOX"]
	ELECTROLYZER = inputs["ELECTROLYZER"]
	VRE_STOR = inputs["VRE_STOR"]
	FUSION = ids_with(gen, :fusion)

	Com_list = ["Generation", "Storage_Discharge", "Storage_Charge",
		"Flexible_Demand_Defer", "Flexible_Demand_Stasify",
		"Demand_Response", "Nonserved_Energy",
		"Transmission_NetExport", "Transmission_Losses",
		"Demand"]
	if !isempty(ELECTROLYZER)
		push!(Com_list, "Electrolyzer_Consumption")
	end
	if !isempty(VRE_STOR)
		push!(Com_list, "VRE_Storage_Discharge")
		push!(Com_list, "VRE_Storage_Charge")
	end
	if !isempty(FUSION)
		push!(Com_list, "Fusion_parasitic_power")
	end

	Lcomp = length(Com_list)
	dfPowerBalance = DataFrame(BalanceComponent = repeat(Com_list, outer = Z),
		Zone = repeat(1:Z, inner = Lcomp),
		AnnualSum = zeros(Lcomp * Z))
	powerbalance = zeros(Z * Lcomp, T)

	for z in 1:Z
		POWER_ZONE = intersect(resources_in_zone_by_rid(gen, z), union(THERM_ALL, VRE, MUST_RUN, HYDRO_RES, ALLAM_CYCLE_LOX))
		ALLAM_ZONE = intersect(resources_in_zone_by_rid(gen, z), ALLAM_CYCLE_LOX)

		if !isempty(ALLAM_ZONE)
			powerbalance[(z - 1) * Lcomp + 1, :] = sum(benders_bundle.power[POWER_ZONE, :], dims = 1) - sum(benders_bundle.charge_allam[ALLAM_ZONE, :], dims = 1)
		else
			powerbalance[(z - 1) * Lcomp + 1, :] = sum(benders_bundle.power[POWER_ZONE, :], dims = 1)
		end

		STOR_ALL_ZONE = intersect(resources_in_zone_by_rid(gen, z), STOR_ALL)
		if !isempty(STOR_ALL_ZONE)
			powerbalance[(z - 1) * Lcomp + 2, :] = sum(benders_bundle.power[STOR_ALL_ZONE, :], dims = 1)
			powerbalance[(z - 1) * Lcomp + 3, :] = (-1) * sum(benders_bundle.charge_storage[STOR_ALL_ZONE, :], dims = 1)
		end

		FLEX_ZONE = intersect(resources_in_zone_by_rid(gen, z), FLEX)
		if !isempty(FLEX_ZONE)
			powerbalance[(z - 1) * Lcomp + 4, :] = sum(benders_bundle.charge_flex[FLEX_ZONE, :], dims = 1)
			powerbalance[(z - 1) * Lcomp + 5, :] = (-1) * sum(benders_bundle.power[FLEX_ZONE, :], dims = 1)
		end

		if SEG > 1
			powerbalance[(z - 1) * Lcomp + 6, :] = sum(benders_bundle.nse[((z - 1) * SEG + 2):(z * SEG), :], dims = 1)
		end
		powerbalance[(z - 1) * Lcomp + 7, :] = benders_bundle.nse[(z - 1) * SEG + 1, :]

		if Z >= 2
			powerbalance[(z - 1) * Lcomp + 8, :] = benders_bundle.net_export_zone[z, :]
			powerbalance[(z - 1) * Lcomp + 9, :] = -benders_bundle.losses_zone[z, :]
		end

		powerbalance[(z - 1) * Lcomp + 10, :] = (-inputs["pD"][:, z])'

		if !isempty(ELECTROLYZER)
			ELECTROLYZER_ZONE = intersect(resources_in_zone_by_rid(gen, z), ELECTROLYZER)
			powerbalance[(z - 1) * Lcomp + 11, :] = (-1) * sum(benders_bundle.use_electrolyzer[ELECTROLYZER_ZONE, :], dims = 1)
		end

		if !isempty(intersect(resources_in_zone_by_rid(gen, z), VRE_STOR))
			VS_ALL_ZONE = intersect(resources_in_zone_by_rid(gen, z), inputs["VS_STOR"])
			is_electrolyzer_empty = isempty(ELECTROLYZER)
			discharge_idx = is_electrolyzer_empty ? 11 : 12
			charge_idx = is_electrolyzer_empty ? 12 : 13
			powerbalance[(z - 1) * Lcomp + discharge_idx, :] = sum(benders_bundle.power[VS_ALL_ZONE, :], dims = 1)
			powerbalance[(z - 1) * Lcomp + charge_idx, :] = (-1) * sum(benders_bundle.charge_vre_stor[VS_ALL_ZONE, :], dims = 1)
		end

		FUSION_ZONE = intersect(resources_in_zone_by_rid(gen, z), FUSION)
		if !isempty(FUSION_ZONE)
			idx = 11
			if !isempty(ELECTROLYZER)
				idx += 1
			end
			if !isempty(VRE_STOR)
				idx += 2
			end
			powerbalance[(z - 1) * Lcomp + idx, :] = -sum(benders_bundle.fusion_parasitic[FUSION_ZONE, :], dims = 1)
		end
	end

	if setup["ParameterScale"] == 1
		powerbalance *= ModelScalingFactor
	end

	dfPowerBalance.AnnualSum .= powerbalance * inputs["omega"]

	if setup["WriteOutputs"] == "annual"
		CSV.write(joinpath(path, "power_balance.csv"), dfPowerBalance)
	else
		dfPowerBalance = hcat(dfPowerBalance, DataFrame(powerbalance, :auto))
		auxNew_Names = [Symbol("BalanceComponent"); Symbol("Zone"); Symbol("AnnualSum"); [Symbol("t$t") for t in 1:T]]
		rename!(dfPowerBalance, auxNew_Names)
		CSV.write(joinpath(path, "power_balance.csv"), dftranspose(dfPowerBalance, false), writeheader = false)

		if setup["OutputFullTimeSeries"] == 1 && setup["TimeDomainReduction"] == 1
			write_full_time_series_reconstruction(path, setup, dfPowerBalance, "power_balance")
			@info("Writing Full Time Series for Power Balance")
		end
	end
	return nothing
end

@doc raw"""
	write_transmission_flows_benders(path, inputs, setup, flow)

Write line-level power flows to `flow.csv`.

`flow` is a `(L × T)` matrix of unscaled flow values.  Annual or time-series output
is selected by `setup["WriteOutputs"]`.
"""
function write_transmission_flows_benders(path::AbstractString, inputs::Dict, setup::Dict, flow::Matrix)
	T = inputs["T"]
	L = inputs["L"]

	dfFlow = DataFrame(Line = 1:L)
	if setup["ParameterScale"] == 1
		flow *= ModelScalingFactor
	end

	filepath = joinpath(path, "flow.csv")
	if setup["WriteOutputs"] == "annual"
		dfFlow.AnnualSum = flow * inputs["omega"]
		total = DataFrame(["Total" sum(dfFlow.AnnualSum)], [:Line, :AnnualSum])
		dfFlow = vcat(dfFlow, total)
		CSV.write(filepath, dfFlow)
	else
		dfFlow = hcat(dfFlow, DataFrame(flow, :auto))
		auxNew_Names = [Symbol("Line"); [Symbol("t$t") for t in 1:T]]
		rename!(dfFlow, auxNew_Names)
		CSV.write(filepath, dftranspose(dfFlow, false), writeheader = false)

		if setup["OutputFullTimeSeries"] == 1 && setup["TimeDomainReduction"] == 1
			write_full_time_series_reconstruction(path, setup, dfFlow, "flow")
			@info("Writing Full Time Series for Transmission Flows")
		end
	end
	return nothing
end

@doc raw"""
	write_transmission_losses_benders(path, inputs, setup, tlosses)

Write line-level transmission losses to `tlosses.csv`.

`tlosses` is a `(L × T)` matrix of unscaled loss values.  Annual or time-series output
is selected by `setup["WriteOutputs"]`.
"""
function write_transmission_losses_benders(path::AbstractString, inputs::Dict, setup::Dict, tlosses::Matrix)
	T = inputs["T"]
	L = inputs["L"]

	dfTLosses = DataFrame(Line = 1:L)
	if setup["ParameterScale"] == 1
		tlosses *= ModelScalingFactor
	end

	dfTLosses.AnnualSum = tlosses * inputs["omega"]

	if setup["WriteOutputs"] == "annual"
		total = DataFrame(["Total" sum(dfTLosses.AnnualSum)], [:Line, :AnnualSum])
		dfTLosses = vcat(dfTLosses, total)
		CSV.write(joinpath(path, "tlosses.csv"), dfTLosses)
	else
		dfTLosses = hcat(dfTLosses, DataFrame(tlosses, :auto))
		auxNew_Names = [Symbol("Line"); Symbol("AnnualSum"); [Symbol("t$t") for t in 1:T]]
		rename!(dfTLosses, auxNew_Names)
		total = DataFrame(["Total" sum(dfTLosses.AnnualSum) fill(0.0, (1, T))], auxNew_Names)
		total[:, 3:(T + 2)] .= sum(tlosses, dims = 1)
		dfTLosses = vcat(dfTLosses, total)
		CSV.write(joinpath(path, "tlosses.csv"), dftranspose(dfTLosses, false), writeheader = false)

		if setup["OutputFullTimeSeries"] == 1 && setup["TimeDomainReduction"] == 1
			write_full_time_series_reconstruction(path, setup, dfTLosses, "tlosses")
			@info("Writing Full Time Series for Time Losses")
		end
	end
	return nothing
end

@doc raw"""
	write_emissions_benders(path, inputs, setup, emissions_by_zone)

Write total CO2 emissions aggregated by zone to `emissions.csv`.

`emissions_by_zone` is a `(Z × T)` matrix of unscaled zone-level emissions.  Annual or
time-series output is selected by `setup["WriteOutputs"]`.
"""
function write_emissions_benders(path::AbstractString, inputs::Dict, setup::Dict, emissions_by_zone::Matrix)
	T = inputs["T"]
	Z = inputs["Z"]

	scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

	dfEmissions = DataFrame(Zone = 1:Z, AnnualSum = Array{Float64}(undef, Z))
	for i in 1:Z
		dfEmissions[i, :AnnualSum] = sum(inputs["omega"] .* emissions_by_zone[i, :]) * scale_factor
	end

	if setup["WriteOutputs"] == "annual"
		total = DataFrame(["Total" sum(dfEmissions.AnnualSum)], [:Zone; :AnnualSum])
		dfEmissions = vcat(dfEmissions, total)
		CSV.write(joinpath(path, "emissions.csv"), dfEmissions)
	else
		dfEmissions = hcat(dfEmissions, DataFrame(emissions_by_zone * scale_factor, :auto))
		auxNew_Names = [Symbol("Zone"); Symbol("AnnualSum"); [Symbol("t$t") for t in 1:T]]
		rename!(dfEmissions, auxNew_Names)
		total = DataFrame(["Total" sum(dfEmissions[!, :AnnualSum]) fill(0.0, (1, T))], :auto)
		for t in 1:T
			total[:, t + 2] .= sum(dfEmissions[:, Symbol("t$t")][1:Z])
		end
		rename!(total, auxNew_Names)
		dfEmissions = vcat(dfEmissions, total)
		CSV.write(joinpath(path, "emissions.csv"), dftranspose(dfEmissions, false), writeheader = false)

		if setup["OutputFullTimeSeries"] == 1 && setup["TimeDomainReduction"] == 1
			write_full_time_series_reconstruction(path, setup, dfEmissions, "emissions")
			@info("Writing Full Time Series for Emissions")
		end
	end

	return nothing
end

@doc raw"""
	write_fuel_consumption_benders(path, inputs, setup, benders_bundle)

Write all fuel consumption outputs.

Calls `write_fuel_consumption_plant_benders`, `write_fuel_consumption_ts_benders`
(when time-series output is requested), and `write_fuel_consumption_tot_benders`.
"""
function write_fuel_consumption_benders(path::AbstractString, inputs::Dict, setup::Dict, benders_bundle::NamedTuple)
	write_fuel_consumption_plant_benders(path, inputs, setup, benders_bundle)
	if setup["WriteOutputs"] != "annual"
		write_fuel_consumption_ts_benders(path, inputs, setup, benders_bundle)
	end
	write_fuel_consumption_tot_benders(path, inputs, setup, benders_bundle)
end

@doc raw"""
	write_fuel_consumption_plant_benders(path, inputs, setup, benders_bundle)

Write per-plant annual fuel costs and heat input to `Fuel_cost_plant.csv`.

Includes multi-fuel breakdown columns when `inputs["MULTI_FUELS"]` is non-empty.
"""
function write_fuel_consumption_plant_benders(path::AbstractString, inputs::Dict, setup::Dict, benders_bundle::NamedTuple)
	gen = inputs["RESOURCES"]
	HAS_FUEL = inputs["HAS_FUEL"]
	MULTI_FUELS = inputs["MULTI_FUELS"]

	# Match the monolithic writer's ParameterScale handling: heat input (MMBtu) scales by
	# ModelScalingFactor, while costs scale by ModelScalingFactor^2 (price x quantity).
	scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

	annual_costs = (benders_bundle.fuel_cost_out + benders_bundle.fuel_cost_start) .* scale_factor^2

	dfPlantFuel = DataFrame(Resource = inputs["RESOURCE_NAMES"][HAS_FUEL],
		Fuel = fuel.(gen[HAS_FUEL]),
		Zone = zone_id.(gen[HAS_FUEL]),
		AnnualSumCosts = annual_costs[HAS_FUEL])

	if !isempty(MULTI_FUELS)
		fuel_cols_num = inputs["FUEL_COLS"]
		max_fuels = inputs["MAX_NUM_FUELS"]
		dfPlantFuel.Multi_Fuels = multi_fuels.(gen[HAS_FUEL])
		for i in 1:max_fuels
			dfPlantFuel[!, fuel_cols_num[i]] = fuel_cols.(gen[HAS_FUEL], tag = i)
			dfPlantFuel[!, Symbol(string(fuel_cols_num[i], "_AnnualSum_Fuel_HeatInput_Generation_MMBtu"))] = benders_bundle.multi_fuel_generation[:, i] .* scale_factor
			dfPlantFuel[!, Symbol(string(fuel_cols_num[i], "_AnnualSum_Fuel_HeatInput_Start_MMBtu"))] = benders_bundle.multi_fuel_start[:, i] .* scale_factor
			dfPlantFuel[!, Symbol(string(fuel_cols_num[i], "_AnnualSum_Fuel_HeatInput_Total_MMBtu"))] = benders_bundle.multi_fuel_total[:, i] .* scale_factor
			dfPlantFuel[!, Symbol(string(fuel_cols_num[i], "_AnnualSum_Fuel_Cost"))] = benders_bundle.multi_fuel_cost[:, i] .* scale_factor^2
		end
	end

	CSV.write(joinpath(path, "Fuel_cost_plant.csv"), dfPlantFuel)
end

@doc raw"""
	write_fuel_consumption_ts_benders(path, inputs, setup, benders_bundle)

Write per-plant hourly fuel consumption time series to `FuelConsumption_plant_MMBTU.csv`.

Only called when `setup["WriteOutputs"] != "annual"`.  Optionally reconstructs the full
time series when `OutputFullTimeSeries` is enabled.
"""
function write_fuel_consumption_ts_benders(path::AbstractString, inputs::Dict, setup::Dict, benders_bundle::NamedTuple)
	T = inputs["T"]
	HAS_FUEL = inputs["HAS_FUEL"]

	# Match the monolithic writer: convert model units (kMMBtu under ParameterScale) to MMBtu.
	scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

	dfPlantFuel_TS = DataFrame(Resource = inputs["RESOURCE_NAMES"][HAS_FUEL])
	tempts = benders_bundle.fuel_ts[HAS_FUEL, :] .* scale_factor
	dfPlantFuel_TS = hcat(dfPlantFuel_TS, DataFrame(tempts, [Symbol("t$t") for t in 1:T]))
	CSV.write(joinpath(path, "FuelConsumption_plant_MMBTU.csv"), dftranspose(dfPlantFuel_TS, false), header = false)

	if setup["OutputFullTimeSeries"] == 1 && setup["TimeDomainReduction"] == 1
		write_full_time_series_reconstruction(path, setup, dfPlantFuel_TS, "FuelConsumption_plant_MMBTU")
		@info("Writing Full Time Series for Fuel Consumption")
	end
end

@doc raw"""
	write_fuel_consumption_tot_benders(path, inputs, setup, benders_bundle)

Write total annual fuel consumption aggregated by fuel type to `FuelConsumption_total_MMBTU.csv`.
"""
function write_fuel_consumption_tot_benders(path::AbstractString, inputs::Dict, setup::Dict, benders_bundle::NamedTuple)
	fuel_types = inputs["fuels"]
	fuel_number = length(fuel_types)
	# Match the monolithic writer: convert model units (billion MMBtu under ParameterScale) to MMBtu.
	scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
	dfFuel = DataFrame(Fuel = fuel_types, AnnualSum = zeros(fuel_number))
	dfFuel.AnnualSum .+= benders_bundle.fuel_total .* scale_factor
	CSV.write(joinpath(path, "FuelConsumption_total_MMBTU.csv"), dfFuel)
end

@doc raw"""
    write_price_benders(path, inputs, setup, price)

Write locational marginal prices (LMPs) from Benders subproblem duals.
`price` is a (Z × T) matrix already scaled (\$/MWh) and divided by period weights.
"""
function write_price_benders(path::AbstractString, inputs::Dict, setup::Dict, price::Matrix)
    T = inputs["T"]
    Z = inputs["Z"]
    dfPrice = DataFrame(Zone = 1:Z)
    dfPrice = hcat(dfPrice, DataFrame(price, :auto))
    rename!(dfPrice, [Symbol("Zone"); [Symbol("t$t") for t in 1:T]])
    CSV.write(joinpath(path, "prices.csv"), dftranspose(dfPrice, false), writeheader = false)
    if setup["OutputFullTimeSeries"] == 1 && setup["TimeDomainReduction"] == 1
        write_full_time_series_reconstruction(path, setup, dfPrice, "prices")
        @info("Writing Full Time Series for Price")
    end
    return nothing
end

@doc raw"""
    write_reliability_benders(path, inputs, setup, reliability)

Write reliability prices (shadow prices on NSE capacity constraints) from Benders subproblem duals.
`reliability` is a (Z × T) matrix already scaled (\$/MWh) and divided by period weights.
"""
function write_reliability_benders(path::AbstractString, inputs::Dict, setup::Dict, reliability::Matrix)
    T = inputs["T"]
    Z = inputs["Z"]
    dfReliability = DataFrame(Zone = 1:Z)
    dfReliability = hcat(dfReliability, DataFrame(reliability, :auto))
    rename!(dfReliability, [Symbol("Zone"); [Symbol("t$t") for t in 1:T]])
    CSV.write(joinpath(path, "reliability.csv"), dftranspose(dfReliability, false), header = false)
    if setup["OutputFullTimeSeries"] == 1 && setup["TimeDomainReduction"] == 1
        write_full_time_series_reconstruction(path, setup, dfReliability, "reliability")
        @info("Writing Full Time Series for Reliability")
    end
    return nothing
end

@doc raw"""
    write_storagedual_benders(path, inputs, setup, storagedual)

Write storage state-of-charge balance duals from Benders subproblem LPs.
`storagedual` is a (G × T) matrix with duals divided by period weights (scale applied here).
"""
function write_storagedual_benders(path::AbstractString, inputs::Dict, setup::Dict, storagedual::Matrix)
    gen = inputs["RESOURCES"]
    zones = zone_id.(gen)
    G = inputs["G"]
    T = inputs["T"]
    STOR_ALL = inputs["STOR_ALL"]
    VRE_STOR = inputs["VRE_STOR"]
    VS_STOR = !isempty(VRE_STOR) ? inputs["VS_STOR"] : []
    stored_ids = !isempty(VS_STOR) ? union(STOR_ALL, VS_STOR) : STOR_ALL
    if isempty(stored_ids)
        return nothing
    end
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
    storagedual_scaled = storagedual[stored_ids, :] .* scale_factor
    dfStorageDual = DataFrame(Resource = inputs["RESOURCE_NAMES"][stored_ids], Zone = zones[stored_ids])
    dfStorageDual = hcat(dfStorageDual, DataFrame(storagedual_scaled, :auto))
    rename!(dfStorageDual, [Symbol("Resource"); Symbol("Zone"); [Symbol("t$t") for t in 1:T]])
    CSV.write(joinpath(path, "storagebal_duals.csv"), dftranspose(dfStorageDual, false), writeheader = false)
    if setup["OutputFullTimeSeries"] == 1 && setup["TimeDomainReduction"] == 1
        write_full_time_series_reconstruction(path, setup, dfStorageDual, "storagebal_duals")
        @info("Writing Full Time Series for Storage Balance Duals")
    end
    return nothing
end

@doc raw"""
    write_energy_revenue_benders(path, inputs, setup, benders_bundle)

Write annual energy revenue for each generator using subproblem LMPs.
"""
function write_energy_revenue_benders(path::AbstractString, inputs::Dict, setup::Dict, benders_bundle::NamedTuple)
    gen = inputs["RESOURCES"]
    regions = region.(gen)
    clusters = cluster.(gen)
    zones = zone_id.(gen)
    G = inputs["G"]
    FLEX = inputs["FLEX"]
    NONFLEX = setdiff(1:G, FLEX)
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    # price (Z, T) is already omega-divided and scaled; power (G, T) is unscaled
    price = benders_bundle.price
    power = benders_bundle.power

    energyrevenue = zeros(G, inputs["T"])
    if !isempty(NONFLEX)
        energyrevenue[NONFLEX, :] .= power[NONFLEX, :] .* price[zone_id.(gen[NONFLEX]), :] .* scale_factor
    end
    if !isempty(FLEX)
        energyrevenue[FLEX, :] .= benders_bundle.charge_flex[FLEX, :] .* price[zone_id.(gen[FLEX]), :] .* scale_factor
    end

    dfEnergyRevenue = DataFrame(Region = regions, Resource = inputs["RESOURCE_NAMES"],
        Zone = zones, Cluster = clusters, AnnualSum = zeros(G))
    dfEnergyRevenue.AnnualSum .= energyrevenue * inputs["omega"]
    write_simple_csv(joinpath(path, "EnergyRevenue.csv"), dfEnergyRevenue)
    return dfEnergyRevenue
end

@doc raw"""
    write_charging_cost_benders(path, inputs, setup, benders_bundle)

Write annual charging costs for storage and flexible demand resources using subproblem LMPs.
"""
function write_charging_cost_benders(path::AbstractString, inputs::Dict, setup::Dict, benders_bundle::NamedTuple)
    gen = inputs["RESOURCES"]
    regions = region.(gen)
    clusters = cluster.(gen)
    zones = zone_id.(gen)
    G = inputs["G"]
    STOR_ALL = inputs["STOR_ALL"]
    FLEX = inputs["FLEX"]
    ELECTROLYZER = inputs["ELECTROLYZER"]
    VRE_STOR = inputs["VRE_STOR"]
    VS_STOR = !isempty(VRE_STOR) ? inputs["VS_STOR"] : []
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    price = benders_bundle.price  # (Z, T)
    chargecost = zeros(G, inputs["T"])

    if !isempty(STOR_ALL)
        chargecost[STOR_ALL, :] .= benders_bundle.charge_storage[STOR_ALL, :] .* price[zone_id.(gen[STOR_ALL]), :] .* scale_factor
    end
    if !isempty(FLEX)
        chargecost[FLEX, :] .= benders_bundle.power[FLEX, :] .* price[zone_id.(gen[FLEX]), :] .* scale_factor
    end
    if !isempty(ELECTROLYZER)
        chargecost[ELECTROLYZER, :] .= benders_bundle.use_electrolyzer[ELECTROLYZER, :] .* price[zone_id.(gen[ELECTROLYZER]), :] .* scale_factor
    end
    if !isempty(VS_STOR)
        chargecost[VS_STOR, :] .= benders_bundle.charge_vre_stor[VS_STOR, :] .* price[zone_id.(gen[VS_STOR]), :] .* scale_factor
    end

    dfChargingcost = DataFrame(Region = regions, Resource = inputs["RESOURCE_NAMES"],
        Zone = zones, Cluster = clusters, AnnualSum = zeros(G))
    dfChargingcost.AnnualSum .= chargecost * inputs["omega"]
    write_simple_csv(joinpath(path, "ChargingCost.csv"), dfChargingcost)
    return dfChargingcost
end

@doc raw"""
    write_capacityfactor_benders(path, inputs, setup, benders_bundle, planning_problem)

Write capacity factors using power output from subproblems and installed capacity from the planning problem.
"""
function write_capacityfactor_benders(path::AbstractString, inputs::Dict, setup::Dict,
    benders_bundle::NamedTuple, planning_problem::Model)
    gen = inputs["RESOURCES"]
    G = inputs["G"]
    THERM_ALL = inputs["THERM_ALL"]
    VRE = inputs["VRE"]
    HYDRO_RES = inputs["HYDRO_RES"]
    MUST_RUN = inputs["MUST_RUN"]
    ELECTROLYZER = inputs["ELECTROLYZER"]
    VRE_STOR = inputs["VRE_STOR"]
    weight = inputs["omega"]
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    df = DataFrame(Resource = inputs["RESOURCE_NAMES"], Zone = zone_id.(gen),
        AnnualSum = zeros(G), Capacity = zeros(G), CapacityFactor = zeros(G))
    df.AnnualSum .= benders_bundle.power * weight .* scale_factor
    df.Capacity .= value.(planning_problem[:eTotalCap]) .* scale_factor

    # Co-located VRE-storage: report the VRE component capacity factor (solar/wind generation
    # over solar/wind capacity), matching the monolithic write_capacityfactor. The aggregate
    # vP/eTotalCap above describe the grid connection, not the renewable component, so we
    # override those rows here. Generation comes from the subproblems (bundle), sub-component
    # capacities from the planning problem.
    if !isempty(VRE_STOR) && haskey(planning_problem, :eTotalCap_SOLAR) && haskey(planning_problem, :eTotalCap_WIND)
        VS_SOLAR = inputs["VS_SOLAR"]
        VS_WIND = inputs["VS_WIND"]
        SOLAR = setdiff(VS_SOLAR, VS_WIND)
        WIND = setdiff(VS_WIND, VS_SOLAR)
        SOLAR_WIND = intersect(VS_SOLAR, VS_WIND)
        solar_gen = benders_bundle.vre_stor_solar
        wind_gen = benders_bundle.vre_stor_wind
        if !isempty(SOLAR)
            df.AnnualSum[SOLAR] .= solar_gen[SOLAR, :] * weight .* scale_factor
            df.Capacity[SOLAR] .= value.(planning_problem[:eTotalCap_SOLAR][SOLAR]).data .* scale_factor
        end
        if !isempty(WIND)
            df.AnnualSum[WIND] .= wind_gen[WIND, :] * weight .* scale_factor
            df.Capacity[WIND] .= value.(planning_problem[:eTotalCap_WIND][WIND]).data .* scale_factor
        end
        if !isempty(SOLAR_WIND)
            inverter_efficiency = etainverter.(gen[SOLAR_WIND])
            df.AnnualSum[SOLAR_WIND] .= (wind_gen[SOLAR_WIND, :] * weight .* scale_factor) +
                                        (solar_gen[SOLAR_WIND, :] * weight .* scale_factor) .* inverter_efficiency
            df.Capacity[SOLAR_WIND] .= (value.(planning_problem[:eTotalCap_WIND][SOLAR_WIND]).data .* scale_factor) +
                                       (value.(planning_problem[:eTotalCap_SOLAR][SOLAR_WIND]).data .* scale_factor) .* inverter_efficiency
        end
    end

    # Electrolyzer uses consumption (vUSE) rather than power output
    if !isempty(ELECTROLYZER)
        df.AnnualSum[ELECTROLYZER] .= benders_bundle.use_electrolyzer[ELECTROLYZER, :] * weight .* scale_factor
    end

    produces_power = findall(x -> x >= 1, df.AnnualSum)
    has_capacity = findall(x -> x >= 1, df.Capacity)
    EXISTING = intersect(produces_power, has_capacity)
    CF_GEN = intersect(union(THERM_ALL, VRE, HYDRO_RES, MUST_RUN, VRE_STOR, ELECTROLYZER), EXISTING)
    df.CapacityFactor[CF_GEN] .= (df.AnnualSum[CF_GEN] ./ df.Capacity[CF_GEN]) ./ sum(weight)

    CSV.write(joinpath(path, "capacityfactor.csv"), df)
    return nothing
end

@doc raw"""
    write_ucommit_benders(path, inputs, setup, data, filename)

Write unit commitment, startup, or shutdown decisions (generic helper).
`data` is a (COMMIT_count × T) matrix of values.
"""
function write_ucommit_benders(path::AbstractString, inputs::Dict, setup::Dict,
    data::Matrix, filename::AbstractString)
    COMMIT = inputs["COMMIT"]
    if isempty(COMMIT)
        return nothing
    end
    gen = inputs["RESOURCES"]
    df = DataFrame(Resource = inputs["RESOURCE_NAMES"][COMMIT], Zone = zone_id.(gen[COMMIT]),
        AnnualSum = data * inputs["omega"])
    write_temporal_data(df, data, path, setup, filename)
    return nothing
end

@doc raw"""
    write_co2_cap_benders(path, inputs, setup, planning_problem)

Write CO2 prices from the Benders planning problem (constraint `cCO2Emissions_systemwide_planning`).
"""
function write_co2_cap_benders(path::AbstractString, inputs::Dict, setup::Dict, planning_problem::Model)
    dfCO2Price = DataFrame(
        CO2_Cap = [Symbol("CO2_Cap_$cap") for cap in 1:inputs["NCO2Cap"]],
        CO2_Price = (-1) .* Array{Float64}(dual.(planning_problem[:cCO2Emissions_systemwide_planning])))
    if setup["ParameterScale"] == 1
        dfCO2Price.CO2_Price .*= ModelScalingFactor  # Convert M$/kton to $/ton
    end
    CSV.write(joinpath(path, "CO2_prices_and_penalties.csv"), dfCO2Price)
    return nothing
end

@doc raw"""
	_vre_stor_zonal_var_om(EP, inputs, z)

Zone-`z` variable O&M for co-located VRE+storage resources in a subproblem `EP`.

Mirrors the VRE-storage block of the monolithic `write_costs` per-zone loop: solar/wind output
VOM (`eCVarOutSolar`/`eCVarOutWind`) plus asymmetric DC/AC charge/discharge VOM. Returns raw
model units; empty when the model has no VRE-storage resources.
"""
function _vre_stor_zonal_var_om(EP::Model, inputs::Dict, z::Int)
	gen = inputs["RESOURCES"]
	Y_ZONE_VRE_STOR = resources_in_zone_by_rid(gen.VreStorage, z)
	c = 0.0
	SOLAR_ZONE = intersect(Y_ZONE_VRE_STOR, inputs["VS_SOLAR"])
	if !isempty(SOLAR_ZONE) && haskey(EP, :eCVarOutSolar)
		c += sum(value.(EP[:eCVarOutSolar][SOLAR_ZONE, :]); init = 0.0)
	end
	WIND_ZONE = intersect(Y_ZONE_VRE_STOR, inputs["VS_WIND"])
	if !isempty(WIND_ZONE) && haskey(EP, :eCVarOutWind)
		c += sum(value.(EP[:eCVarOutWind][WIND_ZONE, :]); init = 0.0)
	end
	STOR_ZONE = intersect(inputs["VS_STOR"], Y_ZONE_VRE_STOR)
	if !isempty(STOR_ZONE)
		vom_map = Dict(intersect(inputs["VS_ASYM_DC_CHARGE"], Y_ZONE_VRE_STOR) => :eCVar_Charge_DC,
			intersect(inputs["VS_ASYM_DC_DISCHARGE"], Y_ZONE_VRE_STOR) => :eCVar_Discharge_DC,
			intersect(inputs["VS_ASYM_AC_DISCHARGE"], Y_ZONE_VRE_STOR) => :eCVar_Discharge_AC,
			intersect(inputs["VS_ASYM_AC_CHARGE"], Y_ZONE_VRE_STOR) => :eCVar_Charge_AC)
		for (set, sym) in vom_map
			if !isempty(set) && haskey(EP, sym)
				c += sum(value.(EP[sym][set, :]); init = 0.0)
			end
		end
	end
	return c
end

@doc raw"""
	_subproblem_zonal_operational_costs(EP, inputs, setup)

Compute per-zone operational costs from a solved subproblem `EP`, as three `Z`-length vectors
`(cvar, cnse, cstart)` in raw model units (scaling applied by the cost writer).

Mirrors the per-zone loop of the monolithic `write_costs`:
- `cvar`   — generation/discharge (`eCVar_out`), storage charging (`eCVar_in`), flexible demand
             (`eCVarFlex_in`), co-located VRE+storage, and Allam-cycle (`eCVar_Allam`) VOM.
- `cnse`   — non-served energy (`eCNSE[:, :, z]`).
- `cstart` — non-fuel startup O&M (`eCStart`, `eCStart_Allam`). Startup **fuel** is excluded here
             and added by the cost writer from the per-plant `fuel_cost_start`.

Each per-zone sum is over the subproblem's time slice; summing across subproblems yields the
annual per-zone value. Component sets absent from the model contribute zero.
"""
function _subproblem_zonal_operational_costs(EP::Model, inputs::Dict, setup::Dict)
	gen = inputs["RESOURCES"]
	Z = inputs["Z"]
	STOR_ALL = inputs["STOR_ALL"]
	FLEX = inputs["FLEX"]
	COMMIT = inputs["COMMIT"]
	VRE_STOR = inputs["VRE_STOR"]
	ALLAM_CYCLE_LOX = inputs["ALLAM_CYCLE_LOX"]

	cvar = zeros(Z)
	cnse = zeros(Z)
	cstart = zeros(Z)

	for z in 1:Z
		Y_ZONE = resources_in_zone_by_rid(gen, z)

		if haskey(EP, :eCVar_out)
			cvar[z] += sum(value.(EP[:eCVar_out][Y_ZONE, :]); init = 0.0)
		end

		STOR_ALL_ZONE = intersect(STOR_ALL, Y_ZONE)
		if !isempty(STOR_ALL_ZONE) && haskey(EP, :eCVar_in)
			cvar[z] += sum(value.(EP[:eCVar_in][STOR_ALL_ZONE, :]); init = 0.0)
		end

		FLEX_ZONE = intersect(FLEX, Y_ZONE)
		if !isempty(FLEX_ZONE) && haskey(EP, :eCVarFlex_in)
			cvar[z] += sum(value.(EP[:eCVarFlex_in][FLEX_ZONE, :]); init = 0.0)
		end

		if !isempty(VRE_STOR)
			cvar[z] += _vre_stor_zonal_var_om(EP, inputs, z)
		end

		if haskey(EP, :eCNSE)
			cnse[z] += sum(value.(EP[:eCNSE][:, :, z]); init = 0.0)
		end

		COMMIT_ZONE = intersect(COMMIT, Y_ZONE)
		if setup["UCommit"] >= 1 && !isempty(COMMIT_ZONE) && haskey(EP, :eCStart)
			cstart[z] += sum(value.(EP[:eCStart][COMMIT_ZONE, :]); init = 0.0)
		end

		if !isempty(ALLAM_CYCLE_LOX)
			Y_ZONE_ALLAM = resources_in_zone_by_rid(gen.AllamCycleLOX, z)
			if !isempty(Y_ZONE_ALLAM)
				haskey(EP, :eCVar_Allam) && (cvar[z] += sum(value.(EP[:eCVar_Allam][Y_ZONE_ALLAM]); init = 0.0))
				if setup["UCommit"] >= 1 && haskey(EP, :eCStart_Allam)
					cstart[z] += sum(value.(EP[:eCStart_Allam][Y_ZONE_ALLAM, :]); init = 0.0)
				end
			end
		end
	end

	return (cvar = cvar, cnse = cnse, cstart = cstart)
end

@doc raw"""
	collect_benders_output_bundle(inputs, setup, subproblems)

Collect all operational output arrays from solved subproblems into a single `NamedTuple`.

Dispatches to `collect_distributed_output_bundle` when `subproblems` is a `DArray`
(multi-worker run) or `get_local_output_bundle` otherwise.
"""
function collect_benders_output_bundle(inputs::Dict, setup::Dict, subproblems::Union{Vector{Dict{Any, Any}},DistributedArrays.DArray})
	if subproblems isa DistributedArrays.DArray
		return collect_distributed_output_bundle(inputs, setup, subproblems)
	end

	return get_local_output_bundle(inputs, setup, subproblems)
end

@doc raw"""
	collect_distributed_output_bundle(inputs, setup, subproblems)

Collect and concatenate output bundles from all workers into a single `NamedTuple`.

Fetches `get_local_output_bundle` from each worker in parallel, then reduces each
time-series field with `hcat` (concatenating representative periods along the time axis)
and each scalar/annual field with `+`.  Returns a single bundle with the same structure
as `get_local_output_bundle`.
"""
function collect_distributed_output_bundle(inputs::Dict, setup::Dict, subproblems::DistributedArrays.DArray)
	p_id = workers()
	np_id = length(p_id)
	bundles = Vector{NamedTuple}(undef, np_id)

	@sync for i in 1:np_id
		@async bundles[i] = @fetchfrom p_id[i] get_local_output_bundle(
			inputs,
			setup,
			DistributedArrays.localpart(subproblems),
		)
	end

	power_chunks = [b.power for b in bundles]
	emission_chunks = [b.emissions_plant for b in bundles]
	charge_chunks = [b.charge for b in bundles]
	charge_id_chunks = [b.charge_ids for b in bundles]
	storage_chunks = [b.storage for b in bundles]
	storage_id_chunks = [b.storage_ids for b in bundles]
	curtailment_chunks = [b.curtailment for b in bundles]
	nse_chunks = [b.nse for b in bundles]
	flow_chunks = [b.flow for b in bundles]
	tloss_chunks = [b.tlosses for b in bundles]
	emissions_zone_chunks = [b.emissions_zone for b in bundles]
	fuel_cost_out_chunks = [b.fuel_cost_out for b in bundles]
	fuel_cost_start_chunks = [b.fuel_cost_start for b in bundles]
	var_om_cost_zone_chunks = [b.var_om_cost_zone for b in bundles]
	nse_cost_zone_chunks = [b.nse_cost_zone for b in bundles]
	start_om_cost_zone_chunks = [b.start_om_cost_zone for b in bundles]
	fuel_ts_chunks = [b.fuel_ts for b in bundles]
	fuel_total_chunks = [b.fuel_total for b in bundles]
	multi_fuel_generation_chunks = [b.multi_fuel_generation for b in bundles]
	multi_fuel_start_chunks = [b.multi_fuel_start for b in bundles]
	multi_fuel_total_chunks = [b.multi_fuel_total for b in bundles]
	multi_fuel_cost_chunks = [b.multi_fuel_cost for b in bundles]
	charge_storage_chunks = [b.charge_storage for b in bundles]
	charge_flex_chunks = [b.charge_flex for b in bundles]
	charge_vre_stor_chunks = [b.charge_vre_stor for b in bundles]
	vre_stor_solar_chunks = [b.vre_stor_solar for b in bundles]
	vre_stor_wind_chunks = [b.vre_stor_wind for b in bundles]
	charge_allam_chunks = [b.charge_allam for b in bundles]
	use_electrolyzer_chunks = [b.use_electrolyzer for b in bundles]
	fusion_parasitic_chunks = [b.fusion_parasitic for b in bundles]
	net_export_zone_chunks = [b.net_export_zone for b in bundles]
	losses_zone_chunks = [b.losses_zone for b in bundles]
	price_chunks = [b.price for b in bundles]
	reliability_chunks = [b.reliability for b in bundles]
	storagedual_chunks = [b.storagedual for b in bundles]
	commit_chunks = [b.commit for b in bundles]
	start_up_chunks = [b.start_up for b in bundles]
	shut_down_chunks = [b.shut_down for b in bundles]

	for ids in charge_id_chunks
		@assert ids == charge_id_chunks[1] "Charge ids are not the same across all subproblems"
	end
	for ids in storage_id_chunks
		@assert ids == storage_id_chunks[1] "Storage ids are not the same across all subproblems"
	end

	return (
		power = reduce(hcat, power_chunks; init=zeros(inputs["G"], 0)),
		emissions_plant = reduce(hcat, emission_chunks; init=zeros(inputs["G"], 0)),
		charge = reduce(hcat, charge_chunks; init=zeros(length(charge_id_chunks[1]), 0)),
		charge_ids = charge_id_chunks[1],
		storage = reduce(hcat, storage_chunks; init=zeros(length(storage_id_chunks[1]), 0)),
		storage_ids = storage_id_chunks[1],
		curtailment = reduce(hcat, curtailment_chunks; init=zeros(inputs["G"], 0)),
		nse = reduce(hcat, nse_chunks; init=zeros(inputs["SEG"] * inputs["Z"], 0)),
		flow = reduce(hcat, flow_chunks; init=zeros(inputs["L"], 0)),
		tlosses = reduce(hcat, tloss_chunks; init=zeros(inputs["L"], 0)),
		emissions_zone = reduce(hcat, emissions_zone_chunks; init=zeros(inputs["Z"], 0)),
		fuel_cost_out = reduce(+, fuel_cost_out_chunks; init=zeros(inputs["G"])),
		fuel_cost_start = reduce(+, fuel_cost_start_chunks; init=zeros(inputs["G"])),
		var_om_cost_zone = reduce(+, var_om_cost_zone_chunks; init=zeros(inputs["Z"])),
		nse_cost_zone = reduce(+, nse_cost_zone_chunks; init=zeros(inputs["Z"])),
		start_om_cost_zone = reduce(+, start_om_cost_zone_chunks; init=zeros(inputs["Z"])),
		fuel_ts = reduce(hcat, fuel_ts_chunks; init=zeros(inputs["G"], 0)),
		fuel_total = reduce(+, fuel_total_chunks; init=zeros(length(inputs["fuels"]))),
		multi_fuel_generation = reduce(+, multi_fuel_generation_chunks; init=zeros(length(inputs["HAS_FUEL"]), get(inputs, "MAX_NUM_FUELS", 0))),
		multi_fuel_start = reduce(+, multi_fuel_start_chunks; init=zeros(length(inputs["HAS_FUEL"]), get(inputs, "MAX_NUM_FUELS", 0))),
		multi_fuel_total = reduce(+, multi_fuel_total_chunks; init=zeros(length(inputs["HAS_FUEL"]), get(inputs, "MAX_NUM_FUELS", 0))),
		multi_fuel_cost = reduce(+, multi_fuel_cost_chunks; init=zeros(length(inputs["HAS_FUEL"]), get(inputs, "MAX_NUM_FUELS", 0))),
		charge_storage = reduce(hcat, charge_storage_chunks; init=zeros(inputs["G"], 0)),
		charge_flex = reduce(hcat, charge_flex_chunks; init=zeros(inputs["G"], 0)),
		charge_vre_stor = reduce(hcat, charge_vre_stor_chunks; init=zeros(inputs["G"], 0)),
		vre_stor_solar = reduce(hcat, vre_stor_solar_chunks; init=zeros(inputs["G"], 0)),
		vre_stor_wind = reduce(hcat, vre_stor_wind_chunks; init=zeros(inputs["G"], 0)),
		charge_allam = reduce(hcat, charge_allam_chunks; init=zeros(inputs["G"], 0)),
		use_electrolyzer = reduce(hcat, use_electrolyzer_chunks; init=zeros(inputs["G"], 0)),
		fusion_parasitic = reduce(hcat, fusion_parasitic_chunks; init=zeros(inputs["G"], 0)),
		net_export_zone = reduce(hcat, net_export_zone_chunks; init=zeros(inputs["Z"], 0)),
		losses_zone = reduce(hcat, losses_zone_chunks; init=zeros(inputs["Z"], 0)),
		price = reduce(hcat, price_chunks; init=zeros(inputs["Z"], 0)),
		reliability = reduce(hcat, reliability_chunks; init=zeros(inputs["Z"], 0)),
		storagedual = reduce(hcat, storagedual_chunks; init=zeros(inputs["G"], 0)),
		commit = reduce(hcat, commit_chunks; init=zeros(length(inputs["COMMIT"]), 0)),
		start_up = reduce(hcat, start_up_chunks; init=zeros(length(inputs["COMMIT"]), 0)),
		shut_down = reduce(hcat, shut_down_chunks; init=zeros(length(inputs["COMMIT"]), 0)),
		has_subproblem_duals = any(b.has_subproblem_duals for b in bundles),
	)
end

@doc raw"""
	_as_time_matrix(data, nrows, ncols, name)

Coerce `data` into a `(nrows × ncols)` `Matrix{Float64}`, transposing if needed.

Accepts vectors (reshaped to a single row or column depending on which dimension
matches), matrices in either orientation, or any `Array`-convertible type.  Raises
`DimensionMismatch` if the data cannot be unambiguously mapped to the target shape.
`name` is used only in error messages.
"""
function _as_time_matrix(data, nrows::Int, ncols::Int, name::AbstractString)
	matrix = Array(data)

	if ndims(matrix) == 1
		if length(matrix) == nrows
			matrix = reshape(matrix, nrows, 1)
		elseif length(matrix) == ncols
			matrix = reshape(matrix, 1, ncols)
		else
			throw(DimensionMismatch("Expected $name to have $nrows rows or $ncols columns, got vector of length $(length(matrix))"))
		end
	end

	if size(matrix) == (ncols, nrows)
		matrix = permutedims(matrix)
	end

	if size(matrix) != (nrows, ncols)
		throw(DimensionMismatch("Expected $name to have size ($nrows, $ncols), got $(size(matrix))"))
	end

	return Matrix{Float64}(matrix)
end

@doc raw"""
	_subproblem_time_columns(inputs, subproblem, local_T)

Return the global time-step range corresponding to a single subproblem.

Uses `subproblem[:subproblem_index]` and `inputs["hours_per_subperiod"]` to map local
time indices `1:local_T` to their position in the full annual time series.  Returns
`1:local_T` when either field is absent (single-period or non-decomposed case).
"""
function _subproblem_time_columns(inputs::Dict, subproblem::Dict{Any, Any}, local_T::Int)
	if !haskey(subproblem, :subproblem_index) || !haskey(inputs, "hours_per_subperiod")
		return 1:local_T
	end

	hours_per_subperiod = inputs["hours_per_subperiod"]
	start_t = (subproblem[:subproblem_index] - 1) * hours_per_subperiod + 1
	end_t = start_t + local_T - 1
	return start_t:end_t
end

@doc raw"""
	_slice_time_series(data, time_columns)

Slice `data` along its time axis using `time_columns`.

For a 1-D array returns `data[time_columns]`; for a 2-D array returns
`data[:, time_columns]`.  Converts to a plain `Array` first to handle JuMP
`DenseAxisArray` inputs.
"""
function _slice_time_series(data, time_columns)
	matrix = Array(data)
	return ndims(matrix) == 1 ? matrix[time_columns] : matrix[:, time_columns]
end

@doc raw"""
	get_local_output_bundle(inputs, setup, subproblems_local)

Extract and assemble all output arrays from the subproblems on a single worker.

Iterates over `subproblems_local`, extracting power dispatch, emissions, charge, storage,
curtailment, NSE, transmission flows and losses, fuel consumption, dual-based prices,
storage duals, and unit commitment decisions from each solved JuMP model.  Time-series
arrays are concatenated along the time axis (representative periods ordered by
`subproblem_index`) to produce full-year matrices.

Returns a `NamedTuple` with all operational output arrays needed by the write functions,
plus `has_subproblem_duals` indicating whether LP duals were available.
"""
function get_local_output_bundle(inputs::Dict, setup::Dict, subproblems_local::Vector{Dict{Any, Any}})
	gen = inputs["RESOURCES"]   # Resources (objects) 

	n_local_subprob = length(subproblems_local)
	power_subprob = Vector{Matrix}(undef, n_local_subprob)
	emissions_subprob = Vector{Matrix}(undef, n_local_subprob)
	charge_subprob = Vector{Matrix}(undef, n_local_subprob)
	charge_ids_subprob = Vector{Vector{Int}}(undef, n_local_subprob)
	storage_subprob = Vector{Matrix}(undef, n_local_subprob)
	storage_ids_subprob = Vector{Vector{Int}}(undef, n_local_subprob)
	curtailment_subprob = Vector{Matrix}(undef, n_local_subprob)
	nse_subprob = Vector{Matrix}(undef, n_local_subprob)
	flow_subprob = Vector{Matrix}(undef, n_local_subprob)
	tloss_subprob = Vector{Matrix}(undef, n_local_subprob)
	emissions_zone_subprob = Vector{Matrix}(undef, n_local_subprob)
	fuel_cost_out_subprob = Vector{Vector{Float64}}(undef, n_local_subprob)
	fuel_cost_start_subprob = Vector{Vector{Float64}}(undef, n_local_subprob)
	# Per-zone operational cost vectors, per subproblem (summed across subproblems below).
	# Fuel cost is already captured per-plant in fuel_cost_out/fuel_cost_start and is aggregated
	# to zones in the cost writer; start O&M here excludes startup fuel (added there too).
	var_om_cost_zone_subprob = Vector{Vector{Float64}}(undef, n_local_subprob)
	nse_cost_zone_subprob = Vector{Vector{Float64}}(undef, n_local_subprob)
	start_om_cost_zone_subprob = Vector{Vector{Float64}}(undef, n_local_subprob)
	fuel_ts_subprob = Vector{Matrix}(undef, n_local_subprob)
	fuel_total_subprob = Vector{Vector{Float64}}(undef, n_local_subprob)
	multi_fuel_generation_subprob = Vector{Matrix}(undef, n_local_subprob)
	multi_fuel_start_subprob = Vector{Matrix}(undef, n_local_subprob)
	multi_fuel_total_subprob = Vector{Matrix}(undef, n_local_subprob)
	multi_fuel_cost_subprob = Vector{Matrix}(undef, n_local_subprob)
	charge_storage_subprob = Vector{Matrix}(undef, n_local_subprob)
	charge_flex_subprob = Vector{Matrix}(undef, n_local_subprob)
	charge_vre_stor_subprob = Vector{Matrix}(undef, n_local_subprob)
	vre_stor_solar_subprob = Vector{Matrix}(undef, n_local_subprob)
	vre_stor_wind_subprob = Vector{Matrix}(undef, n_local_subprob)
	charge_allam_subprob = Vector{Matrix}(undef, n_local_subprob)
	use_electrolyzer_subprob = Vector{Matrix}(undef, n_local_subprob)
	fusion_parasitic_subprob = Vector{Matrix}(undef, n_local_subprob)
	net_export_zone_subprob = Vector{Matrix}(undef, n_local_subprob)
	losses_zone_subprob = Vector{Matrix}(undef, n_local_subprob)
	price_subprob = Vector{Matrix}(undef, n_local_subprob)
	reliability_subprob = Vector{Matrix}(undef, n_local_subprob)
	storagedual_subprob = Vector{Matrix}(undef, n_local_subprob)
	commit_subprob = Vector{Matrix}(undef, n_local_subprob)
	start_subprob = Vector{Matrix}(undef, n_local_subprob)
	shutdown_subprob = Vector{Matrix}(undef, n_local_subprob)
	any_duals = false

	H = inputs["H"]     # Number of time steps (hours)
    STOR_ALL = inputs["STOR_ALL"]
    FLEX = inputs["FLEX"]
    ELECTROLYZER = inputs["ELECTROLYZER"]
    ALLAM_CYCLE_LOX = inputs["ALLAM_CYCLE_LOX"] 
    VRE_STOR = inputs["VRE_STOR"]
    VS_STOR = !isempty(VRE_STOR) ? inputs["VS_STOR"] : []
    FUSION = ids_with(gen, :fusion)
	COMMIT = inputs["COMMIT"]
	G = inputs["G"]
	SEG = inputs["SEG"]
	Z = inputs["Z"]
	VRE = inputs["VRE"]
	SOLAR = !isempty(VRE_STOR) ? setdiff(inputs["VS_SOLAR"], inputs["VS_WIND"]) : Int[]
	WIND = !isempty(VRE_STOR) ? setdiff(inputs["VS_WIND"], inputs["VS_SOLAR"]) : Int[]
	SOLAR_WIND = !isempty(VRE_STOR) ? intersect(inputs["VS_SOLAR"], inputs["VS_WIND"]) : Int[]
	HYDRO_RES = inputs["HYDRO_RES"]
	L = inputs["L"]
	LOSS_LINES = inputs["LOSS_LINES"]
	HAS_FUEL = inputs["HAS_FUEL"]
	MULTI_FUELS = inputs["MULTI_FUELS"]
	MAX_NUM_FUELS = get(inputs, "MAX_NUM_FUELS", 0)
	FUEL_COUNT = length(inputs["fuels"])

	for s in eachindex(subproblems_local)
		EP = subproblems_local[s][:model]
		power_subprob[s] = haskey(EP, :vP) ? Matrix{Float64}(Array(value.(EP[:vP]))) : zeros(inputs["G"], H)
		local_T = size(power_subprob[s], 2)
		time_columns = _subproblem_time_columns(inputs, subproblems_local[s], local_T)
		pP_max_local = _slice_time_series(inputs["pP_Max"], time_columns)
		pP_max_solar_local = haskey(inputs, "pP_Max_Solar") ? _slice_time_series(inputs["pP_Max_Solar"], time_columns) : nothing
		pP_max_wind_local = haskey(inputs, "pP_Max_Wind") ? _slice_time_series(inputs["pP_Max_Wind"], time_columns) : nothing
		emissions_subprob[s] = haskey(EP, :eEmissionsByPlant) ? _as_time_matrix(value.(EP[:eEmissionsByPlant]), inputs["G"], local_T, "eEmissionsByPlant") : zeros(inputs["G"], local_T)
		curtailment_subprob[s] = zeros(G, local_T)
		nse_subprob[s] = zeros(SEG * Z, local_T)
		flow_subprob[s] = haskey(EP, :vFLOW) ? _as_time_matrix(value.(EP[:vFLOW]), L, local_T, "vFLOW") : zeros(L, local_T)
		tloss_subprob[s] = zeros(L, local_T)
		emissions_zone_subprob[s] = haskey(EP, :eEmissionsByZone) ? _as_time_matrix(value.(EP[:eEmissionsByZone]), Z, local_T, "eEmissionsByZone") : zeros(Z, local_T)
		fuel_cost_out_subprob[s] = haskey(EP, :ePlantCFuelOut) ? value.(EP[:ePlantCFuelOut]) : zeros(G)
		fuel_cost_start_subprob[s] = haskey(EP, :ePlantCFuelStart) ? value.(EP[:ePlantCFuelStart]) : zeros(G)
		# Per-zone operational costs (raw model units; scaled in the cost writer). Mirrors how the
		# monolithic write_costs assembles per-zone cVar, cNSE, and cStart (non-fuel startup).
		zonal_op_costs = _subproblem_zonal_operational_costs(EP, inputs, setup)
		var_om_cost_zone_subprob[s] = zonal_op_costs.cvar
		nse_cost_zone_subprob[s] = zonal_op_costs.cnse
		start_om_cost_zone_subprob[s] = zonal_op_costs.cstart
		if haskey(EP, :ePlantFuel_generation) && haskey(EP, :ePlantFuel_start)
			fuel_ts_subprob[s] = _as_time_matrix(value.(EP[:ePlantFuel_generation] + EP[:ePlantFuel_start]), G, local_T, "plant fuel time series")
		else
			fuel_ts_subprob[s] = zeros(G, local_T)
		end
		fuel_total_subprob[s] = haskey(EP, :eFuelConsumptionYear) ? value.(EP[:eFuelConsumptionYear]) : zeros(FUEL_COUNT)
		multi_fuel_generation_subprob[s] = zeros(length(HAS_FUEL), MAX_NUM_FUELS)
		multi_fuel_start_subprob[s] = zeros(length(HAS_FUEL), MAX_NUM_FUELS)
		multi_fuel_total_subprob[s] = zeros(length(HAS_FUEL), MAX_NUM_FUELS)
		multi_fuel_cost_subprob[s] = zeros(length(HAS_FUEL), MAX_NUM_FUELS)
		charge_storage_subprob[s] = zeros(G, local_T)
		charge_flex_subprob[s] = zeros(G, local_T)
		charge_vre_stor_subprob[s] = zeros(G, local_T)
		vre_stor_solar_subprob[s] = zeros(G, local_T)
		vre_stor_wind_subprob[s] = zeros(G, local_T)
		charge_allam_subprob[s] = zeros(G, local_T)
		use_electrolyzer_subprob[s] = zeros(G, local_T)
		fusion_parasitic_subprob[s] = zeros(G, local_T)
		net_export_zone_subprob[s] = haskey(EP, :ePowerBalanceNetExportFlows) ? _as_time_matrix(value.(EP[:ePowerBalanceNetExportFlows]), Z, local_T, "ePowerBalanceNetExportFlows") : zeros(Z, local_T)
		losses_zone_subprob[s] = haskey(EP, :eLosses_By_Zone) ? _as_time_matrix(value.(EP[:eLosses_By_Zone]), Z, local_T, "eLosses_By_Zone") : zeros(Z, local_T)

		# Collect dual-based outputs from subproblem LP
		omega_local = inputs["omega"][time_columns]
		scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
		subprob_has_duals = has_duals(EP)
		any_duals = any_duals || subprob_has_duals

		# Locational marginal prices: dual of power balance / omega [$/MWh or M$/GWh]
		if subprob_has_duals && haskey(EP, :cPowerBalance)
			raw_pb = dual.(EP[:cPowerBalance])  # DenseAxisArray (T_local, Z) or (Z, T_local)
			raw_pb_mat = _as_time_matrix(Array(raw_pb), Z, local_T, "cPowerBalance dual")
			price_subprob[s] = raw_pb_mat ./ omega_local' .* scale_factor  # (Z, T_local)
		else
			price_subprob[s] = zeros(Z, local_T)
		end

		# Reliability prices: dual of NSE capacity constraint / omega [$/MWh]
		if subprob_has_duals && haskey(EP, :cMaxNSE)
			raw_nse = dual.(EP[:cMaxNSE])  # (T_local, Z) or (Z, T_local)
			raw_nse_mat = _as_time_matrix(Array(raw_nse), Z, local_T, "cMaxNSE dual")
			reliability_subprob[s] = raw_nse_mat ./ omega_local' .* scale_factor
		else
			reliability_subprob[s] = zeros(Z, local_T)
		end

		# Storage balance duals: dual of SoC balance / omega (no scale yet, applied in write)
		storagedual_subprob[s] = zeros(G, local_T)
		INTERIOR_LOCAL = 2:local_T
		START_LOCAL = [1]
		if subprob_has_duals && !isempty(STOR_ALL)
			if haskey(EP, :cSoCBalInterior) && !isempty(INTERIOR_LOCAL)
				raw_interior = dual.(EP[:cSoCBalInterior][INTERIOR_LOCAL, STOR_ALL])
				storagedual_subprob[s][STOR_ALL, INTERIOR_LOCAL] .= Matrix{Float64}(raw_interior.data)' ./ omega_local[INTERIOR_LOCAL]'
			end
			if haskey(EP, :cSoCBalStart)
				raw_start = dual.(EP[:cSoCBalStart][START_LOCAL, STOR_ALL])
				storagedual_subprob[s][STOR_ALL, START_LOCAL] .= Matrix{Float64}(raw_start.data)' ./ omega_local[START_LOCAL]'
			end
		end
		if subprob_has_duals && !isempty(VRE_STOR) && !isempty(VS_STOR)
			if haskey(EP, :cSoCBalInterior_VRE_STOR) && !isempty(INTERIOR_LOCAL)
				raw_vs_interior = dual.(EP[:cSoCBalInterior_VRE_STOR][VS_STOR, INTERIOR_LOCAL])
				storagedual_subprob[s][VS_STOR, INTERIOR_LOCAL] .= Matrix{Float64}(raw_vs_interior.data) ./ omega_local[INTERIOR_LOCAL]'
			end
			if haskey(EP, :cSoCBalStart_VRE_STOR)
				VS_NONLDS = haskey(inputs, "VS_nonLDS") ? inputs["VS_nonLDS"] : setdiff(VS_STOR, inputs["VS_LDS"])
				raw_vs_start = dual.(EP[:cSoCBalStart_VRE_STOR][VS_NONLDS, START_LOCAL])
				storagedual_subprob[s][VS_NONLDS, START_LOCAL] .= Matrix{Float64}(raw_vs_start.data) ./ omega_local[START_LOCAL]'
			end
		end

		# Unit commitment variables (if UCommit >= 1)
		n_commit = length(COMMIT)
		if setup["UCommit"] >= 1 && n_commit > 0
			commit_subprob[s] = haskey(EP, :vCOMMIT) ? Matrix{Float64}(value.(EP[:vCOMMIT][COMMIT, :]).data) : zeros(n_commit, local_T)
			start_subprob[s] = haskey(EP, :vSTART) ? Matrix{Float64}(value.(EP[:vSTART][COMMIT, :]).data) : zeros(n_commit, local_T)
			shutdown_subprob[s] = haskey(EP, :vSHUT) ? Matrix{Float64}(value.(EP[:vSHUT][COMMIT, :]).data) : zeros(n_commit, local_T)
		else
			commit_subprob[s] = zeros(0, local_T)
			start_subprob[s] = zeros(0, local_T)
			shutdown_subprob[s] = zeros(0, local_T)
		end

		charge = Matrix[]
		charge_ids = Vector{Int}[]
		storage = Matrix[]
		storage_ids = Vector{Int}[]

		if !isempty(STOR_ALL)
			push!(charge, _as_time_matrix(value.(EP[:vCHARGE]), length(STOR_ALL), local_T, "vCHARGE"))
			push!(charge_ids, STOR_ALL)
			charge_storage_subprob[s][STOR_ALL, :] = charge[end]
			if haskey(EP, :vS)
				push!(storage, _as_time_matrix(value.(EP[:vS]), length(STOR_ALL), local_T, "vS"))
				push!(storage_ids, STOR_ALL)
			end
		end
		if !isempty(HYDRO_RES) && haskey(EP, :vS_HYDRO)
			push!(storage, _as_time_matrix(value.(EP[:vS_HYDRO]), length(HYDRO_RES), local_T, "vS_HYDRO"))
			push!(storage_ids, HYDRO_RES)
		end
		if !isempty(FLEX)
			push!(charge, _as_time_matrix(value.(EP[:vCHARGE_FLEX]), length(FLEX), local_T, "vCHARGE_FLEX"))
			push!(charge_ids, FLEX)
			charge_flex_subprob[s][FLEX, :] = charge[end]
			if haskey(EP, :vS_FLEX)
				push!(storage, _as_time_matrix(value.(EP[:vS_FLEX]), length(FLEX), local_T, "vS_FLEX"))
				push!(storage_ids, FLEX)
			end
		end
		if (setup["HydrogenMinimumProduction"] > 0) & (!isempty(ELECTROLYZER))
			push!(charge, _as_time_matrix(value.(EP[:vUSE]), length(ELECTROLYZER), local_T, "vUSE"))
			push!(charge_ids, ELECTROLYZER)
			use_electrolyzer_subprob[s][ELECTROLYZER, :] = charge[end]
		end
		if !isempty(VS_STOR)
			push!(charge, _as_time_matrix(value.(EP[:vCHARGE_VRE_STOR]), length(VS_STOR), local_T, "vCHARGE_VRE_STOR"))
			push!(charge_ids, VS_STOR)
			charge_vre_stor_subprob[s][VS_STOR, :] = charge[end]
			if haskey(EP, :vS_VRE_STOR)
				push!(storage, _as_time_matrix(value.(EP[:vS_VRE_STOR]), length(VS_STOR), local_T, "vS_VRE_STOR"))
				push!(storage_ids, VS_STOR)
			end
		end
		if !isempty(FUSION)
			_, mat = prepare_fusion_parasitic_power(EP, inputs)
			push!(charge, _as_time_matrix(mat, length(FUSION), local_T, "fusion parasitic power"))
			push!(charge_ids, FUSION)
			fusion_parasitic_subprob[s][FUSION, :] = charge[end]
		end
		if !isempty(ALLAM_CYCLE_LOX)
			push!(charge, _as_time_matrix(value.(EP[:vCHARGE_ALLAM]), length(ALLAM_CYCLE_LOX), local_T, "vCHARGE_ALLAM"))
			push!(charge_ids, ALLAM_CYCLE_LOX)
			charge_allam_subprob[s][ALLAM_CYCLE_LOX, :] = charge[end]
		end

		if haskey(EP, :vNSE)
			for z in 1:Z
				nse_subprob[s][((z - 1) * SEG + 1):(z * SEG), :] = value.(EP[:vNSE])[:, :, z]
			end
		end

		if haskey(EP, :vTLOSS)
			tloss_subprob[s][LOSS_LINES, :] = value.(EP[:vTLOSS][LOSS_LINES, :])
		end

		if !isempty(MULTI_FUELS) && MAX_NUM_FUELS > 0 &&
			haskey(EP, :ePlantFuelConsumptionYear_multi_generation) &&
			haskey(EP, :ePlantFuelConsumptionYear_multi_start) &&
			haskey(EP, :ePlantFuelConsumptionYear_multi) &&
			haskey(EP, :ePlantCFuelOut_multi) &&
			haskey(EP, :ePlantCFuelOut_multi_start)
			for i in 1:MAX_NUM_FUELS
				for g in MULTI_FUELS
					idx = findfirst(x -> x == g, HAS_FUEL)
					if !isnothing(idx)
						multi_fuel_generation_subprob[s][idx, i] = value(EP[:ePlantFuelConsumptionYear_multi_generation][g, i])
						multi_fuel_start_subprob[s][idx, i] = value(EP[:ePlantFuelConsumptionYear_multi_start][g, i])
						multi_fuel_total_subprob[s][idx, i] = value(EP[:ePlantFuelConsumptionYear_multi][g, i])
						multi_fuel_cost_subprob[s][idx, i] = value(EP[:ePlantCFuelOut_multi][g, i]) + value(EP[:ePlantCFuelOut_multi_start][g, i])
					end
				end
			end
		end

		if haskey(EP, :eTotalCap) && haskey(EP, :vP)
			curtailment_subprob[s][VRE, :] = (value.(EP[:eTotalCap][VRE]) .* pP_max_local[VRE, :] .-
				value.(EP[:vP][VRE, :]))
		end
		if !isempty(VRE_STOR)
			if !isempty(SOLAR) && haskey(EP, :eTotalCap_SOLAR) && haskey(EP, :vP_SOLAR)
				curtailment_subprob[s][SOLAR, :] = (value.(EP[:eTotalCap_SOLAR][SOLAR]).data .* pP_max_solar_local[SOLAR, :] .-
					value.(EP[:vP_SOLAR][SOLAR, :]).data) .* etainverter.(gen[SOLAR])
			end
			if !isempty(WIND) && haskey(EP, :eTotalCap_WIND) && haskey(EP, :vP_WIND)
				curtailment_subprob[s][WIND, :] = (value.(EP[:eTotalCap_WIND][WIND]).data .* pP_max_wind_local[WIND, :] .-
					value.(EP[:vP_WIND][WIND, :]).data)
			end
			if !isempty(SOLAR_WIND) && haskey(EP, :eTotalCap_SOLAR) && haskey(EP, :vP_SOLAR) && haskey(EP, :eTotalCap_WIND) && haskey(EP, :vP_WIND)
				curtailment_subprob[s][SOLAR_WIND, :] = (
					(value.(EP[:eTotalCap_SOLAR])[SOLAR_WIND].data .* pP_max_solar_local[SOLAR_WIND, :] .-
						value.(EP[:vP_SOLAR][SOLAR_WIND, :]).data) .* etainverter.(gen[SOLAR_WIND])
					+
					(value.(EP[:eTotalCap_WIND][SOLAR_WIND]).data .* pP_max_wind_local[SOLAR_WIND, :] .-
						value.(EP[:vP_WIND][SOLAR_WIND, :]).data)
				)
			end
		end

		# Per-component VRE-storage generation for capacity-factor reporting.
		# vP_SOLAR is DC solar output (inverter efficiency applied in the writer);
		# vP_WIND is AC wind output. Stored raw (model units), indexed by resource.
		if !isempty(VRE_STOR) && haskey(EP, :vP_SOLAR)
			if !isempty(SOLAR)
				vre_stor_solar_subprob[s][SOLAR, :] = value.(EP[:vP_SOLAR][SOLAR, :]).data
			end
			if !isempty(SOLAR_WIND)
				vre_stor_solar_subprob[s][SOLAR_WIND, :] = value.(EP[:vP_SOLAR][SOLAR_WIND, :]).data
			end
		end
		if !isempty(VRE_STOR) && haskey(EP, :vP_WIND)
			if !isempty(WIND)
				vre_stor_wind_subprob[s][WIND, :] = value.(EP[:vP_WIND][WIND, :]).data
			end
			if !isempty(SOLAR_WIND)
				vre_stor_wind_subprob[s][SOLAR_WIND, :] = value.(EP[:vP_WIND][SOLAR_WIND, :]).data
			end
		end

		charge_subprob[s] = reduce(vcat, charge, init = zeros(0, local_T))
		charge_ids_subprob[s] = reduce(vcat, charge_ids, init = Int[])
		storage_subprob[s] = reduce(vcat, storage, init = zeros(0, local_T))
		storage_ids_subprob[s] = reduce(vcat, storage_ids, init = Int[])
	end

	charge_subprob = reduce(hcat, charge_subprob)
	storage_subprob = reduce(hcat, storage_subprob)
	curtailment_subprob = reduce(hcat, curtailment_subprob)
	nse_subprob = reduce(hcat, nse_subprob)
	flow_subprob = reduce(hcat, flow_subprob)
	tloss_subprob = reduce(hcat, tloss_subprob)
	emissions_zone_subprob = reduce(hcat, emissions_zone_subprob)
	fuel_ts_subprob = reduce(hcat, fuel_ts_subprob)
	fuel_cost_out = reduce(+, fuel_cost_out_subprob; init=zeros(G))
	fuel_cost_start = reduce(+, fuel_cost_start_subprob; init=zeros(G))
	var_om_cost_zone = reduce(+, var_om_cost_zone_subprob; init=zeros(Z))
	nse_cost_zone = reduce(+, nse_cost_zone_subprob; init=zeros(Z))
	start_om_cost_zone = reduce(+, start_om_cost_zone_subprob; init=zeros(Z))
	fuel_total = reduce(+, fuel_total_subprob; init=zeros(FUEL_COUNT))
	multi_fuel_generation = reduce(+, multi_fuel_generation_subprob; init=zeros(length(HAS_FUEL), MAX_NUM_FUELS))
	multi_fuel_start = reduce(+, multi_fuel_start_subprob; init=zeros(length(HAS_FUEL), MAX_NUM_FUELS))
	multi_fuel_total = reduce(+, multi_fuel_total_subprob; init=zeros(length(HAS_FUEL), MAX_NUM_FUELS))
	multi_fuel_cost = reduce(+, multi_fuel_cost_subprob; init=zeros(length(HAS_FUEL), MAX_NUM_FUELS))
	charge_storage = reduce(hcat, charge_storage_subprob)
	charge_flex = reduce(hcat, charge_flex_subprob)
	charge_vre_stor = reduce(hcat, charge_vre_stor_subprob)
	vre_stor_solar = reduce(hcat, vre_stor_solar_subprob)
	vre_stor_wind = reduce(hcat, vre_stor_wind_subprob)
	charge_allam = reduce(hcat, charge_allam_subprob)
	use_electrolyzer = reduce(hcat, use_electrolyzer_subprob)
	fusion_parasitic = reduce(hcat, fusion_parasitic_subprob)
	net_export_zone = reduce(hcat, net_export_zone_subprob)
	losses_zone = reduce(hcat, losses_zone_subprob)
	price = reduce(hcat, price_subprob)
	reliability = reduce(hcat, reliability_subprob)
	storagedual = reduce(hcat, storagedual_subprob)
	commit = reduce(hcat, commit_subprob)
	start_up = reduce(hcat, start_subprob)
	shut_down = reduce(hcat, shutdown_subprob)
	# check that all charge_ids_subprob are the same across all subproblems
	for s in eachindex(charge_ids_subprob)
		@assert charge_ids_subprob[s] == charge_ids_subprob[1] "Charge ids are not the same across all subproblems"
	end
	for s in eachindex(storage_ids_subprob)
		@assert storage_ids_subprob[s] == storage_ids_subprob[1] "Storage ids are not the same across all subproblems"
	end
	charge_ids = charge_ids_subprob[1]
	storage_ids = storage_ids_subprob[1]

	return (
		power = reduce(hcat, power_subprob),
		emissions_plant = reduce(hcat, emissions_subprob),
		emissions_zone = emissions_zone_subprob,
		charge = charge_subprob,
		charge_ids = charge_ids,
		storage = storage_subprob,
		storage_ids = storage_ids,
		curtailment = curtailment_subprob,
		nse = nse_subprob,
		flow = flow_subprob,
		tlosses = tloss_subprob,
		fuel_cost_out = fuel_cost_out,
		fuel_cost_start = fuel_cost_start,
		var_om_cost_zone = var_om_cost_zone,
		nse_cost_zone = nse_cost_zone,
		start_om_cost_zone = start_om_cost_zone,
		fuel_ts = fuel_ts_subprob,
		fuel_total = fuel_total,
		multi_fuel_generation = multi_fuel_generation,
		multi_fuel_start = multi_fuel_start,
		multi_fuel_total = multi_fuel_total,
		multi_fuel_cost = multi_fuel_cost,
		charge_storage = charge_storage,
		charge_flex = charge_flex,
		charge_vre_stor = charge_vre_stor,
		vre_stor_solar = vre_stor_solar,
		vre_stor_wind = vre_stor_wind,
		charge_allam = charge_allam,
		use_electrolyzer = use_electrolyzer,
		fusion_parasitic = fusion_parasitic,
		net_export_zone = net_export_zone,
		losses_zone = losses_zone,
		price = price,
		reliability = reliability,
		storagedual = storagedual,
		commit = commit,
		start_up = start_up,
		shut_down = shut_down,
		has_subproblem_duals = any_duals,
	)
end