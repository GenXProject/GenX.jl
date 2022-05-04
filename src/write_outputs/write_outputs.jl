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
            write_status(path, inputs, setup, EP)
            return
            # Model reached timelimit but failed to find a feasible solution
            #### Aaron Schwartz - Not sure if the below condition is valid anymore. We should revisit ####
        elseif isnan(objective_value(EP)) == true
            # Model failed to solve, so record solver status and exit
            write_status(path, inputs, setup, EP)
            return
        end
    end

    write_status(path, inputs, setup, EP)
    write_costs(path, inputs, setup, EP)
    dfCap = write_capacity(path, inputs, setup, EP)
    dfPower = write_power(path, inputs, setup, EP)
    write_charge(path, inputs, setup, EP)
    write_capacityfactor(path, inputs, setup, EP)
    write_storage(path, inputs, setup, EP)
    write_curtailment(path, inputs, setup, EP)
    write_nse(path, inputs, setup, EP)
    write_zonalnse(path, inputs, setup, EP)
    write_power_balance(path, inputs, setup, EP)

    if inputs["Z"] > 1
        write_transmission_flows(path, inputs, setup, EP)
        write_transmission_losses(path, inputs, setup, EP)
        write_zonal_transmission_losses(path, inputs, setup, EP)
        write_nw_expansion(path, inputs, setup, EP)
    end

    write_co2(path, inputs, setup, EP)

    if has_duals(EP) == 1
        write_reliability(path, inputs, setup, EP)

        # write_storagedual(path, inputs, setup, EP)
    end

    if setup["UCommit"] >= 1
        write_commit(path, inputs, setup, EP)
        write_start(path, inputs, setup, EP)
        write_shutdown(path, inputs, setup, EP)
        if haskey(setup, "Reserves")
            if setup["Reserves"] == 1
                write_reg(path, inputs, setup, EP)
                write_rsv(path, inputs, setup, EP)
            end
        end
    end


    # Output additional variables related inter-period energy transfer via storage
    if setup["OperationWrapping"] == 1 && !isempty(inputs["STOR_LONG_DURATION"])
        write_opwrap_lds_stor_init(path, inputs, setup, EP)

        write_opwrap_lds_dstor(path, inputs, setup, EP)
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
            dfPrice = write_price(path, inputs, setup, EP)
            dfEnergyRevenue = write_energy_revenue(path, inputs, setup, EP)
            dfChargingcost = write_charging_cost(path, inputs, setup, EP)
            dfEnergyPayment = write_energy_payment(path, inputs, setup, EP)
            dfSubRevenue = write_subsidy_revenue(path, inputs, setup, EP)
            if inputs["Z"] > 1
                dfCongestionRevenue = write_congestion_revenue(path, inputs, setup, EP)
                dfTransmissionLossCost = write_transmission_losscost(path, inputs, setup, EP)
            end
        end

        if (haskey(setup, "MinCapReq"))
            if setup["MinCapReq"] == 1 && has_duals(EP) == 1
                dfRegSubRevenue = write_regional_subsidy_revenue(path, inputs, setup, EP)
            end
        end

        write_time_weights(path, inputs)

        #Energy Share Requirement Market
        dfESR = DataFrame()
        dfESRRev = DataFrame()
        dfESRPayment = DataFrame()
        dfESRStoragelossPayment = DataFrame()
        dfESRtransmissionlosspayment = DataFrame()
        if haskey(setup, "EnergyShareRequirement")
            if setup["EnergyShareRequirement"] == 1 && has_duals(EP) == 1
                dfESR = write_esr_prices(path, inputs, setup, EP)
                dfESRRev = write_esr_revenue(path, inputs, setup, EP)
                dfESRPayment = write_esr_payment(path, inputs, setup, EP)
                if !isempty(inputs["STOR_ALL"])
                    if haskey(setup, "StorageLosses")
                        if setup["StorageLosses"] == 1
                            dfESRStoragelossPayment = write_esr_storagelosspayment(path, inputs, setup, EP)
                        end
                    else
                        dfESRStoragelossPayment = write_esr_storagelosspayment(path, inputs, setup, EP)
                    end
                end
                if inputs["Z"] > 1
                    if haskey(setup, "PolicyTransmissionLossCoverage")
                        if setup["PolicyTransmissionLossCoverage"] == 1
                            dfESRtransmissionlosspayment = write_esr_transmissionlosspayment(path, inputs, setup, EP)
                        end
                    else
                        dfESRtransmissionlosspayment = write_esr_transmissionlosspayment(path, inputs, setup, EP)
                    end
                end
            end
        end
        # Capacity Market
        dfResMar = DataFrame()
        dfResRevenue = DataFrame()
        dfResPayment = DataFrame()
        dfResDRSaving = DataFrame()
        dfResTransRevenue = DataFrame()
        if haskey(setup, "CapacityReserveMargin")
            if setup["CapacityReserveMargin"] == 1 && has_duals(EP) == 1
                dfResMar = write_reserve_margin(path, inputs, setup, EP)
                dfResRevenue = write_reserve_margin_revenue(path, inputs, setup, EP)
                dfResPayment = write_reserve_margin_payment(path, inputs, setup, EP)
                if inputs["SEG"] >= 2
                    dfResDRSaving = write_reserve_margin_demand_response_saving(path, inputs, setup, EP)
                end
                if inputs["Z"] > 1
                    dfResTransRevenue = write_reserve_margin_transmission_revenue(path, inputs, setup, EP)
                end
                write_capacity_value(path, inputs, setup, EP)
            end
        end

        dfCO2MassCapCost = DataFrame()
        dfCO2MassCapRev = DataFrame()
        dfCO2Price = DataFrame()
        if haskey(setup, "CO2Cap")
            if setup["CO2Cap"] == 1 && has_duals(EP) == 1
                dfCO2Price, dfCO2MassCapRev, dfCO2MassCapCost = write_co2_cap_price_revenue(path, inputs, setup, EP)
            end
        end


        dfCO2GenRateCapCost = DataFrame()
        dfCO2GenRatePrice = DataFrame()
        if haskey(setup, "CO2GenRateCap")
            if setup["CO2GenRateCap"] == 1 && has_duals(EP) == 1
                dfCO2GenRatePrice, dfCO2GenRateCapCost = write_co2_generation_emission_rate_cap_price_revenue(path, inputs, setup, EP)
            end
        end

        dfCO2LoadRateCapCost = DataFrame()
        dfCO2LoadRateCapRev = DataFrame()
        dfCO2LoadRatePrice = DataFrame()
        if haskey(setup, "CO2LoadRateCap")
            if setup["CO2LoadRateCap"] == 1 && has_duals(EP) == 1
                dfCO2LoadRatePrice, dfCO2LoadRateCapRev, dfCO2LoadRateCapCost = write_co2_load_emission_rate_cap_price_revenue(path, inputs, setup, EP)
            end
        end

        dfCO2TaxCost = DataFrame()
        if haskey(setup, "CO2Tax")
            if setup["CO2Tax"] == 1
                dfCO2TaxCost = write_co2_tax(path, inputs, setup, EP)
            end
        end
        dfCO2CaptureCredit = DataFrame()
        if haskey(setup, "CO2Credit")
            if setup["CO2Credit"] == 1
                dfCO2CaptureCredit = write_credit_for_captured_emissions(path, inputs, setup, EP)
            end
        end

        if haskey(setup, "TFS")
            if setup["TFS"] == 1
                write_twentyfourseven(path, inputs, setup, EP)
            end
        end

        write_net_revenue(path, inputs, setup, EP, dfESRRev, dfResRevenue, dfChargingcost, dfEnergyRevenue, dfSubRevenue, dfRegSubRevenue, dfCO2MassCapCost, dfCO2LoadRateCapCost, dfCO2GenRateCapCost, dfCO2TaxCost, dfCO2CaptureCredit)



    end
    ## Print confirmation
    println("Wrote outputs to $path$sep")

end # END output()
