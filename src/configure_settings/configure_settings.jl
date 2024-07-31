function default_settings()
    Dict{Any, Any}("PrintModel" => 0,
        "OverwriteResults" => 0,
        "NetworkExpansion" => 0,
        "Trans_Loss_Segments" => 1,
        "OperationalReserves" => 0,
        "EnergyShareRequirement" => 0,
        "CapacityReserveMargin" => 0,
        "CO2Cap" => 0,
        "StorageLosses" => 1,
        "LDSAdditionalConstraints" => 1,
        "VirtualChargeDischargeCost" => 1,  # $/MWh
        "MinCapReq" => 0,
        "MaxCapReq" => 0,
        "ParameterScale" => 0,
        "WriteShadowPrices" => 0,
        "UCommit" => 0,
        "TimeDomainReduction" => 0,
        "TimeDomainReductionFolder" => "TDR_results",
        "OutputFullTimeSeries" => 0,
        "OutputFullTimeSeriesFolder" => "Full_TimeSeries",
        "ModelingToGenerateAlternatives" => 0,
        "ModelingtoGenerateAlternativeSlack" => 0.1,
        "MGAAnnualGeneration" => 0,
        "MultiStage" => 0,
        "MethodofMorris" => 0,
        "IncludeLossesInESR" => 0,
        "HydrogenMinimumProduction" => 0,
        "EnableJuMPStringNames" => false,
        "HourlyMatching" => 0,
        "HydrogenHourlyMatching" => 0,
        "DC_OPF" => 0,
        "WriteOutputs" => "full",
        "ComputeConflicts" => 0,
        "StorageVirtualDischarge" => 1,
        "ResourcesFolder" => "resources",
        "ResourcePoliciesFolder" => "policy_assignments",
        "SystemFolder" => "system",
        "PoliciesFolder" => "policies",
        "ObjScale" => 1,
        "ResultsFileType" => "auto_detect",
        "ResultsCompressionType" => "auto_detect")
end

@doc raw"""
    configure_settings(settings_path::String, output_settings_path::String, case::AbstractString)

Reads in the settings from the `genx_settings.yml`, `output_settings.yml`, `input_settings.yml`, and `results_settings.yml` YAML files and
merges them with the default settings. It then validates the settings and returns the
settings dictionary.

# Arguments
- `settings_path::String`: The path to the settings YAML file.
- `output_settings_path::String`: The path to the output settings YAML file.
- `case::AbstractString`: The case used for this instance of GenX.

# Returns
- `settings::Dict`: The settings dictionary.
"""
function configure_settings(settings_path::String, output_settings_path::String, case::AbstractString)
    println("\nConfiguring Settings")
    model_settings = YAML.load(open(settings_path))

    settings = default_settings()
    merge!(settings, model_settings)

    output_settings = configure_writeoutput(output_settings_path, settings)
    settings["WriteOutputsSettingsDict"] = output_settings

    input_settings = configure_input_names(case)
    settings["WriteInputNamesDict"] = input_settings

    results_settings = configure_results_names(case)
    settings["WriteResultsNamesDict"] = results_settings

    validate_settings!(settings)
    return settings
end

function validate_settings!(settings::Dict{Any, Any})
    # Check for any settings combinations that are not allowed.
    # If we find any then make a response and issue a note to the user.

    # make WriteOutputs setting lowercase and check for valid value
    settings["WriteOutputs"] = lowercase(settings["WriteOutputs"])
    @assert settings["WriteOutputs"] ∈ ["annual", "full"]

    if "OperationWrapping" in keys(settings)
        @warn """The behavior of the TimeDomainReduction and OperationWrapping
        settings have changed recently. OperationWrapping has been removed,
        and is ignored. The relevant behavior is now controlled by TimeDomainReduction.
        Please see the Methods page in the documentation.""" maxlog=1
    end

    if haskey(settings, "Reserves")
        Base.depwarn("""The Reserves setting has been deprecated. Please use the
        OperationalReserves setting instead.""",
            :validate_settings!, force = true)
        settings["OperationalReserves"] = settings["Reserves"]
        delete!(settings, "Reserves")
    end

    if settings["EnableJuMPStringNames"] == 0 && settings["ComputeConflicts"] == 1
        settings["EnableJuMPStringNames"] = 1
    end
end

