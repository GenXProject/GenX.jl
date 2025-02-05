@doc raw"""
	write_nse(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for reporting non-served energy for every model zone, time step and cost-segment.
"""
function write_nse(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones
    SEG = inputs["SEG"] # Number of demand curtailment segments
    # Non-served energy/demand curtailment by segment in each time step
    dfNse = DataFrame(Segment = repeat(1:SEG, outer = Z),
        Zone = repeat(1:Z, inner = SEG),
        AnnualSum = zeros(SEG * Z))
    nse = zeros(SEG * Z, T)
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
    for z in 1:Z
        nse[((z - 1) * SEG + 1):(z * SEG), :] = value.(EP[:vNSE])[:, :, z] * scale_factor
    end
    dfNse.AnnualSum .= nse * inputs["omega"]

    if setup["WriteOutputs"] == "annual"
        total = DataFrame(["Total" 0 sum(dfNse[!, :AnnualSum])],
            [:Segment, :Zone, :AnnualSum])
        dfNse = vcat(dfNse, total)
        #CSV.write(joinpath(path, setup["WriteResultsNamesDict"]["nse"]), dfNse)
        write_output_file(joinpath(path, setup["WriteResultsNamesDict"]["nse"]),
                dfNse, 
                filetype = setup["ResultsFileType"], 
                compression = setup["ResultsCompressionType"])
    else # setup["WriteOutputs"] == "full"
        dfNse = hcat(dfNse, DataFrame(nse, :auto))
        auxNew_Names = [Symbol("Segment");
                        Symbol("Zone");
                        Symbol("AnnualSum");
                        [Symbol("t$t") for t in 1:T]]
        rename!(dfNse, auxNew_Names)

        total = DataFrame(["Total" 0 sum(dfNse[!, :AnnualSum]) fill(0.0, (1, T))], :auto)
        total[:, 4:(T + 3)] .= sum(nse, dims = 1)
        rename!(total, auxNew_Names)
        dfNse = vcat(dfNse, total)
        #=
        # Maya: Cast zones as floats
        dfNse[!,:Zone] = convert.(Float64,dfNse[!,:Zone])

        dfNse = dftranspose(dfNse, false)
        rename!(dfNse, Symbol.(Vector(dfNse[1,:])))
        dfNse = dfNse[2:end,:]
        dfNse[!,2:end] = convert.(Float64,dfNse[!,2:end])=#

        CSV.write(joinpath(path, setup["WriteResultsNamesDict"]["nse"]), dftranspose(dfNse, false), writeheader = false)
        #=write_output_file(joinpath(path, setup["WriteResultsNamesDict"]["nse"]),
                dftranspose(dfNse, false), 
                filetype = setup["ResultsFileType"], 
                compression = setup["ResultsCompressionType"])=#

       #= if setup["OutputFullTimeSeries"] == 1 && setup["TimeDomainReduction"] == 1
            write_full_time_series_reconstruction(path, setup, dfNse, "nse")
            @info("Writing Full Time Series for NSE")
        end=#
    end
    return nothing
end
