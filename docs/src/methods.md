# Methods
## Time Domain Reduction

Rather than modeling and optimizing power grid operations at a high temporal resolution (e.g., hourly) while evaluating new capacity investments, which can be computationally expensive for large-scale studies with several resources,  it may be useful to consider a reduced temporal resolution to model annual grid operations. Such a time-domain reduction is often employed in CEMs as a way to balance model spatial and temporal resolution as well as representation of dispatch, while ensuring reasonable computational times.  The time-domain reduction method provided allows the user to automate these feature by specifying the various parameters related to the time-domain reduction algorithm (via time\_domain\_reduction\_settings.yml described under  Model Inputs/Outputs documentations/Inputs), including the desired level of temporal resolution to be used in formulating the resulting optimization model.

```@autodocs
Modules = [GenX]
Pages = ["time_domain_reduction.jl"]
Order = [:type, :function]
```

## Multi-Period Modeling

GenX can be configured for multi-period modeling with perfect foresight. The dual dynamic program (DDP) algorithm is a well-known approach for solving multi-period optimization problems in a computationally efficient manner, first proposed by Pereira and
Pinto (1991). This algorithm splits up a multi-period investment planning problem into multiple, single-period sub-problems. Each period is solved iteratively as a separate linear program sub-problem (“forward pass”), and information from future periods is shared with past periods (“backwards pass”) so that investment decisions made in subsequent iterations reflect the contributions of present-day investments to future costs. Multi-period modeling functionality is designed as a "wrapper" around GenX, and to the extent possible, existing methods were left unchanged.

The time-domain reduction method provided allows the user to automate these feature by specifying the various parameters related to the time-domain reduction algorithm (via time\_domain\_reduction\_settings.yml described under  Model Inputs/Outputs documentations/Inputs), including the desired level of temporal resolution to be used in formulating the resulting optimization model.

```@autodocs
Modules = [GenX]
Pages = ["dual_dynamic_programing.jl"]
Order = [:type, :function]
```

```@autodocs
Modules = [GenX]
Pages = ["configure_multi_period_inputs.jl"]
Order = [:type, :function]
```

```@autodocs
Modules = [GenX]
Pages = ["investment_multi_period.jl"]
Order = [:type, :function]

```@autodocs
Modules = [GenX]
Pages = ["storage_multi_period.jl"]
Order = [:type, :function]

```@autodocs
Modules = [GenX]
Pages = ["transmission_multi_period.jl"]
Order = [:type, :function]

```@autodocs
Modules = [GenX]
Pages = ["write_capacity_multi_period.jl"]
Order = [:type, :function]