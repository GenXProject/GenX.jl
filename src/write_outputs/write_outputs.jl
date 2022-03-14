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

################################################################################
## function output
##
## description: Writes results to multiple .csv output files in path directory
##
## returns: n/a
################################################################################
@doc raw"""
	write_outputs(EP::Model, path::AbstractString, setup::Dict, inputs::Dict)

Function for the entry-point for writing the different output files. From here, onward several other functions are called, each for writing specific output files, like costs, capacities, etc.
"""
function write_outputs(EP::Model, path::AbstractString, setup::Dict, inputs::Dict)

	if !haskey(setup, "OverwriteResults") || setup["OverwriteResults"] == 1
		# Overwrite existing results if dir exists
		# This is the default behaviour when there is no flag, to avoid breaking existing code
		if !(isdir(path))
		mkdir(path)
		end
	else
		# Find closest unused ouput directory name and create it
		path = choose_output_dir(path)
		mkdir(path)
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
		elapsed_time_flows = @elapsed write_transmission_flows(path, inputs, EP)
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
	if has_duals(EP) == 1
		elapsed_time_reliability = @elapsed write_reliability(path, inputs, setup, EP)
		println("Time elapsed for writing reliability is")
		println(elapsed_time_reliability)
		elapsed_time_stordual = @elapsed write_storagedual(path, inputs, setup, EP)
		println("Time elapsed for writing storage duals is")
		println(elapsed_time_stordual)
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



	# Output additional variables related inter-period energy transfer via storage
	if setup["OperationWrapping"] == 1 && !isempty(inputs["STOR_LONG_DURATION"])
		elapsed_time_lds_init = @elapsed write_opwrap_lds_stor_init(path, inputs, setup, EP)
		println("Time elapsed for writing lds init is")
		println(elapsed_time_lds_init)
		elapsed_time_lds_dstor = @elapsed write_opwrap_lds_dstor(path, inputs, setup, EP)
		println("Time elapsed for writing lds dstor is")
		println(elapsed_time_lds_dstor)
	end

	dfPrice = DataFrame()
	dfEnergyRevenue = DataFrame()
	dfChargingcost = DataFrame()
	dfSubRevenue = DataFrame()
	dfRegSubRevenue = DataFrame()
	if has_duals(EP) == 1
		dfPrice = write_price(path, inputs, setup, EP)
		dfEnergyRevenue = write_energy_revenue(path, inputs, setup, EP, dfPower, dfPrice, dfCharge)
		dfChargingcost = write_charging_cost(path, inputs, dfCharge, dfPrice, dfPower, setup)
		dfSubRevenue, dfRegSubRevenue = write_subsidy_revenue(path, inputs, setup, dfCap, EP)
	end

	elapsed_time_time_weights = @elapsed write_time_weights(path, inputs)
	println("Time elapsed for writing time weights is")
	println(elapsed_time_time_weights)
	dfESR = DataFrame()
	dfESRRev = DataFrame()
	if setup["EnergyShareRequirement"]==1 && has_duals(EP) == 1
		dfESR = write_esr_prices(path, inputs, setup, EP)
		dfESRRev = write_esr_revenue(path, inputs, setup, dfPower, dfESR)
	end
	dfResMar = DataFrame()
	dfResRevenue = DataFrame()
	if setup["CapacityReserveMargin"]==1 && has_duals(EP) == 1
		dfResMar = write_reserve_margin(path, setup, EP)
		elapsed_time_rsv_margin = @elapsed write_reserve_margin_w(path, inputs, setup, EP)
		println("Time elapsed for writing reserve margin is")
		println(elapsed_time_rsv_margin)
		dfResRevenue = write_reserve_margin_revenue(path, inputs, setup, dfPower, dfCharge, dfResMar, dfCap)
		elapsed_time_cap_value = @elapsed write_capacity_value(path, inputs, setup, dfPower, dfCharge, dfResMar, dfCap)
		println("Time elapsed for writing capacity value is")
		println(elapsed_time_cap_value)
	end

	elapsed_time_net_rev = @elapsed write_net_revenue(path, inputs, setup, EP, dfCap, dfESRRev, dfResRevenue, dfChargingcost, dfPower, dfEnergyRevenue, dfSubRevenue, dfRegSubRevenue)
	println("Time elapsed for writing net revenue is")
	println(elapsed_time_net_rev)

	if setup["FLECCS"] >= 1
		dfCap_FLECCS = write_capacity_fleccs(path, inputs, setup, EP)
		dfPower_FLECCS = write_power_fleccs(path, inputs, setup, EP)
		dfEnergyRevenue_FLECCS = DataFrame()
		if has_duals(EP) == 1
			dfEnergyRevenue_FLECCS = write_energy_revenue_fleccs(path, inputs, setup, EP, dfPower_FLECCS, dfPrice)
			# we don't have minimum cap requirement for fleccs 
			#dfSubRevenue_FLECCS, dfRegSubRevenue_FLECCS = write_subsidy_revenue_fleccs(path, inputs, setup, dfCap, EP)
		end

	    dfResRevenue_FLECCS = DataFrame()
	    if setup["CapacityReserveMargin"]==1 && has_duals(EP) == 1
	    	dfResRevenue_FLECCS = write_reserve_margin_revenue_fleccs(path, inputs, setup, dfResMar, EP)
    	end

		write_net_revenue_fleccs(path, inputs, setup, EP, dfCap_FLECCS, dfResRevenue_FLECCS, dfPower_FLECCS, dfEnergyRevenue_FLECCS)

    end

	## Print confirmation
	println("Wrote outputs to $path")

end # END output()
