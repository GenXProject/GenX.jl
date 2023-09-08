"""
GenX: An Configurable Capacity Expansion Model
Copyright (C) 2021,  Massachusetts Institute of Technology
This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
A complete copy of the GNU General Public License v2 (GPLv2) is available
in LICENSE.txt.  Users uncompressing this from an archive may not have
received this license file.  If not, see <http://www.gnu.org/licenses/>.
"""

function write_simple_csv(filename::AbstractString, df::DataFrame)
    CSV.write(filename, df)
end

function write_simple_csv(filename::AbstractString,
                          header::Vector,
                          matrix)
    df = DataFrame(matrix, header)
    write_simple_csv(filename, df)
end


function write_core_capacities(EP::Model, inputs::Dict, filename::AbstractString, scale_factor)

    # Capacity decisions
    dfGen = inputs["dfGen"]
    dfTS = inputs["dfTS"]
    T = inputs["T"]
    RH = get_resistive_heating(inputs)

    # load capacity power
    TSResources = dfTS[!,:Resource]
    TSG = length(TSResources)
    corecappower = zeros(TSG)
    for i in 1:TSG
        corecappower[i] = first(value.(EP[:vCCAP][dfTS[i,:R_ID]]))
    end

    # load capacity energy
    corecapenergy = zeros(TSG)
    for i in 1:TSG
        corecapenergy[i] = first(value.(EP[:vTSCAP][dfTS[i,:R_ID]]))
    end

    # load rh capacity
    rhcapacity = zeros(TSG)
    for i in 1:TSG
        if dfTS[i, :R_ID] in RH
            rhcapacity[i] = first(value.(EP[:vRHCAP][dfTS[i,:R_ID]]))
        end
    end

    # create data frame
    dfCoreCap = DataFrame(
        Resource = TSResources,
        Zone = dfTS[!,:Zone],
        CorePowerCap = corecappower[:],
        TSEnergyCap = corecapenergy[:],
        RHPowerCap = rhcapacity[:]
    )

    # adjust files and write
    dfCoreCap.CorePowerCap *= scale_factor
    dfCoreCap.TSEnergyCap *= scale_factor
    dfCoreCap.RHPowerCap *= scale_factor
    write_simple_csv(filename, dfCoreCap)

    return dfCoreCap

end

function prepare_core_commitments(EP::Model, inputs::Dict, SET::Vector{Int}, symbol::Symbol)
    resources = String.(inputs["RESOURCES"][SET])
    jump_variable = EP[symbol]
    quantity = value.(jump_variable[:, SET]).data
    df = DataFrame(quantity, resources)
    return df
end

function write_core_commitments(EP, inputs, SET, symbol, filename::AbstractString)
    df = prepare_core_commitments(EP, inputs, SET, symbol)
    write_simple_csv(filename, df)
end

function prepare_scaled_values(EP::Model, inputs::Dict, SET::Vector{Int}, symbol::Symbol, scale_factor)
    resources = String.(inputs["RESOURCES"][SET])
    jump_variable = EP[symbol]
    quantity = value.(jump_variable[:, SET]).data * scale_factor
    df = DataFrame(quantity, resources)
    return df
end

function write_scaled_values(EP::Model, inputs::Dict, SET::Vector{Int}, symbol::Symbol, filename::AbstractString, scale_factor)
    df = prepare_scaled_values(EP::Model, inputs::Dict, SET::Vector{Int}, symbol::Symbol, scale_factor)
    write_simple_csv(filename, df)
end

function write_thermal_storage_system_max_dual(EP::Model, inputs::Dict, setup::Dict, filename::AbstractString, scale_factor)
    dfTS = inputs["dfTS"]
    FUS = dfTS[dfTS.FUS .== 1, :R_ID]
    CONV = get_conventional_thermal_core(inputs)

    #fusion limit
    if !isempty(FUS)
        FIRST_ROW = 1
        if dfTS[FIRST_ROW, :System_Max_Cap_MWe_net] >= 0
            val = -1*dual.(EP[:cCSystemTot])
            val *= scale_factor
            df = DataFrame(:System_Max_Cap_MW_th_dual => val)
            CSV.write(filename, dftranspose(df, false), writeheader=false)
        end
    end

    #conventional thermal core limit
    if !isempty(CONV)
        FIRST_ROW = 1
        if "Nonfus_System_Max_Cap_MWe" in names(dfTS)
            if dfTS[FIRST_ROW, :Nonfus_System_Max_Cap_MWe] >= 0
                val = -1*dual.(EP[:cNonfusSystemTot])
                val *= scale_factor
                df = DataFrame(:Nonfus_System_Max_Cap_MWe => val)
                CSV.write(filename, dftranspose(df, false), writeheader=false)
            end
        end
    end
end

