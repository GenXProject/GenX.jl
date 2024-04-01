# Store the paths of the current working directory, GenX, and Settings YAML file
if isfile("PreCluster.jl")
    genx_path = cd(pwd, "../..") # pwd() grandparent <-- TDR called from PreCluster.jl
else
    genx_path = pwd()         # <-- TDR called from Run_test.jl
end
settings_path = joinpath(genx_path, "GenX_settings.yml")

# Load GenX modules
push!(LOAD_PATH, genx_path)
push!(LOAD_PATH, pwd())

using YAML
using DataFrames
using StatsBase
using Clustering
using Distances
using CSV
using GenX

const SEED = 1234

@doc raw"""
    rmse_score(y_true, y_pred)

Calculates Root Mean Square Error.

```math
RMSE = \sqrt{\frac{1}{n}\Sigma_{i=1}^{n}{\Big(\frac{d_i -f_i}{\sigma_i}\Big)^2}}
```

"""
function rmse_score(y_true, y_pred)
    errors = y_pred - y_true
    errors² = errors .^ 2
    mse = mean(errors²)
    rmse = sqrt(mse)
    return rmse
end

@doc raw"""
    parse_data(myinputs)

Get demand, solar, wind, and other curves from the input data.

"""
function parse_data(myinputs)
    # Assumes no missing data
    RESOURCE_ZONES = myinputs["RESOURCE_ZONES"]
    ZONES = myinputs["R_ZONES"]

    # DEMAND - Demand_data.csv
    demand_profiles = [myinputs["pD"][:, l] for l in 1:size(myinputs["pD"], 2)]
    demand_col_names = [DEMAND_COLUMN_PREFIX() * string(l)
                        for l in 1:size(demand_profiles)[1]]
    demand_zones = [l for l in 1:size(demand_profiles)[1]]
    col_to_zone_map = Dict(demand_col_names .=> 1:length(demand_col_names))

    # CAPACITY FACTORS - Generators_variability.csv
    solar_profiles = []
    wind_profiles = []
    var_profiles = []
    solar_col_names = []
    wind_col_names = []
    var_col_names = []
    for r in 1:length(RESOURCE_ZONES)
        if occursin("PV", RESOURCE_ZONES[r]) || occursin("pv", RESOURCE_ZONES[r]) ||
           occursin("Pv", RESOURCE_ZONES[r]) || occursin("Solar", RESOURCE_ZONES[r]) ||
           occursin("SOLAR", RESOURCE_ZONES[r]) || occursin("solar", RESOURCE_ZONES[r])
            push!(solar_col_names, RESOURCE_ZONES[r])
            push!(solar_profiles, myinputs["pP_Max"][r, :])
        elseif occursin("Wind", RESOURCE_ZONES[r]) || occursin("WIND", RESOURCE_ZONES[r]) ||
               occursin("wind", RESOURCE_ZONES[r])
            push!(wind_col_names, RESOURCE_ZONES[r])
            push!(wind_profiles, myinputs["pP_Max"][r, :])
        end
        push!(var_col_names, RESOURCE_ZONES[r])
        push!(var_profiles, myinputs["pP_Max"][r, :])
        col_to_zone_map[RESOURCE_ZONES[r]] = ZONES[r]
    end

    # FUEL - Fuels_data.csv
    fuel_col_names = string.(myinputs["fuels"])
    fuel_profiles = []
    AllFuelsConst = true
    for f in 1:length(fuel_col_names)
        push!(fuel_profiles, myinputs["fuel_costs"][fuel_col_names[f]])
        if AllFuelsConst && (minimum(myinputs["fuel_costs"][fuel_col_names[f]]) !=
            maximum(myinputs["fuel_costs"][fuel_col_names[f]]))
            AllFuelsConst = false
        end
    end
    all_col_names = [demand_col_names; var_col_names; fuel_col_names]
    all_profiles = [demand_profiles..., var_profiles..., fuel_profiles...]
    return demand_col_names, var_col_names, solar_col_names, wind_col_names, fuel_col_names,
    all_col_names,
    demand_profiles, var_profiles, solar_profiles, wind_profiles, fuel_profiles,
    all_profiles,
    col_to_zone_map, AllFuelsConst
end

@doc raw"""
    parse_mutli_period_data(inputs_dict)

Get demand, solar, wind, and other curves from multi-stage input data.

"""
function parse_multi_stage_data(inputs_dict)
    # Assumes no missing data
    # Assumes zones and technologies remain the same across planning stages.
    RESOURCE_ZONES = inputs_dict[1]["RESOURCE_ZONES"]
    ZONES = inputs_dict[1]["R_ZONES"]
    solar_col_names = []
    wind_col_names = []
    var_col_names = []
    solar_profiles = []
    wind_profiles = []
    var_profiles = []

    # [ REPLACE THIS with multi_stage_settings.yml StageLengths ]
    # In case not all stages have the same length, check relative lengths
    stage_lengths = [size(inputs_dict[t]["pD"][:, 1], 1)
                     for t in 1:length(keys(inputs_dict))]
    total_length = sum(stage_lengths)
    relative_lengths = stage_lengths / total_length

    # DEMAND - Demand_data.csv
    stage_demand_profiles = [inputs_dict[t]["pD"][:, l]
                             for t in 1:length(keys(inputs_dict)),
    l in 1:size(inputs_dict[1]["pD"], 2)]
    vector_lps = [stage_demand_profiles[:, l] for l in 1:size(inputs_dict[1]["pD"], 2)]
    demand_profiles = [reduce(vcat, vector_lps[l]) for l in 1:size(inputs_dict[1]["pD"], 2)]
    demand_col_names = [DEMAND_COLUMN_PREFIX() * string(l)
                        for l in 1:size(demand_profiles)[1]]
    demand_zones = [l for l in 1:size(demand_profiles)[1]]
    col_to_zone_map = Dict(demand_col_names .=> 1:length(demand_col_names))

    # CAPACITY FACTORS - Generators_variability.csv
    for r in 1:length(RESOURCE_ZONES)
        if occursin("PV", RESOURCE_ZONES[r]) || occursin("pv", RESOURCE_ZONES[r]) ||
           occursin("Pv", RESOURCE_ZONES[r]) || occursin("Solar", RESOURCE_ZONES[r]) ||
           occursin("SOLAR", RESOURCE_ZONES[r]) || occursin("solar", RESOURCE_ZONES[r])
            push!(solar_col_names, RESOURCE_ZONES[r])
            pv_all_stages = []
            for t in 1:length(keys(inputs_dict))
                pv_all_stages = vcat(pv_all_stages, inputs_dict[t]["pP_Max"][r, :])
            end
            push!(solar_profiles, pv_all_stages)
        elseif occursin("Wind", RESOURCE_ZONES[r]) || occursin("WIND", RESOURCE_ZONES[r]) ||
               occursin("wind", RESOURCE_ZONES[r])
            push!(wind_col_names, RESOURCE_ZONES[r])
            wind_all_stages = []
            for t in 1:length(keys(inputs_dict))
                wind_all_stages = vcat(wind_all_stages, inputs_dict[t]["pP_Max"][r, :])
            end
            push!(wind_profiles, wind_all_stages)
        end
        push!(var_col_names, RESOURCE_ZONES[r])
        var_all_stages = []
        for t in 1:length(keys(inputs_dict))
            var_all_stages = vcat(var_all_stages, inputs_dict[t]["pP_Max"][r, :])
        end
        push!(var_profiles, var_all_stages)
        col_to_zone_map[RESOURCE_ZONES[r]] = ZONES[r]
    end

    # FUEL - Fuels_data.csv
    fuel_col_names = string.(inputs_dict[1]["fuels"])
    fuel_profiles = []
    AllFuelsConst = true
    for f in 1:length(fuel_col_names)
        fuel_all_stages = []
        for t in 1:length(keys(inputs_dict))
            fuel_all_stages = vcat(fuel_all_stages,
                inputs_dict[t]["fuel_costs"][fuel_col_names[f]])
            if AllFuelsConst && (minimum(inputs_dict[t]["fuel_costs"][fuel_col_names[f]]) !=
                maximum(inputs_dict[t]["fuel_costs"][fuel_col_names[f]]))
                AllFuelsConst = false
            end
        end
        push!(fuel_profiles, fuel_all_stages)
    end

    all_col_names = [demand_col_names; var_col_names; fuel_col_names]
    all_profiles = [demand_profiles..., var_profiles..., fuel_profiles...]
    return demand_col_names, var_col_names, solar_col_names, wind_col_names, fuel_col_names,
    all_col_names,
    demand_profiles, var_profiles, solar_profiles, wind_profiles, fuel_profiles,
    all_profiles,
    col_to_zone_map, AllFuelsConst, stage_lengths, total_length, relative_lengths
end

