# Time Domain Reduction (TDR)

Rather than modeling and optimizing power grid operations at a high temporal resolution (e.g., hourly, over a full year) while evaluating new capacity investments, which can be computationally expensive for large-scale studies with several resources, it may be useful to consider a reduced temporal resolution to model annual grid operations.
Such a time-domain reduction is often employed in capacity expansion models as a way to balance model spatial and temporal resolution as well as representation of dispatch, while ensuring reasonable computational times.
The time-domain reduction method provided allows the user to automate these features while specifying the various parameters of the time-domain reduction 'clustering' algorithm to be used in formulating the resulting optimization model.

### Running a case with Time Domain Reduction

There are two ways to run a case with a reduced (e.g. less than full-year) temporal resolution.
1. Let GenX perform the time domain reduction before optimizing.
2. Bring your own clustered data

It's also possible for GenX perform clustering separately from the optimization task. Check out the [Running the TDR](@ref) section for more information. 