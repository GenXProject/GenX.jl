function write_power_balance(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    gen = inputs["RESOURCES"]
    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones
    SEG = inputs["SEG"] # Number of demand curtailment segments
    THERM_ALL = inputs["THERM_ALL"]
    VRE = inputs["VRE"]
    MUST_RUN = inputs["MUST_RUN"]
    HYDRO_RES = inputs["HYDRO_RES"]
    STOR_ALL = inputs["STOR_ALL"]
    FLEX = inputs["FLEX"]
    ALLAM_CYCLE_LOX = inputs["ALLAM_CYCLE_LOX"]
    ELECTROLYZER = inputs["ELECTROLYZER"]
    VRE_STOR = inputs["VRE_STOR"]
    FUSION = ids_with(gen, :fusion)
    Com_list = ["Generation", "Storage_Discharge", "Storage_Charge",
        "Flexible_Demand_Defer", "Flexible_Demand_Stasify",
        "Demand_Response", "Nonserved_Energy",
        "Transmission_NetExport", "Transmission_Losses",
        "Demand"]
    if !isempty(ELECTROLYZER)
        push!(Com_list, "Electrolyzer_Consumption")
    end
    if !isempty(VRE_STOR)
        push!(Com_list, "VRE_Storage_Discharge")
        push!(Com_list, "VRE_Storage_Charge")
    end
    if !isempty(FUSION)
        push!(Com_list, "Fusion_parasitic_power")
    end
    if setup["Markets"] == 1
        push!(Com_list, "Market_Buy")
        push!(Com_list, "Market_Sell")
    end

    L = length(Com_list)
    Com_idx = Dict(Com_list[i] => i for i in 1:L)
    dfPowerBalance = DataFrame(BalanceComponent = repeat(Com_list, outer = Z),
        Zone = repeat(1:Z, inner = L),
        AnnualSum = zeros(L * Z))
    powerbalance = zeros(Z * L, T) # following the same style of power/charge/storage/nse
    for z in 1:Z
        # Row of component `c` for the current zone
        row(c) = (z - 1) * L + Com_idx[c]

        POWER_ZONE = intersect(resources_in_zone_by_rid(gen, z),
            union(THERM_ALL, VRE, MUST_RUN, HYDRO_RES, ALLAM_CYCLE_LOX))
        ALLAM_ZONE = intersect(resources_in_zone_by_rid(gen, z), ALLAM_CYCLE_LOX)
        if isempty(ALLAM_ZONE)
            powerbalance[row("Generation"), :] = sum(value.(EP[:vP][POWER_ZONE, :]), dims = 1)
        else
            powerbalance[row("Generation"), :] = sum(value.(Array(EP[:vP][POWER_ZONE, :])), dims = 1) - sum(value.(Array(EP[:vCHARGE_ALLAM][ALLAM_ZONE, :])), dims = 1)
        end
        STOR_ALL_ZONE = intersect(resources_in_zone_by_rid(gen, z), STOR_ALL)
        if !isempty(STOR_ALL_ZONE)
            powerbalance[row("Storage_Discharge"), :] = sum(value.(EP[:vP][STOR_ALL_ZONE, :]),
                dims = 1)
            powerbalance[row("Storage_Charge"), :] = (-1) * sum(
                (value.(EP[:vCHARGE][STOR_ALL_ZONE,:]).data),
                dims = 1)
        end
        FLEX_ZONE = intersect(resources_in_zone_by_rid(gen, z), FLEX)
        if !isempty(FLEX_ZONE)
            powerbalance[row("Flexible_Demand_Defer"), :] = sum(
                (value.(EP[:vCHARGE_FLEX][FLEX_ZONE,:]).data),
                dims = 1)
            powerbalance[row("Flexible_Demand_Stasify"), :] = (-1) *
                                               sum(value.(EP[:vP][FLEX_ZONE, :]), dims = 1)
        end
        if SEG > 1
            powerbalance[row("Demand_Response"), :] = sum(value.(EP[:vNSE][2:SEG, :, z]), dims = 1)
        end
        powerbalance[row("Nonserved_Energy"), :] = value.(EP[:vNSE][1, :, z])
        if Z >= 2
            powerbalance[row("Transmission_NetExport"), :] = (value.(EP[:ePowerBalanceNetExportFlows][:,
                z]))' # Transpose
            powerbalance[row("Transmission_Losses"), :] = -(value.(EP[:eLosses_By_Zone][z, :]))
        end
        powerbalance[row("Demand"), :] = (((-1) * inputs["pD"][:, z]))' # Transpose
        if !isempty(ELECTROLYZER)
            ELECTROLYZER_ZONE = intersect(resources_in_zone_by_rid(gen, z), ELECTROLYZER)
            powerbalance[row("Electrolyzer_Consumption"), :] = (-1) * sum(
                value.(EP[:vUSE][ELECTROLYZER_ZONE,:].data),
                dims = 1)
        end
        # VRE storage discharge and charge
        if !isempty(intersect(resources_in_zone_by_rid(gen, z), VRE_STOR))
            VS_ALL_ZONE = intersect(resources_in_zone_by_rid(gen, z), inputs["VS_STOR"])
            powerbalance[row("VRE_Storage_Discharge"), :] = sum(
                value.(EP[:vP][VS_ALL_ZONE, :]), dims = 1)
            powerbalance[row("VRE_Storage_Charge"), :] = (-1) * sum(
                value.(EP[:vCHARGE_VRE_STOR][VS_ALL_ZONE, :]).data, dims = 1)
        end
        FUSION_ZONE = intersect(resources_in_zone_by_rid(gen, z), FUSION)
        if !isempty(FUSION_ZONE)
            powerbalance[row("Fusion_parasitic_power"), :] = -fusion_total_parasitic_power_unscaled(
                EP, inputs, z)
        end
        # Market purchases enter the zone's balance as supply, sales as consumption
        # (non-market zones keep the default zeros)
        if setup["Markets"] == 1 && z in inputs["MZ"]
            powerbalance[row("Market_Buy"), :] = value.(EP[:vMBUY][z, :])
            powerbalance[row("Market_Sell"), :] = (-1) * value.(EP[:vMSELL][z, :])
        end
    end
    if setup["ParameterScale"] == 1
        powerbalance *= ModelScalingFactor
    end
    dfPowerBalance.AnnualSum .= powerbalance * inputs["omega"]

    if setup["WriteOutputs"] == "annual"
        CSV.write(joinpath(path, "power_balance.csv"), dfPowerBalance)
    else # setup["WriteOutputs"] == "full"
        dfPowerBalance = hcat(dfPowerBalance, DataFrame(powerbalance, :auto))
        auxNew_Names = [Symbol("BalanceComponent");
                        Symbol("Zone");
                        Symbol("AnnualSum");
                        [Symbol("t$t") for t in 1:T]]
        rename!(dfPowerBalance, auxNew_Names)
        CSV.write(joinpath(path, "power_balance.csv"),
            dftranspose(dfPowerBalance, false),
            writeheader = false)

        if setup["OutputFullTimeSeries"] == 1 && setup["TimeDomainReduction"] == 1
            write_full_time_series_reconstruction(
                path, setup, dfPowerBalance, "power_balance")
            @info("Writing Full Time Series for Power Balance")
        end
    end
    return nothing
end
