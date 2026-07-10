@doc raw"""
    load_network_data!(setup::Dict, path::AbstractString, inputs_nw::Dict)

Function for reading input parameters related to the electricity transmission network
"""
function load_network_data!(setup::Dict, path::AbstractString, inputs_nw::Dict)
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    filename = "Network.csv"
    network_var = load_dataframe(joinpath(path, filename))

    # If there are any integer-build lines, rebuild the network_var dataframe so that each
    # discrete new line becomes its own row (with its own flow variable downstream). Everything
    # below derives per-line inputs positionally from network_var, so this expansion propagates
    # to the whole model with no further changes required here.
    if setup["IntegerInvestments"] == 1 && "Integer_Build" in names(network_var) && any(skipmissing(network_var.Integer_Build) .== 1)
        # LINE_MAP_ORIGINAL maps each expanded line index => the original CSV line index, so that
        # per-line results (e.g. flows) can be summed back to the user-provided corridors.
        # INTEGER_BUILD_LINE_GROUPS lists the discrete new-line indices for each corridor with more
        # than one new line, for build-order (symmetry-breaking) constraints.
        network_var, inputs_nw["LINE_MAP_ORIGINAL"], inputs_nw["INTEGER_BUILD_LINE_GROUPS"] = expand_integer_build_lines(network_var)
    end

    as_vector(col::Symbol) = collect(skipmissing(network_var[!, col]))
    to_floats(col::Symbol) = convert(Array{Float64}, as_vector(col))

    # Number of zones in the network
    Z = length(as_vector(:Network_zones))
    inputs_nw["Z"] = Z
    # Number of lines in the network
    L = length(as_vector(:Network_Lines))
    inputs_nw["L"] = L

    # Topology of the network source-sink matrix
    inputs_nw["pNet_Map"] = load_network_map(network_var, Z, L)

    # Transmission capacity of the network (in MW)
    inputs_nw["pTrans_Max"] = to_floats(:Line_Max_Flow_MW) / scale_factor  # convert to GW

    if setup["Trans_Loss_Segments"] == 1
        # Line percentage Loss - valid for case when modeling losses as a fixed percent of absolute value of power flows
        inputs_nw["pPercent_Loss"] = to_floats(:Line_Loss_Percentage)
    elseif setup["Trans_Loss_Segments"] >= 2
        # Transmission line voltage (in kV)
        inputs_nw["kV"] = to_floats(:Line_Voltage_kV)
        # Transmission line resistance (in Ohms) - Used when modeling quadratic transmission losses
        inputs_nw["Ohms"] = to_floats(:Line_Resistance_Ohms)
    end

    ## Inputs for the DC-OPF
    if setup["DC_OPF"] == 1
        println("Reading DC-OPF values...")
        # Transmission line voltage (in kV)
        line_voltage_kV = to_floats(:Line_Voltage_kV)
        # Transmission line reactance (in Ohms)
        line_reactance_Ohms = to_floats(:Line_Reactance_Ohms)
        # Line angle limit (in radians)
        inputs_nw["Line_Angle_Limit"] = to_floats(:Angle_Limit_Rad)
        # DC-OPF coefficient for each line (in MW when not scaled, in GW when scaled) 
        # MW = (kV)^2/Ohms 
        inputs_nw["pDC_OPF_coeff"] = ((line_voltage_kV .^ 2) ./ line_reactance_Ohms) /
                                     scale_factor
    end

    # Maximum possible flow after reinforcement for use in linear segments of piecewise approximation
    inputs_nw["pTrans_Max_Possible"] = inputs_nw["pTrans_Max"]

    if setup["NetworkExpansion"] == 1
        # Read between zone network reinforcement costs per peak MW of capacity added
        inputs_nw["pC_Line_Reinforcement"] = to_floats(:Line_Reinforcement_Cost_per_MWyr) /
                                             scale_factor # convert to million $/GW/yr with objective function in millions
        # Maximum reinforcement allowed in MW
        #NOTE: values <0 indicate no expansion possible
        inputs_nw["pMax_Line_Reinforcement"] = map(x -> max(0, x),
            to_floats(:Line_Max_Reinforcement_MW)) / scale_factor # convert to GW
        inputs_nw["pTrans_Max_Possible"] += inputs_nw["pMax_Line_Reinforcement"]
    end

    # Multi-Stage
    if setup["MultiStage"] == 1 
        # Weighted Average Cost of Capital for Transmission Expansion
        if setup["NetworkExpansion"] >= 1
            inputs_nw["transmission_WACC"] = to_floats(:WACC)
            inputs_nw["Capital_Recovery_Period_Trans"] = to_floats(:Capital_Recovery_Period)
        end

        # Max Flow Possible on Each Line
        inputs_nw["pLine_Max_Flow_Possible_MW"] = to_floats(:Line_Max_Flow_Possible_MW) /
                                                  scale_factor # Convert to GW
    end

    # Transmission line (between zone) loss coefficient (resistance/voltage^2)
    inputs_nw["pTrans_Loss_Coef"] = zeros(Float64, L)
    if setup["Trans_Loss_Segments"] == 1
        inputs_nw["pTrans_Loss_Coef"] = inputs_nw["pPercent_Loss"]
    elseif setup["Trans_Loss_Segments"] >= 2
        # If zones are connected, loss coefficient is R/V^2 where R is resistance in Ohms and V is voltage in Volts
        inputs_nw["pTrans_Loss_Coef"] = (inputs_nw["Ohms"] / 10^6) ./
                                        (inputs_nw["kV"] / 10^3)^2 * scale_factor # 1/GW ***
    end

    ## Sets and indices for transmission losses and expansion
    inputs_nw["TRANS_LOSS_SEGS"] = setup["Trans_Loss_Segments"] # Number of segments used in piecewise linear approximations quadratic loss functions
    inputs_nw["LOSS_LINES"] = findall(inputs_nw["pTrans_Loss_Coef"] .!= 0) # Lines for which loss coefficients apply (are non-zero);

    if setup["NetworkExpansion"] == 1
        # Discrete integer-build lines get their own binary build variable (vNEW_TRANS_LINES), so
        # they must be identified before EXPANSION_LINES and then excluded from it - otherwise they
        # would also receive a continuous vNEW_TRANS_CAP and be double-counted in eAvail_Trans_Cap.
        if setup["IntegerInvestments"] == 1
            if "Integer_Build" in names(network_var)
                integer_vals = collect(skipmissing(network_var[!, :Integer_Build]))
                inputs_nw["INTEGER_BUILD_LINES"] = findall(x -> x == 1, integer_vals)
            else
                inputs_nw["INTEGER_BUILD_LINES"] = Int[]
            end

            if "New_Line_Cap_Size_MW" in names(network_var)
                inputs_nw["Line_Reinforcement_Cap_Size"] = to_floats(:New_Line_Cap_Size_MW) / scale_factor # convert to GW
            else
                error("Network.csv is missing the New_Line_Cap_Size_MW column, which is required when IntegerInvestments = 1.")
            end

            if "BigM" in names(network_var)
                inputs_nw["BigM"] = to_floats(:BigM) / scale_factor # convert to GW
            else
                inputs_nw["BigM"] = inputs_nw["Line_Reinforcement_Cap_Size"] * 10 # default BigM value if not provided
            end
        else
            inputs_nw["INTEGER_BUILD_LINES"] = Int[]
        end

        # Network lines eligible for continuous reinforcement have non-negative maximum reinforcement
        # inputs; discrete integer-build lines are handled separately and excluded here. The raw
        # (unclamped) reinforcement column is used for the eligibility test so that lines flagged with
        # a negative value - including the residual rows of a from-zero integer-build corridor - are
        # genuinely excluded (pMax_Line_Reinforcement clamps negatives to 0, which would include them).
        inputs_nw["EXPANSION_LINES"] = setdiff(
            findall(to_floats(:Line_Max_Reinforcement_MW) .>= 0),
            inputs_nw["INTEGER_BUILD_LINES"])
    end

    println(filename * " Successfully Read!")

    return network_var
