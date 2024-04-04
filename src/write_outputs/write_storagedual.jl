@doc raw"""
	write_storagedual(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for reporting dual of storage level (state of charge) balance of each resource in each time step.
"""
function write_storagedual(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    gen = inputs["RESOURCES"]
    zones = zone_id.(gen)

    G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
    T = inputs["T"]     # Number of time steps (hours)

    START_SUBPERIODS = inputs["START_SUBPERIODS"]
    INTERIOR_SUBPERIODS = inputs["INTERIOR_SUBPERIODS"]
    REP_PERIOD = inputs["REP_PERIOD"]
    STOR_ALL = inputs["STOR_ALL"]
    VRE_STOR = inputs["VRE_STOR"]
    if !isempty(VRE_STOR)
        VS_STOR = inputs["VS_STOR"]
        VS_LDS = inputs["VS_LDS"]
        VS_NONLDS = setdiff(VS_STOR, VS_LDS)
    end

    # # Dual of storage level (state of charge) balance of each resource in each time step
    dfStorageDual = DataFrame(Resource = inputs["RESOURCE_NAMES"], Zone = zones)
    dual_values = zeros(G, T)

    # Loop over W separately hours_per_subperiod
    if !isempty(STOR_ALL)
        STOR_ALL_NONLDS = setdiff(STOR_ALL, inputs["STOR_LONG_DURATION"])
        STOR_ALL_LDS = intersect(STOR_ALL, inputs["STOR_LONG_DURATION"])
        dual_values[STOR_ALL, INTERIOR_SUBPERIODS] = (dual.(EP[:cSoCBalInterior][INTERIOR_SUBPERIODS,
            STOR_ALL]).data ./ inputs["omega"][INTERIOR_SUBPERIODS])'
        dual_values[STOR_ALL_NONLDS, START_SUBPERIODS] = (dual.(EP[:cSoCBalStart][START_SUBPERIODS,
            STOR_ALL_NONLDS]).data ./ inputs["omega"][START_SUBPERIODS])'
        if !isempty(STOR_ALL_LDS)
            if inputs["REP_PERIOD"] > 1
                dual_values[STOR_ALL_LDS, START_SUBPERIODS] = (dual.(EP[:cSoCBalLongDurationStorageStart][1:REP_PERIOD,
                    STOR_ALL_LDS]).data ./ inputs["omega"][START_SUBPERIODS])'
            else
                dual_values[STOR_ALL_LDS, START_SUBPERIODS] = (dual.(EP[:cSoCBalStart][START_SUBPERIODS,
                    STOR_ALL_LDS]).data ./ inputs["omega"][START_SUBPERIODS])'
            end
        end
    end

    if !isempty(VRE_STOR)
        dual_values[VS_STOR, INTERIOR_SUBPERIODS] = ((dual.(EP[:cSoCBalInterior_VRE_STOR][VS_STOR,
            INTERIOR_SUBPERIODS]).data)' ./ inputs["omega"][INTERIOR_SUBPERIODS])'
        dual_values[VS_NONLDS, START_SUBPERIODS] = ((dual.(EP[:cSoCBalStart_VRE_STOR][VS_NONLDS,
            START_SUBPERIODS]).data)' ./ inputs["omega"][START_SUBPERIODS])'
        if !isempty(VS_LDS)
            if inputs["REP_PERIOD"] > 1
                dual_values[VS_LDS, START_SUBPERIODS] = ((dual.(EP[:cVreStorSoCBalLongDurationStorageStart][VS_LDS,
                    1:REP_PERIOD]).data)' ./ inputs["omega"][START_SUBPERIODS])'
            else
                dual_values[VS_LDS, START_SUBPERIODS] = ((dual.(EP[:cSoCBalStart_VRE_STOR][VS_LDS,
                    START_SUBPERIODS]).data)' ./ inputs["omega"][START_SUBPERIODS])'
            end
        end
    end

    if setup["ParameterScale"] == 1
        dual_values *= ModelScalingFactor
    end

    dfStorageDual = hcat(dfStorageDual, DataFrame(dual_values, :auto))
    rename!(dfStorageDual,
        [Symbol("Resource"); Symbol("Zone"); [Symbol("t$t") for t in 1:T]])

    CSV.write(joinpath(path, "storagebal_duals.csv"),
        dftranspose(dfStorageDual, false),
        header = false)
end
