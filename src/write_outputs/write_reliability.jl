@doc raw"""
	write_reliability(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for reporting dual variable of maximum non-served energy constraint (shadow price of reliability constraint) for each model zone and time step.
"""
function write_reliability(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones

    # reliability: Dual variable of maximum NSE constraint = shadow value of reliability constraint
    dfReliability = DataFrame(Zone = 1:Z)
    # Dividing dual variable for each hour with corresponding hourly weight to retrieve marginal cost of generation
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
    dfReliability = hcat(dfReliability,
        DataFrame(transpose(dual.(EP[:cMaxNSE]) ./ inputs["omega"] * scale_factor), :auto))

    auxNew_Names = [Symbol("Zone"); [Symbol("t$t") for t in 1:T]]
    rename!(dfReliability, auxNew_Names)

    CSV.write(joinpath(path, "reliability.csv"),
        dftranspose(dfReliability, false),
        header = false)

    if setup["OutputFullTimeSeries"] == 1 & setup["TimeDomainReduction"] == 1
        DFnames = ["Zone", "1", "2", "3"]
        FullTimeSeriesFolder = setup["OutputFullTimeSeriesFolder"]
        output_path = joinpath(path, FullTimeSeriesFolder)
        dfOut_full = full_time_series_reconstruction(
            path, setup, dftranspose(dfReliability, false), DFnames)
        CSV.write(joinpath(output_path, "reliability.csv"), dfOut_full, header = false)
        println("Writing Full Time Series for Reliability")
    end
end
