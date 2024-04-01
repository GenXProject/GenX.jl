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
        "VirtualChargeDischargeCost" => 1,  # $/MWh
        "MinCapReq" => 0,
        "MaxCapReq" => 0,
        "ParameterScale" => 0,
        "WriteShadowPrices" => 0,
        "UCommit" => 0,
        "TimeDomainReduction" => 0,
        "TimeDomainReductionFolder" => "TDR_results",
        "ModelingToGenerateAlternatives" => 0,
        "ModelingtoGenerateAlternativeSlack" => 0.1,
        "MultiStage" => 0,
        "MethodofMorris" => 0,
        "IncludeLossesInESR" => 0,
        "EnableJuMPStringNames" => false,
        "HydrogenHourlyMatching" => 0,
        "DC_OPF" => 0,
        "WriteOutputs" => "full",
        "ComputeConflicts" => 0,
        "StorageVirtualDischarge" => 1,
        "ResourcesFolder" => "resources",
        "ResourcePoliciesFolder" => "policy_assignments",
        "SystemFolder" => "system",
        "PoliciesFolder" => "policies",
        "ObjScale" => 1)
end

@doc raw"""
    configure_settings(settings_path::String, output_settings_path::String)

Reads in the settings from the `genx_settings.yml` and `output_settings.yml` YAML files and
merges them with the default settings. It then validates the settings and returns the
settings dictionary.

# Arguments
- `settings_path::String`: The path to the settings YAML file.
- `output_settings_path::String`: The path to the output settings YAML file.

# Returns
- `settings::Dict`: The settings dictionary.
"""
function configure_settings(settings_path::String, output_settings_path::String)
    println("Configuring Settings")
    model_settings = YAML.load(open(settings_path))

    settings = default_settings()
    merge!(settings, model_settings)

    output_settings = configure_writeoutput(output_settings_path, settings)
    settings["WriteOutputsSettingsDict"] = output_settings

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
        OperationalReserves setting instead.""", :validate_settings!, force = true)
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
        writeoutput["WriteCommit"] = false
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
