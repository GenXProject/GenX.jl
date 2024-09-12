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
            elapsed_time_time_weights = @elapsed write_time_weights(path, inputs, setup)
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
function write_annual(fullpath::AbstractString, dfOut::DataFrame, setup::Dict)
    push!(dfOut, ["Total" 0 sum(dfOut[!, :AnnualSum], init = 0.0)])
    write_output_file(fullpath, dfOut, filetype = setup["ResultsFileType"], compression = setup["ResultsCompressionType"])
    return nothing
end

"""
	write_fulltimeseries(fullpath::AbstractString, dataOut::Matrix{Float64}, dfOut::DataFrame, setup::Dict)

Internal function for writing full time series outputs. This function wraps the instructions for creating the full time series output files. 
"""
function write_fulltimeseries(fullpath::AbstractString,
        dataOut::Matrix{Float64},
        dfOut::DataFrame,
        setup::Dict)
    T = size(dataOut, 2)
    dfOut = hcat(dfOut, DataFrame(dataOut, :auto))
    auxNew_Names = [Symbol("Resource");
                    Symbol("Zone");
                    Symbol("AnnualSum");
                    [Symbol("t$t") for t in 1:T]]
    rename!(dfOut, auxNew_Names)
    total = DataFrame(
        ["Total" missing sum(dfOut[!, :AnnualSum], init = 0.0) fill(0.0, (1, T))], auxNew_Names)
    total[!, 4:(T + 3)] .= sum(dataOut, dims = 1, init = 0.0)
    dfOut = vcat(dfOut, total)
    dfOut = dftranspose(dfOut, true)
    write_output_file(fullpath, dfOut, 
            filetype = setup["ResultsFileType"], 
            compression = setup["ResultsCompressionType"])
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
    filepath = joinpath(path, filename)
    if setup["WriteOutputs"] == "annual"
        # df_annual is expected to have an AnnualSum column.
        write_annual(filepath, df_annual, setup)
    else # setup["WriteOutputs"] == "full"
        df_full = write_fulltimeseries(filepath, data, df_annual, setup)
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

This function calls `full_time_series_reconstruction()``, which uses the file `Period_map`` to create a new DataFrame with 8,760 time steps, as well as other pre-existing rows such as "Zone".
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
    dfOut_full = full_time_series_reconstruction(path, setup, DF)
    write_output_file(joinpath(output_path, "$name"), 
            dfOut_full, 
            filetype = setup["ResultsFileType"],
            compression = setup["ResultsCompressionType"])
    return nothing
end

