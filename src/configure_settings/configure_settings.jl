function configure_settings(settings_path::String)

    settings = YAML.load(open(settings_path))

    # Optional settings parameters ############################################
	#Write the model formulation as an output; 0 = active; 1 = not active
    if(!haskey(settings, "PrintModel")) settings["PrintModel"] = 0  end
    # Transmission network expansionl; 0 = not active; 1 = active systemwide
    if(!haskey(settings, "NetworkExpansion")) settings["NetworkExpansion"] = 0 end
    # Number of segments used in piecewise linear approximation of transmission losses; 1 = linear, >2 = piecewise quadratic
    if(!haskey(settings, "Trans_Loss_Segments")) settings["Trans_Loss_Segments"] = 1 end
    # Regulation (primary) and operating (secondary) reserves; 0 = not active, 1 = active systemwide
    if(!haskey(settings, "Reserves")) settings["Reserves"] = 0 end
    # Minimum qualifying renewables penetration; 0 = not active; 1 = active systemwide
    if(!haskey(settings, "EnergyShareRequirement")) settings["EnergyShareRequirement"] = 0 end
    # Number of capacity reserve margin constraints; 0 = not active; 1 = active systemwide
    if(!haskey(settings, "CapacityReserveMargin")) settings["CapacityReserveMargin"] = 0 end
    # CO2 emissions cap; 0 = not active (no CO2 emission limit); 1 = mass-based emission limit constraint; 2 = load + rate-based emission limit constraint; 3 = generation + rate-based emission limit constraint
    if(!haskey(settings, "CO2Cap")) settings["CO2Cap"] = 0 end
    # Energy Share Requirement and CO2 constraints account for energy lost; 0 = not active (DO NOT account for energy lost); 1 = active systemwide (DO account for energy lost)
    if(!haskey(settings, "StorageLosses")) settings["StorageLosses"] = 1 end
    # Activate minimum technology carveout constraints; 0 = not active; 1 = active
    if(!haskey(settings, "MinCapReq")) settings["MinCapReq"] = 0 end
    # Available solvers: Gurobi, CPLEX, CLPs
    if(!haskey(settings, "Solver")) settings["Solver"] =  "Gurobi" end
    # Turn on parameter scaling wherein load, capacity and power variables are defined in GW rather than MW. 0 = not active; 1 = active systemwide
    if(!haskey(settings, "ParameterScale")) settings["ParameterScale"] = 0 end
    # Write shadow prices of LP or relaxed MILP; 0 = not active; 1 = active  
    if(!haskey(settings, "WriteShadowPrices")) settings["WriteShadowPrices"] = 0 end
    # Unit committment of thermal power plants; 0 = not active; 1 = active using integer clestering; 2 = active using linearized clustering
    if(!haskey(settings, "UCommit")) settings["UCommit"] = 0 end
    # Sets temporal resolution of the model; 0 = single period to represent the full year, with first-last time step linked; 1 = multiple representative periods
    if(!haskey(settings, "OperationWrapping")) settings["OperationWrapping"] = 0 end
    # Inter-period energy exchange for storage technologies; 0 = not active; 1 = active systemwide
    if(!haskey(settings, "LongDurationStorage")) settings["LongDurationStorage"] = 0 end
    # Directory name where results from time domain reduction will be saved. If results already exist here, these will be used without running time domain reduction script again.
    if(!haskey(settings, "TimeDomainReductionFolder")) settings["TimeDomainReductionFolder"] = "TDR_Results"  end
    # Time domain reduce (i.e. cluster) inputs based on Load_data.csv, Generators_variability.csv, and Fuels_data.csv; 0 = not active (use input data as provided); 0 = active (cluster input data, or use data that has already been clustered)
    if(!haskey(settings, "TimeDomainReduction")) settings["TimeDomainReduction"] = 0 end
    # Modeling to generate alternatives; 0 = not active; 1 = active. Note: produces a single solution as output
    if(!haskey(settings, "ModelingToGenerateAlternatives")) settings["ModelingToGenerateAlternatives"] = 0 end
    # Slack value as a fraction of least-cost objective in budget constraint used for evaluating alternative model solutions; positive float value
    if(!haskey(settings, "ModelingtoGenerateAlternativeSlack")) settings["ModelingtoGenerateAlternativeSlack"] = 0.1 end

return settings
end