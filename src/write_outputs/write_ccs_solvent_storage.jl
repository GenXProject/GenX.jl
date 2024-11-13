@doc raw"""
	write_ccs_ss_capacity(path::AbstractString, inputs::Dict, setup::Dict, EP::Model))

Function for writing the diferent capacities for the CCS_SOLVENT_STORAGE technologies (starting capacities or, existing capacities, retired capacities, and new-built capacities).
"""
function write_ccs_ss_capacity(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    # Capacity decisions
    gen = inputs["RESOURCES"]
    CCS_SOLVENT_STORAGE = inputs["CCS_SOLVENT_STORAGE"] 
    COMMIT_CCS_SS = setup["UCommit"] > 1 ? CCS_SOLVENT_STORAGE : Int[]
    MultiStage = setup["MultiStage"]

    # CCS_SOLVENT_STORAGE components
    # components of ccs generators with solvent storage
    # by default, i = 1 -> gas turbine; i = 2 -> steam turbine;
    #             i = 3 -> absorber; i = 4 -> compressor; i = 5 -> regenerator;
    #             i = 6 -> rich solvent storage; i = 7 -> lean solvent storage
    gasturbine, steamturbine, absorber, compressor, regenerator, solventstorage_rich, solventstorage_lean = 1, 2, 3, 4, 5, 6, 7

    # get component-wise data
    solvent_storage_dict = inputs["solvent_storage_dict"]

    G = inputs["G"]
    capCCS_SS_gasturbine = zeros(G)
    capCCS_SS_steamturbine = zeros(G)
    capCCS_SS_absorber = zeros(G)
    capCCS_SS_compressor = zeros(G)
    capCCS_SS_regenerator = zeros(G)
    capCCS_SS_solventstorage_rich = zeros(G)
    capCCS_SS_solventstorage_lean = zeros(G)

    # new cap
    for y in CCS_SOLVENT_STORAGE
        if y in intersect(inputs["NEW_CAP"], COMMIT_CCS_SS)
            capCCS_SS_gasturbine[y] = value.(EP[:vCAP_CCS_SS])[y, gasturbine]* solvent_storage_dict[y,"cap_size"][gasturbine]
            capCCS_SS_steamturbine[y] = value.(EP[:vCAP_CCS_SS])[y, steamturbine]* solvent_storage_dict[y,"cap_size"][steamturbine]
            capCCS_SS_absorber[y] = value.(EP[:vCAP_CCS_SS])[y, absorber]* solvent_storage_dict[y,"cap_size"][absorber]
            capCCS_SS_compressor[y] = value.(EP[:vCAP_CCS_SS])[y, compressor]* solvent_storage_dict[y,"cap_size"][compressor]
            capCCS_SS_regenerator[y] = value.(EP[:vCAP_CCS_SS])[y, regenerator]* solvent_storage_dict[y,"cap_size"][regenerator]
            capCCS_SS_solventstorage_rich[y] = value.(EP[:vCAP_CCS_SS])[y, solventstorage_rich]* solvent_storage_dict[y,"cap_size"][solventstorage_rich]
            capCCS_SS_solventstorage_lean[y] = value.(EP[:vCAP_CCS_SS])[y, solventstorage_lean]* solvent_storage_dict[y,"cap_size"][solventstorage_lean]
        elseif y in inputs["NEW_CAP"]
            capCCS_SS_gasturbine[y] = value.(EP[:vCAP_CCS_SS])[y, gasturbine]
            capCCS_SS_steamturbine[y] = value.(EP[:vCAP_CCS_SS])[y, steamturbine]
            capCCS_SS_absorber[y] = value.(EP[:vCAP_CCS_SS])[y, absorber]
            capCCS_SS_compressor[y] = value.(EP[:vCAP_CCS_SS])[y, compressor]
            capCCS_SS_regenerator[y] = value.(EP[:vCAP_CCS_SS])[y, regenerator]
            capCCS_SS_solventstorage_rich[y] = value.(EP[:vCAP_CCS_SS])[y, solventstorage_rich]
            capCCS_SS_solventstorage_lean[y] = value.(EP[:vCAP_CCS_SS])[y, solventstorage_lean]
        end
    end

    # retired cap
    retcapCCS_SS_gasturbine = zeros(size(inputs["RESOURCE_NAMES"]))
    retcapCCS_SS_steamturbine = zeros(size(inputs["RESOURCE_NAMES"]))
    retcapCCS_SS_absorber = zeros(size(inputs["RESOURCE_NAMES"]))
    retcapCCS_SS_compressor = zeros(size(inputs["RESOURCE_NAMES"]))
    retcapCCS_SS_regenerator = zeros(size(inputs["RESOURCE_NAMES"]))
    retcapCCS_SS_solventstorage_rich = zeros(size(inputs["RESOURCE_NAMES"]))
    retcapCCS_SS_solventstorage_lean = zeros(size(inputs["RESOURCE_NAMES"]))

    for y in CCS_SOLVENT_STORAGE
        if y in intersect(COMMIT_CCS_SS, inputs["RET_CAP"])
            retcapCCS_SS_gasturbine[y] = value.(EP[:vRETCAP_CCS_SS])[y, gasturbine]* solvent_storage_dict[y,"cap_size"][gasturbine]
            retcapCCS_SS_steamturbine[y] = value.(EP[:vRETCAP_CCS_SS])[y, steamturbine]* solvent_storage_dict[y,"cap_size"][steamturbine]
            retcapCCS_SS_absorber[y] = value.(EP[:vRETCAP_CCS_SS])[y, absorber]* solvent_storage_dict[y,"cap_size"][absorber]
            retcapCCS_SS_compressor[y] = value.(EP[:vRETCAP_CCS_SS])[y, compressor]* solvent_storage_dict[y,"cap_size"][compressor]
            retcapCCS_SS_regenerator[y] = value.(EP[:vRETCAP_CCS_SS])[y, regenerator]* solvent_storage_dict[y,"cap_size"][regenerator]
            retcapCCS_SS_solventstorage_rich[y] = value.(EP[:vRETCAP_CCS_SS])[y, solventstorage_rich]* solvent_storage_dict[y,"cap_size"][solventstorage_rich]
            retcapCCS_SS_solventstorage_lean[y] = value.(EP[:vRETCAP_CCS_SS])[y, solventstorage_lean]* solvent_storage_dict[y,"cap_size"][solventstorage_lean]
        elseif y in inputs["RET_CAP"]
            retcapCCS_SS_gasturbine[y] = value.(EP[:vRETCAP_CCS_SS])[y, gasturbine]
            retcapCCS_SS_steamturbine[y] = value.(EP[:vRETCAP_CCS_SS])[y, steamturbine]
            retcapCCS_SS_absorber[y] = value.(EP[:vRETCAP_CCS_SS])[y, absorber]
            retcapCCS_SS_compressor[y] = value.(EP[:vRETCAP_CCS_SS])[y, compressor]
            retcapCCS_SS_regenerator[y] = value.(EP[:vRETCAP_CCS_SS])[y, regenerator]
            retcapCCS_SS_solventstorage_rich[y] = value.(EP[:vRETCAP_CCS_SS])[y, solventstorage_rich]
            retcapCCS_SS_solventstorage_lean[y] = value.(EP[:vRETCAP_CCS_SS])[y, solventstorage_lean]
        end
    end

    dfCapCCS_SS = DataFrame(Resource = gen.resource[CCS_SOLVENT_STORAGE],
        Zone = gen.zone[CCS_SOLVENT_STORAGE],
        
        StartCap_GasTrubine_MW = MultiStage == 1 ? value.(EP[:vEXISTINGCAP_CCS_SS]) : [solvent_storage_dict[y, "existing_cap"][gasturbine] for y in CCS_SOLVENT_STORAGE],
        StartCap_SteamTrubine_MW = MultiStage == 1 ? value.(EP[:vEXISTINGCAP_CCS_SS]) : [solvent_storage_dict[y, "existing_cap"][steamturbine] for y in CCS_SOLVENT_STORAGE],
        StartCap_Absorber_t = MultiStage == 1 ? value.(EP[:vEXISTINGCAP_CCS_SS]) : [solvent_storage_dict[y, "existing_cap"][absorber] for y in CCS_SOLVENT_STORAGE],
        StartCap_Compressor_MW = MultiStage == 1 ? value.(EP[:vEXISTINGCAP_CCS_SS]) : [solvent_storage_dict[y, "existing_cap"][compressor] for y in CCS_SOLVENT_STORAGE],
        StartCap_Regenerator_t = MultiStage == 1 ? value.(EP[:vEXISTINGCAP_CCS_SS]) : [solvent_storage_dict[y, "existing_cap"][regenerator] for y in CCS_SOLVENT_STORAGE],
        StartCap_SolventStorageRich_t = MultiStage == 1 ? value.(EP[:vEXISTINGCAP_CCS_SS]) : [solvent_storage_dict[y, "existing_cap"][solventstorage_rich] for y in CCS_SOLVENT_STORAGE],
        StartCap_SolventStorageLean_t = MultiStage == 1 ? value.(EP[:vEXISTINGCAP_CCS_SS]) : [solvent_storage_dict[y, "existing_cap"][solventstorage_lean] for y in CCS_SOLVENT_STORAGE],
        
        NewCap_GasTrubine_MW = capCCS_SS_gasturbine[CCS_SOLVENT_STORAGE],
        NewCap_SteamTrubine_MW = capCCS_SS_steamturbine[CCS_SOLVENT_STORAGE],
        NewCap_Absorber_t = capCCS_SS_absorber[CCS_SOLVENT_STORAGE],
        NewCap_Compressor_MW = capCCS_SS_compressor[CCS_SOLVENT_STORAGE],
        NewCap_Regenerator_t = capCCS_SS_regenerator[CCS_SOLVENT_STORAGE],
        NewCap_SolventStorageRich_t = capCCS_SS_solventstorage_rich[CCS_SOLVENT_STORAGE],
        NewCap_SolventStorageLean_t = capCCS_SS_solventstorage_lean[CCS_SOLVENT_STORAGE],

        RetCap_GasTrubine_MW = retcapCCS_SS_gasturbine[CCS_SOLVENT_STORAGE],
        RetCap_SteamTrubine_MW = retcapCCS_SS_steamturbine[CCS_SOLVENT_STORAGE],
        RetCap_Absorber_t = retcapCCS_SS_absorber[CCS_SOLVENT_STORAGE],
        RetCap_Compressor_MW = retcapCCS_SS_compressor[CCS_SOLVENT_STORAGE],
        RetCap_Regenerator_t = retcapCCS_SS_regenerator[CCS_SOLVENT_STORAGE],
        RetCap_SolventStorageRich_t = retcapCCS_SS_solventstorage_rich[CCS_SOLVENT_STORAGE],
        RetCap_SolventStorageLean_t = retcapCCS_SS_solventstorage_lean[CCS_SOLVENT_STORAGE],

        EndCap_GasTrubine_MW = [value.(EP[:eTotalCap_CCS_SS])[y,gasturbine] for y in CCS_SOLVENT_STORAGE],
        EndCap_SteamTrubine_MW = [value.(EP[:eTotalCap_CCS_SS])[y,steamturbine] for y in CCS_SOLVENT_STORAGE],
        EndCap_Absorber_t = [value.(EP[:eTotalCap_CCS_SS])[y,absorber] for y in CCS_SOLVENT_STORAGE],
        EndCap_Compressor_MW = [value.(EP[:eTotalCap_CCS_SS])[y,compressor] for y in CCS_SOLVENT_STORAGE],
        EndCap_Regenerator_t = [value.(EP[:eTotalCap_CCS_SS])[y,regenerator] for y in CCS_SOLVENT_STORAGE],
        EndCap_SolventStorageRich_t = [value.(EP[:eTotalCap_CCS_SS])[y,solventstorage_rich] for y in CCS_SOLVENT_STORAGE],
        EndCap_SolventStorageLean_t = [value.(EP[:eTotalCap_CCS_SS])[y,solventstorage_lean] for y in CCS_SOLVENT_STORAGE]
    )

    if setup["ParameterScale"] == 1
        columns_to_scale = [
        :StartCap_GasTrubine_MW,
        :RetCap_GasTrubine_MW,
        :NewCap_GasTrubine_MW,
        :EndCap_GasTrubine_MW,
        
        :StartCap_SteamTrubine_MW,
        :RetCap_SteamTrubine_MW,
        :NewCap_SteamTrubine_MW,
        :EndCap_SteamTrubine_MW,

        :StartCap_Absorber_t,
        :RetCap_Absorber_t,
        :NewCap_Absorber_t,
        :EndCap_Absorber_t,

        :StartCap_Compressor_MW,
        :RetCap_Compressor_MW,
        :NewCap_Compressor_MW,
        :EndCap_Compressor_MW,
        
        :StartCap_Regenerator_t,
        :RetCap_Regenerator_t,
        :NewCap_Regenerator_t,
        :EndCap_Regenerator_t,

        :StartCap_SolventStorageRich_t,
        :RetCap_SolventStorageRich_t,
        :NewCap_SolventStorageRich_t,
        :EndCap_SolventStorageRich_t,

        :StartCap_SolventStorageLean_t,
        :RetCap_SolventStorageLean_t,
        :NewCap_SolventStorageLean_t,
        :EndCap_SolventStorageLean_t,
        ]

        scale_columns!(dfCapCCS_SS, columns_to_scale, ModelScalingFactor)
    end

    total_solvent_storage = DataFrame(
        Resource = "Total", Zone = "n/a", 
        StartCap_GasTrubine_MW = sum(dfCapCCS_SS[!,:StartCap_GasTrubine_MW]), 
        RetCap_GasTrubine_MW = sum(dfCapCCS_SS[!,:RetCap_GasTrubine_MW]),
        NewCap_GasTrubine_MW = sum(dfCapCCS_SS[!,:NewCap_GasTrubine_MW]), 
        EndCap_GasTrubine_MW = sum(dfCapCCS_SS[!,:EndCap_GasTrubine_MW]),

        StartCap_SteamTrubine_MW = sum(dfCapCCS_SS[!,:StartCap_SteamTrubine_MW]), 
        RetCap_SteamTrubine_MW = sum(dfCapCCS_SS[!,:RetCap_SteamTrubine_MW]),
        NewCap_SteamTrubine_MW = sum(dfCapCCS_SS[!,:NewCap_SteamTrubine_MW]), 
        EndCap_SteamTrubine_MW = sum(dfCapCCS_SS[!,:EndCap_SteamTrubine_MW]),

        StartCap_Absorber_t = sum(dfCapCCS_SS[!,:StartCap_Absorber_t]), 
        RetCap_Absorber_t = sum(dfCapCCS_SS[!,:RetCap_Absorber_t]),
        NewCap_Absorber_t = sum(dfCapCCS_SS[!,:NewCap_Absorber_t]), 
        EndCap_Absorber_t = sum(dfCapCCS_SS[!,:EndCap_Absorber_t]),

        StartCap_Compressor_MW = sum(dfCapCCS_SS[!,:StartCap_Compressor_MW]), 
        RetCap_Compressor_MW = sum(dfCapCCS_SS[!,:RetCap_Compressor_MW]),
        NewCap_Compressor_MW = sum(dfCapCCS_SS[!,:NewCap_Compressor_MW]), 
        EndCap_Compressor_MW = sum(dfCapCCS_SS[!,:EndCap_Compressor_MW]),

        StartCap_Regenerator_t = sum(dfCapCCS_SS[!,:StartCap_Regenerator_t]), 
        RetCap_Regenerator_t = sum(dfCapCCS_SS[!,:RetCap_Regenerator_t]),
        NewCap_Regenerator_t = sum(dfCapCCS_SS[!,:NewCap_Regenerator_t]), 
        EndCap_Regenerator_t = sum(dfCapCCS_SS[!,:EndCap_Regenerator_t]),

        StartCap_SolventStorageRich_t = sum(dfCapCCS_SS[!,:StartCap_SolventStorageRich_t]), 
        RetCap_SolventStorageRich_t = sum(dfCapCCS_SS[!,:RetCap_SolventStorageRich_t]),
        NewCap_SolventStorageRich_t = sum(dfCapCCS_SS[!,:NewCap_SolventStorageRich_t]), 
        EndCap_SolventStorageRich_t = sum(dfCapCCS_SS[!,:EndCap_SolventStorageRich_t]),

        StartCap_SolventStorageLean_t = sum(dfCapCCS_SS[!,:StartCap_SolventStorageLean_t]), 
        RetCap_SolventStorageLean_t = sum(dfCapCCS_SS[!,:RetCap_SolventStorageLean_t]),
        NewCap_SolventStorageLean_t = sum(dfCapCCS_SS[!,:NewCap_SolventStorageLean_t]), 
        EndCap_SolventStorageLean_t = sum(dfCapCCS_SS[!,:EndCap_SolventStorageLean_t]),
        )

    dfCapCCS_SS = vcat(dfCapCCS_SS, total_solvent_storage)
    CSV.write(joinpath(path,"capacity_CCS_SOLVENT_STORAGE.csv"), dfCapCCS_SS)

    end

    function write_ccs_ss_output(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    CCS_SOLVENT_STORAGE = inputs["CCS_SOLVENT_STORAGE"] 
    T = inputs["T"]
    # CCS_SOLVENT_STORAGE components
    # components of ccs generators with solvent storage
    # by default, i = 1 -> gas turbine; i = 2 -> steam turbine;
    #             i = 3 -> absorber; i = 4 -> compressor; i = 5 -> regenerator;
    #             i = 6 -> rich solvent storage; i = 7 -> lean solvent storage
    gasturbine, steamturbine, absorber, compressor, regenerator, solventstorage_rich, solventstorage_lean = 1, 2, 3, 4, 5, 6, 7

    @expression(EP, eNetPowerCCS_SS[y in CCS_SOLVENT_STORAGE, t = 1:T],
        EP[:eP_CCS_SS][y,t] - EP[:vCHARGE_CCS_SS][y,t])

    # Power injected by each resource in each time step
    solvent_storage_resources = inputs["RESOURCE_NAMES"][CCS_SOLVENT_STORAGE]
    dfCCS_SS_output = DataFrame(Resource = 
        [solvent_storage_resources .*"_gasturbine_power_mw";
        solvent_storage_resources .*"_steamturbine_power_mw";
        solvent_storage_resources .*"_combinedcycle_commit";
        solvent_storage_resources .*"_net_power_output_mw";
        solvent_storage_resources .*"_absorber_CO2_t";
        solvent_storage_resources .*"_absorber_commit";
        solvent_storage_resources .*"_compressor_commit";
        solvent_storage_resources .*"_regenerator_CO2_t";
        
        ])

    # unit commitment is grouped
    # combinedcycle_commit is used for both gas and steam turbines
    # compressor_commit is used for both compressors and compressors
    # absorber_commit is used only for absorbers
    if setup["UCommit"] > 0
        combinedcycle_commit = value.(EP[:vCOMMIT_CCS_SS])[:, gasturbine, :]
        compressor_commit = value.(EP[:vCOMMIT_CCS_SS])[:, compressor, :]
        absorber_commit = value.(EP[:vCOMMIT_CCS_SS])[:, absorber, :]
    else
        combinedcycle_commit = zeros(1,T)
        compressor_commit = zeros(1,T)
        absorber_commit = zeros(1,T)
    end
    gross_power_gasturbine = value.(EP[:vOutput_CCS_SS])[:,gasturbine,:]
    gross_power_steamturbine = value.(EP[:vOutput_CCS_SS])[:,steamturbine,:]
    net_power_out = value.(EP[:eNetPowerCCS_SS])[:,:]
    absorber_co2 = value.(EP[:vOutput_CCS_SS])[:,absorber,:]
    regenerator_co2 = value.(EP[:vOutput_CCS_SS])[:,regenerator,:]

    if setup["ParameterScale"] == 1
        gross_power_gasturbine *= ModelScalingFactor
        gross_power_steamturbine *= ModelScalingFactor
        net_power_out *= ModelScalingFactor
        absorber_co2 *= ModelScalingFactor
        regenerator_co2 *= ModelScalingFactor
    end

    solvent_storage_output = [Array(gross_power_gasturbine);
                            Array(gross_power_steamturbine);
                            Array(combinedcycle_commit);
                            Array(net_power_out);
                            Array(absorber_co2);
                            Array(absorber_commit);
                            Array(regenerator_co2);
                            Array(compressor_commit)]

    final_solvent_storage = permutedims(DataFrame(hcat(Array(dfCCS_SS_output), solvent_storage_output), :auto))
    CSV.write(joinpath(path,"output_CCS_SOLVENT_STORAGE.csv"), final_solvent_storage, writeheader = false)
end
