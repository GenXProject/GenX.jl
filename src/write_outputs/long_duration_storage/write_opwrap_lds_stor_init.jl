function write_opwrap_lds_stor_init(path::AbstractString,
        inputs::Dict,
        setup::Dict,
        EP::Model)
    ## Extract data frames from input dictionary
    gen = inputs["RESOURCES"]
    zones = zone_id.(gen)

    G = inputs["G"]

    # Initial level of storage in each modeled period
    NPeriods = size(inputs["Period_Map"])[1]
    dfStorageInit = DataFrame(Resource = inputs["RESOURCE_NAMES"], Zone = zones)
    socw = zeros(G, NPeriods)
    for i in 1:G
        if i in inputs["STOR_LONG_DURATION"]
            socw[i, :] = value.(EP[:vSOCw])[i, :]
        end
        if !isempty(inputs["VRE_STOR"])
            if i in inputs["VS_LDS"]
                socw[i, :] = value.(EP[:vSOCw_VRE_STOR][i, :])
            end
        end
    end
    if setup["ParameterScale"] == 1
        socw *= ModelScalingFactor
    end

    dfStorageInit = hcat(dfStorageInit, DataFrame(socw, :auto))
    auxNew_Names = [Symbol("Resource"); Symbol("Zone"); [Symbol("n$t") for t in 1:NPeriods]]
    rename!(dfStorageInit, auxNew_Names)
    CSV.write(joinpath(path, "StorageInit.csv"),
        dftranspose(dfStorageInit, false),
        header = false)

    # Write storage evolution over full time horizon
    hours_per_subperiod = inputs["hours_per_subperiod"];
    t_interior = 2:hours_per_subperiod
    T_hor = hours_per_subperiod*NPeriods # total number of time steps in time horizon
    SOC_t = zeros(G, T_hor)
    stor_long_duration = inputs["STOR_LONG_DURATION"]
    stor_hydro_long_duration = inputs["STOR_HYDRO_LONG_DURATION"]
    period_map = inputs["Period_Map"].Rep_Period_Index
    pP_max = inputs["pP_Max"]
    e_total_cap = value.(EP[:eTotalCap])
    v_charge = value.(EP[:vCHARGE])
    v_P = value.(EP[:vP])
    if setup["ParameterScale"] == 1
        v_charge *= ModelScalingFactor
        v_P *= ModelScalingFactor
    end
    if !isempty(stor_hydro_long_duration)
        v_spill = value.(EP[:vSPILL])
    end
    for r in 1:NPeriods
        w = period_map[r]
        t_r = hours_per_subperiod * (r - 1) + 1
        t_start_w = hours_per_subperiod * (w - 1) + 1
        t_interior = 2:hours_per_subperiod

        if !isempty(stor_long_duration)
            SOC_t[stor_long_duration, t_r] = socw[stor_long_duration, r] .* (1 .- self_discharge.(gen[stor_long_duration])) .+ efficiency_up.(gen[stor_long_duration]) .* v_charge[stor_long_duration, t_start_w] .- 1 ./ efficiency_down.(gen[stor_long_duration]) .* v_P[stor_long_duration, t_start_w]

            for t_int in t_interior
                t = hours_per_subperiod * (w - 1) + t_int
                SOC_t[stor_long_duration, t_r + t_int - 1] = SOC_t[stor_long_duration, t_r + t_int - 2] .* (1 .- self_discharge.(gen[stor_long_duration])) .+ efficiency_up.(gen[stor_long_duration]) .* v_charge[stor_long_duration, t] .- 1 ./ efficiency_down.(gen[stor_long_duration]) .* v_P[stor_long_duration, t]
            end
        end

        if !isempty(stor_hydro_long_duration)
            SOC_t[stor_hydro_long_duration, t_r] = socw[stor_hydro_long_duration, r] .- 1 ./ efficiency_down.(gen[stor_long_duration]) .* v_P[stor_hydro_long_duration, t_start_w] .- v_spill[stor_hydro_long_duration, t_start_w] .+ pP_max[stor_hydro_long_duration, t_start_w] .* e_total_cap[stor_hydro_long_duration]

            for t_int in t_interior
                t = hours_per_subperiod * (w - 1) + t_int
                SOC_t[stor_hydro_long_duration, t_r + t_int - 1] = SOC_t[stor_hydro_long_duration, t_r + t_int - 2] .- 1 ./ efficiency_down.(gen[stor_long_duration]) .* v_P[stor_hydro_long_duration, t] .- v_spill[stor_hydro_long_duration, t] .+ pP_max[stor_hydro_long_duration, t] .* e_total_cap[stor_hydro_long_duration]
            end
        end
    end
    df_SOC_t = DataFrame(Resource = inputs["RESOURCE_NAMES"], Zone = zones)
    df_SOC_t = hcat(df_SOC_t, DataFrame(SOC_t, :auto))
    auxNew_Names = [Symbol("Resource"); Symbol("Zone"); [Symbol("n$t") for t in 1:T_hor]]
    rename!(df_SOC_t,auxNew_Names)
    CSV.write(joinpath(path, "StorageEvol.csv"), dftranspose(df_SOC_t, false), writeheader=false)

end
