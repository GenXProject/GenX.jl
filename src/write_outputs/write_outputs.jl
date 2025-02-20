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

    if setup["OutputFullTimeSeries"] == 1
        mkpath(joinpath(path, setup["OutputFullTimeSeriesFolder"]))
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

    # Dict containing the list of outputs to write
    output_settings_d = setup["WriteOutputsSettingsDict"]
    write_settings_file(path, setup)
    write_system_env_summary(path)

    output_settings_d["WriteStatus"] && write_status(path, inputs, setup, EP)

    # linearize and re-solve model if duals are not available but ShadowPrices are requested
    if !has_duals(EP) && setup["WriteShadowPrices"] == 1
        # function to fix integers and linearize problem
        fix_integers(EP)
        # re-solve statement for LP solution
        println("Solving LP solution for duals")
        set_silent(EP)
        optimize!(EP)
    end

    if output_settings_d["WriteCosts"]
        elapsed_time_costs = @elapsed write_costs(path, inputs, setup, EP)
        println("Time elapsed for writing costs is")
        println(elapsed_time_costs)
    end

    if output_settings_d["WriteCapacity"] || output_settings_d["WriteNetRevenue"]
        elapsed_time_capacity = @elapsed dfCap = write_capacity(path, inputs, setup, EP)
        println("Time elapsed for writing capacity is")
        println(elapsed_time_capacity)
    end

    if output_settings_d["WritePower"] || output_settings_d["WriteNetRevenue"]
        elapsed_time_power = @elapsed dfPower = write_power(path, inputs, setup, EP)
        println("Time elapsed for writing power is")
        println(elapsed_time_power)
    end

    if output_settings_d["WriteCharge"]
        elapsed_time_charge = @elapsed write_charge(path, inputs, setup, EP)
        println("Time elapsed for writing charge is")
        println(elapsed_time_charge)
    end

    if output_settings_d["WriteCapacityFactor"]
        elapsed_time_capacityfactor = @elapsed write_capacityfactor(path, inputs, setup, EP)
        println("Time elapsed for writing capacity factor is")
        println(elapsed_time_capacityfactor)
    end

    if output_settings_d["WriteStorage"]
        elapsed_time_storage = @elapsed write_storage(path, inputs, setup, EP)
        println("Time elapsed for writing storage is")
        println(elapsed_time_storage)
    end

    if output_settings_d["WriteCurtailment"]
        elapsed_time_curtailment = @elapsed write_curtailment(path, inputs, setup, EP)
        println("Time elapsed for writing curtailment is")
        println(elapsed_time_curtailment)
    end

    if output_settings_d["WriteNSE"]
        elapsed_time_nse = @elapsed write_nse(path, inputs, setup, EP)
        println("Time elapsed for writing nse is")
        println(elapsed_time_nse)
    end

    if output_settings_d["WritePowerBalance"]
        elapsed_time_power_balance = @elapsed write_power_balance(path, inputs, setup, EP)
        println("Time elapsed for writing power balance is")
        println(elapsed_time_power_balance)
    end

    if inputs["Z"] > 1
        if output_settings_d["WriteTransmissionFlows"]
            elapsed_time_flows = @elapsed write_transmission_flows(path, inputs, setup, EP)
            println("Time elapsed for writing transmission flows is")
            println(elapsed_time_flows)
        end

        if output_settings_d["WriteTransmissionLosses"]
            elapsed_time_losses = @elapsed write_transmission_losses(path,
                inputs,
                setup,
                EP)
            println("Time elapsed for writing transmission losses is")
            println(elapsed_time_losses)
        end

        if setup["NetworkExpansion"] == 1 && output_settings_d["WriteNWExpansion"]
            elapsed_time_expansion = @elapsed write_nw_expansion(path, inputs, setup, EP)
            println("Time elapsed for writing network expansion is")
            println(elapsed_time_expansion)
        end
    end

    if output_settings_d["WriteEmissions"]
        elapsed_time_emissions = @elapsed write_emissions(path, inputs, setup, EP)
        println("Time elapsed for writing emissions is")
        println(elapsed_time_emissions)
    end

    dfVreStor = DataFrame()
    if !isempty(inputs["VRE_STOR"])
        if output_settings_d["WriteVREStor"] || output_settings_d["WriteNetRevenue"]
            elapsed_time_vrestor = @elapsed dfVreStor = write_vre_stor(path,
                inputs,
                setup,
                EP)
            println("Time elapsed for writing vre stor is")
            println(elapsed_time_vrestor)
        end
        VS_LDS = inputs["VS_LDS"]
        VS_STOR = inputs["VS_STOR"]
    else
        VS_LDS = []
        VS_STOR = []
    end

    if has_duals(EP) == 1
        if output_settings_d["WriteReliability"]
            elapsed_time_reliability = @elapsed write_reliability(path, inputs, setup, EP)
            println("Time elapsed for writing reliability is")
            println(elapsed_time_reliability)
        end
        if !isempty(inputs["STOR_ALL"]) || !isempty(VS_STOR)
            if output_settings_d["WriteStorageDual"]
                elapsed_time_stordual = @elapsed write_storagedual(path, inputs, setup, EP)
                println("Time elapsed for writing storage duals is")
                println(elapsed_time_stordual)
            end
        end
    end

    if setup["UCommit"] >= 1
        if output_settings_d["WriteCommit"]
            elapsed_time_commit = @elapsed write_commit(path, inputs, setup, EP)
            println("Time elapsed for writing commitment is")
            println(elapsed_time_commit)
        end

        if output_settings_d["WriteStart"]
            elapsed_time_start = @elapsed write_start(path, inputs, setup, EP)
            println("Time elapsed for writing startup is")
            println(elapsed_time_start)
        end

        if output_settings_d["WriteShutdown"]
            elapsed_time_shutdown = @elapsed write_shutdown(path, inputs, setup, EP)
            println("Time elapsed for writing shutdown is")
            println(elapsed_time_shutdown)
        end

        if setup["OperationalReserves"] == 1
            if output_settings_d["WriteReg"]
                elapsed_time_reg = @elapsed write_reg(path, inputs, setup, EP)
                println("Time elapsed for writing regulation is")
                println(elapsed_time_reg)
            end

            if output_settings_d["WriteRsv"]
                elapsed_time_rsv = @elapsed write_rsv(path, inputs, setup, EP)
                println("Time elapsed for writing reserves is")
                println(elapsed_time_rsv)
            end
        end

        # fusion is only applicable to UCommit=1 resources
        if output_settings_d["WriteFusion"] && has_fusion(inputs)
            write_fusion_net_capacity_factor(path, inputs, setup, EP)
            write_fusion_pulse_starts(path, inputs, setup, EP)
        end
    end

    # Output additional variables related inter-period energy transfer via storage
    representative_periods = inputs["REP_PERIOD"]
    if representative_periods > 1 &&
       (!isempty(inputs["STOR_LONG_DURATION"]) || !isempty(VS_LDS))
        if output_settings_d["WriteOpWrapLDSStorInit"]
            elapsed_time_lds_init = @elapsed write_opwrap_lds_stor_init(path,
                inputs,
                setup,
                EP)
            println("Time elapsed for writing lds init is")
            println(elapsed_time_lds_init)
        end

        if output_settings_d["WriteOpWrapLDSdStor"]
            elapsed_time_lds_dstor = @elapsed write_opwrap_lds_dstor(path,
                inputs,
                setup,
                EP)
            println("Time elapsed for writing lds dstor is")
            println(elapsed_time_lds_dstor)
        end
    end

    if output_settings_d["WriteFuelConsumption"]
        elapsed_time_fuel_consumption = @elapsed write_fuel_consumption(path,
            inputs,
            setup,
            EP)
        println("Time elapsed for writing fuel consumption is")
        println(elapsed_time_fuel_consumption)
    end

    if output_settings_d["WriteCO2"]
        elapsed_time_emissions = @elapsed write_co2(path, inputs, setup, EP)
        println("Time elapsed for writing co2 is")
        println(elapsed_time_emissions)
    end

    if has_maintenance(inputs) && output_settings_d["WriteMaintenance"]
        write_maintenance(path, inputs, setup, EP)
    end

    #Write angles when DC_OPF is activated
    if setup["DC_OPF"] == 1 && output_settings_d["WriteAngles"]
        elapsed_time_angles = @elapsed write_angles(path, inputs, setup, EP)
        println("Time elapsed for writing angles is")
        println(elapsed_time_angles)
    end

    # Temporary! Suppress these outputs until we know that they are compatable with multi-stage modeling
    if setup["MultiStage"] == 0
        dfEnergyRevenue = DataFrame()
        dfChargingcost = DataFrame()
        dfSubRevenue = DataFrame()
        dfRegSubRevenue = DataFrame()
        if has_duals(EP) == 1
            if output_settings_d["WritePrice"]
                elapsed_time_price = @elapsed write_price(path, inputs, setup, EP)
                println("Time elapsed for writing price is")
                println(elapsed_time_price)
            end

            if output_settings_d["WriteEnergyRevenue"] ||
               output_settings_d["WriteNetRevenue"]
                elapsed_time_energy_rev = @elapsed dfEnergyRevenue = write_energy_revenue(
                    path,
                    inputs,
                    setup,
                    EP)
                println("Time elapsed for writing energy revenue is")
                println(elapsed_time_energy_rev)
            end

            if output_settings_d["WriteChargingCost"] ||
               output_settings_d["WriteNetRevenue"]
                elapsed_time_charging_cost = @elapsed dfChargingcost = write_charging_cost(
                    path,
                    inputs,
                    setup,
                    EP)
                println("Time elapsed for writing charging cost is")
                println(elapsed_time_charging_cost)
            end

            if output_settings_d["WriteSubsidyRevenue"] ||
               output_settings_d["WriteNetRevenue"]
                elapsed_time_subsidy = @elapsed dfSubRevenue, dfRegSubRevenue = write_subsidy_revenue(
                    path,
                    inputs,
                    setup,
                    EP)
                println("Time elapsed for writing subsidy is")
                println(elapsed_time_subsidy)
            end
        end

        if output_settings_d["WriteTimeWeights"]
            elapsed_time_time_weights = @elapsed write_time_weights(path, inputs)
            println("Time elapsed for writing time weights is")
            println(elapsed_time_time_weights)
        end

        dfESRRev = DataFrame()
        if setup["EnergyShareRequirement"] == 1 && has_duals(EP)
            dfESR = DataFrame()
            if output_settings_d["WriteESRPrices"] ||
               output_settings_d["WriteESRRevenue"] || output_settings_d["WriteNetRevenue"]
                elapsed_time_esr_prices = @elapsed dfESR = write_esr_prices(path,
                    inputs,
                    setup,
                    EP)
                println("Time elapsed for writing esr prices is")
                println(elapsed_time_esr_prices)
            end

            if output_settings_d["WriteESRRevenue"] || output_settings_d["WriteNetRevenue"]
                elapsed_time_esr_revenue = @elapsed dfESRRev = write_esr_revenue(path,
                    inputs,
                    setup,
                    dfPower,
                    dfESR,
                    EP)
                println("Time elapsed for writing esr revenue is")
                println(elapsed_time_esr_revenue)
            end
        end

        dfResRevenue = DataFrame()
        if setup["CapacityReserveMargin"] == 1 && has_duals(EP)
            if output_settings_d["WriteReserveMargin"]
                elapsed_time_reserve_margin = @elapsed write_reserve_margin(path, setup, EP)
                println("Time elapsed for writing reserve margin is")
                println(elapsed_time_reserve_margin)
            end

            if output_settings_d["WriteReserveMarginWithWeights"]
                elapsed_time_rsv_margin_w = @elapsed write_reserve_margin_w(path,
                    inputs,
                    setup,
                    EP)
                println("Time elapsed for writing reserve margin with weights is")
                println(elapsed_time_rsv_margin_w)
            end

            if output_settings_d["WriteVirtualDischarge"]
                elapsed_time_virtual_discharge = @elapsed write_virtual_discharge(path,
                    inputs,
                    setup,
                    EP)
                println("Time elapsed for writing virtual discharge is")
                println(elapsed_time_virtual_discharge)
            end

            if output_settings_d["WriteReserveMarginRevenue"] ||
               output_settings_d["WriteNetRevenue"]
                elapsed_time_res_rev = @elapsed dfResRevenue = write_reserve_margin_revenue(
                    path,
                    inputs,
                    setup,
                    EP)
                println("Time elapsed for writing reserve revenue is")
                println(elapsed_time_res_rev)
            end

            if haskey(inputs, "dfCapRes_slack") &&
               output_settings_d["WriteReserveMarginSlack"]
                elapsed_time_rsv_slack = @elapsed write_reserve_margin_slack(path,
                    inputs,
                    setup,
                    EP)
                println("Time elapsed for writing reserve margin slack is")
                println(elapsed_time_rsv_slack)
            end

            if output_settings_d["WriteCapacityValue"]
                elapsed_time_cap_value = @elapsed write_capacity_value(path,
                    inputs,
                    setup,
                    EP)
                println("Time elapsed for writing capacity value is")
                println(elapsed_time_cap_value)
            end
        end

        dfOpRegRevenue = DataFrame()
        dfOpRsvRevenue = DataFrame()
        if setup["OperationalReserves"] == 1 && has_duals(EP)
            elapsed_time_op_res_rev = @elapsed dfOpRegRevenue, dfOpRsvRevenue = write_operating_reserve_regulation_revenue(
                path,
                inputs,
                setup,
                EP)
            println("Time elapsed for writing oerating reserve and regulation revenue is")
            println(elapsed_time_op_res_rev)
        end

        if setup["CO2Cap"] > 0 && has_duals(EP) == 1 && output_settings_d["WriteCO2Cap"]
            elapsed_time_co2_cap = @elapsed write_co2_cap(path, inputs, setup, EP)
            println("Time elapsed for writing co2 cap is")
            println(elapsed_time_co2_cap)
        end
        if setup["MinCapReq"] == 1 && has_duals(EP) == 1 &&
           output_settings_d["WriteMinCapReq"]
            elapsed_time_min_cap_req = @elapsed write_minimum_capacity_requirement(path,
                inputs,
                setup,
                EP)
            println("Time elapsed for writing minimum capacity requirement is")
            println(elapsed_time_min_cap_req)
        end

        if setup["MaxCapReq"] == 1 && has_duals(EP) == 1 &&
           output_settings_d["WriteMaxCapReq"]
            elapsed_time_max_cap_req = @elapsed write_maximum_capacity_requirement(path,
                inputs,
                setup,
                EP)
            println("Time elapsed for writing maximum capacity requirement is")
            println(elapsed_time_max_cap_req)
        end

        if setup["HydrogenMinimumProduction"] == 1 && has_duals(EP)
            if output_settings_d["WriteHydrogenPrices"]
                elapsed_time_hydrogen_prices = @elapsed write_hydrogen_prices(path,
                    inputs,
                    setup,
                    EP)
                println("Time elapsed for writing hydrogen prices is")
                println(elapsed_time_hydrogen_prices)
            end
            if setup["HourlyMatching"] == 1 &&
               output_settings_d["WriteHourlyMatchingPrices"]
                elapsed_time_hourly_matching_prices = @elapsed write_hourly_matching_prices(
                    path,
                    inputs,
                    setup,
                    EP)
                println("Time elapsed for writing hourly matching prices is")
                println(elapsed_time_hourly_matching_prices)
            end
        end

        if output_settings_d["WriteNetRevenue"]
            elapsed_time_net_rev = @elapsed write_net_revenue(path,
                inputs,
                setup,
                EP,
                dfCap,
                dfESRRev,
                dfResRevenue,
                dfChargingcost,
                dfPower,
                dfEnergyRevenue,
                dfSubRevenue,
                dfRegSubRevenue,
                dfVreStor,
                dfOpRegRevenue,
                dfOpRsvRevenue)
            println("Time elapsed for writing net revenue is")
            println(elapsed_time_net_rev)
        end
    end
    ## Print confirmation
    println("Wrote outputs to $path")

    return path
