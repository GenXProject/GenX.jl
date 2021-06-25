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

##############################################
#
#   Time Series Clustering, Python => Julia
#    - Jack Morris, 1/20/2021   <- Happy Inauguration Day!
#    - Renamed time_domain_reduction 3/21/2021
#
# Use kmeans or kemoids to cluster raw load profiles and resource capacity factor profiles
# into representative periods. Use Extreme Periods to capture noteworthy periods or
# periods with notably poor fits.
#
#  Inputs
#
#  In time_domain_reduction_settings.yml, include the following:
#
#  - Timesteps_per_Rep_Period - Typically 168 timesteps (e.g., hours) per period, this designates the length
#     of each representative period.
#  - UseExtremePeriods - Either 1 or 0, this designates whether or not to include
#     outliers (by performance or load/resource extreme) as their own representative periods.
#     This setting automatically includes the periods with maximum load, minimum solar cf and
#     minimum wind cf as extreme periods.
#  - ClusterMethod - Either 'kmeans' or 'kmedoids', this designates the method used to cluster
#     periods and determine each point's representative period.
#  - ScalingMethod - Either 'N' or 'S', this designates directs the module to normalize ([0,1])
#     or standardize (mean 0, variance 1) the input data.
#  - MinPeriods - The minimum number of periods used to represent the input data. If using
#     UseExtremePeriods, this must be at least three. If IterativelyAddPeriods if off,
#    this will be the total number of periods.
#  - MaxPeriods - The maximum number of periods - both clustered periods and extreme periods -
#     that may be used to represent the input data.
#  - IterativelyAddPeriods - Either 1 or 0, this designates whether or not to add periods
#     until the error threshold between input data and represented data is met or the maximum
#     number of periods is reached.
#  - Threshold - Iterative period addition will end if the period farthest (Euclidean Distance)
#     from its representative period is within this percentage of the total possible error (for normalization)
#     or ~95% of the total possible error (for standardization). E.g., for a threshold of 0.01,
#     every period must be within 1% of the spread of possible error before the clustering
#     iterations will terminate (or until the max number of periods is reached).
#  - IterateMethod - Either 'cluster' (Default) or 'extreme', this designates whether to add clusters to
#     the kmeans/kmedoids method or to set aside the worst-fitting periods as a new extreme periods.
#  - nReps - Default 200, the number of times to repeat each kmeans/kmedoids clustering at the same setting.
#  - LoadWeight - Default 1, this is an optional multiplier on load columns in order to prioritize
#     better fits for load profiles over resource capacity factor profiles.
#  - WeightTotal - Default 8760, the sum to which the relative weights of representative periods will be scaled.
#  - ClusterFuelPrices - Either 1 or 0, this indicates whether or not to use the fuel price
#     time series in Fuels_data.csv in the clustering process. If 'no', this function will still write
#     Fuels_data_clustered.csv with reshaped fuel prices based on the number and size of the
#     representative weeks, assuming a constant time series of fuel prices with length equal to the
#     number of timesteps in the raw input data.
#
#
#############################################

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

using YAML          # 0.4.2
using DataFrames    # 0.20.0
using StatsBase     # 0.33.0
using Clustering    # 0.14.1
using Distances     # 0.9.0
using Documenter    # 0.24.7
using CSV           # 0.5.23


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

Get load, solar, wind, and other curves from the input data.

