function default_settings()
    Dict{Any,Any}(
        "PrintModel" => 0,
        "NetworkExpansion" => 0,
        "Trans_Loss_Segments" => 1,
        "Reserves" => 0,
        "EnergyShareRequirement" => 0,
        "CapacityReserveMargin" => 0,
        "CO2Cap" => 0,
        "StorageLosses" => 1,
        "MinCapReq" => 0,
        "MaxCapReq" => 0,
        "Solver" => "HiGHS",
        "ParameterScale" => 0,
        "WriteShadowPrices" => 0,
        "UCommit" => 0,
        "OperationWrapping" => 0,
        "TimeDomainReduction" => 0,
        "TimeDomainReductionFolder" => "TDR_Results",
        "ModelingToGenerateAlternatives" => 0,
        "ModelingtoGenerateAlternativeSlack" => 0.1,
        "MultiStage" => 0,
        "MethodofMorris" => 0,
        "IncludeLossesInESR" => 0,
        "EnableJuMPStringNames" => false,
        "PieceWiseHeatRate" => 0,
        "CO2Capture" =>0
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

    ###### HARD-CODED COMBINATIONS OF SETTING COMBINATIONS WHICH CAUSE PROBLEMS ######

    # If OperationWrapping = 1, then TimeDomainReduction must be 1.
    # Will be fixed by removing OperationWrapping in future versions.
    if settings["OperationWrapping"] == 1 && settings["TimeDomainReduction"] == 0
        error(
            "OperationWrapping = 1, but TimeDomainReduction = 0 (is OFF).
            This combination of settings does not currently work.
            If you want to use time domain reduction, set TimeDomainReduction = 1 in the settings.
            Otherwise set OperationWrapping = 0."
        )
    end

end