@doc raw"""
    check_condition(Threshold, R, OldColNames, ScalingMethod, TimestepsPerRepPeriod)

Check whether the greatest Euclidean deviation in the input data and the clustered
representation is within a given proportion of the "maximum" possible deviation.

(1 for Normalization covers 100%, 4 for Standardization covers ~95%)

"""
function check_condition(Threshold, R, OldColNames, ScalingMethod, TimestepsPerRepPeriod)
    if ScalingMethod == "N"
        return maximum(R.costs) / (length(OldColNames) * TimestepsPerRepPeriod) < Threshold
    elseif ScalingMethod == "S"
        return maximum(R.costs) / (length(OldColNames) * TimestepsPerRepPeriod * 4) <
               Threshold
    else
        println("INVALID Scaling Method ",
            ScalingMethod,
            " / Choose N for Normalization or S for Standardization. Proceeding with N.")
    end
    return maximum(R.costs) / (length(OldColNames) * TimestepsPerRepPeriod) < Threshold
end

@doc raw"""
    get_worst_period_idx(R)

Get the index of the period that is farthest from its representative
period by Euclidean distance.

"""
function get_worst_period_idx(R)
    return argmax(R.costs)
end

@doc raw"""
    cluster(ClusterMethod, ClusteringInputDF, NClusters, nIters, v=false, random=true)

Get representative periods using cluster centers from kmeans or kmedoids.

K-Means: [https://juliastats.org/Clustering.jl/dev/kmeans.html](https://juliastats.org/Clustering.jl/dev/kmeans.html)

K-Medoids: [https://juliastats.org/Clustering.jl/stable/kmedoids.html](https://juliastats.org/Clustering.jl/stable/kmedoids.html)
"""
function cluster(ClusterMethod,
    ClusteringInputDF,
    NClusters,
    nIters,
    v = false,
    random = true)
    if ClusterMethod == "kmeans"
        DistMatrix = pairwise(Euclidean(), Matrix(ClusteringInputDF), dims = 2)
        R = kmeans(Matrix(ClusteringInputDF), NClusters, init = :kmcen)

        for i in 1:nIters
            if !random
                Random.seed!(SEED)
            end
            R_i = kmeans(Matrix(ClusteringInputDF), NClusters)

            if R_i.totalcost < R.totalcost
                R = R_i
            end
            if v && (i % (nIters / 10) == 0)
                println(string(i) * " : " * string(round(R_i.totalcost, digits = 3)) * " " *
                        string(round(R.totalcost, digits = 3)))
            end
        end

        A = R.assignments # get points to clusters mapping - A for Assignments
        W = R.counts # get the cluster sizes - W for Weights
        Centers = R.centers # get the cluster centers - M for Medoids

        M = []
        for i in 1:NClusters
            dists = [euclidean(Centers[:, i], ClusteringInputDF[!, j])
                     for j in 1:size(ClusteringInputDF, 2)]
            push!(M, argmin(dists))
        end

    elseif ClusterMethod == "kmedoids"
        DistMatrix = pairwise(Euclidean(), Matrix(ClusteringInputDF), dims = 2)
        R = kmedoids(DistMatrix, NClusters, init = :kmcen)

        for i in 1:nIters
            if !random
                Random.seed!(SEED)
            end
            R_i = kmedoids(DistMatrix, NClusters)
            if R_i.totalcost < R.totalcost
                R = R_i
            end
            if v && (i % (nIters / 10) == 0)
                println(string(i) * " : " * string(round(R_i.totalcost, digits = 3)) * " " *
                        string(round(R.totalcost, digits = 3)))
            end
        end

        A = R.assignments # get points to clusters mapping - A for Assignments
        W = R.counts # get the cluster sizes - W for Weights
        M = R.medoids # get the cluster centers - M for Medoids
    else
        println("INVALID ClusterMethod. Select kmeans or kmedoids. Running kmeans instead.")
        return cluster("kmeans", ClusteringInputDF, NClusters, nIters, v, random)
    end
    return [R, A, W, M, DistMatrix]
end

@doc raw"""
    RemoveConstCols(all_profiles, all_col_names)

Remove and store the columns that do not vary during the period.

"""
function RemoveConstCols(all_profiles, all_col_names, v = false)
    ConstData = []
    ConstIdx = []
    ConstCols = []
    for c in 1:length(all_col_names)
        Const = minimum(all_profiles[c]) == maximum(all_profiles[c])
        if Const
            if v
                println("Removing constant col: ", all_col_names[c])
            end
            push!(ConstData, all_profiles[c])
            push!(ConstCols, all_col_names[c])
            push!(ConstIdx, c)
        end
    end
    all_profiles = [all_profiles[i] for i in 1:length(all_profiles) if i ∉ ConstIdx]
    all_col_names = [all_col_names[i] for i in 1:length(all_col_names) if i ∉ ConstIdx]
    return all_profiles, all_col_names, ConstData, ConstCols, ConstIdx
end

@doc raw"""

    get_extreme_period(DF, GDF, profKey, typeKey, statKey,
       ConstCols, demand_col_names, solar_col_names, wind_col_names)

Identify extreme week by specification of profile type (Demand, PV, Wind),
measurement type (absolute (timestep with min/max value) vs. integral
(period with min/max summed value)), and statistic (minimum or maximum).
I.e., the user could want the hour with the most demand across the whole
system to be included among the extreme periods. They would select
"Demand", "System, "Absolute, and "Max".


"""
function get_extreme_period(DF, GDF, profKey, typeKey, statKey,
    ConstCols, demand_col_names, solar_col_names, wind_col_names, v = false)
    if v
        println(profKey, " ", typeKey, " ", statKey)
    end
    if typeKey == "Integral"
        if profKey == "Demand"
            (stat, group_idx) = get_integral_extreme(GDF,
                statKey,
                demand_col_names,
                ConstCols)
        elseif profKey == "PV"
            (stat, group_idx) = get_integral_extreme(GDF,
                statKey,
                solar_col_names,
                ConstCols)
        elseif profKey == "Wind"
            (stat, group_idx) = get_integral_extreme(GDF,
                statKey,
                wind_col_names,
                ConstCols)
        else
            println("Error: Profile Key ",
                profKey,
                " is invalid. Choose `Demand', `PV' or `Wind'.")
        end
    elseif typeKey == "Absolute"
        if profKey == "Demand"
            (stat, group_idx) = get_absolute_extreme(DF,
                statKey,
                demand_col_names,
                ConstCols)
        elseif profKey == "PV"
            (stat, group_idx) = get_absolute_extreme(DF,
                statKey,
                solar_col_names,
                ConstCols)
        elseif profKey == "Wind"
            (stat, group_idx) = get_absolute_extreme(DF, statKey, wind_col_names, ConstCols)
        else
            println("Error: Profile Key ",
                profKey,
                " is invalid. Choose `Demand', `PV' or `Wind'.")
        end
    else
        println("Error: Type Key ",
            typeKey,
            " is invalid. Choose `Absolute' or `Integral'.")
        stat = 0
        group_idx = 0
    end
    return (stat, group_idx)
end

@doc raw"""

    get_integral_extreme(GDF, statKey, col_names, ConstCols)

Get the period index with the minimum or maximum demand or capacity factor
summed over the period.

"""
function get_integral_extreme(GDF, statKey, col_names, ConstCols)
    if statKey == "Max"
        (stat, stat_idx) = findmax(sum([GDF[!, Symbol(c)]
                                        for c in setdiff(col_names, ConstCols)]))
    elseif statKey == "Min"
        (stat, stat_idx) = findmin(sum([GDF[!, Symbol(c)]
                                        for c in setdiff(col_names, ConstCols)]))
    else
        println("Error: Statistic Key ", statKey, " is invalid. Choose `Max' or `Min'.")
    end
    return (stat, stat_idx)
end

@doc raw"""

    get_absolute_extreme(DF, statKey, col_names, ConstCols)

Get the period index of the single timestep with the minimum or maximum demand or capacity factor.

"""
function get_absolute_extreme(DF, statKey, col_names, ConstCols)
    if statKey == "Max"
        (stat, stat_idx) = findmax(sum([DF[!, Symbol(c)]
                                        for c in setdiff(col_names, ConstCols)]))
        group_idx = DF.Group[stat_idx]
    elseif statKey == "Min"
        (stat, stat_idx) = findmin(sum([DF[!, Symbol(c)]
                                        for c in setdiff(col_names, ConstCols)]))
        group_idx = DF.Group[stat_idx]
    else
        println("Error: Statistic Key ", statKey, " is invalid. Choose `Max' or `Min'.")
    end
    return (stat, group_idx)
end

@doc raw"""

    scale_weights(W, H)

Linearly scale weights W such that they sum to the desired number of timesteps (hours) H.

```math
w_j \leftarrow H \cdot \frac{w_j}{\sum_i w_i} \: \: \: \forall w_j \in W
```

"""
function scale_weights(W, H, v = false)
    if v
        println("Weights before scaling: ", W)
    end
    W = [float(w) / sum(W) * H for w in W] # Scale to number of hours in input data
    if v
        println("Weights after scaling: ", W)
        println("Sum of Updated Cluster Weights: ", sum(W))
    end
    return W
end