"""
function parse_data(myinputs)
    RESOURCES = myinputs["RESOURCE_ZONES"]
    ZONES = myinputs["R_ZONES"]
    # Assuming no missing data
    solar_col_names = []
    wind_col_names = []
    var_col_names = []
    solar_profiles = []
    wind_profiles = []
    var_profiles = []

    # LOAD - Load_data.csv
    load_profiles = [ myinputs["pD"][:,l] for l in 1:size(myinputs["pD"],2) ]
    load_col_names = ["Load_MW_z"*string(l) for l in 1:size(load_profiles)[1]]
    load_zones = [l for l in 1:size(load_profiles)[1]]
    col_to_zone_map = Dict("Load_MW_z"*string(l) => l for l in 1:size(load_profiles)[1])

    # CAPACITY FACTORS - Generators_variability.csv
    for r in 1:length(RESOURCES)
        if occursin("PV", RESOURCES[r]) || occursin("pv", RESOURCES[r]) || occursin("Pv", RESOURCES[r]) || occursin("Solar", RESOURCES[r]) || occursin("SOLAR", RESOURCES[r]) || occursin("solar", RESOURCES[r])
            push!(solar_col_names, RESOURCES[r])
            push!(solar_profiles, myinputs["pP_Max"][r,:])
        elseif occursin("Wind", RESOURCES[r]) || occursin("WIND", RESOURCES[r]) || occursin("wind", RESOURCES[r])
            push!(wind_col_names, RESOURCES[r])
            push!(wind_profiles, myinputs["pP_Max"][r,:])
        end
        push!(var_col_names, RESOURCES[r])
        push!(var_profiles, myinputs["pP_Max"][r,:])
        col_to_zone_map[RESOURCES[r]] = ZONES[r]
    end

    fuel_col_names = string.(myinputs["fuels"])
    fuel_profiles = []
    AllFuelsConst = true
    for f in 1:length(fuel_col_names)
        push!(fuel_profiles, myinputs["fuel_costs"][fuel_col_names[f]])
        if AllFuelsConst && (minimum(myinputs["fuel_costs"][fuel_col_names[f]]) != maximum(myinputs["fuel_costs"][fuel_col_names[f]]))
            AllFuelsConst = false
        end
    end
    all_col_names = [load_col_names; var_col_names; fuel_col_names]
    all_profiles = [load_profiles..., var_profiles..., fuel_profiles...]
    return load_col_names, var_col_names, solar_col_names, wind_col_names, fuel_col_names, all_col_names,
         load_profiles, var_profiles, solar_profiles, wind_profiles, fuel_profiles, all_profiles,
         col_to_zone_map, AllFuelsConst
end


@doc raw"""
    check_condition(Threshold, R, OldColNames, ScalingMethod, TimestepsPerRepPeriod)

Check whether the greatest Euclidean deviation in the input data and the clustered
representation is within a given proportion of the "maximum" possible deviation.

(1 for Normalization covers 100%, 4 for Standardization covers ~95%)

"""
function check_condition(Threshold, R, OldColNames, ScalingMethod, TimestepsPerRepPeriod)
    if ScalingMethod == "N"
        return maximum(R.costs)/(length(OldColNames)*TimestepsPerRepPeriod) < Threshold
    elseif ScalingMethod == "S"
        return maximum(R.costs)/(length(OldColNames)*TimestepsPerRepPeriod*4) < Threshold
    else
        println("INVALID Scaling Method ", ScalingMethod, " / Choose N for Normalization or S for Standardization. Proceeding with N.")
    end
    return maximum(R.costs)/(length(OldColNames)*TimestepsPerRepPeriod) < Threshold
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
    cluster(ClusterMethod, ClusteringInputDF, NClusters, nIters)

Get representative periods using cluster centers from kmeans or kmedoids.

K-Means:
https://juliastats.org/Clustering.jl/dev/kmeans.html

K-Medoids:
 https://juliastats.org/Clustering.jl/stable/kmedoids.html
"""
function cluster(ClusterMethod, ClusteringInputDF, NClusters, nIters, v=false)
    if ClusterMethod == "kmeans"
        DistMatrix = pairwise(Euclidean(), convert(Matrix, ClusteringInputDF), dims=2)
        R = kmeans(convert(Matrix, ClusteringInputDF), NClusters, init=:kmcen)

        for i in 1:nIters
            R_i = kmeans(convert(Matrix, ClusteringInputDF), NClusters)

            if R_i.totalcost < R.totalcost
                R = R_i
            end
            if v && (i % (nIters/10) == 0)
                println(string(i) * " : " * string(round(R_i.totalcost, digits=3)) * " " * string(round(R.totalcost, digits=3)) )
            end
        end

        A = R.assignments # get points to clusters mapping - A for Assignments
        W = R.counts # get the cluster sizes - W for Weights
        Centers = R.centers # get the cluster centers - M for Medoids

        M = []
        for i in 1:NClusters
            dists = [euclidean(Centers[:,i], ClusteringInputDF[!, j]) for j in 1:size(ClusteringInputDF, 2)]
            push!(M,argmin(dists))
        end

    elseif ClusterMethod == "kmedoids"
        DistMatrix = pairwise(Euclidean(), convert(Matrix, ClusteringInputDF), dims=2)
        R = kmedoids(DistMatrix, NClusters, init=:kmcen)

        for i in 1:nIters
            R_i = kmedoids(DistMatrix, NClusters)
            if R_i.totalcost < R.totalcost
                R = R_i
            end
            if v && (i % (nIters/10) == 0)
                println(string(i) * " : " * string(round(R_i.totalcost, digits=3)) * " " * string(round(R.totalcost, digits=3)) )
            end
        end

        A = R.assignments # get points to clusters mapping - A for Assignments
        W = R.counts # get the cluster sizes - W for Weights
        M = R.medoids # get the cluster centers - M for Medoids
    else
        println("INVALID ClusterMethod. Select kmeans or kmedoids. Running kmeans instead.")
        return cluster("kmeans", ClusteringInputDF, NClusters, nIters)
    end
    return [R, A, W, M, DistMatrix]