end

@doc raw"""
    expand_integer_build_lines(network_var::DataFrame)

Rebuild the transmission network dataframe so that discrete new lines each become their own row.

Returns a tuple `(df, line_map, line_groups)`:
  - `df` is the rebuilt dataframe.
  - `line_map` is a `Dict{Int, Int}` mapping each new (expanded) line index `1:new_L` to the
    original line index it was derived from. Downstream results (e.g. `write_transmission_flows`)
    are written one row per expanded line index, so `line_map` lets those results be summed back to
    the original user-provided corridors. It is the dictionary form of the `Original_Line_Index`
    column.
  - `line_groups` is a `Vector{Vector{Int}}` listing the discrete new-line indices for each corridor
    that produced more than one new line (e.g. `[[10, 11, 12, 13]]`). Used later to impose a
    build-order constraint on identical parallel lines to remove degenerate (symmetric) solutions.

For every line with `Integer_Build == 1`, the number of discrete new lines is
`floor(Line_Max_Reinforcement_MW / New_Line_Cap_Size_MW)`, treating `Line_Max_Reinforcement_MW` as
the *additional* capacity allowed on top of the existing `Line_Max_Flow_MW`. Each new line is a
copy of the original line's row except:
  - `Line_Max_Flow_MW` is set to 0 (no pre-existing capacity),
  - `Line_Max_Reinforcement_MW` is set to `New_Line_Cap_Size_MW` (its own discrete size),
  - `Integer_Build` stays 1 (marking it as a discrete buildable line).

The residual "existing" line row keeps its `Line_Max_Flow_MW`, has `Integer_Build` reset to 0, and
has `Line_Max_Reinforcement_MW` set negative so it is excluded from continuous expansion (all new
capacity comes from the discrete lines instead).

An `Original_Line_Index` column is added so the corridor a row belongs to can be recovered later.

The dataframe mixes zone-indexed columns (the leading label column and `Network_zones`, length Z)
with line-indexed columns (length L); only the line rows are expanded, leaving each zone column's
`skipmissing` sequence unchanged.
"""
function expand_integer_build_lines(network_var::DataFrame)
    cols = names(network_var)

    # Line-indexed rows are those with a non-missing Network_Lines entry.
    line_rows = findall(!ismissing, network_var[!, :Network_Lines])
    L_orig = length(line_rows)

    # The leading (label) column and Network_zones are zone-indexed; everything else is
    # line-indexed and gets expanded.
    zone_cols = Set{String}([cols[1], "Network_zones"])
    line_cols = [c for c in cols if !(c in zone_cols)]

    # Per-line values (indexed 1:L_orig) for the columns that drive the split.
    lineval(col) = [network_var[r, col] for r in line_rows]
    ib_vals = lineval(:Integer_Build)
    reinf_vals = lineval(:Line_Max_Reinforcement_MW)
    size_vals = "New_Line_Cap_Size_MW" in cols ? lineval(:New_Line_Cap_Size_MW) :
                fill(missing, L_orig)

    is_int_build(p) = !ismissing(ib_vals[p]) && ib_vals[p] == 1

    # Build the expanded ordering as (source_line, role) pairs, with the existing line immediately
    # followed by its discrete new lines.
    order = Tuple{Int, Symbol}[]
    for p in 1:L_orig
        push!(order, (p, :existing))
        is_int_build(p) || continue
        sz = size_vals[p]
        if ismissing(sz) || sz <= 0
            error("Network line $(p) has Integer_Build = 1 but a missing or non-positive " *
                  "New_Line_Cap_Size_MW. A positive discrete line size is required.")
        end
        # Line_Max_Reinforcement_MW is the additional capacity allowed on top of the existing
        # Line_Max_Flow_MW, so the number of discrete new lines is that amount divided by the size.
        additional_mw = reinf_vals[p]
        n_new = additional_mw <= 0 ? 0 : floor(Int, additional_mw / sz)
        if n_new > 0 && !isapprox(n_new * sz, additional_mw)
            @warn "Network line $(p): additional reinforcement ($(additional_mw) MW) is not an " *
                  "integer multiple of New_Line_Cap_Size_MW ($(sz) MW); building $(n_new) " *
                  "discrete line(s) totaling $(n_new * sz) MW."
        end
        for _ in 1:n_new
            push!(order, (p, :new))
        end
    end
    new_L = length(order)

    # Rebuild each line column by copying the source line's value for every emitted row.
    new_line_data = Dict{String, Vector}()
    for c in line_cols
        src = [network_var[r, c] for r in line_rows]
        new_line_data[c] = [src[p] for (p, _) in order]
    end
    orig_index = [p for (p, _) in order]

    # Per-role overrides.
    for (i, (p, role)) in enumerate(order)
        if role == :new
            new_line_data["Line_Max_Flow_MW"][i] = 0
            new_line_data["Line_Max_Reinforcement_MW"][i] = size_vals[p]
            new_line_data["Integer_Build"][i] = 1
        elseif is_int_build(p) # residual existing line of an integer-build corridor
            new_line_data["Integer_Build"][i] = 0
            # Disable continuous expansion on the existing line; all new capacity now comes from
            # the discrete lines (excluded from EXPANSION_LINES since reinforcement < 0).
            new_line_data["Line_Max_Reinforcement_MW"][i] = -1
        end
    end
    # Renumber Network_Lines sequentially so the values stay 1..new_L.
    new_line_data["Network_Lines"] = collect(1:new_L)

    # Assemble the rebuilt dataframe. Line columns occupy the first new_L rows; zone columns keep
    # their original values. Pad the shorter dimension with missing.
    Z = length(collect(skipmissing(network_var[!, :Network_zones])))
    nrows = max(new_L, Z)
    pad(v) = vcat(v, fill(missing, nrows - length(v)))

    df = DataFrame()
    for c in cols
        df[!, c] = c in zone_cols ? pad(collect(network_var[!, c])) : pad(new_line_data[c])
    end
    df[!, :Original_Line_Index] = pad(orig_index)

    # Dictionary form of the mapping: new (expanded) line index => original line index.
    line_map = Dict{Int, Int}(i => orig_index[i] for i in 1:new_L)

    # Group the discrete new-line indices by original corridor, keeping only corridors that
    # produced more than one new line. Each entry is the list of expanded line indices for one
    # corridor (e.g. [10, 11, 12, 13]). Used later to impose a build-order constraint on these
    # identical parallel lines to remove degenerate (symmetric) solutions.
    new_by_orig = Dict{Int, Vector{Int}}()
    for (i, (p, role)) in enumerate(order)
        role == :new || continue
        push!(get!(new_by_orig, p, Int[]), i)
    end
    line_groups = [new_by_orig[p]
                   for p in 1:L_orig if haskey(new_by_orig, p) && length(new_by_orig[p]) > 1]

    return df, line_map, line_groups