@doc raw"""

    get_demand_multipliers(ClusterOutputData, ModifiedData, M, W, DemandCols, TimestepsPerRepPeriod, NewColNames, NClusters, Ncols)

Get multipliers to linearly scale clustered demand profiles L zone-wise such that their weighted sum equals the original zonal total demand.
Scale demand profiles later using these multipliers in order to ensure that a copy of the original demand is kept for validation.

Find $k_z$ such that:

```math
\sum_{i \in I} L_{i,z} = \sum_{t \in T, m \in M} C_{t,m,z} \cdot \frac{w_m}{T} \cdot k_z   \: \: \: \forall z \in Z
```

where $Z$ is the set of zones, $I$ is the full time domain, $T$ is the length of one period (e.g., 168 for one week in hours),
$M$ is the set of representative periods, $L_{i,z}$ is the original zonal demand profile over time (hour) index $i$, $C_{i,m,z}$ is the
demand in timestep $i$ for representative period $m$ in zone $z$, $w_m$ is the weight of the representative period equal to the total number of
hours that one hour in representative period $m$ represents in the original profile, and $k_z$ is the zonal demand multiplier returned by the function.

"""
function get_demand_multipliers(ClusterOutputData,
    InputData,
    M,
    W,
    DemandCols,
    TimestepsPerRepPeriod,
    NewColNames,
    NClusters,
    Ncols,
    v = false)
    # Compute original zonal total demands
    zone_sums = Dict()
    for demandcol in DemandCols
        zone_sums[demandcol] = sum(InputData[:, demandcol])
    end

    # Compute zonal demands per representative period
    cluster_zone_sums = Dict()
    for m in 1:NClusters
        clustered_lp_DF = DataFrame(Dict(NewColNames[i] => ClusterOutputData[!, m][(TimestepsPerRepPeriod * (i - 1) + 1):(TimestepsPerRepPeriod * i)]
                                         for i in 1:Ncols
                                             if (Symbol(NewColNames[i]) in DemandCols)))
        cluster_zone_sums[m] = Dict()
        for demandcol in DemandCols
            cluster_zone_sums[m][demandcol] = sum(clustered_lp_DF[:, demandcol])
        end
    end

    # Use representative period weights to compute total zonal demand of the representative profile
    # Determine multiplier to bridge the gap between original zonal demands and representative zonal demands
    weighted_cluster_zone_sums = Dict(demandcol => 0.0 for demandcol in DemandCols)
    demand_mults = Dict()
    for demandcol in DemandCols
        for m in 1:NClusters
            weighted_cluster_zone_sums[demandcol] += (W[m] / (TimestepsPerRepPeriod)) *
                                                     cluster_zone_sums[m][demandcol]
        end
        demand_mults[demandcol] = zone_sums[demandcol] /
                                  weighted_cluster_zone_sums[demandcol]
        if v
            println(demandcol,
                ": ",
                weighted_cluster_zone_sums[demandcol],
                " vs. ",
                zone_sums[demandcol],
                " => ",
                demand_mults[demandcol])
        end
    end

    # Zone-wise validation that scaled clustered demand equals original demand (Don't actually scale demand in this function)
    if v
        new_zone_sums = Dict(demandcol => 0.0 for demandcol in DemandCols)
        for m in 1:NClusters
            for i in 1:Ncols
                if (NewColNames[i] in DemandCols)
                    # Uncomment this line if we decide to scale demand here instead of later. (Also remove "demand_mults[NewColNames[i]]*" term from new_zone_sums computation)
                    #ClusterOutputData[!,m][TimestepsPerRepPeriod*(i-1)+1 : TimestepsPerRepPeriod*i] *= demand_mults[NewColNames[i]]
                    println("   Scaling ",
                        M[m],
                        " (",
                        NewColNames[i],
                        ") : ",
                        cluster_zone_sums[m][NewColNames[i]],
                        " => ",
                        demand_mults[NewColNames[i]] *
                        sum(ClusterOutputData[!, m][(TimestepsPerRepPeriod * (i - 1) + 1):(TimestepsPerRepPeriod * i)]))
                    new_zone_sums[NewColNames[i]] += (W[m] / (TimestepsPerRepPeriod)) *
                                                     demand_mults[NewColNames[i]] *
                                                     sum(ClusterOutputData[!, m][(TimestepsPerRepPeriod * (i - 1) + 1):(TimestepsPerRepPeriod * i)])
                end
            end
        end
        for demandcol in DemandCols
            println(demandcol,
                ": ",
                new_zone_sums[demandcol],
                " =?= ",
                zone_sums[demandcol])
        end
    end

    return demand_mults
end

function update_deprecated_tdr_inputs!(setup::Dict{Any, Any})
    if "LoadWeight" in keys(setup)
        setup["DemandWeight"] = setup["LoadWeight"]
        delete!(setup, "LoadWeight")
        @info "In time_domain_reduction_settings file the key LoadWeight is deprecated. Prefer DemandWeight."
    end

    extreme_periods = "ExtremePeriods"

    if extreme_periods in keys(setup)
        extr_dict = setup[extreme_periods]

        if "Load" in keys(extr_dict)
            extr_dict["Demand"] = extr_dict["Load"]
            delete!(extr_dict, "Load")
            @info "In time_domain_reduction_settings file the key Load is deprecated. Prefer Demand."
        end
    end
end