@doc raw"""write_output_file(path::String,
            file::DataFrame;
            filetype::String = "auto_detect",
            compression::String = "auto_detect")
    This internal function takes a dataframe and saves it according to the type specified in `ResultsFileType` in `genx_settings.yml`. Acceptable file types are .csv, .json, and .parqet.
    It also has the option to compress files according to the compression type specified in `ResultsCompressionType` in `genx_settings.yml`. Acceptable compression types are gzip for CSV and JSON files,
    and snappy and zstd for parquet files. It compresses and saves the files using DuckDB.

    This function has the ability to automatically detect the correct file extension from the file name, if one exists, by setting `ResultsFileType = "auto_detect"`. If a filename has an extension that clashes with the extension provided in 
    `ResultsFileType`, the extension already present in the name is used. For example, if a file is called "capacity.csv" in `results_settings.yml`, but `ResultsFileType = ".parquet"`, the file will be saved as a CSV.
    If no extension is present, and `ResultsFileType` is set to `auto_detect`, then .csv is automatically used.

    Compression type can also be automatically detected by setting `ResultsCompressionType = "auto_detect"`. This will automatically detect if `.gz` is present in the filename for CSV and JSON files,
    and for parquet files will automatically detect if "-snappy" or "-zstd" is present in the file name. If `auto_detect` is on, but no compression is present, the files will be saved uncompressed.
    If a file extension contains `.gz`, but `ResultsCompressionType = "none"`, the file will still be compressed as a gzip. 

    The keyword arguments `filetype` and `compression` are optional and are both set to `auto_detect` by default.

    # Arguments
    - `path::AbstractString`: The path including the file name. This can include the file extension (e.g. .csv) but does not have to.
    - `file::DataFrame`: The DataFrame being saved to the input path. All columns in the DataFrame must have a type (cannot be type "Any") in order for DuckDB to work.
    - `filetype::String`: The file type, as specified in `ResultsFileType` in `genx_settings.yml`. Accepted inputs are `.csv`,`.csv.gz` `.parquet`, `.json`, `.json.gz`, and `auto_detect` (default).
    - `compression::String`: The compression type, as specified in `ResultsCompressionType` in `genx_settings.yml`. Accepted inputs are `gzip`, `snappy`, `zstd`, `none`, and `auto_detect` (default). 
"""
function write_output_file(path::AbstractString, file::DataFrame; filetype::String = "auto_detect", compression::String = "auto_detect")
    # 1) Check if an extension is already in the file name, if not, add it based on filetype
    if occursin(".", path)
        if occursin(".", splitext(path)[1]) # If two extensions are present (eg .csv.gz, or .json.gz, only the first will be added to the filetype as .gz will be autodetected by DuckDB later)
            if filetype == "auto_detect" # If auto-detect is on for the extension type, change the filetype to the extension detected using splitext
                filetype = splitext(splitext(path)[1])[2]
            elseif filetype != splitext(splitext(path)[1])[2] # If the extension in the file name is different than the filetype key, override the filetype key and throw a warning.
                filetype = splitext(splitext(path)[1])[2]
                @warn("File extension conflicts with filetype in genx_settings.yml. Saving file as $filetype")
            end
        else
            if filetype == "auto_detect"  # If auto-detect is on for the extension type, change the filetype to the extension detected using splitext
                filetype = splitext(path)[2]
            elseif filetype != splitext(path)[2] # If the extension in the file name is different than the filetype key, override the filetype key and throw a warning.
                filetype = splitext(path)[2]
                @warn("File extension conflicts with filetype in genx_settings.yml. Saving file as $filetype")
            end
            if splitext(path)[2] == ".csv" && isgzip(compression)
                path = path * ".gz" # If the file only ends in ".csv", but compression is set to gzip, add ".gz" to the end of the file
            elseif splitext(path)[2] == ".json" && isgzip(compression)
                path *= ".gz"
            end
        end  
    elseif filetype == "auto_detect" # If no extension is detected in the file name, but auto-detect is on, .csv will automatically be added
        filetype = ".csv"
        path *= ".csv"
    elseif filetype == ".csv" # If no extension is present, but filetype is set to .csv, .csv will be appended to the path name.
       if compression == "none" 
            path *= ".csv"
       elseif isgzip(compression) # If no extension is present, and compression is set to gzip, add .gz to the end of the file name.
            path *= ".csv.gz"
       elseif compression == "auto_detect" # If no extension is present, but compression is set to auto_detect, no compression is added
            path *= ".csv"
       else
            @warn("Compression type '$compression' not supported with .csv. Saving as uncompressed csv.")
            path *= ".csv"
       end
    elseif filetype == ".json" # If no extension is present, but filetype is set to .csv, .csv will be appended to the path name
        if compression == "none"
            path *= ".json"
        elseif isgzip(compression)
            path *= ".json.gz"
        elseif compression == "auto_detect"
            path *= ".json"
        else
            @warn("Compression type '$compression' not supported with .json. Saving as uncompressed json.")
            path *= ".json"
        end
    elseif filetype == ".parquet"
        if compression == "none"
            path *= ".parquet"
        elseif compression == "snappy" || compression == "-snappy"
            path *= "-snappy.parqet"
        elseif compression == "zstd" || compression == "-zstd"
            path *= "-zstd.parquet"
        elseif compression == "auto_detect"
            path *= ".parquet"
        else
            @warn("Compression type '$compression' not supported with .parquet. Saving as uncompressed parquet.")
            path *= ".parquet"
        end
    else
        @error "Filetype '$filetype' not accepted. Accepted formats are .csv, .gz, .parquet, and .json."
    end

    # 2) Save file according to compression type: auto_detect, gzip, snappy, zstd, or none
    if compression == "auto_detect"
        if filetype == ".csv" || filetype == ".csv.gz"
            save_with_duckdb(file,path,"csv","none") # DuckDB will automatically detect if the file should be compressed or not
        elseif filetype == ".parquet"
            if occursin("-", path) # Parquet files can be saved with compression types in the name e.g. "capacity-snappy.parquet"
                filename = splitext(path)[1]
                compression_type = filename[findlast('-', filename):end]
                if compression_type == "-snappy"
                    save_with_duckdb(file,path,"parquet","snappy")
                elseif compression_type == "-zstd"
                    save_with_duckdb(file,path,"parquet","zstd")
                elseif compression_type == "-uncompressed"
                    save_with_duckdb(file,path,"parquet","uncompressed")
                else
                    @warn "Unable to auto-detect compression type of parquet file. Saving as uncompressed parquet."
                    save_with_duckdb(file,path,"parquet","uncompressed")
                end
            else
                save_with_duckdb(file,path,"parquet","uncompressed") # If no "-" is present, file is saved uncompressed.
            end
        elseif filetype == ".json"
            save_with_duckdb(file,path,"json","none")
        else
            @error "Filetype '$filetype' not accepted. Accepted formats are .csv, .parquet, and .json."
        end        
    elseif isgzip(compression)
        if filetype == ".csv"
            if splitext(path)[2] == ".gz"
                save_with_duckdb(file,path,"csv","gzip")
            else
                path *= ".gz"
                save_with_duckdb(file,path,"csv","gzip")
            end
        elseif filetype == ".json"
            if splitext(path)[2] == ".gz"
                save_with_duckdb(file,path,"json","auto_detect")
            else
                path *= ".gz"
                save_with_duckdb(file,path,"json","auto_detect")
            end
        elseif filetype == ".parquet"
            @warn(".parquet cannot be compressed as gzip. Saving as uncompressed parquet")
            save_with_duckdb(file,path,"parquet","uncompressed")
        else
            @error("Filetype '$filetype' not accepted. Accepted formats are .csv, .csv.gz, .parquet, .json, and .json.gz.")
        end
    elseif compression == "snappy" || compression == "-snappy"
        if filetype == ".parquet"
            save_with_duckdb(file,path,"parquet","snappy")
        elseif filetype == ".csv"
            @warn("Filetype .csv cannot be saved with snappy compression. Saving as uncompressed csv.")
            save_with_duckdb(file,path,"csv","none")
        elseif filetype == ".json"
            @warn("Filetype .json cannot be saved with snappy compression. Saving as uncompressed json.")
            save_with_duckdb(file,path,"json","auto_detect")
        end
    elseif compression == "zstd" || compression == "-zstd"
        if filetype == ".parquet"
            save_with_duckdb(file,path,"parquet","zstd")
        elseif filetype == ".csv"
            @warn("Filetype .csv cannot be saved with zstd compression. Saving as uncompressed csv.")
            save_with_duckdb(file,path,"csv","none")
        elseif filetype == ".json"
            save_with_duckdb(file,path,"json","zstd")
        else
            @error "Filetype '$filetype' not accepted. Accepted formats are .csv, .csv.gz, .parquet, .json, and .json.gz."
        end
    else
        if compression != "none"
            @warn("Compression type '$compression' is not accepted. Saving without file compression.")
        end
        if filetype == ".csv" 
            save_with_duckdb(file,path,"csv","none")
        elseif filetype == "csv.gz" # If compression type is listed as none, but filetype has .gz in it, compression type is overridden and .gz is used.
            @warn("Gzip compression detected in file name. Saving with gzip compression.")
            save_with_duckdb(file,path,"csv","gzip")
        elseif filetype == ".parquet"
            save_with_duckdb(file,path,"parquet","uncompressed")
        elseif filetype == ".json"
            save_with_duckdb(file,path,"json","none")
        elseif filetype == ".json.gz"
            @warn("Gzip compression detected in file name. Saving with gzip compression.")
            save_with_duckdb(file,path,"json","gzip")
        else
            @error "Filetype '$filetype' not accepted. Accepted formats are .csv, .csv.gz, .parquet, .json, and .json.gz."
        end
    end
