function default_settings()
    Dict{Any,Any}(
        "PrintModel" => 0,
        "OverwriteResults" => 0,
        "NetworkExpansion" => 0,
        "Trans_Loss_Segments" => 1,
        "Reserves" => 0,
        "EnergyShareRequirement" => 0,
        "CapacityReserveMargin" => 0,
        "CO2Cap" => 0,
        "StorageLosses" => 1,
        "MinCapReq" => 0,
        "MaxCapReq" => 0,
        "ParameterScale" => 0,
        "WriteShadowPrices" => 0,
        "UCommit" => 0,
        "TimeDomainReduction" => 0,
        "TimeDomainReductionFolder" => "TDR_Results",
        "ModelingToGenerateAlternatives" => 0,
        "ModelingtoGenerateAlternativeSlack" => 0.1,
        "MultiStage" => 0,
        "MethodofMorris" => 0,
        "IncludeLossesInESR" => 0,
        "EnableJuMPStringNames" => false,
        "HydrogenHourlyMatching" => 0,
        "DC_OPF" => 0,
    )
end

function configure_settings(settings_path::String)
    println("Configuring Settings")
    model_settings = YAML.load(open(settings_path))

    settings = default_settings()

    merge!(settings, model_settings)

    validate_settings!(settings)
    return settings
end

function validate_settings!(settings::Dict{Any,Any})
    # Check for any settings combinations that are not allowed.
    # If we find any then make a response and issue a note to the user.

    if "OperationWrapping" in keys(settings)
        @warn """The behavior of the TimeDomainReduction and OperationWrapping
        settings have changed recently. OperationWrapping has been removed,
        and is ignored. The relevant behavior is now controlled by TimeDomainReduction.
        Please see the Methods page in the documentation.""" maxlog=1
    end

end
