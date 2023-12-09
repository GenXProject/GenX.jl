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
        "VirtualChargeDischargeCost" => 1,  # $/MWh
        "MinCapReq" => 0,
        "MaxCapReq" => 0,
        "Solver" => "HiGHS",
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
        "HydrogenHourlyMatching" => 0,
        "EnableJuMPStringNames" => false,
        "ComputeConflicts" => 0
    )
end

function configure_settings(settings_path::String)
	println("Configuring Settings")
    settings = YAML.load(open(settings_path))

    # Optional settings parameters ############################################
    #Write the model formulation as an output; 0 = active; 1 = not active
    set_default_if_absent!(settings, "PrintModel", 0)
    # Transmission network expansionl; 0 = not active; 1 = active systemwide
    set_default_if_absent!(settings, "NetworkExpansion", 0)
    # Number of segments used in piecewise linear approximation of transmission losses; 1 = linear, >2 = piecewise quadratic
    set_default_if_absent!(settings, "Trans_Loss_Segments", 1)
    # Regulation (primary) and operating (secondary) reserves; 0 = not active, 1 = active systemwide
    set_default_if_absent!(settings, "Reserves", 0)
    # Minimum qualifying renewables penetration; 0 = not active; 1 = active systemwide
    set_default_if_absent!(settings, "EnergyShareRequirement", 0)
    # Number of capacity reserve margin constraints; 0 = not active; 1 = active systemwide
    set_default_if_absent!(settings, "CapacityReserveMargin", 0)
    # CO2 emissions cap; 0 = not active (no CO2 emission limit); 1 = mass-based emission limit constraint; 2 = load + rate-based emission limit constraint; 3 = generation + rate-based emission limit constraint
    set_default_if_absent!(settings, "CO2Cap", 0)
    # Energy Share Requirement and CO2 constraints account for energy lost; 0 = not active (DO NOT account for energy lost); 1 = active systemwide (DO account for energy lost)
    set_default_if_absent!(settings, "StorageLosses", 1)
    # Activate minimum technology carveout constraints; 0 = not active; 1 = active
    set_default_if_absent!(settings, "MinCapReq", 0)
    # Available solvers: Gurobi, CPLEX, CLPs
    set_default_if_absent!(settings, "Solver", "HiGHS")
    # Turn on parameter scaling wherein load, capacity and power variables are defined in GW rather than MW. 0 = not active; 1 = active systemwide
    set_default_if_absent!(settings, "ParameterScale", 0)
    # Write shadow prices of LP or relaxed MILP; 0 = not active; 1 = active
    set_default_if_absent!(settings, "WriteShadowPrices", 0)
    # Unit committment of thermal power plants; 0 = not active; 1 = active using integer clestering; 2 = active using linearized clustering
    set_default_if_absent!(settings, "UCommit", 0)
    # Sets temporal resolution of the model; 0 = single period to represent the full year, with first-last time step linked; 1 = multiple representative periods
    set_default_if_absent!(settings, "OperationWrapping", 0)
    # Directory name where results from time domain reduction will be saved. If results already exist here, these will be used without running time domain reduction script again.
    set_default_if_absent!(settings, "TimeDomainReductionFolder", "TDR_Results")
    # Time domain reduce (i.e. cluster) inputs based on Load_data.csv, Generators_variability.csv, and Fuels_data.csv; 0 = not active (use input data as provided); 0 = active (cluster input data, or use data that has already been clustered)
    set_default_if_absent!(settings, "TimeDomainReduction", 0)
    # Modeling to generate alternatives; 0 = not active; 1 = active. Note: produces a single solution as output
    set_default_if_absent!(settings, "ModelingToGenerateAlternatives", 0)
    # Slack value as a fraction of least-cost objective in budget constraint used for evaluating alternative model solutions; positive float value
    set_default_if_absent!(settings, "ModelingtoGenerateAlternativeSlack", 0.1)
    # Multistage expansion; 0 = Single-stage GenX; 1 = Multi-stage GenX
    set_default_if_absent!(settings, "MultiStage", 0)


return settings
end

function validate_settings!(settings::Dict{Any,Any})
    # Check for any settings combinations that are not allowed.
    # If we find any then make a response and issue a note to the user.

    if "OperationWrapping" in keys(settings)
        @warn """The behavior of the TimeDomainReduction and OperationWrapping
        settings have changed recently. OperationWrapping has been removed,
        and is ignored. The relevant behavior is now controlled by TimeDomainReduction.
        Please see the Methods page in the documentation."""
    end

    if settings["EnableJuMPStringNames"]==0 && settings["ComputeConflicts"]==1
        settings["EnableJuMPStringNames"]=1;
    end

end
