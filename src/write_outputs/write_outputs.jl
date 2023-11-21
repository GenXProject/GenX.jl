################################################################################
## function output
##
## description: Writes results to multiple .csv output files in path directory
##
## returns: path directory
################################################################################
@doc raw"""
	write_outputs(EP::Model, path::AbstractString, setup::Dict, inputs::Dict)

Function for the entry-point for writing the different output files. From here, onward several other functions are called, each for writing specific output files, like costs, capacities, etc.
"""
function write_outputs(EP::Model, path::AbstractString, setup::Dict, inputs::Dict)

	if setup["OverwriteResults"] == 1
		# Overwrite existing results if dir exists
		# This is the default behaviour when there is no flag, to avoid breaking existing code
		if !(isdir(path))
		mkpath(path)
		end
	else
		# Find closest unused ouput directory name and create it
		path = choose_output_dir(path)
		mkpath(path)
	end

	# https://jump.dev/MathOptInterface.jl/v0.9.10/apireference/#MathOptInterface.TerminationStatusCode
	status = termination_status(EP)

	## Check if solved sucessfully - time out is included
	if status != MOI.OPTIMAL && status != MOI.LOCALLY_SOLVED
		if status != MOI.TIME_LIMIT # Model failed to solve, so record solver status and exit
			write_status(path, inputs, setup, EP)
			return
			# Model reached timelimit but failed to find a feasible solution
	#### Aaron Schwartz - Not sure if the below condition is valid anymore. We should revisit ####
		elseif isnan(objective_value(EP))==true
			# Model failed to solve, so record solver status and exit
			write_status(path, inputs, setup, EP)
			return
		end
	end

	write_status(path, inputs, setup, EP)
	elapsed_time_costs = @elapsed write_costs(path, inputs, setup, EP)
	println("Time elapsed for writing costs is")
	println(elapsed_time_costs)
	dfCap = write_capacity(path, inputs, setup, EP)
	dfPower = write_power(path, inputs, setup, EP)
	dfCharge = write_charge(path, inputs, setup, EP)
	dfCapacityfactor = write_capacityfactor(path, inputs, setup, EP)
	elapsed_time_storage = @elapsed write_storage(path, inputs, setup, EP)
	println("Time elapsed for writing storage is")
	println(elapsed_time_storage)
	dfCurtailment = write_curtailment(path, inputs, setup, EP)
	elapsed_time_nse = @elapsed write_nse(path, inputs, setup, EP)
	println("Time elapsed for writing nse is")
	println(elapsed_time_nse)
	elapsed_time_power_balance = @elapsed write_power_balance(path, inputs, setup, EP)
	println("Time elapsed for writing power balance is")
	println(elapsed_time_power_balance)
	if inputs["Z"] > 1
		elapsed_time_flows = @elapsed write_transmission_flows(path, inputs, setup, EP)
		println("Time elapsed for writing transmission flows is")
		println(elapsed_time_flows)
		elapsed_time_losses = @elapsed write_transmission_losses(path, inputs, setup, EP)
		println("Time elapsed for writing transmission losses is")
		println(elapsed_time_losses)
		if setup["NetworkExpansion"] == 1
			elapsed_time_expansion = @elapsed write_nw_expansion(path, inputs, setup, EP)
			println("Time elapsed for writing network expansion is")
			println(elapsed_time_expansion)
		end
	end
	elapsed_time_emissions = @elapsed write_emissions(path, inputs, setup, EP)
	println("Time elapsed for writing emissions is")
	println(elapsed_time_emissions)

	dfVreStor = DataFrame()
	if !isempty(inputs["VRE_STOR"])
		dfVreStor = write_vre_stor(path, inputs, setup, EP)
		VS_LDS = inputs["VS_LDS"]
		VS_STOR = inputs["VS_STOR"]
	else
		VS_LDS = []
		VS_STOR = []
	end

	if has_duals(EP) == 1
		elapsed_time_reliability = @elapsed write_reliability(path, inputs, setup, EP)
		println("Time elapsed for writing reliability is")
		println(elapsed_time_reliability)
		if !isempty(inputs["STOR_ALL"]) || !isempty(VS_STOR)
			elapsed_time_stordual = @elapsed write_storagedual(path, inputs, setup, EP)
			println("Time elapsed for writing storage duals is")
			println(elapsed_time_stordual)
		end
	end

	if setup["UCommit"] >= 1
		elapsed_time_commit = @elapsed write_commit(path, inputs, setup, EP)
		println("Time elapsed for writing commitment is")
		println(elapsed_time_commit)
		elapsed_time_start = @elapsed write_start(path, inputs, setup, EP)
		println("Time elapsed for writing startup is")
		println(elapsed_time_start)
		elapsed_time_shutdown = @elapsed write_shutdown(path, inputs, setup, EP)
		println("Time elapsed for writing shutdown is")
		println(elapsed_time_shutdown)
		if setup["Reserves"] == 1
			elapsed_time_reg = @elapsed write_reg(path, inputs, setup, EP)
			println("Time elapsed for writing regulation is")
			println(elapsed_time_reg)
			elapsed_time_rsv = @elapsed write_rsv(path, inputs, setup, EP)
			println("Time elapsed for writing reserves is")
			println(elapsed_time_rsv)
		end
	end

    if has_fusion(inputs)
        write_fusion_parasitic_power(path, inputs, setup, EP)
        write_fusion_pulse_starts(path, inputs, setup, EP)
    end

	# Output additional variables related inter-period energy transfer via storage
	representative_periods = inputs["REP_PERIOD"]
	if representative_periods > 1 && (!isempty(inputs["STOR_LONG_DURATION"]) || !isempty(VS_LDS))
		elapsed_time_lds_init = @elapsed write_opwrap_lds_stor_init(path, inputs, setup, EP)
		println("Time elapsed for writing lds init is")
		println(elapsed_time_lds_init)
		elapsed_time_lds_dstor = @elapsed write_opwrap_lds_dstor(path, inputs, setup, EP)
		println("Time elapsed for writing lds dstor is")
		println(elapsed_time_lds_dstor)
	end

	elapsed_time_fuel_consumption = @elapsed write_fuel_consumption(path, inputs, setup, EP)
	println("Time elapsed for writing fuel consumption is")
	println(elapsed_time_fuel_consumption)

	elapsed_time_emissions = @elapsed write_co2(path, inputs, setup, EP)
	println("Time elapsed for writing co2 is")
	println(elapsed_time_emissions)

    if has_maintenance(inputs)
        write_maintenance(path, inputs, EP)
    end

	# Temporary! Suppress these outputs until we know that they are compatable with multi-stage modeling
	if setup["MultiStage"] == 0
		dfPrice = DataFrame()
		dfEnergyRevenue = DataFrame()
		dfChargingcost = DataFrame()
		dfSubRevenue = DataFrame()
		dfRegSubRevenue = DataFrame()
		if has_duals(EP) == 1
			dfPrice = write_price(path, inputs, setup, EP)
			dfEnergyRevenue = write_energy_revenue(path, inputs, setup, EP)
			dfChargingcost = write_charging_cost(path, inputs, setup, EP)
			dfSubRevenue, dfRegSubRevenue = write_subsidy_revenue(path, inputs, setup, EP)
		end

		elapsed_time_time_weights = @elapsed write_time_weights(path, inputs)
	  println("Time elapsed for writing time weights is")
	  println(elapsed_time_time_weights)
		dfESR = DataFrame()
		dfESRRev = DataFrame()
		if setup["EnergyShareRequirement"]==1 && has_duals(EP) == 1
			dfESR = write_esr_prices(path, inputs, setup, EP)
			dfESRRev = write_esr_revenue(path, inputs, setup, dfPower, dfESR, EP)
		end
		dfResMar = DataFrame()
		dfResRevenue = DataFrame()
		if setup["CapacityReserveMargin"]==1 && has_duals(EP) == 1
			dfResMar = write_reserve_margin(path, setup, EP)
			elapsed_time_rsv_margin = @elapsed write_reserve_margin_w(path, inputs, setup, EP)
			dfVirtualDischarge = write_virtual_discharge(path, inputs, setup, EP)
		  println("Time elapsed for writing reserve margin is")
		  println(elapsed_time_rsv_margin)
			dfResRevenue = write_reserve_margin_revenue(path, inputs, setup, EP)
			elapsed_time_cap_value = @elapsed write_capacity_value(path, inputs, setup, EP)
		  println("Time elapsed for writing capacity value is")
		  println(elapsed_time_cap_value)
			if haskey(inputs, "dfCapRes_slack")
				dfResMar_slack = write_reserve_margin_slack(path, inputs, setup, EP)
			end		  
		end
		if setup["CO2Cap"]>0 && has_duals(EP) == 1
			dfCO2Cap = write_co2_cap(path, inputs, setup, EP)
		end
		if setup["MinCapReq"] == 1 && has_duals(EP) == 1
			dfMinCapReq = write_minimum_capacity_requirement(path, inputs, setup, EP)
		end
		if setup["MaxCapReq"] == 1 && has_duals(EP) == 1
			dfMaxCapReq = write_maximum_capacity_requirement(path, inputs, setup, EP)
		end

		if !isempty(inputs["ELECTROLYZER"]) && has_duals(EP) == 1
			dfHydrogenPrice = write_hydrogen_prices(path, inputs, setup, EP)
			if setup["HydrogenHourlyMatching"] == 1
				dfHourlyMatchingPrices = write_hourly_matching_prices(path, inputs, setup, EP)
			end
		end

		elapsed_time_net_rev = @elapsed write_net_revenue(path, inputs, setup, EP, dfCap, dfESRRev, dfResRevenue, dfChargingcost, dfPower, dfEnergyRevenue, dfSubRevenue, dfRegSubRevenue, dfVreStor)
	  	println("Time elapsed for writing net revenue is")
	  	println(elapsed_time_net_rev)
	end
	## Print confirmation
	println("Wrote outputs to $path")

	return path
end # END output()