function write_thermal_storage_capacity_duals(EP::Model, inputs::Dict, setup::Dict, filename::AbstractString, scale_factor)
    dfTS = inputs["dfTS"]
    TS = inputs["TS"]
    NONFUS = get_conventional_thermal_core(inputs)

    if !isempty(NONFUS)
        HAS_MAX_LIMIT = dfTS[dfTS.Max_Cap_MW_th .>= 0, :R_ID]
        intersect!(HAS_MAX_LIMIT, NONFUS)
        resources = by_rid_df(HAS_MAX_LIMIT, :Resource, dfTS)
        n_max = length(HAS_MAX_LIMIT)
        vals = zeros(n_max)
        for i in 1:n_max
            vals[i] = -1 * dual.(EP[:cCCAPMax][HAS_MAX_LIMIT[i]]) * scale_factor
        end
        df = DataFrame(
            Resource = resources,
            R_ID = HAS_MAX_LIMIT,
            Dual = vals
        )
        CSV.write(filename, dftranspose(df, false), writeheader=false)
    end
end
function write_thermal_storage_costs(EP::Model, inputs::Dict, filename::AbstractString, scale_factor)
    CONV = get_conventional_thermal_core(inputs)
    THERM_COMMIT = inputs["THERM_COMMIT"]
    COMMIT = intersect(THERM_COMMIT, CONV)

    var_core_costs = value.(EP[:eTotalCVarCore]) * scale_factor^2
    fix_core_costs = value.(EP[:eTotalCFixedCore]) * scale_factor^2
    fix_TS_costs = value.(EP[:eTotalCFixedTS]) * scale_factor^2
    fix_RH_costs = value.(EP[:eTotalCFixedRH]) * scale_factor^2
    total_costs = var_core_costs + fix_core_costs + fix_TS_costs + fix_RH_costs

    df = DataFrame(
        cVarCore = var_core_costs,
        cFixCore = fix_core_costs,
        cFixTS = fix_TS_costs,
        cFixRH = fix_RH_costs
    )

    if !isempty(COMMIT)
        start_core_costs = value.(EP[:eTotalCStartTS]) * scale_factor^2
        df.cStartCore = [start_core_costs]
        total_costs += start_core_costs
    end

    df.cTotalTS = [total_costs]

    write_simple_csv(filename, df)
end

@doc raw"""
    write_thermal_storage(path::AbstractString, inputs::Dict, setup::Dict, EP::Model))

Function for writing the diferent capacities for the different generation technologies (starting capacities or, existing capacities, retired capacities, and new-built capacities).
"""
function write_thermal_storage(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

    ### LOAD DATASETS AND PREPARE SCALING FACTOR
    dfGen = inputs["dfGen"]
    dfTS = inputs["dfTS"]
    T = inputs["T"]
    rep_periods = inputs["REP_PERIOD"]

    TS = inputs["TS"]
    TSResources = dfTS[!,:Resource]
    TSG = length(TSResources)

    # set a single scalar to avoid future branching
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    ### WRITE CORE CAPACITY DECISIONS ###
    write_core_capacities(EP, inputs, joinpath(path,"TS_capacity.csv"), scale_factor)

    ### LOAD RELEVANT SETS ###
    RH = get_resistive_heating(inputs)
    FUS = get_fus(inputs)

    ### CORE POWER TIME SERIES ###
    write_scaled_values(EP, inputs, TS, :vCP, joinpath(path, "TS_CorePwr.csv"), scale_factor)

    ### THERMAL SOC TIME SERIES ###
    write_scaled_values(EP, inputs, TS, :vTS, joinpath(path, "TS_SOC.csv"), scale_factor)

    ### RESISTIVE HEATING TIME SERIES ###
    if !isempty(RH)
        write_scaled_values(EP, inputs, RH, :vRH, joinpath(path, "TS_RH.csv"), scale_factor)
    end

    ### FUSION-SPECIFIC OUTPUTS ###
    if !isempty(FUS)
        ### RECIRCULATING POWER TIME SERIES ###
        write_scaled_values(EP, inputs, FUS, :eTotalRecircFus, joinpath(path, "TS_fusion_recirc.csv"), scale_factor)
    end

    MAINT = get_maintenance(inputs)
    if rep_periods == 1 && !isempty(MAINT)
        write_core_commitments(EP, inputs, MAINT, :vMDOWN, joinpath(path, "TS_maint.csv"))
        write_core_commitments(EP, inputs, MAINT, :vMSHUT, joinpath(path, "TS_maintshut.csv"))
    end

    ### NON FUS CORE STARTS, SHUTS, COMMITS ###
    if setup["UCommit"] > 0
        write_core_commitments(EP, inputs, TS, :vCSTART, joinpath(path, "TS_start.csv"))
        write_core_commitments(EP, inputs, TS, :vCSHUT, joinpath(path, "TS_shut.csv"))
        write_core_commitments(EP, inputs, TS, :vCCOMMIT, joinpath(path, "TS_commit.csv"))
    end

    # Write dual values of certain constraints
    write_thermal_storage_system_max_dual(EP, inputs, setup, joinpath(path, "TS_System_Max_Cap_dual.csv"), scale_factor)
    write_thermal_storage_capacity_duals(EP, inputs, setup, joinpath(path, "TS_Capacity_Duals.csv"), scale_factor)

    #write costs
    write_thermal_storage_costs(EP, inputs, joinpath(path, "TS_costs.csv"), scale_factor)

end