end # END output()

"""
	write_annual(fullpath::AbstractString, dfOut::DataFrame)

Internal function for writing annual outputs. 
"""
function write_annual(fullpath::AbstractString, dfOut::DataFrame)
    push!(dfOut, ["Total" 0 sum(dfOut[!, :AnnualSum], init = 0.0)])
    CSV.write(fullpath, dfOut)
    return nothing
end

"""
	write_fulltimeseries(fullpath::AbstractString, dataOut::Matrix{Float64}, dfOut::DataFrame)

Internal function for writing full time series outputs. This function wraps the instructions for creating the full time series output files. 
"""
function write_fulltimeseries(fullpath::AbstractString,
        dataOut::Matrix{Float64},
        dfOut::DataFrame)
    T = size(dataOut, 2)
    dfOut = hcat(dfOut, DataFrame(dataOut, :auto))
    auxNew_Names = [Symbol("Resource");
                    Symbol("Zone");
                    Symbol("AnnualSum");
                    [Symbol("t$t") for t in 1:T]]
    rename!(dfOut, auxNew_Names)
    total = DataFrame(
        ["Total" 0 sum(dfOut[!, :AnnualSum], init = 0.0) fill(0.0, (1, T))], auxNew_Names)
    total[!, 4:(T + 3)] .= sum(dataOut, dims = 1, init = 0.0)
    dfOut = vcat(dfOut, total)

    CSV.write(fullpath, dftranspose(dfOut, false), writeheader = false)
    return dfOut