function default_writeoutput()
    Dict{String, Bool}("WriteCosts" => true,
        "WriteCapacity" => true,
        "WriteCapacityValue" => true,
        "WriteCapacityFactor" => true,
        "WriteCharge" => true,
        "WriteChargingCost" => true,
        "WriteCO2" => true,
        "WriteCO2Cap" => true,
        "WriteCommit" => true,
        "WriteCurtailment" => true,
        "WriteEmissions" => true,
        "WriteEnergyRevenue" => true,
        "WriteESRPrices" => true,
        "WriteESRRevenue" => true,
        "WriteFuelConsumption" => true,
        "WriteFusion" => true,
        "WriteHourlyMatchingPrices" => true,
        "WriteHydrogenPrices" => true,
        "WriteMaintenance" => true,
        "WriteMaxCapReq" => true,
        "WriteMinCapReq" => true,
        "WriteNetRevenue" => true,
        "WriteNSE" => true,
        "WriteNWExpansion" => true,
        "WriteOpWrapLDSdStor" => true,
        "WriteOpWrapLDSStorInit" => true,
        "WritePower" => true,
        "WritePowerBalance" => true,
        "WritePrice" => true,
        "WriteReg" => true,
        "WriteReliability" => true,
        "WriteReserveMargin" => true,
        "WriteReserveMarginRevenue" => true,
        "WriteReserveMarginSlack" => true,
        "WriteReserveMarginWithWeights" => true,
        "WriteRsv" => true,
        "WriteShutdown" => true,
        "WriteStart" => true,
        "WriteStatus" => true,
        "WriteStorage" => true,
        "WriteStorageDual" => true,
        "WriteSubsidyRevenue" => true,
        "WriteTimeWeights" => true,
        "WriteTransmissionFlows" => true,
        "WriteTransmissionLosses" => true,
        "WriteVirtualDischarge" => true,
        "WriteVREStor" => true,
        "WriteAngles" => true)
end

function configure_writeoutput(output_settings_path::String, settings::Dict)
    writeoutput = default_writeoutput()

    # don't write files with hourly data if settings["WriteOutputs"] == "annual"
    if settings["WriteOutputs"] == "annual"
        writeoutput["WritePrice"] = false
        writeoutput["WriteReliability"] = false
        writeoutput["WriteStorage"] = false
        writeoutput["WriteStorageDual"] = false
        writeoutput["WriteTimeWeights"] = false
        writeoutput["WriteCapacityValue"] = false
        writeoutput["WriteReserveMargin"] = false
        writeoutput["WriteReserveMarginWithWeights"] = false
        writeoutput["WriteAngles"] = false
        writeoutput["WriteTransmissionFlows"] = false
    end

    # read in YAML file if provided
    if isfile(output_settings_path)
        model_writeoutput = YAML.load(open(output_settings_path))
        merge!(writeoutput, model_writeoutput)
    end
    return writeoutput
end

function default_settings_multistage()
    Dict{Any, Any}("NumStages" => 3,
        "StageLengths" => [10, 10, 10],
        "WACC" => 0.045,
        "ConvergenceTolerance" => 0.01,
        "Myopic" => 1,
        "WriteIntermittentOutputs" => 0)
end

@doc raw"""
    configure_settings_multistage(settings_path::String)

Reads in the settings from the `multi_stage_settings.yml` YAML file and
merges them with the default multistage settings. It then returns the
settings dictionary.

# Arguments
- `settings_path::String`: The path to the multistage settings YAML file.

# Returns
- `settings::Dict`: The multistage settings dictionary.
"""
function configure_settings_multistage(settings_path::String)
    println("Configuring Multistage Settings")
    model_settings = isfile(settings_path) ? YAML.load(open(settings_path)) : Dict{Any, Any}()

    settings = default_settings_multistage()
    merge!(settings, model_settings)

    validate_multistage_settings!(settings)
    return settings
end

function validate_multistage_settings!(settings::Dict{Any, Any})
    # Check for any settings combinations that are not allowed.
    # If we find any then make a response and issue a note to the user.

    if settings["Myopic"] == 0 && settings["WriteIntermittentOutputs"] == 1
        msg = "WriteIntermittentOutputs is not supported for non-myopic multistage models." *
              " Setting WriteIntermittentOutputs to 0 in the multistage settings."
        @warn msg
        settings["WriteIntermittentOutputs"] = 0
    end
end