end

@doc raw"""isgzip(compression::String)
    This internal function determines if the compression is of type gzip. It's purporse is to prevent a misspelling of gzip, since you can write "gz" or "gzip".

    # Arguments
    - `compression::String`: - compression type, from the genxsettings YAML file or default dictionary
    
    # Output
    - `true` or `false` if the file has a compression type of gzip.
"""
function isgzip(compression::String)
    if compression == "gzip" || compression == ".gz" || compression == "gz" || compression == ".gzip"
        return true
    end
    return false
end

@doc raw"""save_with_duckdb(compression::String)
    This internal function saves a DataFrame using the package DuckDB.

    # Arguments
    - `file::DataFrame`: Dataframe of information to be saved
    - `path::AbstractString`: path of the directory to save the file in
    - `filetype::String`: file type, from the genxsettings YAML file or default dictionary. Can be `csv`, `json`, or `parquet`
    - `compression::String`: - compression type, from the genxsettings YAML file or default dictionary. Can be `gzip`, `snappy`, `zstd`, `none`, or `uncompressed`.
"""
function save_with_duckdb(file::DataFrame,path::AbstractString,filetype::String,compression::String)
    con = DBInterface.connect(DuckDB.DB)
    DuckDB.register_data_frame(con, file, "temp_df")
    if filetype == "csv"
        DBInterface.execute(con, "COPY temp_df TO '$path'") # DuckDB will auto detect the prescence of gzip
    elseif filetype == "parquet"
        DBInterface.execute(con, "COPY temp_df TO '$path' (FORMAT 'parquet', CODEC '$compression');")
    elseif filetype == "json"
        if compression == "auto_detect"
            DBInterface.execute(con, "COPY temp_df TO '$path' (FORMAT JSON, AUTO_DETECT true);")
        else
            DBInterface.execute(con, "COPY temp_df TO '$path' (FORMAT JSON, COMPRESSION '$compression');")
        end
    end
    DBInterface.close(con)
end