end

"""
    write_settings_file(path, setup)

Internal function for writing settings files
"""
function write_settings_file(path, setup)
    YAML.write_file(joinpath(path, "run_settings.yml"), setup)
end

"""
    write_system_env_summary(path::AbstractString)

Write a summary of the current testing environment to a YAML file. The summary 
includes information like the CPU name and architecture, number of CPU threads, 
JIT status, operating system kernel, machine name, Julia standard library path, 
Julia version and GenX version.

# Arguments
- `path::AbstractString`: The directory path where the YAML file will be written.

# Output
Writes a file named `env_summary.yml` in the specified directory.

"""
function write_system_env_summary(path::AbstractString)
    v = pkgversion(GenX)
    env_summary = Dict(
        :ARCH => getproperty(Sys, :ARCH),
        :CPU_NAME => getproperty(Sys, :CPU_NAME),
        :CPU_THREADS => getproperty(Sys, :CPU_THREADS),
        :JIT => getproperty(Sys, :JIT),
        :KERNEL => getproperty(Sys, :KERNEL),
        :MACHINE => getproperty(Sys, :MACHINE),
        :JULIA_STDLIB => getproperty(Sys, :STDLIB),
        :JULIA_VERSION => VERSION,
        :GENX_VERSION => v
    )

    YAML.write_file(joinpath(path, "system_summary.yml"), env_summary)