function default_input_names(case::AbstractString)
    Dict{Any, Any}("system_location" => joinpath(case, "system"),
    "demand_name" => "Demand_data.csv",
    "fuel_name" => "Fuels_data.csv",
    "generators_name" => "Generators_variability.csv",
    "network_name" => "Network.csv",
    "resources_location" => joinpath(case, "resources"),
    "storage_name" => "Storage.csv",
    "thermal_name" => "Thermal.csv",
    "vre_name" => "Vre.csv",
    "vre_stor_name" => "Vre_stor.csv",
    "vre_stor_solar_name" => "Vre_and_stor_solar_variability.csv",
    "vre_stor_wind_name" => "Vre_and_stor_wind_variability.csv",
    "hydro_name" => "Hydro.csv",
    "flex_demand_name" => "Flex_demand.csv",
    "must_run_name" => "Must_run.csv",
    "electrolyzer_name" => "Electrolyzer.csv",
    "resource_cap_name" => "Resource_capacity_reserve_margin.csv",
    "resource_energy_share_requirement" => "Resource_energy_share_requirement.csv",
    "resource_min_name" => "Resource_minimum_capacity_requirement.csv",
    "resource_max_name" => "Resource_maximum_capacity_requirement.csv",
    "policies_location" => joinpath(case, "policies"),
    "capacity_name" => "Capacity_reserve_margin.csv",
    "CRM_slack_name" => "Capacity_reserve_margin_slack.csv",
    "co2_cap_name" => "CO2_cap.csv",
    "co2_cap_slack_name" => "CO2_cap_slack.csv",
    "esr_name" => "Energy_share_requirement.csv",
    "esr_slack_name" => "Energy_share_requirement_slack.csv",
    "min_cap_name" => "Minimum_capacity_requirement.csv",
    "max_cap_name" => "Maximum_capacity_requirement.csv",
    "operational_reserves_name" => "Operational_reserves.csv")
end

@doc raw"""
    configure_input_names(case::AbstractString)

Reads in the settings from the `input_settings.yml` YAML file and
merges them with the default input settings. It then returns the
settings dictionary.

# Arguments
- `case::AbstractString`: The case containing the settings file.

# Returns
- `names::Dict`: The input names dictionary.
"""
function configure_input_names(case::AbstractString)
    println("Configuring Input File and Path Names")
    input_settings_path = get_settings_path(case, "input_settings.yml")
    input_names = YAML.load(open(input_settings_path))
    input_names = isfile(input_settings_path) ? YAML.load(open(input_settings_path)) : Dict{Any, Any}()

    names = default_input_names(case)
    merge!(names,input_names)

    return names
end

function default_results_names()
   Dict{Any, Any}("capacity_name" => "capacity",
    "capacity_factor_name" => "capacityfactor",
    "captured_emissions_plant_name" => "captured_emissions_plant",
    "charge_name" => "charge.csv",
    "charging_cost_name" => "ChargingCost",
    "co2_prices_name" => "CO2_prices_and_penalties",
    "commit_name" => "commit",
    "costs_name" => "costs",
    "curtail_name" => "curtail",
    "emissions_plant_name" => "emissions_plant",
    "emissions_name" => "emissions",
    "energy_revenue_name" => "EnergyRevenue",
    "flow_name" => "flow",
    "fuel_cost_plant_name" => "Fuel_cost_plant",
    "fuel_consumption_plant_name" => "FuelConsumption_plant_MMBTU",
    "fuel_consumption_total_name" => "FuelConsumtion_total_MMBTU",
    "mincap_name" => "MinCapReq_prices_and_penalties",
    "revenue_name" => "NetRevenue",
    "network_expansion_name" => "network_expansion",
    "nse_name" => "nse",
    "power_balance_name" => "power_balance",
    "power_name" => "power",
    "prices_name" => "prices",
    "reg_subsidy_revenue_name" => "RegSubsidyRevenue",
    "reg_name" => "reg",
    "reg_dn_name" => "reg_dn",
    "reliability_name" => "reliability",
    "shutdown_name" => "shutdown",
    "start_name" => "start",
    "status_name" => "status",
    "storage_name" => "storage",
    "subsidy_revenue_name" => "SubsidyRevenue",
    "time_weights_name" => "time_weights",
    "tlosses_name" => "tlosses",
    "virtual_discharge_name" => "virtual_discharge",
    "vre_stor_dc_charge_name" => "vre_stor_dc_charge",
    "vre_stor_ac_charge_name" => "vre_stor_ac_charge",
    "vre_stor_dc_discharge_name" => "vre_stor_dc_discharge",
    "vre_stor_ac_discharge_name" => "vre_stor_ac_discharge",
    "vre_stor_wind_power_name" => "vre_stor_wind_power",
    "vre_stor_solar_power_name" => "vre_stor_solar_power")
end

@doc raw"""
    configure_results_names(case::AbstractString)

Reads in the settings from the `results_settings.yml` YAML file and
merges them with the default results settings. It then returns the
settings dictionary.

# Arguments
- `case::AbstractString`: The case containing the settings file.

# Returns
- `names::Dict`: The results names dictionary.
"""
function configure_results_names(case::AbstractString)
    println("Configuring Results File Names")
    results_settings_path = get_settings_path(case, "results_settings.yml")
    results_names = YAML.load(open(results_settings_path))
    results_names = isfile(results_settings_path) ? YAML.load(open(results_settings_path)) : Dict{Any, Any}()

    names = default_results_names()
    merge!(names,results_names)

    return names
end