end

@doc raw"""
    RemoveConstCols(all_profiles, all_col_names)

Remove and store the columns that do not vary during the period.

"""
function RemoveConstCols(all_profiles, all_col_names, v=false)
    ConstData = []
    ConstIdx = []
    ConstCols = []
    for c in 1:length(all_col_names)
        Const = minimum(all_profiles[c]) == maximum(all_profiles[c])
        if Const
            if v println("Removing constant col: ", all_col_names[c]) end
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
       ConstCols, load_col_names, solar_col_names, wind_col_names)

Identify extreme week by specification of profile type (Load, PV, Wind),
measurement type (absolute (timestep with min/max value) vs. integral
(period with min/max summed value)), and statistic (minimum or maximum).
I.e., the user could want the hour with the most load across the whole
system to be included among the extreme periods. They would select
"Load", "System, "Absolute, and "Max".


"""
function get_extreme_period(DF, GDF, profKey, typeKey, statKey,
    ConstCols, load_col_names, solar_col_names, wind_col_names, v=false)
    if v println(profKey," ", typeKey," ", statKey) end
    if typeKey == "Integral"
        if profKey == "Load"
            (stat, group_idx) = get_integral_extreme(GDF, statKey, load_col_names, ConstCols)
        elseif profKey == "PV"
            (stat, group_idx) = get_integral_extreme(GDF, statKey, solar_col_names, ConstCols)
        elseif profKey == "Wind"
            (stat, group_idx) = get_integral_extreme(GDF, statKey, wind_col_names, ConstCols)
        else
            println("Error: Profile Key ", profKey, " is invalid. Choose `Load', `PV' or `Wind'.")
        end
    elseif typeKey == "Absolute"
        if profKey == "Load"
            (stat, group_idx) = get_absolute_extreme(DF, statKey, load_col_names, ConstCols)
        elseif profKey == "PV"
            (stat, group_idx) = get_absolute_extreme(DF, statKey, solar_col_names, ConstCols)
        elseif profKey == "Wind"
            (stat, group_idx) = get_absolute_extreme(DF, statKey, wind_col_names, ConstCols)
        else
            println("Error: Profile Key ", profKey, " is invalid. Choose `Load', `PV' or `Wind'.")
        end
   else
       println("Error: Type Key ", typeKey, " is invalid. Choose `Absolute' or `Integral'.")
       stat = 0
       group_idx = 0
   end
    return (stat, group_idx)
end


@doc raw"""

    get_integral_extreme(GDF, statKey, col_names, ConstCols)

Get the period index with the minimum or maximum load or capacity factor
summed over the period.

"""
function get_integral_extreme(GDF, statKey, col_names, ConstCols)
    if statKey == "Max"
        (stat, stat_idx) = findmax( sum([GDF[!, Symbol(c)] for c in setdiff(col_names, ConstCols) ]) )
    elseif statKey == "Min"
        (stat, stat_idx) = findmin( sum([GDF[!, Symbol(c)] for c in setdiff(col_names, ConstCols) ]) )
    else
        println("Error: Statistic Key ", statKey, " is invalid. Choose `Max' or `Min'.")
    end
    return (stat, stat_idx)
end

@doc raw"""

    get_absolute_extreme(DF, statKey, col_names, ConstCols)

Get the period index of the single timestep with the minimum or maximum load or capacity factor.

"""
function get_absolute_extreme(DF, statKey, col_names, ConstCols)
    if statKey == "Max"
        (stat, stat_idx) = findmax( sum([DF[!, Symbol(c)] for c in setdiff(col_names, ConstCols) ]) )
        group_idx = DF.Group[stat_idx]
    elseif statKey == "Min"
        (stat, stat_idx) = findmin( sum([DF[!, Symbol(c)] for c in setdiff(col_names, ConstCols) ]) )
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
function scale_weights(W, H, v=false)
    if v println("Weights before scaling: ", W) end
    W = [ float(w)/sum(W) * H for w in W] # Scale to number of hours in input data
    if v
        println("Weights after scaling: ", W)
        println("Sum of Updated Cluster Weights: ", sum(W))
    end
    return W
end


@doc raw"""
    cluster_inputs(inpath, settings_path, v=false, norm_plot=false, silh_plot=false, res_plots=false, indiv_plots=false, pair_plots=false)

