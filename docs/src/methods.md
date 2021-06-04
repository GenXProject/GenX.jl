# Methods
## Time Domain Reduction

Rather than modeling and optimizing power grid operations at a high temporal resolution (e.g., hourly) while evaluating new capacity investments, which can be computationally expensive for large-scale studies with several resources,  it may be useful to consider a reduced temporal resolution to model annual grid operations. Such a time-domain reduction is often employed in CEMs as a way to balance model spatial and temporal resolution as well as representation of dispatch, while ensuring reasonable computational times.  The time-domain reduction method provided allows the user to automate these feature by specifying the various parameters related to the time-domain reduction algorithm (via time\_domain\_reduction\_settings.yml described under  Model Inputs/Outputs documentations/Inputs), including the desired level of temporal resolution to be used in formulating the resulting optimization model.

```@autodocs
Modules = [GenX]
Pages = ["time_domain_reduction.jl"]
Order = [:type, :function]
```