end

@doc raw"""
    load_network_map_from_list(network_var::DataFrame, Z, L, list_columns)

Loads the network map from a list-style interface
```
..., Network_Lines, Start_Zone, End_Zone, ...
                 1,           1,       2,
                 2,           1,       3,
```
"""
function load_network_map_from_list(network_var::DataFrame, Z, L, list_columns)
    start_col, end_col = list_columns
    mat = zeros(L, Z)
    start_zones = collect(skipmissing(network_var[!, start_col]))
    end_zones = collect(skipmissing(network_var[!, end_col]))
    for l in 1:L
        mat[l, start_zones[l]] = 1
        mat[l, end_zones[l]] = -1
    end
    mat
end

@doc raw"""
    load_network_map_from_matrix(network_var::DataFrame, Z, L)

Loads the network map from a matrix-style interface
```
..., Network_Lines, z1, z2, z3, ...
                 1,  1, -1,  0,
                 2,  1,  0, -1,
```
This is equivalent to the list-style interface where the zone zN with entry +1 is the
starting zone of the line and the zone with entry -1 is the ending zone of the line.
"""
function load_network_map_from_matrix(network_var::DataFrame, Z, L)
    # Topology of the network source-sink matrix
    network_map_matrix_format_deprecation_warning()
    col = findall(s -> s == "z1", names(network_var))[1]
    mat = Matrix{Float64}(network_var[1:L, col:(col + Z - 1)])