Use kmeans or kemoids to cluster raw load profiles and resource capacity factor profiles
into representative periods. Use Extreme Periods to capture noteworthy periods or
periods with notably poor fits.

In Load_data.csv, include the following:

 - Timesteps\_per\_Rep\_Period - Typically 168 timesteps (e.g., hours) per period, this designates the length
     of each representative period.
 - UseExtremePeriods - Either 1 or 0, this designates whether or not to include
    outliers (by performance or load/resource extreme) as their own representative periods.
    This setting automatically includes the periods with maximum load, minimum solar cf and
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
 - LoadWeight - Default 1, this is an optional multiplier on load columns in order to prioritize
    better fits for load profiles over resource capacity factor profiles.
 - WeightTotal - Default 8760, the sum to which the relative weights of representative periods will be scaled.
 - ClusterFuelPrices - Either 1 or 0, this indicates whether or not to use the fuel price
    time series in Fuels\_data.csv in the clustering process. If 'no', this function will still write
    Fuels\_data\_clustered.csv with reshaped fuel prices based on the number and size of the
    representative weeks, assuming a constant time series of fuel prices with length equal to the
    number of timesteps in the raw input data.
"""
function cluster_inputs(inpath, settings_path, mysetup, v=false)

    if v println(now()) end

    ##### Step 0: Load in settings and data

    myTDRsetup = YAML.load(open(joinpath(settings_path,"time_domain_reduction_settings.yml")))

    # Accept Model Parameters from the Settings File time_domain_reduction_settings.yml
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
    LoadWeight = myTDRsetup["LoadWeight"]
    WeightTotal = myTDRsetup["WeightTotal"]
    ClusterFuelPrices = myTDRsetup["ClusterFuelPrices"]
    TimeDomainReductionFolder = mysetup["TimeDomainReductionFolder"]

    Load_Outfile = joinpath(TimeDomainReductionFolder, "Load_data.csv")
    GVar_Outfile = joinpath(TimeDomainReductionFolder, "Generators_variability.csv")
    Fuel_Outfile = joinpath(TimeDomainReductionFolder, "Fuels_data.csv")
    PMap_Outfile = joinpath(TimeDomainReductionFolder, "Period_map.csv")
    YAML_Outfile = joinpath(TimeDomainReductionFolder, "time_domain_reduction_settings.yml")

    if v println("Loading inputs") end
    myinputs=Dict()
    # Define a local version of the setup so that you can modify the mysetup["ParameterScale] value to be zero in case it is 1
    mysetup_local = mysetup
    # If ParameterScale =1 then make it zero, since clustered inputs will be scaled prior to generating model
    mysetup_local["ParameterScale"]=0  # Performing cluster and report outputs in user-provided units
    myinputs = load_inputs(mysetup_local,inpath)

    if v println() end

    # LATER Replace these with collections of col_names, profiles, zones
    load_col_names, var_col_names, solar_col_names, wind_col_names, fuel_col_names, all_col_names,
         load_profiles, var_profiles, solar_profiles, wind_profiles, fuel_profiles, all_profiles,
         col_to_zone_map, AllFuelsConst = parse_data(myinputs)

    # Remove Constant Columns - Add back later in final output
    all_profiles, all_col_names, ConstData, ConstCols, ConstIdx = RemoveConstCols(all_profiles, all_col_names, v)

    IncludeFuel = true
    if (ClusterFuelPrices != 1) || (AllFuelsConst) IncludeFuel = false end

    InputData = DataFrame( Dict( all_col_names[c]=>all_profiles[c] for c in 1:length(all_col_names) ) )
    if v
        println("Load (MW) and Capacity Factor Profiles: ")
        println(describe(InputData))
        println()
    end

    OldColNames = names(InputData)
    NewColNames = [OldColNames; :GrpWeight]
    Nhours = nrow(InputData) # Timesteps


    ##### Step 1: Normalize or standardize all load, renewables, and fuel data / optionally scale with LoadWeight

    if ScalingMethod == "N"
        normProfiles = [ StatsBase.transform(fit(UnitRangeTransform, InputData[:,c]; dims=1, unit=true), InputData[:,c]) for c in 1:length(OldColNames)  ]
    elseif ScalingMethod == "S"
        normProfiles = [ StatsBase.transform(fit(ZScoreTransform, InputData[:,c]; dims=1, center=true, scale=true), InputData[:,c]) for c in 1:length(OldColNames)  ]
    else
        println("ERROR InvalidScalingMethod: Use N for Normalization or S for Standardization.")
        println("CONTINUING using 0->1 normalization...")
        normProfiles = [ StatsBase.transform(fit(UnitRangeTransform, InputData[:,c]; dims=1, unit=true), InputData[:,c]) for c in 1:length(OldColNames)  ]
    end

    AnnualTSeriesNormalized = DataFrame(Dict(  OldColNames[c] => normProfiles[c] for c in 1:length(OldColNames) ))

    if LoadWeight != 1   # If we want to value load more/less than capacity factors. Assume nonnegative.
        for c in load_col_names
            AnnualTSeriesNormalized[!, Symbol(c)] .= AnnualTSeriesNormalized[!, Symbol(c)] .* LoadWeight
        end
    end

    if v
        println("Load (MW) and Capacity Factor Profiles NORMALIZED! ")
        println(describe(AnnualTSeriesNormalized))
        println()
    end


    ##### STEP 2: Identify extreme periods in the model, Reshape data for clustering

    # Total number of subperiod available in the data set, where each subperiod length = NumGrpDays
    NumDataPoints = Nhours÷TimestepsPerRepPeriod # 364 weeks in 7 years
    if v println("Total Subperiods in the data set: ", NumDataPoints) end
    InputData[:, :Group] .= (1:Nhours) .÷ (TimestepsPerRepPeriod+0.0001) .+ 1

    cgdf = combine(groupby(InputData, :Group), [c .=> sum for c in OldColNames])
    cgdf = cgdf[setdiff(1:end, NumDataPoints+1), :]
    rename!(cgdf, [:Group; OldColNames])

    # Extreme Period Identification
    ExtremeWksList = []
    if UseExtremePeriods == 1
      for profKey in keys(ExtPeriodSelections)
          for geoKey in keys(ExtPeriodSelections[profKey])
              for typeKey in keys(ExtPeriodSelections[profKey][geoKey])
                  for statKey in keys(ExtPeriodSelections[profKey][geoKey][typeKey])
                      if ExtPeriodSelections[profKey][geoKey][typeKey][statKey] == 1
                          if geoKey == "System"
                              if v print(geoKey, " ") end
                              (stat, group_idx) = get_extreme_period(InputData, cgdf, profKey, typeKey, statKey, ConstCols, load_col_names, solar_col_names, wind_col_names, v)
                              push!(ExtremeWksList, floor(Int, group_idx))
                              if v println(group_idx, " : ", stat) end
                          elseif geoKey == "Zone"
                              for z in sort(unique(myinputs["R_ZONES"]))
                                  z_cols = [k for (k,v) in col_to_zone_map if v==z]
                                  if profKey == "Load" z_cols_type = intersect(z_cols, load_col_names)
                                  elseif profKey == "PV" z_cols_type = intersect(z_cols, solar_col_names)
                                  elseif profKey == "Wind" z_cols_type = intersect(z_cols, wind_col_names)
                                  else z_cols_type = []
                                  end
                                  z_cols_type = setdiff(z_cols_type, ConstCols)
                                  if length(z_cols_type) > 0
                                      if v print(geoKey, " ") end
                                      (stat, group_idx) = get_extreme_period(select(InputData, [:Group; Symbol.(z_cols_type)]), select(cgdf, [:Group; Symbol.(z_cols_type)]), profKey, typeKey, statKey, ConstCols, z_cols_type, z_cols_type, z_cols_type, v)
                                      push!(ExtremeWksList, floor(Int, group_idx))
                                      if v println(group_idx, " : ", stat, "(", z, ")") end
                                  else
                                      if v println("Zone ", z, " has no time series profiles of type ", profKey) end
                                  end
                              end
                          else
                              println("Error: Geography Key ", geoKey, " is invalid. Select `System' or `Zone'.")
                          end
                      end
                  end
              end
          end
      end
      if v println(ExtremeWksList) end
      sort!(unique!(ExtremeWksList))
      if v println("Reduced to ", ExtremeWksList) end
    end

    ### DATA MODIFICATION - Shifting InputData and Normalized InputData
    #    from 8760 (# hours) by n (# profiles) DF to
    #    168*n (n period-stacked profiles) by 52 (# periods) DF

    DFsToConcat = [stack(InputData[isequal.(InputData.Group,w),:], OldColNames)[!,:value] for w in 1:NumDataPoints if w <= NumDataPoints ]
    ModifiedData = DataFrame(Dict(i => DFsToConcat[i] for i in 1:NumDataPoints))

    AnnualTSeriesNormalized[:, :Group] .= (1:Nhours) .÷ (TimestepsPerRepPeriod+0.0001) .+ 1
    DFsToConcatNorm = [stack(AnnualTSeriesNormalized[isequal.(AnnualTSeriesNormalized.Group,w),:], OldColNames)[!,:value] for w in 1:NumDataPoints if w <= NumDataPoints ]
    ModifiedDataNormalized = DataFrame(Dict(i => DFsToConcatNorm[i] for i in 1:NumDataPoints))

    NClusters = MinPeriods
    if UseExtremePeriods == 1
        ClusteringInputDF = select(ModifiedDataNormalized, Not(ExtremeWksList))
        if v println("Post-removal: ", names(ClusteringInputDF)) end
        NClusters -= length(ExtremeWksList)
    else
        ClusteringInputDF = ModifiedDataNormalized
    end


    ##### STEP 3: Clustering

    cluster_results = []

    # Cluster once regardless of iteration decisions
    push!(cluster_results, cluster(ClusterMethod, ClusteringInputDF, NClusters, nReps, v))

    # Iteratively add worst periods as extreme periods OR increment number of clusters k
    #    until threshold is met or maximum periods are added (If chosen in inputs)
    if (Iterate == 1)
        while (!check_condition(Threshold, last(cluster_results)[1], OldColNames, ScalingMethod, TimestepsPerRepPeriod)) & ((length(ExtremeWksList)+NClusters) < MaxPeriods)
            if IterateMethod == "cluster"
                if v println("Adding a new Cluster! ") end
                NClusters += 1
                push!(cluster_results, cluster(ClusterMethod, ClusteringInputDF, NClusters, nReps, v))
            elseif (IterateMethod == "extreme") & (UseExtremePeriods == 1)
                if v println("Adding a new Extreme Period! ") end
                worst_period_idx = get_worst_period_idx(last(cluster_results)[1])
                removed_period = string(names(ClusteringInputDF)[worst_period_idx])
                select!(ClusteringInputDF, Not(worst_period_idx))
                push!(ExtremeWksList, parse(Int, removed_period))
                if v println(worst_period_idx, " (", removed_period, ") ", ExtremeWksList) end
                push!(cluster_results, cluster(ClusterMethod, ClusteringInputDF, NClusters, nReps, v))
            elseif IterateMethod == "extreme"
                println("INVALID IterateMethod ", IterateMethod, " because UseExtremePeriods is off. Set to 1 if you wish to add extreme periods.")
                break
            else
                println("INVALID IterateMethod ", IterateMethod, ". Choose 'cluster' or 'extreme'.")
                break
            end
        end
        if v && (length(ExtremeWksList)+NClusters == MaxPeriods)
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

    # K-medoids returns indices from DistMatrix as its medoids.
    #   This does not account for missing extreme weeks.
    #   This is corrected retroactively here.
    M = [parse(Int64, string(names(ClusteringInputDF)[i])) for i in M]
    if v println("Fixed M: ", M) end


    ##### Step 4: Aggregation
    # Add the subperiods corresponding to the extreme periods back into the data.
    # Rescaling weights to account for partial period cut out.
    # If we want to rescale to ensure total demand is equal, we should
    #   do that here too.
    #      - Would we add a constant multiplier just to load columns? Does this change the daily/weekly representation too much?
    #      - Should the the weighted total load be equal with respect to each zone?

    ExtremeWksList = sort(ExtremeWksList)
    if UseExtremePeriods == 1
        if v println("Extreme Periods: ", ExtremeWksList) end
        M = [M; ExtremeWksList]
        for w in 1:length(ExtremeWksList)
            insert!(A, ExtremeWksList[w], NClusters+w)
            push!(W, 1)
        end
        NClusters += length(ExtremeWksList) #NClusers from this point forward is the ending number of periods
    end

    N = W  # Keep cluster version of weights stored as N, number of periods represented by RP
    W = scale_weights(W, WeightTotal, v)

    # SORT A W M in conjunction, chronologically by M, before handling them elsewhere to be consistent
    # A points to an index of M. We need it to point to a new index of sorted M.
    old_M = M
    df_sort = DataFrame( Weights = W, NumPeriods = N, Rep_Period = M)
    sort!(df_sort, [:Rep_Period])
    W = df_sort[!, :Weights]
    N = df_sort[!, :NumPeriods]
    M = df_sort[!, :Rep_Period]
    AssignMap = Dict( i => findall(x->x==old_M[i], M)[1] for i in 1:length(M))
    A = [AssignMap[a] for a in A]

    # Make PeriodMap
    PeriodMap = DataFrame(Period_Index = 1:length(A),
                            Rep_Period = [M[a] for a in A],
                            Rep_Period_Index = [a for a in A])

    # Get column names by type for later analysis
    LoadCols = [Symbol("Load_MW_z"*string(i)) for i in 1:length(load_col_names) ]
    VarCols = [Symbol(var_col_names[i]) for i in 1:length(var_col_names) ]
    FuelCols = [Symbol(fuel_col_names[i]) for i in 1:length(fuel_col_names) ]
    ConstCol_Syms = [Symbol(ConstCols[i]) for i in 1:length(ConstCols) ]

    # SCALE LOAD - The reprsentative period's load times the number of periods it represents
    #  should equal the total load of all the periods it represents (within each load zone)
    MultMap = Dict()
    for m in 1:NClusters
        MultMap[M[m]] = Dict()
        periods_represented = findall(x->x==m, A)
        for loadcol in LoadCols
            ### ADD HERE
            if loadcol ∉ ConstCol_Syms
                persums = [sum(InputData[(TimestepsPerRepPeriod*(i-1)+1):(TimestepsPerRepPeriod*i),loadcol]) for i in periods_represented]
                multiplier = sum(persums) / (N[m]*sum(InputData[(TimestepsPerRepPeriod*(M[m]-1)+1):(TimestepsPerRepPeriod*M[m]),loadcol]))
                MultMap[M[m]][loadcol] = multiplier
            end
        end
    end

    # Cluster Ouput: The original data at the medoids/centers
    ClusterOutputData = ModifiedData[:,M]

    # Reorganize Data by Load, Solar, Wind, Fuel, and GrpWeight by Hour, Add Constant Data Back In
    rpDFs = [] # Representative Period DataFrames - Load and Resource Profiles
    gvDFs = [] # Generators Variability DataFrames - Just Resource Profiles
    lpDFs = [] # Load Profile DataFrames - Just Load Profiles
    fpDFs = [] # Fuel Profile DataFrames - Just Fuel Profiles
    Ncols = length(NewColNames) - 1
    for m in 1:NClusters
        rpDF = DataFrame( Dict( NewColNames[i] => ClusterOutputData[!,m][TimestepsPerRepPeriod*(i-1)+1 : TimestepsPerRepPeriod*i] for i in 1:Ncols) )
        gvDF = DataFrame( Dict( NewColNames[i] => ClusterOutputData[!,m][TimestepsPerRepPeriod*(i-1)+1 : TimestepsPerRepPeriod*i] for i in 1:Ncols if (NewColNames[i] in VarCols)) )
        lpDF = DataFrame( Dict( NewColNames[i] => ClusterOutputData[!,m][TimestepsPerRepPeriod*(i-1)+1 : TimestepsPerRepPeriod*i] for i in 1:Ncols if (NewColNames[i] in LoadCols)) )
        if IncludeFuel fpDF = DataFrame( Dict( NewColNames[i] => ClusterOutputData[!,m][TimestepsPerRepPeriod*(i-1)+1 : TimestepsPerRepPeriod*i] for i in 1:Ncols if (NewColNames[i] in FuelCols)) ) end
        if !IncludeFuel fpDF = DataFrame(Placeholder = 1:TimestepsPerRepPeriod) end
        # Add Constant Columns back in
        for c in 1:length(ConstCols)
            rpDF[!,Symbol(ConstCols[c])] .= ConstData[c][1]
            if Symbol(ConstCols[c]) in VarCols
                gvDF[!,Symbol(ConstCols[c])] .= ConstData[c][1]
            elseif Symbol(ConstCols[c]) in FuelCols
                fpDF[!,Symbol(ConstCols[c])] .= ConstData[c][1]
            elseif Symbol(ConstCols[c]) in LoadCols
                lpDF[!,Symbol(ConstCols[c])] .= ConstData[c][1]
            end
        end
        if !IncludeFuel select!(fpDF, Not(:Placeholder)) end

        # Scale Load using previously identified multipliers
        #   Scale lpDF but not rpDF which compares to input data but is not written to file.
        for loadcol in LoadCols
            if loadcol ∉ ConstCol_Syms
                lpDF[!,loadcol] .*= MultMap[M[m]][loadcol]
            end
        end

        rpDF[!,:GrpWeight] .= W[m]
        rpDF[!,:Cluster] .= M[m]
        push!(rpDFs, rpDF)
        push!(gvDFs, gvDF)
        push!(lpDFs, lpDF)
        push!(fpDFs, fpDF)
    end
    FinalOutputData = vcat(rpDFs...)  # For comparisons with input data to evaluate clustering process
    GVOutputData = vcat(gvDFs...)     # Generators Variability
    LPOutputData = vcat(lpDFs...)     # Load Profiles
    FPOutputData = vcat(fpDFs...)     # Load Profiles


    ##### Step 5: Evaluation

    InputDataTest = InputData[(InputData.Group .<= NumDataPoints*1.0), :]
    ClusterDataTest = vcat([rpDFs[a] for a in A]...) # To compare fairly, load is not scaled here
    RMSE = Dict( c => rmse_score(InputDataTest[:, c], ClusterDataTest[:, c])  for c in OldColNames)


    ##### Step 6: Print to File

    if mysetup["MacOrWindows"]=="Mac"
		sep = "/"
	else
		sep = "\U005c"
	end

    mkpath(joinpath(inpath, TimeDomainReductionFolder))

    ### Load_data_clustered.csv
    load_in = DataFrame(CSV.File(string(inpath,sep,"Load_data.csv"), header=true), copycols=true) #Setting header to false doesn't take the names of the columns; not including it, not including copycols, or, setting copycols to false has no effect
    load_in[!,:Sub_Weights] = load_in[!,:Sub_Weights] * 1.
    load_in[1:length(W),:Sub_Weights] .= W
    load_in[!,:Rep_Periods][1] = length(W)
    load_in[!,:Timesteps_per_Rep_Period][1] = TimestepsPerRepPeriod
    select!(load_in, Not(LoadCols))
    select!(load_in, Not(:Time_Index))
    Time_Index_M = Union{Int64, Missings.Missing}[missing for i in 1:size(load_in,1)]
    Time_Index_M[1:size(LPOutputData,1)] = 1:size(LPOutputData,1)
    load_in[!,:Time_Index] .= Time_Index_M

    for c in LoadCols
        new_col = Union{Float64, Missings.Missing}[missing for i in 1:size(load_in,1)]
        new_col[1:size(LPOutputData,1)] = LPOutputData[!,c]
        load_in[!,c] .= new_col
    end

    if v println("Writing load file...") end
    CSV.write(string(inpath,sep,Load_Outfile), load_in)

    ### Generators_variability_clustered.csv

    # Reset column ordering, add time index, and solve duplicate column name trouble with CSV.write's header kwarg
    GVColMap = Dict(myinputs["RESOURCE_ZONES"][i] => myinputs["RESOURCES"][i] for i in 1:length(myinputs["RESOURCES"]))
    GVColMap["Time_Index"] = "Time_Index"
    GVOutputData = GVOutputData[!, Symbol.(myinputs["RESOURCE_ZONES"])]
    insertcols!(GVOutputData, 1, :Time_Index => 1:size(GVOutputData,1))
    NewGVColNames = [GVColMap[string(c)] for c in names(GVOutputData)]
    if v println("Writing resource file...") end
    CSV.write(string(inpath,sep,GVar_Outfile), GVOutputData, header=NewGVColNames)

    ### Fuels_data_clustered.csv

    fuel_in = DataFrame(CSV.File(string(inpath,sep,"Fuels_data.csv"), header=true), copycols=true)
    select!(fuel_in, Not(:Time_Index))
    SepFirstRow = DataFrame(fuel_in[1, :])
    NewFuelOutput = vcat(SepFirstRow, FPOutputData)
    rename!(NewFuelOutput, FuelCols)
    insertcols!(NewFuelOutput, 1, :Time_Index => 0:size(NewFuelOutput,1)-1)
    if v println("Writing fuel profiles...") end
    CSV.write(string(inpath,sep,Fuel_Outfile), NewFuelOutput)

    ### Period_map.csv
    if v println("Writing period map...") end
    CSV.write(string(inpath,sep,PMap_Outfile), PeriodMap)

    ### time_domain_reduction_settings.yml
    if v println("Writing .yml settings...") end
    YAML.write_file(string(inpath,sep,YAML_Outfile), myTDRsetup)

    return FinalOutputData, W, RMSE, myTDRsetup, col_to_zone_map
end