@doc raw"""
    cluster_inputs(inpath, settings_path, mysetup, stage_id=-99, v=false; random=true)

Use kmeans or kmedoids to cluster raw demand profiles and resource capacity factor profiles
into representative periods. Use Extreme Periods to capture noteworthy periods or
periods with notably poor fits.

In Demand_data.csv, include the following:

 - Timesteps\_per\_Rep\_Period - Typically 168 timesteps (e.g., hours) per period, this designates the length
     of each representative period.
 - UseExtremePeriods - Either 1 or 0, this designates whether or not to include
    outliers (by performance or demand/resource extreme) as their own representative periods.
    This setting automatically includes the periods with maximum demand, minimum solar cf and
    minimum wind cf as extreme periods.
 - ClusterMethod - Either 'kmeans' or 'kmedoids', this designates the method used to cluster
    periods and determine each point's representative period.
 - ScalingMethod - Either 'N' or 'S', this designates directs the module to normalize ([0,1])
    or standardize (mean 0, variance 1) the input data.
 - MinPeriods - The minimum number of periods used to represent the input data. If using
    UseExtremePeriods, this must be at least three. If IterativelyAddPeriods if off,
    this will be the total number of periods.
 - MaxPeriods - The maximum number of periods - both clustered periods and extreme periods -
    that may be used to represent the input data.
 - IterativelyAddPeriods - Either 1 or 0, this designates whether or not to add periods
    until the error threshold between input data and represented data is met or the maximum
    number of periods is reached.
 - Threshold - Iterative period addition will end if the period farthest (Euclidean Distance)
    from its representative period is within this percentage of the total possible error (for normalization)
    or ~95% of the total possible error (for standardization). E.g., for a threshold of 0.01,
    every period must be within 1% of the spread of possible error before the clustering
    iterations will terminate (or until the max number of periods is reached).
 - IterateMethod - Either 'cluster' or 'extreme', this designates whether to add clusters to
    the kmeans/kmedoids method or to set aside the worst-fitting periods as a new extreme periods.
 - nReps - The number of times to repeat each kmeans/kmedoids clustering at the same setting.
 - DemandWeight - Default 1, this is an optional multiplier on demand columns in order to prioritize
    better fits for demand profiles over resource capacity factor profiles.
 - WeightTotal - Default 8760, the sum to which the relative weights of representative periods will be scaled.
 - ClusterFuelPrices - Either 1 or 0, this indicates whether or not to use the fuel price
    time series in Fuels\_data.csv in the clustering process. If 'no', this function will still write
    Fuels\_data\_clustered.csv with reshaped fuel prices based on the number and size of the
    representative weeks, assuming a constant time series of fuel prices with length equal to the
    number of timesteps in the raw input data.
 -  MultiStageConcatenate - (Only considered if MultiStage = 1 in genx_settings.yml)
    If 1, this designates that the model should time domain reduce the input data
     of all model stages together. Else if 0, [still in development] the model will time domain reduce only
     the first stage and will apply the periods of each other model stage to this set
     of representative periods by closest Eucliden distance.

For co-located VRE-STOR resources, all capacity factors must be in the Generators_variability.csv file in addition
to separate Vre_and_stor_solar_variability.csv and Vre_and_stor_wind_variability.csv files. The co-located solar PV
and wind profiles for co-located resources will be separated into different CSV files to be read by loading the inputs 
after the clustering of the inputs has occurred. 
"""
function cluster_inputs(inpath,
    settings_path,
    mysetup,
    stage_id = -99,
    v = false;
    random = true)
    if v
        println(now())
    end

    ##### Step 0: Load in settings and data

    # Read time domain reduction settings file time_domain_reduction_settings.yml
    myTDRsetup = YAML.load(open(joinpath(settings_path,
        "time_domain_reduction_settings.yml")))
    update_deprecated_tdr_inputs!(myTDRsetup)

    # Accept model parameters from the settings file time_domain_reduction_settings.yml
    TimestepsPerRepPeriod = myTDRsetup["TimestepsPerRepPeriod"]
    ClusterMethod = myTDRsetup["ClusterMethod"]
    ScalingMethod = myTDRsetup["ScalingMethod"]
    MinPeriods = myTDRsetup["MinPeriods"]
    MaxPeriods = myTDRsetup["MaxPeriods"]
    UseExtremePeriods = myTDRsetup["UseExtremePeriods"]
    ExtPeriodSelections = myTDRsetup["ExtremePeriods"]
    Iterate = myTDRsetup["IterativelyAddPeriods"]
    IterateMethod = myTDRsetup["IterateMethod"]
    Threshold = myTDRsetup["Threshold"]
    nReps = myTDRsetup["nReps"]
    DemandWeight = myTDRsetup["DemandWeight"]
    WeightTotal = myTDRsetup["WeightTotal"]
    ClusterFuelPrices = myTDRsetup["ClusterFuelPrices"]
    TimeDomainReductionFolder = mysetup["TimeDomainReductionFolder"]

    MultiStage = mysetup["MultiStage"]
    if MultiStage == 1
        MultiStageConcatenate = myTDRsetup["MultiStageConcatenate"]
        NumStages = mysetup["MultiStageSettingsDict"]["NumStages"]
    end

    Demand_Outfile = joinpath(TimeDomainReductionFolder, "Demand_data.csv")
    GVar_Outfile = joinpath(TimeDomainReductionFolder, "Generators_variability.csv")
    Fuel_Outfile = joinpath(TimeDomainReductionFolder, "Fuels_data.csv")
    PMap_Outfile = joinpath(TimeDomainReductionFolder, "Period_map.csv")
    YAML_Outfile = joinpath(TimeDomainReductionFolder, "time_domain_reduction_settings.yml")

    # Define a local version of the setup so that you can modify the mysetup["ParameterScale"] value to be zero in case it is 1
    mysetup_local = copy(mysetup)
    # If ParameterScale =1 then make it zero, since clustered inputs will be scaled prior to generating model
    mysetup_local["ParameterScale"] = 0  # Performing cluster and report outputs in user-provided units

    # Define another local version of setup such that Multi-Stage Non-Concatentation TDR can iteratively read in the raw data
    mysetup_MS = copy(mysetup)
    mysetup_MS["TimeDomainReduction"] = 0
    mysetup_MS["DoNotReadPeriodMap"] = 1
    mysetup_MS["ParameterScale"] = 0

    if MultiStage == 1
        model_dict = Dict()
        inputs_dict = Dict()
        for t in 1:NumStages

            # Step 0) Set Model Year
            mysetup["MultiStageSettingsDict"]["CurStage"] = t

            # Step 1) Load Inputs
            global inpath_sub = string("$inpath/inputs/inputs_p", t)

            # this prevents doubled time domain reduction in stages past
            # the first, even if the first stage is okay.
            prevent_doubled_timedomainreduction(joinpath(inpath_sub,
                mysetup["SystemFolder"]))

            inputs_dict[t] = load_inputs(mysetup_MS, inpath_sub)

            inputs_dict[t] = configure_multi_stage_inputs(inputs_dict[t],
                mysetup["MultiStageSettingsDict"],
                mysetup["NetworkExpansion"])
        end
        if MultiStageConcatenate == 1
            if v
                println("MultiStage with Concatenation")
            end
            RESOURCE_ZONES = inputs_dict[1]["RESOURCE_ZONES"]
            RESOURCES = inputs_dict[1]["RESOURCE_NAMES"]
            ZONES = inputs_dict[1]["R_ZONES"]
            # Parse input data into useful structures divided by type (demand, wind, solar, fuel, groupings thereof, etc.)
            # TO DO LATER: Replace these with collections of col_names, profiles, zones
            demand_col_names, var_col_names, solar_col_names, wind_col_names, fuel_col_names, all_col_names,
            demand_profiles, var_profiles, solar_profiles, wind_profiles, fuel_profiles, all_profiles,
            col_to_zone_map, AllFuelsConst, stage_lengths, total_length, relative_lengths = parse_multi_stage_data(inputs_dict)
        else # TDR each period individually
            if v
                println("MultiStage without Concatenation")
            end
            if v
                println("---> STAGE ", stage_id)
            end
            myinputs = inputs_dict[stage_id]
            RESOURCE_ZONES = myinputs["RESOURCE_ZONES"]
            RESOURCES = myinputs["RESOURCE_NAMES"]
            ZONES = myinputs["R_ZONES"]
            # Parse input data into useful structures divided by type (demand, wind, solar, fuel, groupings thereof, etc.)
            # TO DO LATER: Replace these with collections of col_names, profiles, zones
            demand_col_names, var_col_names, solar_col_names, wind_col_names, fuel_col_names, all_col_names,
            demand_profiles, var_profiles, solar_profiles, wind_profiles, fuel_profiles, all_profiles,
            col_to_zone_map, AllFuelsConst = parse_data(myinputs)
        end
    else
        if v
            println("Not MultiStage")
        end
        myinputs = load_inputs(mysetup_local, inpath)
        RESOURCE_ZONES = myinputs["RESOURCE_ZONES"]
        RESOURCES = myinputs["RESOURCE_NAMES"]
        ZONES = myinputs["R_ZONES"]
        # Parse input data into useful structures divided by type (demand, wind, solar, fuel, groupings thereof, etc.)
        # TO DO LATER: Replace these with collections of col_names, profiles, zones
        demand_col_names, var_col_names, solar_col_names, wind_col_names, fuel_col_names, all_col_names,
        demand_profiles, var_profiles, solar_profiles, wind_profiles, fuel_profiles, all_profiles,
        col_to_zone_map, AllFuelsConst = parse_data(myinputs)
    end
    if v
        println()
    end

    # Remove Constant Columns - Add back later in final output
    all_profiles, all_col_names, ConstData, ConstCols, ConstIdx = RemoveConstCols(all_profiles,
        all_col_names,
        v)

    # Determine whether or not to time domain reduce fuel profiles as well based on user choice and file structure (i.e., variable fuels in Fuels_data.csv)
    IncludeFuel = true
    if (ClusterFuelPrices != 1) || (AllFuelsConst)
        IncludeFuel = false
    end

    # Put it together!
    InputData = DataFrame(Dict(all_col_names[c] => all_profiles[c]
                               for c in 1:length(all_col_names)))
    InputData = convert.(Float64, InputData)
    if v
        println("Demand (MW) and Capacity Factor Profiles: ")
        println(describe(InputData))
        println()
    end
    OldColNames = names(InputData)
    NewColNames = [Symbol.(OldColNames); :GrpWeight]
    Nhours = nrow(InputData) # Timesteps
    Ncols = length(NewColNames) - 1

    ##### Step 1: Normalize or standardize all demand, renewables, and fuel data / optionally scale with DemandWeight

    # Normalize/standardize data based on user-provided method
    if ScalingMethod == "N"
        normProfiles = [StatsBase.transform(fit(UnitRangeTransform,
                InputData[:, c];
                dims = 1,
                unit = true),
            InputData[:, c]) for c in 1:length(OldColNames)]
    elseif ScalingMethod == "S"
        normProfiles = [StatsBase.transform(fit(ZScoreTransform, InputData[:, c]; dims = 1),
            InputData[:, c]) for c in 1:length(OldColNames)]
    else
        println("ERROR InvalidScalingMethod: Use N for Normalization or S for Standardization.")
        println("CONTINUING using 0->1 normalization...")
        normProfiles = [StatsBase.transform(fit(UnitRangeTransform,
                InputData[:, c];
                dims = 1,
                unit = true),
            InputData[:, c]) for c in 1:length(OldColNames)]
    end

    # Compile newly normalized/standardized profiles
    AnnualTSeriesNormalized = DataFrame(Dict(OldColNames[c] => normProfiles[c]
                                             for c in 1:length(OldColNames)))

    # Optional pre-scaling of demand in order to give it more preference in clutering algorithm
    if DemandWeight != 1   # If we want to value demand more/less than capacity factors. Assume nonnegative. LW=1 means no scaling.
        for c in demand_col_names
            AnnualTSeriesNormalized[!, Symbol(c)] .= AnnualTSeriesNormalized[!,
                Symbol(c)] .* DemandWeight
        end
    end

    if v
        println("Demand (MW) and Capacity Factor Profiles NORMALIZED! ")
        println(describe(AnnualTSeriesNormalized))
        println()
    end

    ##### STEP 2: Identify extreme periods in the model, Reshape data for clustering

    # Total number of subperiods available in the dataset, where each subperiod length = TimestepsPerRepPeriod
    NumDataPoints = Nhours ÷ TimestepsPerRepPeriod # 364 weeks in 7 years
    if v
        println("Total Subperiods in the data set: ", NumDataPoints)
    end
    InputData[:, :Group] .= (1:Nhours) .÷ (TimestepsPerRepPeriod + 0.0001) .+ 1    # Group col identifies the subperiod ID of each hour (e.g., all hours in week 2 have Group=2 if using TimestepsPerRepPeriod=168)

    # Group by period (e.g., week)
    cgdf = combine(groupby(InputData, :Group), [c .=> sum for c in OldColNames])
    cgdf = cgdf[setdiff(1:end, NumDataPoints + 1), :]
    rename!(cgdf, [:Group; Symbol.(OldColNames)])

    # Extreme period identification based on user selection in time_domain_reduction_settings.yml
    DemandExtremePeriod = false        # Used when deciding whether or not to scale demand curves to equal original total demand
    ExtremeWksList = []
    if UseExtremePeriods == 1
        for profKey in keys(ExtPeriodSelections)
            for geoKey in keys(ExtPeriodSelections[profKey])
                for typeKey in keys(ExtPeriodSelections[profKey][geoKey])
                    for statKey in keys(ExtPeriodSelections[profKey][geoKey][typeKey])
                        if ExtPeriodSelections[profKey][geoKey][typeKey][statKey] == 1
                            if profKey == "Demand"
                                DemandExtremePeriod = true
                            end
                            if geoKey == "System"
                                if v
                                    print(geoKey, " ")
                                end
                                (stat, group_idx) = get_extreme_period(InputData,
                                    cgdf,
                                    profKey,
                                    typeKey,
                                    statKey,
                                    ConstCols,
                                    demand_col_names,
                                    solar_col_names,
                                    wind_col_names,
                                    v)
                                push!(ExtremeWksList, floor(Int, group_idx))
                                if v
                                    println(group_idx, " : ", stat)
                                end
                            elseif geoKey == "Zone"
                                for z in sort(unique(ZONES))
                                    z_cols = [k for (k, v) in col_to_zone_map if v == z]
                                    if profKey == "Demand"
                                        z_cols_type = intersect(z_cols, demand_col_names)
                                    elseif profKey == "PV"
                                        z_cols_type = intersect(z_cols, solar_col_names)
                                    elseif profKey == "Wind"
                                        z_cols_type = intersect(z_cols, wind_col_names)
                                    else
                                        z_cols_type = []
                                    end
                                    z_cols_type = setdiff(z_cols_type, ConstCols)
                                    if length(z_cols_type) > 0
                                        if v
                                            print(geoKey, " ")
                                        end
                                        (stat, group_idx) = get_extreme_period(select(InputData,
                                                [:Group; Symbol.(z_cols_type)]),
                                            select(cgdf, [:Group; Symbol.(z_cols_type)]),
                                            profKey,
                                            typeKey,
                                            statKey,
                                            ConstCols,
                                            z_cols_type,
                                            z_cols_type,
                                            z_cols_type,
                                            v)
                                        push!(ExtremeWksList, floor(Int, group_idx))
                                        if v
                                            println(group_idx, " : ", stat, "(", z, ")")
                                        end
                                    else
                                        if v
                                            println("Zone ",
                                                z,
                                                " has no time series profiles of type ",
                                                profKey)
                                        end
                                    end
                                end
                            else
                                println("Error: Geography Key ",
                                    geoKey,
                                    " is invalid. Select `System' or `Zone'.")
                            end
                        end
                    end
                end
            end
        end
        if v
            println(ExtremeWksList)
        end
        sort!(unique!(ExtremeWksList))
        if v
            println("Reduced to ", ExtremeWksList)
        end
    end

    ### DATA MODIFICATION - Shifting InputData and Normalized InputData
    #    from 8760 (# hours) by n (# profiles) DF to
    #    168*n (n period-stacked profiles) by 52 (# periods) DF
    DFsToConcat = [stack(InputData[isequal.(InputData.Group, w), :], OldColNames)[!,
        :value] for w in 1:NumDataPoints if w <= NumDataPoints]
    ModifiedData = DataFrame(Dict(Symbol(i) => DFsToConcat[i] for i in 1:NumDataPoints))

    AnnualTSeriesNormalized[:, :Group] .= (1:Nhours) .÷ (TimestepsPerRepPeriod + 0.0001) .+
                                          1
    DFsToConcatNorm = [stack(AnnualTSeriesNormalized[isequal.(AnnualTSeriesNormalized.Group,
                w),
            :],
        OldColNames)[!,
        :value] for w in 1:NumDataPoints if w <= NumDataPoints]
    ModifiedDataNormalized = DataFrame(Dict(Symbol(i) => DFsToConcatNorm[i]
                                            for i in 1:NumDataPoints))

    # Remove extreme periods from normalized data before clustering
    NClusters = MinPeriods
    if UseExtremePeriods == 1
        if v
            println("Pre-removal: ", names(ModifiedDataNormalized))
        end
        if v
            println("Extreme Periods: ", string.(ExtremeWksList))
        end
        ClusteringInputDF = select(ModifiedDataNormalized, Not(string.(ExtremeWksList)))
        if v
            println("Post-removal: ", names(ClusteringInputDF))
        end
        NClusters -= length(ExtremeWksList)
    else
        ClusteringInputDF = ModifiedDataNormalized
    end

    ##### STEP 3: Clustering
    cluster_results = []

    # Cluster once regardless of iteration decisions
    push!(cluster_results,
        cluster(ClusterMethod, ClusteringInputDF, NClusters, nReps, v, random))

    # Iteratively add worst periods as extreme periods OR increment number of clusters k
    #    until threshold is met or maximum periods are added (If chosen in inputs)
    if (Iterate == 1)
        while (!check_condition(Threshold,
            last(cluster_results)[1],
            OldColNames,
            ScalingMethod,
            TimestepsPerRepPeriod)) & ((length(ExtremeWksList) + NClusters) < MaxPeriods)
            if IterateMethod == "cluster"
                if v
                    println("Adding a new Cluster! ")
                end
                NClusters += 1
                push!(cluster_results,
                    cluster(ClusterMethod, ClusteringInputDF, NClusters, nReps, v, random))
            elseif (IterateMethod == "extreme") & (UseExtremePeriods == 1)
                if v
                    println("Adding a new Extreme Period! ")
                end
                worst_period_idx = get_worst_period_idx(last(cluster_results)[1])
                removed_period = string(names(ClusteringInputDF)[worst_period_idx])
                select!(ClusteringInputDF, Not(worst_period_idx))
                push!(ExtremeWksList, parse(Int, removed_period))
                if v
                    println(worst_period_idx, " (", removed_period, ") ", ExtremeWksList)
                end
                push!(cluster_results,
                    cluster(ClusterMethod, ClusteringInputDF, NClusters, nReps, v, random))
            elseif IterateMethod == "extreme"
                println("INVALID IterateMethod ",
                    IterateMethod,
                    " because UseExtremePeriods is off. Set to 1 if you wish to add extreme periods.")
                break
            else
                println("INVALID IterateMethod ",
                    IterateMethod,
                    ". Choose 'cluster' or 'extreme'.")
                break
            end
        end
        if v && (length(ExtremeWksList) + NClusters == MaxPeriods)
            println("Stopped iterating by hitting the maximum number of periods.")
        elseif v
            println("Stopped by meeting the accuracy threshold.")
        end
    end

    # Interpret Final Clustering Result
    R = last(cluster_results)[1]  # Cluster Object
    A = last(cluster_results)[2]  # Assignments
    W = last(cluster_results)[3]  # Weights
    M = last(cluster_results)[4]  # Centers or Medoids
    DistMatrix = last(cluster_results)[5]  # Pairwise distances
    if v
        println("Total Groups Assigned to Each Cluster: ", W)
        println("Sum Cluster Weights: ", sum(W))
        println("Representative Periods: ", M)
    end

    ##### Step 4: Aggregation
    # Set clustering outputs in correct numeric order.
    # Add the subperiods corresponding to the extreme periods back into the data.
    # Rescale weights to total user-specified number of hours (e.g., 8760 for one year).
    # If DemandExtremePeriod=false (because we don't want to change peak demand day), rescale demand to ensure total demand is equal.

    ### K-means/medoids returns indices from DistMatrix as its medoids.
    #   This does not account for missing extreme weeks nor "alphabetical" ordering of numeric columns (i.e., 1, 10, 11, ...).
    #   This is corrected retroactively here.
    #   Optional to do later: reorder ClusterInputDF numerically before clustering instead

    # ClusterInputDF Reframing of Centers/Medoids (i.e., alphabetical as opposed to indices, same order)
    M = [parse(Int64, string(names(ClusteringInputDF)[i])) for i in M]
    if v
        println("Fixed M: ", M)
    end

    # ClusterInputDF Ordering of All Periods (i.e., alphabetical as opposed to indices)
    A_Dict = Dict()   # States index of representative period within M for each period a in A
    M_Dict = Dict()   # States representative period m for each period a in A
    for i in 1:length(A)
        A_Dict[parse(Int64, string(names(ClusteringInputDF)[i]))] = A[i]
        M_Dict[parse(Int64, string(names(ClusteringInputDF)[i]))] = M[A[i]]
    end

    # Add extreme periods into the clustering result with # of occurences = 1 for each
    ExtremeWksList = sort(ExtremeWksList)
    if UseExtremePeriods == 1
        if v
            println("Extreme Periods: ", ExtremeWksList)
        end
        M = [M; ExtremeWksList]
        A_idx = NClusters + 1
        for w in ExtremeWksList
            A_Dict[w] = A_idx
            M_Dict[w] = w
            push!(W, 1)
            A_idx += 1
        end
        NClusters += length(ExtremeWksList) #NClusers from this point forward is the ending number of periods
    end

    # Recreate A in numeric order (as opposed to ClusterInputDF order)
    A = [A_Dict[i] for i in 1:(length(A) + length(ExtremeWksList))]

    N = W  # Keep cluster version of weights stored as N, number of periods represented by RP

    # Rescale weights to total user-specified number of hours
    W = scale_weights(W, WeightTotal, v)

    # Order representative periods chronologically for Demand_data outputs
    #   SORT A W M in conjunction, chronologically by M, before handling them elsewhere to be consistent
    #   A points to an index of M. We need it to point to a new index of sorted M. Hence, AssignMap.
    old_M = M
    df_sort = DataFrame(Weights = W, NumPeriodsRepresented = N, Rep_Period = M)
    sort!(df_sort, [:Rep_Period])
    W = df_sort[!, :Weights]
    N = df_sort[!, :NumPeriodsRepresented]
    M = df_sort[!, :Rep_Period]
    AssignMap = Dict(i => findall(x -> x == old_M[i], M)[1] for i in 1:length(M))
    A = [AssignMap[a] for a in A]

    # Make PeriodMap, maps each period to its representative period
    PeriodMap = DataFrame(Period_Index = 1:length(A),
        Rep_Period = [M[a] for a in A],
        Rep_Period_Index = [a for a in A])

    # Get Symbol-version of column names by type for later analysis
    DemandCols = Symbol.(demand_col_names)
    VarCols = [Symbol(var_col_names[i]) for i in 1:length(var_col_names)]
    FuelCols = [Symbol(fuel_col_names[i]) for i in 1:length(fuel_col_names)]
    ConstCol_Syms = [Symbol(ConstCols[i]) for i in 1:length(ConstCols)]

    # Cluster Ouput: The original data at the medoids/centers
    ClusterOutputData = ModifiedData[:, Symbol.(M)]

    # Get zone-wise demand multipliers for later scaling in order for weighted-representative-total-zonal demand to equal original total-zonal demand
    #  (Only if we don't have demand-related extreme periods because we don't want to change peak demand periods)
    if !DemandExtremePeriod
        demand_mults = get_demand_multipliers(ClusterOutputData,
            InputData,
            M,
            W,
            DemandCols,
            TimestepsPerRepPeriod,
            NewColNames,
            NClusters,
            Ncols)
    end

    # Reorganize Data by Demand, Solar, Wind, Fuel, and GrpWeight by Hour, Add Constant Data Back In
    rpDFs = [] # Representative Period DataFrames - All Profiles (Demand, Resource, Fuel)
    gvDFs = [] # Generators Variability DataFrames - Just Resource Profiles
    dmDFs = [] # Demand Profile DataFrames - Just Demand Profiles
    fpDFs = [] # Fuel Profile DataFrames - Just Fuel Profiles

    for m in 1:NClusters
        rpDF = DataFrame(Dict(NewColNames[i] => ClusterOutputData[!, m][(TimestepsPerRepPeriod * (i - 1) + 1):(TimestepsPerRepPeriod * i)]
                              for i in 1:Ncols))
        gvDF = DataFrame(Dict(NewColNames[i] => ClusterOutputData[!, m][(TimestepsPerRepPeriod * (i - 1) + 1):(TimestepsPerRepPeriod * i)]
                              for i in 1:Ncols if (Symbol(NewColNames[i]) in VarCols)))
        dmDF = DataFrame(Dict(NewColNames[i] => ClusterOutputData[!, m][(TimestepsPerRepPeriod * (i - 1) + 1):(TimestepsPerRepPeriod * i)]
                              for i in 1:Ncols if (Symbol(NewColNames[i]) in DemandCols)))
        if IncludeFuel
            fpDF = DataFrame(Dict(NewColNames[i] => ClusterOutputData[!, m][(TimestepsPerRepPeriod * (i - 1) + 1):(TimestepsPerRepPeriod * i)]
                                  for i in 1:Ncols if (Symbol(NewColNames[i]) in FuelCols)))
        end
        if !IncludeFuel
            fpDF = DataFrame(Placeholder = 1:TimestepsPerRepPeriod)
        end

        # Add Constant Columns back in
        for c in 1:length(ConstCols)
            rpDF[!, Symbol(ConstCols[c])] .= ConstData[c][1]
            if Symbol(ConstCols[c]) in VarCols
                gvDF[!, Symbol(ConstCols[c])] .= ConstData[c][1]
            elseif Symbol(ConstCols[c]) in FuelCols
                fpDF[!, Symbol(ConstCols[c])] .= ConstData[c][1]
            elseif Symbol(ConstCols[c]) in DemandCols
                dmDF[!, Symbol(ConstCols[c])] .= ConstData[c][1]
            end
        end
        if !IncludeFuel
            select!(fpDF, Not(:Placeholder))
        end

        # Scale Demand using previously identified multipliers
        #   Scale dmDF but not rpDF which compares to input data but is not written to file.
        for demandcol in DemandCols
            if demandcol ∉ ConstCol_Syms
                if !DemandExtremePeriod
                    dmDF[!, demandcol] .*= demand_mults[demandcol]
                end
            end
        end

        rpDF[!, :GrpWeight] .= W[m]
        rpDF[!, :Cluster] .= M[m]
        push!(rpDFs, rpDF)
        push!(gvDFs, gvDF)
        push!(dmDFs, dmDF)
        push!(fpDFs, fpDF)
    end
    FinalOutputData = vcat(rpDFs...)  # For comparisons with input data to evaluate clustering process
    GVOutputData = vcat(gvDFs...)     # Generators Variability
    DMOutputData = vcat(dmDFs...)     # Demand Profiles
    FPOutputData = vcat(fpDFs...)     # Fuel Profiles

    ##### Step 5: Evaluation

    InputDataTest = InputData[(InputData.Group .<= NumDataPoints * 1.0), :]
    ClusterDataTest = vcat([rpDFs[a] for a in A]...) # To compare fairly, demand is not scaled here
    RMSE = Dict(c => rmse_score(InputDataTest[:, c], ClusterDataTest[:, c])
                for c in OldColNames)

    ##### Step 6: Print to File

    if MultiStage == 1
        if v
            print("Outputs: MultiStage")
        end
        if MultiStageConcatenate == 1
            if v
                println(" with Concatenation")
            end
            groups_per_stage = round.(Int, size(A, 1) * relative_lengths)
            group_ranges = [if i == 1
                1:groups_per_stage[1]
            else
                (sum(groups_per_stage[1:(i - 1)]) + 1):sum(groups_per_stage[1:i])
            end
                            for i in 1:size(relative_lengths, 1)]

            Stage_Weights = Dict()
            Stage_PeriodMaps = Dict()
            Stage_Outfiles = Dict()
            SolarVar_Outfile = joinpath(TimeDomainReductionFolder,
                "Vre_and_stor_solar_variability.csv")
            WindVar_Outfile = joinpath(TimeDomainReductionFolder,
                "Vre_and_stor_wind_variability.csv")
            for per in 1:NumStages                      # Iterate over multi-stages
                mkpath(joinpath(inpath,
                    "inputs",
                    "inputs_p$per",
                    TimeDomainReductionFolder))
                # Stage-specific weights and mappings
                cmap = countmap(A[group_ranges[per]])    # Count number of each rep. period in the planning stage
                weight_props = [if i in keys(cmap)
                    cmap[i] / N[i]
                else
                    0
                end
                                for i in 1:size(M, 1)]  # Proportions of each rep. period associated with each planning stage
                Stage_Weights[per] = weight_props .* W    # Total hours that each rep. period represents within the planning stage
                Stage_PeriodMaps[per] = PeriodMap[group_ranges[per], :]
                Stage_PeriodMaps[per][!, :Period_Index] = 1:(group_ranges[per][end] - group_ranges[per][1] + 1)
                # Outfiles
                Stage_Outfiles[per] = Dict()
                Stage_Outfiles[per]["Demand"] = joinpath("inputs_p$per", Demand_Outfile)
                Stage_Outfiles[per]["GVar"] = joinpath("inputs_p$per", GVar_Outfile)
                Stage_Outfiles[per]["Fuel"] = joinpath("inputs_p$per", Fuel_Outfile)
                Stage_Outfiles[per]["PMap"] = joinpath("inputs_p$per", PMap_Outfile)
                Stage_Outfiles[per]["YAML"] = joinpath("inputs_p$per", YAML_Outfile)
                if !isempty(inputs_dict[per]["VRE_STOR"])
                    Stage_Outfiles[per]["GSolar"] = joinpath("inputs_p$per",
                        SolarVar_Outfile)
                    Stage_Outfiles[per]["GWind"] = joinpath("inputs_p$per", WindVar_Outfile)
                end

                # Save output data to stage-specific locations
                ### TDR_Results/Demand_data_clustered.csv
                demand_in = get_demand_dataframe(joinpath(inpath, "inputs", "inputs_p$per"),
                    mysetup["SystemFolder"])
                demand_in[!, :Sub_Weights] = demand_in[!, :Sub_Weights] * 1.0
                demand_in[1:length(Stage_Weights[per]), :Sub_Weights] .= Stage_Weights[per]
                demand_in[!, :Rep_Periods][1] = length(Stage_Weights[per])
                demand_in[!, :Timesteps_per_Rep_Period][1] = TimestepsPerRepPeriod
                select!(demand_in, Not(DemandCols))
                select!(demand_in, Not(:Time_Index))
                Time_Index_M = Union{Int64, Missings.Missing}[missing
                                                              for i in 1:size(demand_in, 1)]
                Time_Index_M[1:size(DMOutputData, 1)] = 1:size(DMOutputData, 1)
                demand_in[!, :Time_Index] .= Time_Index_M

                for c in DemandCols
                    new_col = Union{Float64, Missings.Missing}[missing
                                                               for i in 1:size(demand_in, 1)]
                    new_col[1:size(DMOutputData, 1)] = DMOutputData[!, c]
                    demand_in[!, c] .= new_col
                end
                demand_in = demand_in[1:size(DMOutputData, 1), :]

                if v
                    println("Writing demand file...")
                end
                CSV.write(joinpath(inpath, "inputs", Stage_Outfiles[per]["Demand"]),
                    demand_in)

                ### TDR_Results/Generators_variability.csv
                # Reset column ordering, add time index, and solve duplicate column name trouble with CSV.write's header kwarg
                GVColMap = Dict(RESOURCE_ZONES[i] => RESOURCES[i]
                                for i in 1:length(inputs_dict[1]["RESOURCE_NAMES"]))
                GVColMap["Time_Index"] = "Time_Index"
                GVOutputData = GVOutputData[!, Symbol.(RESOURCE_ZONES)]
                insertcols!(GVOutputData, 1, :Time_Index => 1:size(GVOutputData, 1))
                NewGVColNames = [GVColMap[string(c)] for c in names(GVOutputData)]
                if v
                    println("Writing resource file...")
                end
                CSV.write(joinpath(inpath, "inputs", Stage_Outfiles[per]["GVar"]),
                    GVOutputData,
                    header = NewGVColNames)

                if !isempty(inputs_dict[per]["VRE_STOR"])
                    gen_var = load_dataframe(joinpath(inpath,
                        "inputs",
                        Stage_Outfiles[per]["GVar"]))

                    # Find which indexes have solar PV/wind names
                    RESOURCE_ZONES_VRE_STOR = NewGVColNames
                    solar_col_names = []
                    wind_col_names = []
                    for r in 1:length(RESOURCE_ZONES_VRE_STOR)
                        if occursin("PV", RESOURCE_ZONES_VRE_STOR[r]) ||
                           occursin("pv", RESOURCE_ZONES_VRE_STOR[r]) ||
                           occursin("Pv", RESOURCE_ZONES_VRE_STOR[r]) ||
                           occursin("Solar", RESOURCE_ZONES_VRE_STOR[r]) ||
                           occursin("SOLAR", RESOURCE_ZONES_VRE_STOR[r]) ||
                           occursin("solar", RESOURCE_ZONES_VRE_STOR[r]) ||
                           occursin("Time", RESOURCE_ZONES_VRE_STOR[r])
                            push!(solar_col_names, r)
                        end
                        if occursin("Wind", RESOURCE_ZONES_VRE_STOR[r]) ||
                           occursin("WIND", RESOURCE_ZONES_VRE_STOR[r]) ||
                           occursin("wind", RESOURCE_ZONES_VRE_STOR[r]) ||
                           occursin("Time", RESOURCE_ZONES_VRE_STOR[r])
                            push!(wind_col_names, r)
                        end
                    end

                    # Index into dataframe and output them
                    solar_var = gen_var[!, solar_col_names]
                    solar_var[!, :Time_Index] = 1:size(solar_var, 1)
                    wind_var = gen_var[!, wind_col_names]
                    wind_var[!, :Time_Index] = 1:size(wind_var, 1)

                    CSV.write(joinpath(inpath, "inputs", Stage_Outfiles[per]["GSolar"]),
                        solar_var)
                    CSV.write(joinpath(inpath, "inputs", Stage_Outfiles[per]["GWind"]),
                        wind_var)
                end

                ### TDR_Results/Fuels_data.csv
                fuel_in = load_dataframe(joinpath(inpath,
                    "inputs",
                    "inputs_p$per",
                    mysetup["SystemFolder"],
                    "Fuels_data.csv"))
                select!(fuel_in, Not(:Time_Index))
                SepFirstRow = DataFrame(fuel_in[1, :])
                NewFuelOutput = vcat(SepFirstRow, FPOutputData)
                rename!(NewFuelOutput, FuelCols)
                insertcols!(NewFuelOutput, 1, :Time_Index => 0:(size(NewFuelOutput, 1) - 1))
                if v
                    println("Writing fuel profiles...")
                end
                CSV.write(joinpath(inpath, "inputs", Stage_Outfiles[per]["Fuel"]),
                    NewFuelOutput)

                ### TDR_Results/Period_map.csv
                if v
                    println("Writing period map...")
                end
                CSV.write(joinpath(inpath, "inputs", Stage_Outfiles[per]["PMap"]),
                    Stage_PeriodMaps[per])

                ### TDR_Results/time_domain_reduction_settings.yml
                if v
                    println("Writing .yml settings...")
                end
                YAML.write_file(joinpath(inpath, "inputs", Stage_Outfiles[per]["YAML"]),
                    myTDRsetup)
            end

        else
            if v
                print("without Concatenation has not yet been fully implemented. ")
            end
            if v
                println("( STAGE ", stage_id, " )")
            end
            input_stage_directory = "inputs_p" * string(stage_id)
            mkpath(joinpath(inpath,
                "inputs",
                input_stage_directory,
                TimeDomainReductionFolder))

            ### TDR_Results/Demand_data.csv
            demand_in = get_demand_dataframe(joinpath(inpath,
                "inputs",
                input_stage_directory,
                mysetup["SystemFolder"]))
            demand_in[!, :Sub_Weights] = demand_in[!, :Sub_Weights] * 1.0
            demand_in[1:length(W), :Sub_Weights] .= W
            demand_in[!, :Rep_Periods][1] = length(W)
            demand_in[!, :Timesteps_per_Rep_Period][1] = TimestepsPerRepPeriod
            select!(demand_in, Not(DemandCols))
            select!(demand_in, Not(:Time_Index))
            Time_Index_M = Union{Int64, Missings.Missing}[missing
                                                          for i in 1:size(demand_in, 1)]
            Time_Index_M[1:size(DMOutputData, 1)] = 1:size(DMOutputData, 1)
            demand_in[!, :Time_Index] .= Time_Index_M

            for c in DemandCols
                new_col = Union{Float64, Missings.Missing}[missing
                                                           for i in 1:size(demand_in, 1)]
                new_col[1:size(DMOutputData, 1)] = DMOutputData[!, c]
                demand_in[!, c] .= new_col
            end
            demand_in = demand_in[1:size(DMOutputData, 1), :]

            if v
                println("Writing demand file...")
            end
            CSV.write(joinpath(inpath, "inputs", input_stage_directory, Demand_Outfile),
                demand_in)

            ### TDR_Results/Generators_variability.csv

            # Reset column ordering, add time index, and solve duplicate column name trouble with CSV.write's header kwarg
            GVColMap = Dict(RESOURCE_ZONES[i] => RESOURCES[i]
                            for i in 1:length(myinputs["RESOURCE_NAMES"]))
            GVColMap["Time_Index"] = "Time_Index"
            GVOutputData = GVOutputData[!, Symbol.(RESOURCE_ZONES)]
            insertcols!(GVOutputData, 1, :Time_Index => 1:size(GVOutputData, 1))
            NewGVColNames = [GVColMap[string(c)] for c in names(GVOutputData)]
            if v
                println("Writing resource file...")
            end
            CSV.write(joinpath(inpath, "inputs", input_stage_directory, GVar_Outfile),
                GVOutputData,
                header = NewGVColNames)

            # Break up VRE-storage components if needed
            if !isempty(myinputs["VRE_STOR"])
                gen_var = load_dataframe(joinpath(inpath,
                    "inputs",
                    input_stage_directory,
                    GVar_Outfile))

                # Find which indexes have solar PV/wind names
                RESOURCE_ZONES_VRE_STOR = NewGVColNames
                solar_col_names = []
                wind_col_names = []
                for r in 1:length(RESOURCE_ZONES_VRE_STOR)
                    if occursin("PV", RESOURCE_ZONES_VRE_STOR[r]) ||
                       occursin("pv", RESOURCE_ZONES_VRE_STOR[r]) ||
                       occursin("Pv", RESOURCE_ZONES_VRE_STOR[r]) ||
                       occursin("Solar", RESOURCE_ZONES_VRE_STOR[r]) ||
                       occursin("SOLAR", RESOURCE_ZONES_VRE_STOR[r]) ||
                       occursin("solar", RESOURCE_ZONES_VRE_STOR[r]) ||
                       occursin("Time", RESOURCE_ZONES_VRE_STOR[r])
                        push!(solar_col_names, r)
                    end
                    if occursin("Wind", RESOURCE_ZONES_VRE_STOR[r]) ||
                       occursin("WIND", RESOURCE_ZONES_VRE_STOR[r]) ||
                       occursin("wind", RESOURCE_ZONES_VRE_STOR[r]) ||
                       occursin("Time", RESOURCE_ZONES_VRE_STOR[r])
                        push!(wind_col_names, r)
                    end
                end

                # Index into dataframe and output them
                solar_var = gen_var[!, solar_col_names]
                solar_var[!, :Time_Index] = 1:size(solar_var, 1)
                wind_var = gen_var[!, wind_col_names]
                wind_var[!, :Time_Index] = 1:size(wind_var, 1)

                SolarVar_Outfile = joinpath(TimeDomainReductionFolder,
                    "Vre_and_stor_solar_variability.csv")
                WindVar_Outfile = joinpath(TimeDomainReductionFolder,
                    "Vre_and_stor_wind_variability.csv")
                CSV.write(joinpath(inpath,
                        "inputs",
                        input_stage_directory,
                        SolarVar_Outfile),
                    solar_var)
                CSV.write(joinpath(inpath,
                        "inputs",
                        input_stage_directory,
                        WindVar_Outfile),
                    wind_var)
            end

            ### TDR_Results/Fuels_data.csv

            fuel_in = load_dataframe(joinpath(inpath,
                "inputs",
                input_stage_directory,
                mysetup["SystemFolder"],
                "Fuels_data.csv"))
            select!(fuel_in, Not(:Time_Index))
            SepFirstRow = DataFrame(fuel_in[1, :])
            NewFuelOutput = vcat(SepFirstRow, FPOutputData)
            rename!(NewFuelOutput, FuelCols)
            insertcols!(NewFuelOutput, 1, :Time_Index => 0:(size(NewFuelOutput, 1) - 1))
            if v
                println("Writing fuel profiles...")
            end
            CSV.write(joinpath(inpath, "inputs", input_stage_directory, Fuel_Outfile),
                NewFuelOutput)

            ### Period_map.csv
            if v
                println("Writing period map...")
            end
            CSV.write(joinpath(inpath, "inputs", input_stage_directory, PMap_Outfile),
                PeriodMap)

            ### time_domain_reduction_settings.yml
            if v
                println("Writing .yml settings...")
            end
            YAML.write_file(joinpath(inpath, "inputs", input_stage_directory, YAML_Outfile),
                myTDRsetup)
        end
    else
        if v
            println("Outputs: Single-Stage")
        end
        mkpath(joinpath(inpath, TimeDomainReductionFolder))

        ### TDR_Results/Demand_data.csv
        system_path = joinpath(inpath, mysetup["SystemFolder"])
        demand_in = get_demand_dataframe(system_path)
        demand_in[!, :Sub_Weights] = demand_in[!, :Sub_Weights] * 1.0
        demand_in[1:length(W), :Sub_Weights] .= W
        demand_in[!, :Rep_Periods][1] = length(W)
        demand_in[!, :Timesteps_per_Rep_Period][1] = TimestepsPerRepPeriod
        select!(demand_in, Not(DemandCols))
        select!(demand_in, Not(:Time_Index))
        Time_Index_M = Union{Int64, Missings.Missing}[missing for i in 1:size(demand_in, 1)]
        Time_Index_M[1:size(DMOutputData, 1)] = 1:size(DMOutputData, 1)
        demand_in[!, :Time_Index] .= Time_Index_M

        for c in DemandCols
            new_col = Union{Float64, Missings.Missing}[missing for i in 1:size(demand_in, 1)]
            new_col[1:size(DMOutputData, 1)] = DMOutputData[!, c]
            demand_in[!, c] .= new_col
        end
        demand_in = demand_in[1:size(DMOutputData, 1), :]

        if v
            println("Writing demand file...")
        end
        CSV.write(joinpath(inpath, Demand_Outfile), demand_in)

        ### TDR_Results/Generators_variability.csv

        # Reset column ordering, add time index, and solve duplicate column name trouble with CSV.write's header kwarg
        GVColMap = Dict(RESOURCE_ZONES[i] => RESOURCES[i]
                        for i in 1:length(myinputs["RESOURCE_NAMES"]))
        GVColMap["Time_Index"] = "Time_Index"
        GVOutputData = GVOutputData[!, Symbol.(RESOURCE_ZONES)]
        insertcols!(GVOutputData, 1, :Time_Index => 1:size(GVOutputData, 1))
        NewGVColNames = [GVColMap[string(c)] for c in names(GVOutputData)]
        if v
            println("Writing resource file...")
        end
        CSV.write(joinpath(inpath, GVar_Outfile), GVOutputData, header = NewGVColNames)

        # Break up VRE-storage components if needed
        if !isempty(myinputs["VRE_STOR"])
            gen_var = load_dataframe(joinpath(inpath, GVar_Outfile))

            # Find which indexes have solar PV/wind names
            RESOURCE_ZONES_VRE_STOR = NewGVColNames
            solar_col_names = []
            wind_col_names = []
            for r in 1:length(RESOURCE_ZONES_VRE_STOR)
                if occursin("PV", RESOURCE_ZONES_VRE_STOR[r]) ||
                   occursin("pv", RESOURCE_ZONES_VRE_STOR[r]) ||
                   occursin("Pv", RESOURCE_ZONES_VRE_STOR[r]) ||
                   occursin("Solar", RESOURCE_ZONES_VRE_STOR[r]) ||
                   occursin("SOLAR", RESOURCE_ZONES_VRE_STOR[r]) ||
                   occursin("solar", RESOURCE_ZONES_VRE_STOR[r]) ||
                   occursin("Time", RESOURCE_ZONES_VRE_STOR[r])
                    push!(solar_col_names, r)
                end
                if occursin("Wind", RESOURCE_ZONES_VRE_STOR[r]) ||
                   occursin("WIND", RESOURCE_ZONES_VRE_STOR[r]) ||
                   occursin("wind", RESOURCE_ZONES_VRE_STOR[r]) ||
                   occursin("Time", RESOURCE_ZONES_VRE_STOR[r])
                    push!(wind_col_names, r)
                end
            end

            # Index into dataframe and output them
            solar_var = gen_var[!, solar_col_names]
            solar_var[!, :Time_Index] = 1:size(solar_var, 1)
            wind_var = gen_var[!, wind_col_names]
            wind_var[!, :Time_Index] = 1:size(wind_var, 1)

            SolarVar_Outfile = joinpath(TimeDomainReductionFolder,
                "Vre_and_stor_solar_variability.csv")
            WindVar_Outfile = joinpath(TimeDomainReductionFolder,
                "Vre_and_stor_wind_variability.csv")
            CSV.write(joinpath(inpath, SolarVar_Outfile), solar_var)
            CSV.write(joinpath(inpath, WindVar_Outfile), wind_var)
        end

        ### TDR_Results/Fuels_data.csv
        system_path = joinpath(inpath, mysetup["SystemFolder"])
        fuel_in = load_dataframe(joinpath(system_path, "Fuels_data.csv"))
        select!(fuel_in, Not(:Time_Index))
        SepFirstRow = DataFrame(fuel_in[1, :])
        NewFuelOutput = vcat(SepFirstRow, FPOutputData)
        rename!(NewFuelOutput, FuelCols)
        insertcols!(NewFuelOutput, 1, :Time_Index => 0:(size(NewFuelOutput, 1) - 1))
        if v
            println("Writing fuel profiles...")
        end
        CSV.write(joinpath(inpath, Fuel_Outfile), NewFuelOutput)

        ### TDR_Results/Period_map.csv
        if v
            println("Writing period map...")
        end
        CSV.write(joinpath(inpath, PMap_Outfile), PeriodMap)

        ### TDR_Results/time_domain_reduction_settings.yml
        if v
            println("Writing .yml settings...")
        end
        YAML.write_file(joinpath(inpath, YAML_Outfile), myTDRsetup)
    end

    return Dict("OutputDF" => FinalOutputData,
        "InputDF" => ClusteringInputDF,
        "ColToZoneMap" => col_to_zone_map,
        "TDRsetup" => myTDRsetup,
        "ClusterObject" => R,
        "Assignments" => A,
        "Weights" => W,
        "Centers" => M,
        "RMSE" => RMSE)
end
