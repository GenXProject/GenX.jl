# Methods
## Time Domain Reduction (TDR)

Rather than modeling and optimizing power grid operations at a high temporal resolution (e.g., hourly, over a full year) while evaluating new capacity investments, which can be computationally expensive for large-scale studies with several resources, it may be useful to consider a reduced temporal resolution to model annual grid operations.
Such a time-domain reduction is often employed in capacity expansion models as a way to balance model spatial and temporal resolution as well as representation of dispatch, while ensuring reasonable computational times.
The time-domain reduction method provided allows the user to automate these features while specifying the various parameters of the time-domain reduction 'clustering' algorithm to be used in formulating the resulting optimization model.

### Running a case with Time Domain Reduction

There are two ways to run a case with a reduced (e.g. less than full-year) temporal resolution.
1. Let GenX perform the time domain reduction before optimizing.
2. Bring your own clustered data

It's also possible for GenX perform clustering separately from the optimization task.

### Method 1: Let GenX perform the time domain reduction (clustering)

Set `TimeDomainReduction: 1` in the GenX settings for the case.

When the case is run (but before the optimization model is built), 
reduced time series data will be output to a folder within the case, (typically) `TDR_Results`.
Note that if the data already exists in that folder, it will *not* be overwritten.
If a user wants to change the time domain reduction settings and try again, the folder should be deleted before the case is run.

The clustering is done according to the settings in `time_domain_reduction.yml`.
These are described in the Inputs section of [data_documentation](data_documentation.md).

Time domain clustering can only be performed on data which represents a single contiguous period: typically a year of 8760 or 8736 hours.

The header of the file `Load_data.csv` in the main case folder will typically look like this:
```
..., Rep_Periods, Timesteps_per_Rep_Period, Sub_Weights, ...
               1,                     8760,        8760,
```

For an example that uses this method, see `Example_Systems/RealSystemExample/ISONE_Singlezone`.

Note that for co-located VRE and storage resources, if GenX performs the time domain reduction clustering, all variable renewable energy variabilities must be in the `Generators_variability.csv` in addition to these files existing in the inputs folder because GenX will separate the wind and solar PV capacity factors after the clustering has been completed into `Vre_and_stor_solar_variability.csv` and `Vre_and_stor_wind_variability.csv`. However, if a user brings their own clustered data, these three files must be separated by the user (and no co-located VRE variabilities should be found in `Generators_variability.csv`).

### Method 2: Bring your own clustered data
The second method is to use an external program to generate the reduced ('clustered') time series data.
For instance, [PowerGenome](https://github.com/PowerGenome/PowerGenome) has a capability to construct GenX cases with clustered time series data.

Running using this method **requires** setting `TimeDomainReduction: 0` in the GenX settings for the case.

Clustered time series data requires specifying the clustering data using three columns in `Load_data.csv`: `Rep_Periods`, `Timesteps_per_Rep_Period`, and `Sub_Weights`.
For example, a problem representing a full year via 3 representative weeks, and where the first week represents one which is twice as common as the others, would look like

```
..., Rep_Periods, Timesteps_per_Rep_Period, Sub_Weights, ...
               3,                      168,      4368.0,
                                                 2184.0,
                                                 2184.0,
```
In this example, the first week represents a total of `26*168 = 4368` hours over a full year.

The time series data are written in single unbroken columns: in this example, the `Time_Index` ranges from 1 to 504.

For problems involving Long Duration Storage, a file `Period_map.csv` is necessary to describe how these representative periods occur throughout the modeled year.

See also the Inputs section of [data_documentation](data_documentation.md).

For an example that uses this method, see `Example_Systems/RealSystemExample/ISONE_Trizone`.

### Performing time domain reduction (TDR) separately from optimization
_Added in 0.3.4_

It may be useful to perform time domain reduction (TDR) (or "clustering") on a set of inputs before using them as part of full GenX optimization task.
For example, a user might want to test various TDR settings and examine the resulting clustered inputs.
This can now be performed using the `run_timedomainreduction!` function.

```
> julia --project=/home/youruser/GenX

julia> using GenX
julia> run_timedomainreduction!("/path/to/case")
```

This function will obey the settings in `path/to/case/Settings/time_domain_reduction_settings.yml`.
It will output the resulting clustered time series files in the case.

Running this function will *overwrite* these files in the case.
This is done with the expectation that the user is trying out various settings.


### Developer's docs for internal functions related to time domain reduction

```@autodocs
Modules = [GenX]
Pages = ["time_domain_reduction.jl"]
Order = [:type, :function]
```

## Multi-Stage Modeling

GenX can be configured for multi-stage modeling with perfect foresight. The dual dynamic program (DDP) algorithm is a well-known approach for solving multi-stage optimization problems in a computationally efficient manner, first proposed by Pereira and
Pinto (1991). This algorithm splits up a multi-stage investment planning problem into multiple, single-period sub-problems. Each period is solved iteratively as a separate linear program sub-problem (“forward pass”), and information from future periods is shared with past periods (“backwards pass”) so that investment decisions made in subsequent iterations reflect the contributions of present-day investments to future costs. Multi-period modeling functionality is designed as a "wrapper" around GenX, and to the extent possible, existing methods were left unchanged.

The time-domain reduction method provided allows the user to automate these feature by specifying the various parameters related to the time-domain reduction algorithm (via time\_domain\_reduction\_settings.yml described under  Model Inputs/Outputs documentations/Inputs), including the desired level of temporal resolution to be used in formulating the resulting optimization model.

```@autodocs
Modules = [GenX]
Pages = ["dual_dynamic_programming.jl"]
Order = [:type, :function]
```

```@autodocs
Modules = [GenX]
Pages = ["configure_multi_stage_inputs.jl"]
Order = [:type, :function]
```

```@autodocs
Modules = [GenX]
Pages = ["investment_multi_stage.jl"]
Order = [:type, :function]
```

```@autodocs
Modules = [GenX]
Pages = ["storage_multi_stage.jl"]
Order = [:type, :function]
```

```@autodocs
Modules = [GenX]
Pages = ["transmission_multi_stage.jl"]
Order = [:type, :function]
```

```@autodocs
Modules = [GenX]
Pages = ["write_capacity_multi_stage.jl"]
Order = [:type, :function]
```
