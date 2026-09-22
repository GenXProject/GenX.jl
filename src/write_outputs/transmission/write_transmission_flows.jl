@doc raw"""
    fold_lines_to_corridors(inputs::Dict, data::AbstractArray)

Fold a per-line quantity from the (possibly expanded) solved network back to the original
user-provided corridors by summing the rows that belong to each corridor.

When discrete-build lines are present, `load_network_data!` rebuilds the network so each
discrete new line is its own row (see `expand_discrete_build_lines`), giving the solved model more
lines than the user's `Network.csv`. `LINE_MAP_ORIGINAL` maps each expanded line index back to its
original corridor; all the expanded lines of a corridor share the same orientation
(`Start_Zone`/`End_Zone` are copied), so summing them yields the corridor total. When no rebuild
occurred (`LINE_MAP_ORIGINAL` absent) the mapping is the identity and the data is returned unchanged.

`data` may be an `L`-vector or an `L×T` matrix. Returns `(corridors, folded)` where `corridors` is
the sorted vector of original corridor indices used as the output `Line` column.
"""
function fold_lines_to_corridors(inputs::Dict, data::AbstractArray)
    L = inputs["L"]
    line_map = get(inputs, "LINE_MAP_ORIGINAL", Dict(l => l for l in 1:L))
    corridors = sort(unique(values(line_map)))
    pos = Dict(o => k for (k, o) in enumerate(corridors))

    if ndims(data) == 1
        folded = zeros(eltype(data), length(corridors))
        for l in 1:L
            folded[pos[line_map[l]]] += data[l]
        end
    else
        folded = zeros(eltype(data), length(corridors), size(data, 2))
        for l in 1:L
            folded[pos[line_map[l]], :] .+= @view data[l, :]
        end
    end
    return corridors, folded
end

function write_transmission_flows(path::AbstractString,
        inputs::Dict,
        setup::Dict,
        EP::Model)
    # Transmission related values
    T = inputs["T"]     # Number of time steps (hours)
    # Power flows on transmission lines at each time step
    flow = value.(EP[:vFLOW])
    if setup["ParameterScale"] == 1
        flow *= ModelScalingFactor
    end

    # Fold expanded lines back to original corridors (identity when no discrete-build rebuild).
    corridors, flow = fold_lines_to_corridors(inputs, flow)
    dfFlow = DataFrame(Line = corridors)

    filepath = joinpath(path, "flow.csv")
    if setup["WriteOutputs"] == "annual"
        dfFlow.AnnualSum = flow * inputs["omega"]
        total = DataFrame(["Total" sum(dfFlow.AnnualSum)], [:Line, :AnnualSum])
        dfFlow = vcat(dfFlow, total)
        CSV.write(filepath, dfFlow)
    else # setup["WriteOutputs"] == "full"
        dfFlow = hcat(dfFlow, DataFrame(flow, :auto))
        auxNew_Names = [Symbol("Line"); [Symbol("t$t") for t in 1:T]]
        rename!(dfFlow, auxNew_Names)
        CSV.write(filepath, dftranspose(dfFlow, false), writeheader = false)

        if setup["OutputFullTimeSeries"] == 1 && setup["TimeDomainReduction"] == 1
            write_full_time_series_reconstruction(path, setup, dfFlow, "flow")
            @info("Writing Full Time Series for Transmission Flows")
        end
    end
    return nothing
end
