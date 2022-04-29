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

Function for the entry-point for writing the different output files. 
    From here, onward several other functions are called, each for writing specific output files, like costs, capacities, etc.
"""
function write_outputs(EP::Model, path::AbstractString, setup::Dict, inputs::Dict)

    ## Use appropriate directory separator depending on Mac or Windows config
    if Sys.isunix()
        sep = "/"
    elseif Sys.iswindows()
        sep = "\U005c"
    else
        sep = "/"
    end

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
            write_status(path, sep, inputs, setup, EP)
            return
            # Model reached timelimit but failed to find a feasible solution
            #### Aaron Schwartz - Not sure if the below condition is valid anymore. We should revisit ####
        elseif isnan(objective_value(EP)) == true
            # Model failed to solve, so record solver status and exit
            write_status(path, sep, inputs, setup, EP)
            return
        end
    end

    write_status(path, sep, inputs, setup, EP)
    # write_costs(path, sep, inputs, setup, EP) # On Jan 21, 2022, seems unnecessary as below.

    if setup["MultiStage"] == 1
        dfCap = write_capacity_multi_stage(path, sep, inputs, setup, EP)
        write_costs(path, sep, inputs, setup, EP)
    else
        elapsed_time_costs = @elapsed write_costs(path, sep, inputs, setup, EP)
        println("Time elapsed for writing costs is")
        println(elapsed_time_costs)
        dfCap = write_capacity(path, sep, inputs, setup, EP)
    end
    dfPower = write_power(path, sep, inputs, setup, EP)

    dfCharge = write_charge(path, sep, inputs, setup, EP)

    dfCapacityfactor = write_capacityfactor(path, sep, inputs, setup, EP)

    elapsed_time_storage = @elapsed write_storage(path, sep, inputs, setup, EP)
    println("Time elapsed for writing storage is")
    println(elapsed_time_storage)

    dfCurtailment = write_curtailment(path, sep, inputs, setup, EP)

    elapsed_time_nse = @elapsed write_nse(path, sep, inputs, setup, EP)
    println("Time elapsed for writing nse is")
    println(elapsed_time_nse)

    elapsed_time_nse = @elapsed write_zonalnse(path, sep, inputs, setup, EP)
    println("Time elapsed for writing zonal nse is")
    println(elapsed_time_nse)

    elapsed_time_power_balance = @elapsed write_power_balance(path, sep, inputs, setup, EP)
    println("Time elapsed for writing power balance is")
    println(elapsed_time_power_balance)

    if inputs["Z"] > 1
        elapsed_time_flows = @elapsed write_transmission_flows(path, sep, setup, inputs, EP)
        println("Time elapsed for writing transmission flows is")
        println(elapsed_time_flows)
    
        elapsed_time_losses = @elapsed write_transmission_losses(path, sep, inputs, setup, EP)
        println("Time elapsed for writing transmission losses is")
        println(elapsed_time_losses)
    
        elapsed_time_zonallosses = @elapsed write_zonal_transmission_losses(path, sep, inputs, setup, EP)
        println("Time elapsed for writing zonal transmission losses is")
        println(elapsed_time_zonallosses)
    
        elapsed_time_expansion = @elapsed write_nw_expansion(path, sep, inputs, setup, EP)
        println("Time elapsed for writing network expansion is")
        println(elapsed_time_expansion)
    
    end
    # elapsed_time_emissions = @elapsed write_emissions(path, sep, inputs, setup, EP)
    elapsed_time_emissions = @elapsed write_co2(path, sep, inputs, setup, EP)
    println("Time elapsed for writing emissions is")
    println(elapsed_time_emissions)

    if has_duals(EP) == 1
        elapsed_time_reliability = @elapsed write_reliability(path, sep, inputs, setup, EP)
        println("Time elapsed for writing reliability is")
        println(elapsed_time_reliability)

        # elapsed_time_stordual = @elapsed write_storagedual(path, sep, inputs, setup, EP)
        # println("Time elapsed for writing storage duals is")
        # println(elapsed_time_stordual)
    end

    if setup["UCommit"] >= 1
        elapsed_time_commit = @elapsed write_commit(path, sep, inputs, setup, EP)
        println("Time elapsed for writing commitment is")
        println(elapsed_time_commit)

        elapsed_time_start = @elapsed write_start(path, sep, inputs, setup, EP)
        println("Time elapsed for writing startup is")
        println(elapsed_time_start)

        elapsed_time_shutdown = @elapsed write_shutdown(path, sep, inputs, setup, EP)
        println("Time elapsed for writing shutdown is")
        println(elapsed_time_shutdown)

        if setup["Reserves"] == 1
            elapsed_time_reg = @elapsed write_reg(path, sep, inputs, setup, EP)
            println("Time elapsed for writing regulation is")
            println(elapsed_time_reg)

            elapsed_time_rsv = @elapsed write_rsv(path, sep, inputs, setup, EP)
            println("Time elapsed for writing reserves is")
            println(elapsed_time_rsv)
        end
    end


    # Output additional variables related inter-period energy transfer via storage
    if setup["OperationWrapping"] == 1 && !isempty(inputs["STOR_LONG_DURATION"])
        elapsed_time_lds_init = @elapsed write_opwrap_lds_stor_init(path, sep, inputs, setup, EP)
        println("Time elapsed for writing lds init is")
        println(elapsed_time_lds_init)
        elapsed_time_lds_dstor = @elapsed write_opwrap_lds_dstor(path, sep, inputs, setup, EP)
        println("Time elapsed for writing lds dstor is")
        println(elapsed_time_lds_dstor)
    end

    # Temporary! Suppress these outputs until we know that they are compatable with multi-stage modeling
    if setup["MultiStage"] == 0
        # Energy Market & Subsidy
        dfPrice = DataFrame()
        dfEnergyRevenue = DataFrame()
        dfChargingcost = DataFrame()
        dfSubRevenue = DataFrame()
        dfRegSubRevenue = DataFrame()
        dfEnergyPayment = DataFrame()
        dfCongestionRevenue = DataFrame()
        dfTransmissionLossCost = DataFrame()
        if has_duals(EP) == 1
            dfPrice = write_price(path, sep, inputs, setup, EP)
            dfEnergyRevenue = write_energy_revenue(path, sep, inputs, setup, EP)
            dfChargingcost = write_charging_cost(path, sep, inputs, setup, EP)
            dfEnergyPayment = write_energy_payment(path, sep, inputs, setup, EP)
            dfSubRevenue, dfRegSubRevenue = write_subsidy_revenue(path, sep, inputs, setup, EP)
            if inputs["Z"] > 1
                dfCongestionRevenue = write_congestion_revenue(path, sep, inputs, setup, EP)
                dfTransmissionLossCost = write_transmission_losscost(path, sep, inputs, setup, EP)
            end
        end
    
        elapsed_time_time_weights = @elapsed write_time_weights(path, sep, inputs)
        println("Time elapsed for writing time weights is")
        println(elapsed_time_time_weights)
    
        #Energy Share Requirement Market
        dfESR = DataFrame()
        dfESRRev = DataFrame()
        dfESRPayment = DataFrame()
        dfESRStoragelossPayment = DataFrame()
        dfESRtransmissionlosspayment = DataFrame()
        if setup["EnergyShareRequirement"] == 1 && has_duals(EP) == 1
            dfESR = write_esr_prices(path, sep, inputs, setup, EP)
            dfESRRev = write_esr_revenue(path, sep, inputs, setup, EP)
            dfESRPayment = write_esr_payment(path, sep, inputs, setup, EP)
            if !isempty(inputs["STOR_ALL"])
                if haskey(setup, "StorageLosses")
                    if setup["StorageLosses"] == 1
                        dfESRStoragelossPayment = write_esr_storagelosspayment(path, sep, inputs, setup, EP)
                    end
                else
                    dfESRStoragelossPayment = write_esr_storagelosspayment(path, sep, inputs, setup, EP)
                end
            end
            if Z > 1
                if haskey(setup, "PolicyTransmissionLossCoverage")
                    if setup["PolicyTransmissionLossCoverage"] == 1
                        dfESRtransmissionlosspayment = write_esr_transmissionlosspayment(path, sep, inputs, setup, EP)
                    end
                else
                    dfESRtransmissionlosspayment = write_esr_transmissionlosspayment(path, sep, inputs, setup, EP)
                end
            end
        end
        # Capacity Market
        dfResMar = DataFrame()
        dfResRevenue = DataFrame()
        dfResPayment = DataFrame()
        dfResDRSaving = DataFrame()
        dfResTransRevenue = DataFrame()
        if setup["CapacityReserveMargin"] == 1 && has_duals(EP) == 1
            dfResMar = write_reserve_margin(path, sep, inputs, setup, EP)
            dfResRevenue = write_reserve_margin_revenue(path, sep, inputs, setup, EP)
            dfResPayment = write_reserve_margin_payment(path, sep, inputs, setup, EP)
            if inputs["SEG"] >= 2
                dfResDRSaving = write_reserve_margin_demand_response_saving(path, sep, inputs, setup, EP)
            end
            if inputs["Z"] >= 2
                dfResTransRevenue = write_reserve_margin_transmission_revenue(path, sep, inputs, setup, EP)
            end
            elapsed_time_cap_value = @elapsed write_capacity_value(path, sep, inputs, setup, EP)
            println("Time elapsed for writing capacity value is")
            println(elapsed_time_cap_value)
        end
    
        dfCO2MassCapCost = DataFrame()
        dfCO2MassCapRev = DataFrame()
        dfCO2Price = DataFrame()
        if setup["CO2Cap"] == 1 && has_duals(EP) == 1
            dfCO2Price, dfCO2MassCapRev, dfCO2MassCapCost = write_co2_cap_price_revenue(path, sep, inputs, setup, EP)
        end
    
        dfCO2GenRateCapCost = DataFrame()
        dfCO2GenRatePrice = DataFrame()
        if haskey(setup, "CO2GenRateCap")
            if setup["CO2GenRateCap"] == 1 && has_duals(EP) == 1
                dfCO2GenRatePrice, dfCO2GenRateCapCost = write_co2_generation_emission_rate_cap_price_revenue(path, sep, inputs, setup, EP)
            end
        end
    
        dfCO2LoadRateCapCost = DataFrame()
        dfCO2LoadRateCapRev = DataFrame()
        dfCO2LoadRatePrice = DataFrame()
        if haskey(setup, "CO2LoadRateCap")
            if setup["CO2LoadRateCap"] == 1 && has_duals(EP) == 1
                dfCO2LoadRatePrice, dfCO2LoadRateCapRev, dfCO2LoadRateCapCost = write_co2_load_emission_rate_cap_price_revenue(path, sep, inputs, setup, EP)
            end
        end
    
        dfCO2TaxCost = DataFrame()
        if haskey(setup, "CO2Tax")
            if setup["CO2Tax"] == 1
                dfCO2TaxCost = write_co2_tax(path, sep, inputs, setup, EP)
            end
        end
        if haskey(setup, "CO2Credit")
            dfCO2CaptureCredit = DataFrame()
            if setup["CO2Credit"] == 1
                dfCO2CaptureCredit = write_credit_for_captured_emissions(path, sep, inputs, setup, EP)
            end
        end
        if haskey(setup, "TFS")
            if setup["TFS"] == 1
                write_twentyfourseven(path, sep, inputs, setup, EP)
            end
        end
    
        elapsed_time_net_rev = @elapsed write_net_revenue(path, sep, inputs, setup, EP, dfCap, dfESRRev, dfResRevenue, dfChargingcost, dfPower, dfEnergyRevenue, dfSubRevenue, dfRegSubRevenue, dfCO2MassCapCost, dfCO2LoadRateCapCost, dfCO2GenRateCapCost, dfCO2TaxCost, dfCO2CaptureCredit)
        println("Time elapsed for writing net revenue is")
        println(elapsed_time_net_rev)
    
    
    
    end
    ## Print confirmation
    println("Wrote outputs to $path$sep")

end # END output()
