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

	## Use appropriate directory separator depending on Mac or Windows config
	if setup["MacOrWindows"]=="Mac"
		sep = "/"
	else
		sep = "\U005c"
	end

	# If output directory does not exist, create it
	if !(isdir(path))
		mkdir(path)
	end

	# https://jump.dev/MathOptInterface.jl/v0.9.10/apireference/#MathOptInterface.TerminationStatusCode
	status = termination_status(EP)

	## Check if solved sucessfully - time out is included
	if status != MOI.OPTIMAL
		if status != MOI.TIME_LIMIT # Model failed to solve, so record solver status and exit
			write_status(path, sep, inputs, EP)
			return
			# Model reached timelimit but failed to find a feasible solution
	#### Aaron Schwartz - Not sure if the below condition is valid anymore. We should revisit ####
		elseif isnan(objective_value(EP))==true
			# Model failed to solve, so record solver status and exit
			write_status(path, sep, inputs, EP)
			return
		end
	end

	write_status(path, sep, inputs, EP)
	write_costs(path, sep, inputs, setup, EP)
	dfCap = write_capacity(path, sep, inputs, setup, EP)
	dfPower = write_power(path, sep, inputs, setup, EP)
	dfCharge = write_charge(path, sep, inputs, setup, EP)
	write_storage(path, sep, inputs, setup, EP)
	dfCurtailment = write_curtailment(path, sep, inputs, setup, EP)
	write_nse(path, sep, inputs, setup, EP)
	write_power_balance(path, sep, inputs, setup, EP)
	if inputs["Z"] > 1
		write_transmission_flows(path, sep, inputs, EP)
		write_transmission_losses(path, sep, inputs, EP)
		if setup["NetworkExpansion"] == 1
			write_nw_expansion(path, sep, inputs, setup, EP)
		end
	end
	write_emissions(path, sep, inputs, setup, EP)
	if has_duals(EP) == 1
		write_reliability(path, sep, inputs, setup, EP)
		write_storagedual(path, sep, inputs, setup, EP)
	end

	if setup["UCommit"] >= 1
		write_commit(path, sep, inputs, setup, EP)
		write_start(path, sep, inputs, setup, EP)
		write_shutdown(path, sep, inputs, setup, EP)
		if setup["Reserves"] == 1
			write_reg(path, sep, inputs, setup, EP)
			write_rsv(path, sep, inputs, setup, EP)
		end
	end


	# Output additional variables related inter-period energy transfer via storage
	if setup["OperationWrapping"] == 1 && setup["LongDurationStorage"] == 1
		write_opwrap_lds_stor_init(path, sep, inputs, setup, EP)
		write_opwrap_lds_dstor(path, sep, inputs, setup, EP)
	end

	dfPrice = DataFrame()
	dfEnergyRevenue = DataFrame()
	dfChargingcost = DataFrame()
	dfSubRevenue = DataFrame()
	dfRegSubRevenue = DataFrame()
	if has_duals(EP) == 1
		dfPrice = write_price(path, sep, inputs, setup, EP)
		dfEnergyRevenue = write_energy_revenue(path, sep, inputs, setup, EP, dfPower, dfPrice, dfCharge)
		dfChargingcost = write_charging_cost(path, sep, inputs, dfCharge, dfPrice, dfPower, setup)
		dfSubRevenue, dfRegSubRevenue = write_subsidy_revenue(path, sep, inputs, setup, dfCap, EP)
	end

	write_time_weights(path, sep, inputs)
	dfESR = DataFrame()
	dfESRRev = DataFrame()
	if setup["EnergyShareRequirement"]==1 && has_duals(EP) == 1
		dfESR = write_esr_prices(path, sep, inputs, setup, EP)
		dfESRRev = write_esr_revenue(path, sep, inputs, setup, dfPower, dfESR)
	end
	dfResMar = DataFrame()
	dfResRevenue = DataFrame()
	if setup["CapacityReserveMargin"]==1 && has_duals(EP) == 1
		dfResMar = write_reserve_margin(path, sep, setup, EP)
		write_reserve_margin_w(path, sep, inputs, setup, EP)
		dfResRevenue = write_reserve_margin_revenue(path, sep, inputs, setup, dfPower, dfCharge, dfResMar, dfCap)
		write_capacity_value(path, sep, inputs, setup, dfPower, dfCharge, dfResMar, dfCap)
	end

	write_net_revenue(path, sep, inputs, setup, EP, dfCap, dfESRRev, dfResRevenue, dfChargingcost, dfPower, dfEnergyRevenue, dfSubRevenue, dfRegSubRevenue)

	## Print confirmation
	println("Wrote outputs to $path$sep")

end # END output()