end

# used by ucommit. Could be used by more functions as well.
function _create_annualsum_df(inputs::Dict, set::Vector{Int64}, data::Matrix{Float64})
    resources = inputs["RESOURCE_NAMES"][set]
    zones = inputs["R_ZONES"][set]
    weight = inputs["omega"]
    df_annual = DataFrame(Resource = resources, Zone = zones)
    df_annual.AnnualSum = data * weight
    return df_annual
end

function write_temporal_data(
        df_annual, data, path::AbstractString, setup::Dict, filename::AbstractString)
    filepath = joinpath(path, filename * ".csv")
    if setup["WriteOutputs"] == "annual"
        # df_annual is expected to have an AnnualSum column.
        write_annual(filepath, df_annual)
    else # setup["WriteOutputs"] == "full"
        df_full = write_fulltimeseries(filepath, data, df_annual)
        if setup["OutputFullTimeSeries"] == 1 && setup["TimeDomainReduction"] == 1
            write_full_time_series_reconstruction(path, setup, df_full, filename)
            @info("Writing Full Time Series for "*filename)
        end
    end
    return nothing
end

@doc raw"""write_full_time_series_reconstruction(path::AbstractString,
                            setup::Dict,
                            DF::DataFrame,
                            name::String)
Create a DataFrame with all 8,760 hours of the year from the reduced output.

This function calls `full_time_series_reconstruction()``, which uses Period_map.csv to create a new DataFrame with 8,760 time steps, as well as other pre-existing rows such as "Zone".
For each 52 weeks of the year, the corresponding representative week is taken from the input DataFrame and copied into the new DataFrame. Representative periods that 
represent more than one week will appear multiple times in the output. 

Note: Currently, TDR only gives the representative periods in Period_map for 52 weeks, when a (non-leap) year is 52 weeks + 24 hours. This function takes the last 24 hours of 
the time series and copies them to get up to all 8,760 hours in a year.

This function is called when output files with time series data (e.g. power.csv, emissions.csv) are created, if the setup key "OutputFullTimeSeries" is set to "1".

# Arguments
- `path` (AbstractString): Path input to the results folder
- `setup` (Dict): Case setup
- `DF` (DataFrame): DataFrame to be reconstructed
- `name` (String): Name desired for the .csv file

"""
function write_full_time_series_reconstruction(
        path::AbstractString, setup::Dict, DF::DataFrame, name::String)
    FullTimeSeriesFolder = setup["OutputFullTimeSeriesFolder"]
    output_path = joinpath(path, FullTimeSeriesFolder)
    dfOut_full = full_time_series_reconstruction(path, setup, dftranspose(DF, false))
    CSV.write(joinpath(output_path, "$name.csv"), dfOut_full, header = false)
    return nothing
end
