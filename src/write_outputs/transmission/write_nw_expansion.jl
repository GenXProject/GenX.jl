@doc raw"""
    network_expansion_dataframe(inputs::Dict, setup::Dict; cont_value, disc_value)

Build the `network_expansion.csv` table, folding results from the (possibly expanded) per-line
solve back to the original user-provided corridors.

When discrete integer-build lines are present, `load_network_data!` rebuilds the network so each
discrete new line is its own row (see `expand_integer_build_lines`), so the solved model has more
lines than the user's `Network.csv`. `LINE_MAP_ORIGINAL` maps each expanded line index back to the
original corridor index; here we use it to aggregate both the continuous reinforcement
(`vNEW_TRANS_CAP`) and the discrete builds (`vNEW_TRANS_LINES`) up to one row per original corridor.
When no rebuild occurred (`LINE_MAP_ORIGINAL` absent) the mapping is the identity, so the output is
one row per line exactly as before.

`cont_value(l)` returns the continuous reinforcement of expanded line `l` (only called for
`l in EXPANSION_LINES`); `disc_value(l)` returns the binary build decision of expanded line `l`
(only called for `l in INTEGER_BUILD_LINES`). Passing these as callbacks lets the monolithic and
Benders writers share this logic while reading their respective solutions.
"""
function network_expansion_dataframe(inputs::Dict, setup::Dict;
        cont_value::Function, disc_value::Function)
    L = inputs["L"]     # Number of (expanded) transmission lines
    scale = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    EXPANSION_LINES = get(inputs, "EXPANSION_LINES", Int[])
    INTEGER_BUILD_LINES = get(inputs, "INTEGER_BUILD_LINES", Int[])
    pC = inputs["pC_Line_Reinforcement"]                          # reinforcement cost per line
    line_size = get(inputs, "Line_Reinforcement_Cap_Size", Float64[])  # discrete line size per line

    # Map each expanded line to its original corridor (identity when no integer-build rebuild occurred).
    line_map = get(inputs, "LINE_MAP_ORIGINAL", Dict(l => l for l in 1:L))
    corridors = sort(unique(values(line_map)))
    pos = Dict(o => k for (k, o) in enumerate(corridors))
    n = length(corridors)

    cont_cap = zeros(n)     # continuous capacity added per corridor
    disc_cap = zeros(n)     # discrete capacity added per corridor
    n_disc = zeros(Int, n)  # number of discrete lines built per corridor
    cost = zeros(n)         # total annualized reinforcement cost per corridor

    for l in 1:L
        k = pos[line_map[l]]
        if l in EXPANSION_LINES
            v = cont_value(l)
            cont_cap[k] += v
            cost[k] += v * pC[l]
        end
        if l in INTEGER_BUILD_LINES
            b = disc_value(l)
            n_disc[k] += round(Int, b)
            disc_cap[k] += b * line_size[l]
            cost[k] += b * line_size[l] * pC[l]
        end
    end

    total_cap = cont_cap .+ disc_cap

    return DataFrame(Line = corridors,
        New_Continuous_Capacity = convert(Array{Float64}, cont_cap * scale),
        Num_Discrete_Lines_Built = n_disc,
        New_Discrete_Capacity = convert(Array{Float64}, disc_cap * scale),
        New_Trans_Capacity = convert(Array{Float64}, total_cap * scale),
        Cost_Trans_Capacity = convert(Array{Float64}, cost * scale^2))
end

function write_nw_expansion(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    dfTransCap = network_expansion_dataframe(inputs, setup;
        cont_value = l -> value(EP[:vNEW_TRANS_CAP][l]),
        disc_value = l -> value(EP[:vNEW_TRANS_LINES][l]))

    CSV.write(joinpath(path, "network_expansion.csv"), dfTransCap)
end
