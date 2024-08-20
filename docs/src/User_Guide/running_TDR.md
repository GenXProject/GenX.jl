# Running a case with Time Domain Reduction

There are two ways to run a case with a reduced (e.g. less than full-year) temporal resolution.
1. Let GenX perform the time domain reduction before optimizing.
2. Bring your own clustered data

It's also possible for GenX perform clustering separately from the optimization task. 

## Method 1: Let GenX perform the time domain reduction (clustering)

Set `TimeDomainReduction: 1 `in the GenX settings for the case.

When the case is run (but before the optimization model is built), reduced time series data will be output to a folder within the case, (typically) `TDR_results`. Note that if the data already exists in that folder, it will not be overwritten. If a user wants to change the time domain reduction settings and try again, the folder should be deleted before the case is run.

The clustering is done according to the settings in `time_domain_reduction.yml`. These are described in the Inputs section of data_documentation.

Time domain clustering can only be performed on data which represents a single contiguous period: typically a year of 8760 or 8736 hours.

The header of the file `Demand_data.csv` in the main case folder will typically look like this:

```
..., Rep_Periods, Timesteps_per_Rep_Period, Sub_Weights, ...
               1,                     8760,        8760,
```

## Method 2: Bring your own clustered data

The second method is to use an external program to generate the reduced ('clustered') time series data. For instance, PowerGenome has a capability to construct GenX cases with clustered time series data.

Running using this method **requires** setting `TimeDomainReduction: 0` in the GenX settings for the case.

Clustered time series data requires specifying the clustering data using three columns in `Demand_data.csv`: `Rep_Periods`, `Timesteps_per_Rep_Period`, and `Sub_Weights`. For example, a problem representing a full year via 3 representative weeks, and where the first week represents one which is twice as common as the others, would look like

```
..., Rep_Periods, Timesteps_per_Rep_Period, Sub_Weights, ...
               3,                      168,      4368.0,
                                                 2184.0,
                                                 2184.0,
```

In this example, the first week represents a total of `26*168 = 4368` hours over a full year.

The time series data are written in single unbroken columns: in this example, the `Time_Index` ranges from 1 to 504.

For problems involving Long Duration Storage, a file `Period_map.csv` is necessary to describe how these representative periods occur throughout the modeled year.

See also the [Time-domain reduction](@ref).

## Performing time domain reduction (TDR) separately from optimization
*Added in 0.3.4*

It may be useful to perform time domain reduction (TDR) (or "clustering") on a set of inputs before using them as part of full GenX optimization task. For example, a user might want to test various TDR settings and examine the resulting clustered inputs. This can now be performed using the run_timedomainreduction! function.

```
$ julia --project=/home/youruser/GenX

julia> using GenX
julia> run_timedomainreduction!("/path/to/case")
```

This function will obey the settings in `path/to/case/settings/time_domain_reduction_settings.yml`. It will output the resulting clustered time series files in the case.

Running this function will overwrite these files in the case. This is done with the expectation that the user is trying out various settings.