end

function load_network_map(network_var::DataFrame, Z, L)
    columns = names(network_var)

    list_columns = ["Start_Zone", "End_Zone"]
    has_network_list = all([c in columns for c in list_columns])

    zones_as_strings = ["z" * string(i) for i in 1:Z]
    has_network_matrix = all([c in columns for c in zones_as_strings])

    instructions = """The transmission network should be specified in the form of a matrix
           (with columns z1, z2, ... zN) or in the form of lists (with Start_Zone, End_Zone),
           but not both. See the documentation for examples."""

    if has_network_list && has_network_matrix
        error("two types of transmission network map were provided.\n" * instructions)
    elseif !(has_network_list || has_network_matrix)
        error("no transmission network map was detected.\n" * instructions)
    elseif has_network_list
        load_network_map_from_list(network_var, Z, L, list_columns)
    elseif has_network_matrix
        load_network_map_from_matrix(network_var, Z, L)
    end
end

function network_map_matrix_format_deprecation_warning()
    @warn """Specifying the network map as a matrix is deprecated as of v0.4
  and will be removed in v0.5. Instead, use the more compact list-style format.

  ..., Network_Lines, Start_Zone, End_Zone, ...
                   1,          1,        2,
                   2,          1,        3,
                   3,          2,        3,
  """ maxlog=1
end
