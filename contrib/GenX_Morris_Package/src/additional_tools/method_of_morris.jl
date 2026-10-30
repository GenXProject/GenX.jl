# Change History:
# 2026-10 — Shane Menezes
#
# Extended the GenX Morris-based global sensitivity analysis framework
# for the New York 2040 capacity expansion planning system:
#
# - Added configurable demand and fuel-price multipliers.
# - Added resource-specific screening parameters and eligibility controls.
# - Added validation for screening configurations and trajectory processing.
# - Added run-level input/output tracking.
# - Expanded system-wide and zonally resolved diagnostic outputs.
# - Added BFPS-inspired sensitivity indices based on conditional
#   output-mean differences.
#
# Research reference:
# Menezes, S., & Patankar, N. (2026). "Zonal Global Sensitivity Analysis
# for Policy-Constrained Capacity Expansion Planning in New York."
# 11th North American International Conference on Industrial Engineering
# and Operations Management. https://doi.org/10.46254/NA11.20260328

const SEED = 1234
using Statistics
using DataFrames
using JuMP
using Random
using RecursiveArrayTools

@doc raw"""
	morris(EP::Model, path::AbstractString, setup::Dict, inputs::Dict, outpath::AbstractString, OPTIMIZER)

We apply the Method of Morris developed by [Morris, M., 1991](https://www.jstor.org/stable/1269043) in order to identify the input parameters that produce the largest change on total system cost. Method of Morris falls under the simplest class of one-factor-at-a-time (OAT) screening techniques. It assumes l levels per input factor and erates a set of trajectories through the input space. As such, the Method of Morris erates a grid of uncertain model input parameters, $x_i, i=1, ..., k$,, where the range $[x_i^{-}, x_i^{+}$ of each uncertain input parameter i is split into l intervals of equal length. Each trajectory starts at different realizations of input parameters chosen at random and are built by successively selecting one of the inputs randomly and moving it to an adjacent level. These trajectories are used to estimate the mean and the standard deviation of each input parameter on total system cost. A high estimated mean indicates that the input parameter is important; a high estimated standard deviation indicates important interactions between that input parameter and other inputs.
"""
struct MatSpread{T1, T2}
    mat::T1
    spread::T2
end

struct MorrisResult{T1, T2}
    means::T1
    means_star::T1
    variances::T1
    elementary_effects::T2
end

struct InputOutputPair{T1, T2}
    trajectory_number::Int
    run_index::Int
    inputs::T1
    output::T2
end

# --- BFPS Sensitivity Index Functions ---
"""
    bfps_sensitivity(X::Matrix, Y::Vector, input_index::Int)

Purpose:
    For each sampled value of one input, compare the mean output conditional
    on that value with the mean of the full output sample `Y`. Aggregate the
    squared shifts, weighted by each input value's frequency.

Arguments:
    - `X`: Sample matrix; rows are runs and columns are input dimensions.
    - `Y`: Output value for each run.
    - `input_index`: Column of `X` identifying the input to analyze.

Returns:
    `(xi_W2_sq, iota)`. `xi_W2_sq` is the frequency-weighted squared difference
    between each conditional output mean and the full-sample output mean; the
    name is retained for compatibility. `iota` is `xi_W2_sq` normalized by
    twice the population variance of the full output sample `Y` and can be
    used to rank inputs by their conditional-mean shifts. 
"""
function bfps_sensitivity(X::Matrix, Y::Vector, input_index::Int)
    xi_values = unique(X[:, input_index])
    n_samples = length(Y)
    μY = mean(Y)
    weighted_sum = 0.0
    
    for xi in xi_values
        # indices where Xi == xi
        idx = findall(x -> x == xi, X[:, input_index])
        # conditional outputs
        Y_cond = Y[idx]
        μY_cond = mean(Y_cond)
        
        # Squared shift from this conditional mean to the full-sample mean.
        W2_sq = (μY - μY_cond)^2
        
        # weight by frequency
        weighted_sum += length(idx) * W2_sq
    end
    
    # normalize by total samples
    xi_W2_sq = weighted_sum / n_samples
    
    # normalized sensitivity
    iota = xi_W2_sq / (2 * var(Y, corrected=false))
    
    return xi_W2_sq, iota
end

"""
    calculate_and_print_bfps_indices(input_output_pairs;
        input_labels=String[], output_labels=String[], bfps_output_path="")

Calculate and report BFPS optimal transport-inspired normalized conditional-mean shift indices for each input
and output.

The function extracts the sampled inputs and model outputs from
`input_output_pairs`. For each output and input, it compares the conditional
mean at each sampled input value with the mean across the full output sample,
weights squared shifts by their input-value frequencies, and normalizes by
twice the full-sample output variance. Results are printed and, when
`bfps_output_path` is non-empty, written to a CSV file. The resulting `iota`
values can be used to rank inputs by these shifts.

Keyword arguments:
- `input_labels`: Optional labels for the input dimensions.
- `output_labels`: Optional labels for the output dimensions.
- `bfps_output_path`: Optional path for the CSV results; no file is written
  when this is empty.

Returns:
    `nothing`. If fewer than two runs are supplied, reports that there is
    insufficient data and returns without calculating indices.

"""
function calculate_and_print_bfps_indices(input_output_pairs;
        input_labels::Vector{String} = String[],
        output_labels::Vector{String} = String[],
        bfps_output_path::String = "")
    # 1. Extract inputs (X) and outputs (Y) from the pairs
    # Convert array of input vectors to a single matrix
    X = Matrix(reduce(hcat, [pair.inputs for pair in input_output_pairs])')

    # Extract outputs.
    Y_raw = [pair.output for pair in input_output_pairs]
    n_samples = length(Y_raw)
    if n_samples < 2
        println("\n--- BFPS Sensitivity Indices ---")
        println("Not enough data to calculate sensitivity indices.")
        println("--------------------------------\n")
        return
    end

    n_samples_X, n_inputs = size(X)
    n_samples_X == n_samples || error("Input/output sample mismatch in BFPS: X has $n_samples_X samples, outputs have $n_samples")

    # Build output matrix with one scalar Y vector per output dimension.
    first_output = Y_raw[1]
    Y_mat = if first_output isa AbstractVector
        n_outputs = length(first_output)
        zeros(Float64, n_samples, n_outputs)
    else
        zeros(Float64, n_samples, 1)
    end

    for r in 1:n_samples
        y = Y_raw[r]
        if y isa AbstractVector
            yv = collect(y)
            if length(yv) != size(Y_mat, 2)
                error("Inconsistent output vector lengths in BFPS at run $r: expected $(size(Y_mat, 2)), got $(length(yv))")
            end
            Y_mat[r, :] .= Float64.(yv)
        else
            Y_mat[r, 1] = Float64(y)
        end
    end

    # 2. Compute and print indices for all inputs and each output separately
    println("\n--- BFPS Sensitivity Indices ---")
    println("Total Samples: $n_samples")
    println("Number of Inputs: $n_inputs")
    println("Number of Outputs: $(size(Y_mat, 2))")
    println("--------------------------------")

    if !isempty(input_labels) && length(input_labels) != n_inputs
        println("BFPS label note: using Morris input labels by index where available ($(length(input_labels)) labels for $n_inputs inputs).")
    end

    bfps_rows = NamedTuple{(:Output, :OutputMean, :OutputVariance, :InputIndex, :InputLabel, :Xi_W2_sq, :Iota),
        Tuple{String, Float64, Float64, Int64, String, Float64, Float64}}[]

    for j in 1:size(Y_mat, 2)
        Y = Y_mat[:, j]
        out_name = (length(output_labels) == size(Y_mat, 2)) ? output_labels[j] : "Output $j"
        varY = var(Y, corrected=false)

        println("Output: $out_name")
        println("  Mean (μY): $(round(mean(Y), digits=2))")
        println("  Variance (Var(Y)): $(round(varY, digits=2))")

        if varY == 0
            println("  Variance is zero. Skipping BFPS for this output.")
            println("--------------------------------")
            continue
        end

        for i in 1:n_inputs
            xi_W2_sq, iota = bfps_sensitivity(X, Y, i)
            input_name = (i <= length(input_labels) && !isempty(strip(input_labels[i]))) ? input_labels[i] : "Input $i"
            println("  $(input_name): ξ_W2^2 = $(round(xi_W2_sq, digits=2)), ι = $(round(iota, digits=2))")
            push!(bfps_rows,
                (Output = String(out_name),
                    OutputMean = Float64(mean(Y)),
                    OutputVariance = Float64(varY),
                    InputIndex = Int64(i),
                    InputLabel = String(input_name),
                    Xi_W2_sq = Float64(xi_W2_sq),
                    Iota = Float64(iota)))
        end
        println("--------------------------------")
    end
    println()

    if !isempty(strip(bfps_output_path))
        bfps_df = DataFrame(bfps_rows)
        CSV.write(bfps_output_path, bfps_df)
        println("BFPS sensitivity indices written to: $(bfps_output_path)")
    end
end

"""
    _ensure_output_df(writer_result)

Convert a writer result into a `DataFrame`.

A `DataFrame` is returned unchanged. If `writer_result` is a string path,
the CSV at that path is read and returned as a `DataFrame`. Any other
result type raises an error.

Returns:
    A `DataFrame` containing the writer output.
"""
function _ensure_output_df(writer_result)
    if writer_result isa DataFrame
        return writer_result
    elseif writer_result isa AbstractString
        return CSV.read(writer_result, DataFrame)
    else
        error("Unexpected writer output type: $(typeof(writer_result)). Expected DataFrame or String path.")
    end
end

"""
    _csv_snapshot(path)

Create a snapshot of CSV files in the specified directory.

Arguments:
    path::AbstractString: Directory path to scan for CSV files.

Returns:
    A dictionary mapping CSV file paths to their last modification times.
"""
function _csv_snapshot(path::AbstractString)
    files = filter(f -> endswith(lowercase(f), ".csv"), readdir(path; join = true))
    snapshot = Dict{String, Float64}()
    for file in files
        snapshot[file] = try
            Float64(stat(file).mtime)
        catch
            0.0
        end
    end
    return snapshot
end

"""
    _recently_written_csvs(before, after)

Identify CSV files that have been modified between two snapshots.

Arguments:
    before::Dict{String, Float64}: Snapshot of CSV files before writing.
    after::Dict{String, Float64}: Snapshot of CSV files after writing.

Returns:
    An array of CSV file paths that have been modified.
"""
function _recently_written_csvs(before::Dict{String, Float64}, after::Dict{String, Float64})
    changed = String[]
    for (file, t_after) in after
        t_before = get(before, file, -Inf)
        if t_after > t_before
            push!(changed, file)
        end
    end
    return changed
end

"""
    _run_writer_as_df(writer_fn::Function, path::AbstractString)

Run a writer function and return its output as a `DataFrame`.

If the writer returns a `DataFrame`, it is returned directly. If it returns a
file path, that CSV is read into a `DataFrame`. If it returns `nothing`, the
function compares CSV modification times before and after running the writer
and reads the changed CSV; if multiple CSVs changed, it selects the most
recently modified one.

Throws an error if the writer result cannot be resolved to a `DataFrame`.

Returns:
    A `DataFrame` containing the writer output.
"""
function _run_writer_as_df(writer_fn::Function, path::AbstractString)
    before = _csv_snapshot(path)
    writer_result = writer_fn()

    if writer_result isa DataFrame || writer_result isa AbstractString
        return _ensure_output_df(writer_result)
    end

    if writer_result === nothing
        after = _csv_snapshot(path)
        changed = _recently_written_csvs(before, after)
        if length(changed) == 1
            return CSV.read(changed[1], DataFrame)
        elseif length(changed) > 1
            latest = sort(changed; by = f -> get(after, f, -Inf), rev = true)[1]
            return CSV.read(latest, DataFrame)
        end
    end

    error("Unexpected writer output type: $(typeof(writer_result)). Expected DataFrame, String path, or a writer that updates a CSV in the output path.")
end

"""
    _compute_curtailment_by_zone(inputs::Dict, setup::Dict, EP::Model)

Calculate annual renewable-energy curtailment and aggregate it by zone.

Curtailment is computed from available renewable generation capacity and
modeled generation. The calculation accounts for solar inverter efficiency
where applicable, applies the model scale factor when parameter scaling is
enabled, weights by `inputs["omega"]`, and sums across resources in each zone.

Arguments:
- `inputs`: Model input data, including resource, zone, generation-profile,
  and time-weight information.
- `setup`: Model configuration, including the `ParameterScale` setting.
- `EP`: Solved JuMP model containing the capacity and generation variables.

Returns:
    A vector of total weighted curtailment by zone.
"""
function _compute_curtailment_by_zone(inputs::Dict, setup::Dict, EP::Model)
    gen = inputs["RESOURCES"]
    G = inputs["G"]
    T = inputs["T"]
    VRE = inputs["VRE"]
    VRE_STOR = inputs["VRE_STOR"]
    weight = inputs["omega"]
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    curtailment = zeros(G, T)
    curtailment[VRE, :] = (value.(EP[:eTotalCap][VRE]) .* inputs["pP_Max"][VRE, :] .-
                           value.(EP[:vP][VRE, :]))

    if !isempty(VRE_STOR)
        SOLAR = setdiff(inputs["VS_SOLAR"], inputs["VS_WIND"])
        WIND = setdiff(inputs["VS_WIND"], inputs["VS_SOLAR"])
        SOLAR_WIND = intersect(inputs["VS_SOLAR"], inputs["VS_WIND"])
        if !isempty(SOLAR)
            curtailment[SOLAR, :] = (value.(EP[:eTotalCap_SOLAR][SOLAR]).data .*
                                     inputs["pP_Max_Solar"][SOLAR, :] .-
                                     value.(EP[:vP_SOLAR][SOLAR, :]).data) .*
                                    etainverter.(gen[SOLAR])
        end
        if !isempty(WIND)
            curtailment[WIND, :] = (value.(EP[:eTotalCap_WIND][WIND]).data .*
                                    inputs["pP_Max_Wind"][WIND, :] .-
                                    value.(EP[:vP_WIND][WIND, :]).data)
        end
        if !isempty(SOLAR_WIND)
            curtailment[SOLAR_WIND, :] = ((value.(EP[:eTotalCap_SOLAR])[SOLAR_WIND].data .*
                                           inputs["pP_Max_Solar"][SOLAR_WIND, :] .-
                                           value.(EP[:vP_SOLAR][SOLAR_WIND, :]).data) .*
                                          etainverter.(gen[SOLAR_WIND]) .+
                                          (value.(EP[:eTotalCap_WIND][SOLAR_WIND]).data .*
                                           inputs["pP_Max_Wind"][SOLAR_WIND, :] .-
                                           value.(EP[:vP_WIND][SOLAR_WIND, :]).data))
        end
    end

    annual_by_resource = (curtailment .* scale_factor) * weight
    zonal_curtailment = zeros(Float64, inputs["Z"])
    for (rid, z) in enumerate(zone_id.(gen))
        zonal_curtailment[Int(z)] += annual_by_resource[rid]
    end
    return zonal_curtailment
end

"""
    system_outputs_table(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Collect system-wide output metrics from a solved model.

The function obtains cost and capacity data from the model’s output writers,
calculates emissions, average price, curtailment, transmission expansion,
transmission flow, and transmission losses, then assembles the metrics into a
single-row `DataFrame`. Some output writers also write their usual files to
`path`.

Arguments:
- `path`: Directory used by the output writers.
- `inputs`: Model input data used to calculate weighted and zonal metrics.
- `setup`: Model settings, including the parameter-scaling configuration.
- `EP`: Solved JuMP model containing the objective and decision variables.

Returns:
    A one-row `DataFrame` containing the system-level output metrics.
"""
function system_outputs_table(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    # System Costs
    SystemTotalCost = value(EP[:eObj])
    dfCost = _run_writer_as_df(path) do
        write_costs(path, inputs, setup, EP)
    end
    SystemTotalCostCheck = dfCost[1, :Total]  # row 1 = cTotal

    # Emissions
    write_emissions(path, inputs, setup, EP)
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
    emissions_by_zone = value.(EP[:eEmissionsByZone])
    SystemEmissions = sum(emissions_by_zone .* reshape(inputs["omega"], 1, :)) * scale_factor

    # Prices
    price_matrix = locational_marginal_price(EP, inputs, setup)
    SystemPrice = mean(price_matrix)

    # Curtailment
    write_curtailment(path, inputs, setup, EP)
    zonal_curtail = _compute_curtailment_by_zone(inputs, setup, EP)
    SystemCurtailment = sum(zonal_curtail)

    # Firm Capacity
    dfCap = _run_writer_as_df(path) do
        write_capacity(path, inputs, setup, EP)
    end
    SystemFirmCapacity = dfCap[end, :EndCap]

    # Transmission Expansion
    L = inputs["L"]
    transcap = zeros(L)
    for i in 1:L
        if i in inputs["EXPANSION_LINES"]
            transcap[i] = value.(EP[:vNEW_TRANS_CAP][i])
        end
    end
    dfTransCap = DataFrame(New_Trans_Capacity = transcap,
                           Cost_Trans_Capacity = transcap .* inputs["pC_Line_Reinforcement"])
    if setup["ParameterScale"] == 1
        dfTransCap.New_Trans_Capacity *= ModelScalingFactor
        dfTransCap.Cost_Trans_Capacity *= ModelScalingFactor^2
    end
    SystemTransmissionExpansionCapacity = sum(dfTransCap.New_Trans_Capacity)
    SystemTransmissionExpansionCost = sum(dfTransCap.Cost_Trans_Capacity)

    # Transmission Flows & Losses
    if L > 0 && haskey(EP.obj_dict, :vFLOW)
        SystemTransmissionFlow = sum(value.(EP[:vFLOW]))
    else
        SystemTransmissionFlow = 0.0
    end
    LOSS_LINES = inputs["LOSS_LINES"]
    T_steps = inputs["T"]
    if L > 0 && !isempty(LOSS_LINES) && haskey(EP.obj_dict, :vTLOSS)
        tlosses = zeros(L, T_steps)
        tlosses[LOSS_LINES, :] = value.(EP[:vTLOSS][LOSS_LINES, :])
        SystemTransmissionLosses = sum(tlosses)
    else
        SystemTransmissionLosses = 0.0
    end

    # Build system output row
    DataFrame(SystemTotalCost = SystemTotalCost,
              SystemTotalCostCheck = SystemTotalCostCheck,
              SystemEmissions = SystemEmissions,
              SystemPrice = SystemPrice,
              SystemCurtailment = SystemCurtailment,
              SystemFirmCapacity = SystemFirmCapacity,
              SystemTransmissionExpansionCapacity = SystemTransmissionExpansionCapacity,
              SystemTransmissionExpansionCost = SystemTransmissionExpansionCost,
              SystemTransmissionFlow = SystemTransmissionFlow,
              SystemTransmissionLosses = SystemTransmissionLosses)
end

"""
    zonal_outputs_table(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Collect output metrics separately for each model zone.

The function combines zonal costs, weighted emissions, average prices,
curtailment, firm capacity, transmission flows, and transmission losses into a
single-row `DataFrame`. It uses the model output writers for cost, capacity,
emissions, and curtailment; those writers may also write their usual files to
`path`.

Arguments:
- `path`: Directory used by the output writers.
- `inputs`: Model input data used to calculate and aggregate zonal metrics.
- `setup`: Model settings, including the parameter-scaling configuration.
- `EP`: Solved JuMP model containing the objective and decision variables.

Returns:
    A one-row `DataFrame` with a column for each metric in each zone.
"""
function zonal_outputs_table(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    Z = inputs["Z"]

    # Costs
    dfCost = _run_writer_as_df(path) do
        write_costs(path, inputs, setup, EP)
    end
    # dfCost rows = cost categories (row 1 = cTotal); columns = Total, Zone1, Zone2, ...
    # Zone columns contain "-" for non-applicable rows, so they're read back as String
    zonal_costs = [parse(Float64, string(dfCost[1, Symbol("Zone$(z)")])) for z in 1:Z]

    # Emissions
    write_emissions(path, inputs, setup, EP)
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
    emissions_matrix = value.(EP[:eEmissionsByZone])
    emissions_by_zone = vec(sum(emissions_matrix .* reshape(inputs["omega"], 1, :), dims = 2)) .* scale_factor

    # Prices
    price_matrix = locational_marginal_price(EP, inputs, setup)
    zonal_price = vec(mean(price_matrix, dims=1))

    # Curtailment
    write_curtailment(path, inputs, setup, EP)
    zonal_curtail = _compute_curtailment_by_zone(inputs, setup, EP)

    # Firm Capacity — look up by zone value (Zone column is String in CSV)
    dfCap = _run_writer_as_df(path) do
        write_capacity(path, inputs, setup, EP)
    end
    dfCap_resources = dfCap[dfCap.Zone .!= "n/a", :]
    dfCap_resources = transform(dfCap_resources, :Zone => ByRow(z -> parse(Int, string(z))) => :ZoneInt)
    zonal_cap_agg = combine(groupby(dfCap_resources, :ZoneInt), :EndCap => sum => :FirmCapacity)
    cap_lookup = Dict(row.ZoneInt => row.FirmCapacity for row in eachrow(zonal_cap_agg))

    # Transmission Flows & Losses
    Llines = inputs["L"]
    T_steps_z = inputs["T"]
    LOSS_LINES_Z = inputs["LOSS_LINES"]
    flows_mat = (Llines > 0 && haskey(EP.obj_dict, :vFLOW)) ?
        value.(EP[:vFLOW]) : zeros(Llines, T_steps_z)
    losses_mat = zeros(Llines, T_steps_z)
    if Llines > 0 && !isempty(LOSS_LINES_Z) && haskey(EP.obj_dict, :vTLOSS)
        losses_mat[LOSS_LINES_Z, :] = value.(EP[:vTLOSS][LOSS_LINES_Z, :])
    end
    dfFlowLoss = DataFrame(Line = repeat(1:Llines, inner=T_steps_z),
                           Time = repeat(1:T_steps_z, outer=Llines),
                           Flow_MW = vec(flows_mat),
                           Loss_MW = vec(losses_mat))
    if haskey(inputs, "line_to_zone")
        zone_map = inputs["line_to_zone"]
        dfFlowLoss.Zone = zone_map[dfFlowLoss.Line]
        zonal_flow = combine(groupby(dfFlowLoss, :Zone), :Flow_MW => sum => :Flow)
        zonal_losses = combine(groupby(dfFlowLoss, :Zone), :Loss_MW => sum => :Loss)
        zonal_flow = sort!(zonal_flow, :Zone)
        zonal_losses = sort!(zonal_losses, :Zone)
    else
        zonal_flow = DataFrame(Zone = 1:Z, Flow = zeros(Z))
        zonal_losses = DataFrame(Zone = 1:Z, Loss = zeros(Z))
    end

    # Build zonal output row (one column per zone per metric)
    row = DataFrame()
    for z in 1:Z
        row[!, Symbol("Cost_Z$(z)")] = [zonal_costs[z]]
        row[!, Symbol("Emissions_Z$(z)")] = [emissions_by_zone[z]]
        row[!, Symbol("Price_Z$(z)")] = [zonal_price[z]]
        row[!, Symbol("Curtailment_Z$(z)")] = [zonal_curtail[z]]
        row[!, Symbol("FirmCapacity_Z$(z)")] = [get(cap_lookup, z, 0.0)]
        row[!, Symbol("TransmissionFlow_Z$(z)")] = [zonal_flow.Flow[z]]
        row[!, Symbol("TransmissionLoss_Z$(z)")] = [zonal_losses.Loss[z]]
    end

    return row
end

"""
    erate_design_matrix(p_range, p_steps, rng; len_design_mat, groups)

Generate one grouped Morris design matrix by sampling input levels and applying
one-factor-at-a-time index changes across the design points.

For each input dimension, the levels are evenly spaced between its lower and
upper bounds in `p_range`, with the number of levels specified by `p_steps`.
Dimensions assigned to the same group in `groups` share the same sampled level
index at each design point.

Arguments:
- `p_range`: Lower and upper bounds for each input dimension.
- `p_steps`: Number of levels to use for each input dimension.
- `rng`: Random-number generator used to sample and perturb level indices.
- `len_design_mat`: Number of design points to generate.
- `groups`: Group assignment for each input dimension.

Returns:
    A matrix with input dimensions as rows and design points as columns.
"""
function erate_design_matrix(p_range, p_steps, rng; len_design_mat, groups)
    ps = [range(p_range[i][1], stop = p_range[i][2], length = p_steps[i])
          for i in 1:length(p_range)]
    indices = [rand(rng, 1:i) for i in p_steps]
    all_idxs_original = Vector{typeof(indices)}(undef, len_design_mat)

    for i in 1:len_design_mat
        j = rand(rng, 1:length(p_range))
        indices[j] += (rand(rng) < 0.5 ? -1 : 1)
        if indices[j] > p_steps[j]
            indices[j] -= 2
        elseif indices[j] < 1.0
            indices[j] += 2
        end
        all_idxs_original[i] = copy(indices)
    end

    df_all_idx_original = DataFrame(all_idxs_original, :auto)
    println("Prints the original indices of the design matrix.")
    println(df_all_idx_original)
    all_idxs = similar(df_all_idx_original)
    for g in unique(groups)
        temp = findall(x -> x == g, groups)
        for k in temp
            all_idxs[k, :] = df_all_idx_original[temp[1], :]
        end
    end
    println("Prints the modified indices after applying grouping.")
    println(all_idxs)

    B = Array{Array{Float64}}(undef, len_design_mat)
    for j in 1:len_design_mat
        cur_p = [ps[u][(all_idxs[:, j][u])] for u in 1:length(p_range)]
        B[j] = cur_p
    end
    reduce(hcat, B)
end

"""
    calculate_spread(matrix)

Calculate the total Euclidean distance between consecutive design points.

Each column of `matrix` represents a design point. The function sums the
Euclidean distance from each point to the next, providing a measure of the
trajectory's overall spread.

Arguments:
- `matrix`: Design matrix with design points stored in columns.

Returns:
    The summed distance as a `Float64`.
"""
function calculate_spread(matrix)
    spread = 0.0
    for i in 2:size(matrix, 2)
        spread += sqrt(sum(abs2.(matrix[:, i] - matrix[:, i - 1])))
    end
    spread
end

"""
    sample_matrices(p_range, p_steps, rng;
        num_trajectory, total_num_trajectory, len_design_mat, groups)

Generate candidate Morris design matrices, rank them by spread, and select the
highest-spread trajectories.

The function generates `total_num_trajectory` candidates using `erate_design_matrix`,
calculates each candidate's spread, and returns the `num_trajectory` candidates
with the greatest spread concatenated horizontally. It errors if fewer
candidates are requested than selected trajectories.

Arguments:
- `p_range`: Lower and upper bounds for each input dimension.
- `p_steps`: Number of levels for each input dimension.
- `rng`: Random-number generator used to generate the candidates.
- `num_trajectory`: Number of highest-spread trajectories to retain.
- `total_num_trajectory`: Number of candidate trajectories to generate.
- `len_design_mat`: Number of design points in each candidate trajectory.
- `groups`: Group assignment for each input dimension.

Returns:
    A matrix containing the selected design matrices side by side.
"""
function sample_matrices(p_range,
        p_steps,
        rng;
        num_trajectory,
        total_num_trajectory,
        len_design_mat,
        groups)
    matrix_array = []
    println("Print the number of trajectories and total number of trajectories to be generated.")
    println(num_trajectory)
    println(total_num_trajectory)
    if total_num_trajectory < num_trajectory
        error("total_num_trajectory should be greater than num_trajectory preferably atleast 3-4 times higher")
    end
    for i in 1:total_num_trajectory
        mat = erate_design_matrix(p_range, p_steps, rng; len_design_mat, groups)
        spread = calculate_spread(mat)
        push!(matrix_array, MatSpread(mat, spread))
    end
    sort!(matrix_array, by = x -> x.spread, rev = true)
    matrices = [i.mat for i in matrix_array[1:num_trajectory]]
    reduce(hcat, matrices)
end

"""
    my_gsa(f, p_steps, num_trajectory, total_num_trajectory, p_range,
        len_design_mat, groups, random;
        input_labels=String[], output_labels=String[],
        bfps_output_path="", morris_outputs_path="")

Run a Morris global sensitivity analysis using the supplied model-evaluation
function `f`.

The function generates and selects design trajectories, evaluates `f` at each
design point, and calculates the mean, mean absolute, and variance of the
elementary effects for each input and output. It also reports BFPS sensitivity
indices and can write the sampled design points, model outputs, and BFPS
summary to CSV files.

Arguments:
- `f`: Function that accepts one sampled input vector and returns a scalar or
  vector of model outputs.
- `p_steps`: Number of levels for each input dimension.
- `num_trajectory`: Number of trajectories to retain for analysis.
- `total_num_trajectory`: Number of candidate trajectories to generate.
- `p_range`: Lower and upper sampling bounds for each input dimension.
- `len_design_mat`: Number of design points in each candidate trajectory.
- `groups`: Group assignment for the input dimensions.
- `random`: If `false`, seed the random-number generator with `SEED` for
  repeatable sampling; if `true`, use the current random state.

Keyword arguments:
- `input_labels`: Optional labels for the input dimensions.
- `output_labels`: Optional labels for the output dimensions.
- `bfps_output_path`: Optional CSV path for BFPS indices; an empty string
  disables this output.
- `morris_outputs_path`: Optional CSV path for sampled inputs and model
  outputs; an empty string disables this output.

Returns:
    A `MorrisResult` containing the elementary-effect means, mean absolute
    effects, variances, and collected elementary effects.

Throws:
    An error if the input ranges, level counts, groups, or generated
    trajectories are insufficient or inconsistent for the analysis.
"""
function my_gsa(f,
        p_steps,
        num_trajectory,
        total_num_trajectory,
        p_range::AbstractVector,
        len_design_mat,
        groups,
    random;
    input_labels::Vector{String} = String[],
    output_labels::Vector{String} = String[],
    bfps_output_path::String = "",
    morris_outputs_path::String = "")
    rng = Random.default_rng()
    if !random
        Random.seed!(SEED)
    end

    if isempty(p_range)
        error("Method of Morris has no active uncertain dimensions (p_range is empty). Check Method_of_morris CSV rows, zone labels, and parameter names against loaded inputs.")
    end
    if isempty(p_steps)
        error("Method of Morris received empty p_steps.")
    end
    if length(p_steps) < length(p_range)
        error("Method of Morris dimension mismatch: p_steps has $(length(p_steps)) entries but p_range has $(length(p_range)).")
    end
    if isempty(groups)
        error("Method of Morris received empty groups. Check the Group column in Method_of_morris CSV.")
    end
    if length(groups) < length(p_range)
        error("Method of Morris dimension mismatch: groups has $(length(groups)) entries but p_range has $(length(p_range)).")
    end

    design_matrices_original = sample_matrices(p_range, p_steps, rng; num_trajectory,
        total_num_trajectory, len_design_mat, groups)
    println("Prints the original design matrices.")
    println(design_matrices_original)
    L = DataFrame(design_matrices_original, :auto)
    println("Prints the design matrices converted to a DataFrame.")
    println(L)

    distinct_trajectories = Array{Int64}(undef, num_trajectory)
    design_matrices = Matrix(DataFrame(unique(last,
        pairs(eachcol(L[!, 1:len_design_mat])))))
    distinct_trajectories[1] = length(design_matrices[1, :])
    if num_trajectory > 1
        for i in 2:num_trajectory
            design_matrices = hcat(design_matrices,
                Matrix(DataFrame(unique(last,
                    pairs(eachcol(L[!,
                        ((i - 1) * len_design_mat + 1):(i * len_design_mat)]))))))
            distinct_trajectories[i] = length(Matrix(DataFrame(unique(last,
                pairs(eachcol(L[!, ((i - 1) * len_design_mat + 1):(i * len_design_mat)])))))[
                1,
                :])
        end
    end
    println("Prints the number of distinct trajectories for each iteration.")
    println(distinct_trajectories)
    println("Prints the final design matrices after processing.")
    println(design_matrices)

    multioutput = false
    desol = false
    local y_size

    _y = [f(design_matrices[:, i]) for i in 1:size(design_matrices, 2)]
    multioutput = !(eltype(_y) <: Number)
    if eltype(_y) <: RecursiveArrayTools.AbstractVectorOfArray
        y_size = size(_y[1])
        _y = vec.(_y)
        desol = true
    end
    all_y = multioutput ? reduce(hcat, _y) : _y
    println("Prints the model outputs for all design points.")
    println(all_y)

    # Create a mapping from column index to trajectory number
    trajectory_map = Vector{Int}(undef, size(design_matrices, 2))
    current_col = 1
    for i in 1:num_trajectory
        num_runs_in_traj = distinct_trajectories[i]
        if num_runs_in_traj > 0
            trajectory_map[current_col:(current_col + num_runs_in_traj - 1)] .= i
            current_col += num_runs_in_traj
        end
    end

    # Store and print input-output pairs
    num_runs = size(design_matrices, 2)
    input_output_pairs = Vector{InputOutputPair}(undef, num_runs)
    for i in 1:num_runs
        inputs = design_matrices[:, i]
        output = multioutput ? all_y[:, i] : all_y[i]
        traj_num = trajectory_map[i]
        input_output_pairs[i] = InputOutputPair(traj_num, i, inputs, output)
    end

    # Persist model outputs at each design point before BFPS computation.
    if !isempty(strip(morris_outputs_path))
        n_inputs = size(design_matrices, 1)
        n_outputs = multioutput ? size(all_y, 1) : 1
        resolved_input_labels = if length(input_labels) == n_inputs
            [isempty(strip(lbl)) ? "Input $i" : lbl for (i, lbl) in enumerate(input_labels)]
        else
            ["Input $i" for i in 1:n_inputs]
        end
        resolved_output_labels = if length(output_labels) == n_outputs
            [isempty(strip(lbl)) ? "Output $j" : lbl for (j, lbl) in enumerate(output_labels)]
        else
            ["Output $j" for j in 1:n_outputs]
        end

        morris_outputs_df = DataFrame()
        for i in 1:n_inputs
            values_i = Float64.(vec(design_matrices[i, :]))
            morris_outputs_df[!, Symbol(resolved_input_labels[i])] = values_i
        end
        for j in 1:n_outputs
            values_j = multioutput ? Float64.(vec(all_y[j, :])) : Float64.(all_y)
            morris_outputs_df[!, Symbol(resolved_output_labels[j])] = values_j
        end

        CSV.write(morris_outputs_path, morris_outputs_df)
        println("Morris model outputs written to: $(morris_outputs_path)")
    end

    # --- Calculate and Print BFPS Sensitivity Indices ---
    calculate_and_print_bfps_indices(input_output_pairs;
        input_labels = input_labels,
        output_labels = output_labels,
        bfps_output_path = bfps_output_path)

    println("\n--- Input and Output for Each Run ---")
    for pair in input_output_pairs
        println("Trajectory: $(pair.trajectory_number), Run Index: $(pair.run_index)")
        println("  Inputs:")
        for i in 1:length(pair.inputs)
            lbl = (i <= length(input_labels) && !isempty(strip(input_labels[i]))) ? input_labels[i] : "Input $i"
            println("    ", lbl, " => ", pair.inputs[i])
        end

        if pair.output isa AbstractVector
            output_vec = collect(pair.output)
            if length(output_labels) == length(output_vec)
                println("  Outputs:")
                for (lbl, val) in zip(output_labels, output_vec)
                    println("    ", lbl, " => ", val)
                end
            else
                println("  Output: ", output_vec)
            end
        else
            scalar_label = (!isempty(output_labels) && length(output_labels) == 1) ? output_labels[1] : "Output"
            println("  ", scalar_label, " => ", pair.output)
        end
    end
    println("-------------------------------------\n")
    effects = []
    while (length(effects) < length(groups))
        push!(effects, Vector{Float64}[])
    end

    # --- Corrected Loop Logic ---
    # This variable will track our position in the giant `all_y` and `design_matrices`
    current_start_column = 1

    for i in 1:num_trajectory
        # Use the ACTUAL length of the trajectory after the `unique` filter
        current_len = distinct_trajectories[i]
        
        # If the trajectory has only one point or is empty, we can't calculate effects. Skip it.
        if current_len <= 1
            current_start_column += current_len
            continue
        end

        y1 = multioutput ? all_y[:, current_start_column] : all_y[current_start_column]
        
        # Loop from the first to the second-to-last column of the CURRENT trajectory segment
        for j in 0:(current_len - 2)
            # `col_idx` is the absolute column index in the large `design_matrices`
            col_idx = current_start_column + j
            y2 = y1
            del = design_matrices[:, col_idx + 1] - design_matrices[:, col_idx]
            change_index = 0
            for k in 1:length(del)
                if abs(del[k]) > 0
                    change_index = k
                    break
                end
            end
            del = sum(del)
            y1 = multioutput ? all_y[:, col_idx + 1] : all_y[col_idx + 1]
            effect = @. (y1 - y2) / (del)
#            elem_effect = typeof(y1) <: Number ? effect : mean(effect, dims = 2)
            elem_effect = typeof(y1) <: Number ? effect : effect
            temp_g_index = findall(x -> x == groups[change_index], groups)
            for g in temp_g_index
                println("Print the elementary effects during their calculation.")    
                println(effects)
                println(elem_effect)
                push!(effects[g], elem_effect)
            end
        end
        
        # Move the starting column pointer for the next trajectory
        current_start_column += current_len
    end

    isempty(effects) && error("Method of Morris could not initialize elementary effects (effects is empty).")
    first_nonempty_idx = findfirst(k -> !isempty(k), effects)
    first_nonempty_idx === nothing && error("Method of Morris produced no elementary effects. This can happen when trajectories collapse to repeated points or no dimensions vary.")
    template_effect = effects[first_nonempty_idx][1]
    _zero_like(x) = x isa Number ? zero(x) : zero.(x)

    means = typeof(template_effect)[]
    means_star = typeof(template_effect)[]
    variances = typeof(template_effect)[]
    for k in effects
        if !isempty(k)
            push!(means, mean(k))
            push!(means_star, mean(x -> abs.(x), k))
            push!(variances, var(k))
        else
            push!(means, _zero_like(template_effect))
            push!(means_star, _zero_like(template_effect))
            push!(variances, _zero_like(template_effect))
        end
    end
    if desol
        f_shape = x -> [reshape(x[:, i], y_size) for i in 1:size(x, 2)]
        means = map(f_shape, means)
        means_star = map(f_shape, means_star)
        variances = map(f_shape, variances)
    end
    MorrisResult(reduce(hcat, means),
        reduce(hcat, means_star),
        reduce(hcat, variances),
        effects)
end

"""
    morris(EP::Model, path::AbstractString, setup::Dict, inputs::Dict,
        outpath::AbstractString, OPTIMIZER; random=true)

Run a Morris sensitivity analysis for the configured GenX case.

The function selects a Method of Morris range file from `path`, maps its
uncertain parameters to model inputs, and generates Morris trajectories. For
each sampled design point, it applies the sampled parameter values, builds
and solves the model using `OPTIMIZER`, and collects system-wide and
zone-specific outputs. It then calculates Morris elementary-effect
statistics and BFPS sensitivity indices, and writes the analysis results to
CSV files in `outpath`.

The sampled values are applied to `inputs` during the analysis. The function
may also call GenX output writers while collecting model outputs.

Arguments:
- `EP`: JuMP model argument retained by this method's interface.
- `path`: Case input directory containing the Method of Morris range file and
  related policy inputs.
- `setup`: GenX configuration dictionary, including policy and scaling
  settings.
- `inputs`: Loaded model inputs; values are perturbed for each sampled run.
- `outpath`: Directory for model outputs and Morris analysis CSV files.
- `OPTIMIZER`: JuMP-compatible optimizer used to build and solve each sampled
  model.

Keyword arguments:
- `random`: If `false`, use the fixed `SEED` for repeatable sampling; if
  `true`, use the current random-number generator state.

Returns:
    A `DataFrame` containing the configured Morris input rows and their
    `SystemCost` elementary-effect mean and variance.

Throws:
    An error if no supported Method of Morris range file is found, if no
    active uncertain inputs can be mapped, or if a model run or analysis
    step fails.
"""
function morris(EP::Model,
        path::AbstractString,
        setup::Dict,
        inputs::Dict,
        outpath::AbstractString,
        OPTIMIZER;
        random = true)

    screening_toggle_params = Set(["gas_retirement", "nuclear_availability"])
    screening_multiplier_params = Set([
        "ira_invcost_multiplier",
        "solar_cost_multiplier",
        "battery_cost_multiplier",
        "offshorewind_cost_multiplier",
        "onshorewind_cost_multiplier",
        "siting_maxcap_multiplier",
        "demand_flexibility_multiplier",
        "fuel_price_multiplier",
        "load_multiplier",
    ])

    _normalize_token(x) = replace(lowercase(strip(string(x))), r"[^a-z0-9]" => "")
    """
        _find_property_symbol(item, sym::Symbol)

    Resolve `sym` to the corresponding property or key on `item`.

    For `AbstractResource` objects, the lookup also checks keys in the resource's
    backing dictionary. If an exact match is not found, names are compared after
    normalizing case and removing non-alphanumeric characters.

    Arguments:
    - `item`: Resource or other object to inspect.
    - `sym`: Property name to resolve.

    Returns:
        The matching `Symbol`, or `nothing` if no matching property or key exists.
    """
    function _find_property_symbol(item, sym::Symbol)
        if item isa AbstractResource
            if haskey(item, sym)
                return sym
            end
            target = _normalize_token(sym)
            for k in keys(parent(item))
                if _normalize_token(k) == target
                    return k
                end
            end
        end
        if hasproperty(item, sym)
            return sym
        end
        target = _normalize_token(sym)
        for p in propertynames(item)
            if _normalize_token(p) == target
                return p
            end
        end
        return nothing
    end
    """
        _zone_match(item, morris_zone)

    Determine whether `item` belongs to the zone specified by `morris_zone`.

    A missing or empty zone selector matches every item. Otherwise, the item's zone
    is obtained from its `zone` property when available, with `zone_id(item)` used
    as a fallback. A leading `"z"` is ignored when comparing zone labels, and
    numeric labels are compared approximately.

    Arguments:
    - `item`: Resource or other object whose zone is being checked.
    - `morris_zone`: Zone selector to compare against; may be missing or empty to
      match all zones.

    Returns:
        `true` if the item matches the requested zone, otherwise `false`.
    """
    function _zone_match(item, morris_zone)
        if ismissing(morris_zone) || morris_zone == ""
            return true
        end
        zone_sym = _find_property_symbol(item, :zone)
        item_zone_raw = if zone_sym !== nothing
            string(getproperty(item, zone_sym))
        else
            try
                string(zone_id(item))
            catch
                ""
            end
        end
        item_zone_raw == "" && return false
        item_zone = lowercase(strip(item_zone_raw))
        morris_zone_str = lowercase(strip(string(morris_zone)))
        item_zone_norm = startswith(item_zone, "z") ? item_zone[2:end] : item_zone
        morris_zone_norm = startswith(morris_zone_str, "z") ? morris_zone_str[2:end] : morris_zone_str
        if item_zone_norm == morris_zone_norm
            return true
        end
        item_zone_num = tryparse(Float64, item_zone_norm)
        morris_zone_num = tryparse(Float64, morris_zone_norm)
        if item_zone_num !== nothing && morris_zone_num !== nothing
            return isapprox(item_zone_num, morris_zone_num; atol=1e-9)
        end
        return false
    end

    """
        _item_get(item, sym::Symbol, default)

    Retrieve the value of the property `sym` from `item`, returning `default` if the property does not exist.

    Arguments:
    - `item`: Resource or other object to inspect.
    - `sym`: Property name to retrieve.
    - `default`: Value to return if the property is not found.

    Returns:
        The value of the property if it exists, otherwise `default`.
    """
    function _item_get(item, sym::Symbol, default)
        resolved_sym = _find_property_symbol(item, sym)
        resolved_sym === nothing && return default
        return getproperty(item, resolved_sym)
    end

    """
        _item_set!(item, sym::Symbol, value)

    Set the property `sym` on `item` to `value`. If the property does not exist and `item` is an `AbstractResource` backed by a dictionary, a new key is added.

    Arguments:
    - `item`: Resource or other object to modify.
    - `sym`: Property name to set.
    - `value`: Value to assign to the property.

    Returns:
        `true` if the property was successfully set, otherwise `false`.
    """
    function _item_set!(item, sym::Symbol, value)
        resolved_sym = _find_property_symbol(item, sym)
        if resolved_sym === nothing
            if item isa AbstractResource
                # For resources backed by Dict, allow setting new canonical keys.
                setproperty!(item, sym, value)
                return true
            end
            return false
        end
        setproperty!(item, resolved_sym, value)
        return true
    end

    """
        _screening_items(inputs, param_name_lower)

    Select the model input items associated with a screening parameter.

    Fuel-price screening parameters use rows from `inputs["FUELS"]`; load screening
    parameters use rows from `inputs["DEMAND"]`. Other screening parameters use
    `inputs["RESOURCES"]`.

    Arguments:
    - `inputs`: Model input dictionary.
    - `param_name_lower`: Lowercase screening-parameter name.

    Returns:
        A collection of matching input items, or an empty collection if the
        corresponding input table is unavailable.
    """
    function _screening_items(inputs, param_name_lower)
        if param_name_lower == "fuel_price_multiplier"
            # This screening path requires a custom FUELS table; standard GenX
            # provides `fuels` (a list of names) and `fuel_costs`, not `FUELS`.
            return haskey(inputs, "FUELS") ? collect(eachrow(inputs["FUELS"])) : Any[]
        elseif param_name_lower == "load_multiplier"
            return haskey(inputs, "DEMAND") ? collect(eachrow(inputs["DEMAND"])) : Any[]
        else
            return haskey(inputs, "RESOURCES") ? inputs["RESOURCES"] : Any[]
        end
    end

    """
        _target_resources_for_screening(resources, param_name_lower, morris_zone)

    Filter input items to those eligible for the specified screening parameter and
    matching the requested zone.

    Eligibility is determined by the Boolean property named
    `<param_name_lower>_eligible`. Zone matching is delegated to `_zone_match`;
    a missing or empty zone selector therefore matches items in all zones.

    Arguments:
    - `resources`: Collection of resources or other screening items.
    - `param_name_lower`: Lowercase screening-parameter name used to identify its
      eligibility property.
    - `morris_zone`: Zone selector used to filter the items.

    Returns:
        A collection containing only eligible items that match the requested zone.
    """
    function _target_resources_for_screening(resources, param_name_lower, morris_zone)
        eligible_sym = Symbol(param_name_lower * "_eligible")
        return filter(item -> _zone_match(item, morris_zone) && _item_get(item, eligible_sym, false), resources)
    end

    function _network_inputs_dict(inputs)
        haskey(inputs, "inputs_nw") ? inputs["inputs_nw"] : inputs
    end

    """
        _resolve_network_key(inputs, parameter_name)

    Resolve a Morris parameter name to its corresponding key in the network input
    dictionary.

    The function checks for an exact key match first, then maps supported
    parameter names to their GenX network-input keys. It returns `nothing` if no
    matching key is found.

    Arguments:
    - `inputs`: Model input dictionary, optionally containing a nested
      `"inputs_nw"` dictionary.
    - `parameter_name`: Network parameter name from the Morris range configuration.

    Returns:
        The matching network-input key as a string, or `nothing` if unresolved.
    """
    function _resolve_network_key(inputs, parameter_name)
        nw = _network_inputs_dict(inputs)
        param = String(parameter_name)
        if haskey(nw, param)
            return param
        end
        param_lower = lowercase(strip(param))
        mapped_key = if param_lower == "line_max_reinforcement_mw"
            "pMax_Line_Reinforcement"
        elseif param_lower == "line_max_flow_mw"
            "pTrans_Max"
        elseif param_lower == "line_reinforcement_cost_per_mwyr"
            "pC_Line_Reinforcement"
        elseif param_lower == "line_max_flow_possible_mw"
            "pLine_Max_Flow_Possible_MW"
        else
            nothing
        end
        mapped_key !== nothing && haskey(nw, mapped_key) ? mapped_key : nothing
    end

    """
        _demand_zone_from_parameter(parameter_name)

    Extract the zone index from a demand parameter name such as
    `Demand_MW_z1`.

    The parameter name must match the `Demand_MW_z<N>` convention, where `<N>`
    is a positive integer zone index; matching is case-insensitive.

    Arguments:
    - `parameter_name`: Demand parameter name to parse.

    Returns:
        The parsed zone index as an `Int`, or `nothing` if the name does not
        match the expected convention.
    """
    function _demand_zone_from_parameter(parameter_name)
        m = match(r"^demand_mw_z(\d+)$"i, strip(String(parameter_name)))
        m === nothing && return nothing
        tryparse(Int, m.captures[1])
    end

    """
        _line_index_from_parameter(parameter_name)

    Extract the line index from a line-reinforcement parameter name such as
    `Line_Max_Reinforcement_MW_L15`.

    The parameter name must match the `Line_Max_Reinforcement_MW_L<N>` convention,
    where `<N>` is a positive integer line index; matching is case-insensitive.

    Arguments:
    - `parameter_name`: Line-reinforcement parameter name to parse.

    Returns:
        The parsed line index as an `Int`, or `nothing` if the name does not
        match the expected convention.
    """
    function _line_index_from_parameter(parameter_name)
        m = match(r"^line_max_reinforcement_mw_l(\d+)$"i, strip(String(parameter_name)))
        m === nothing && return nothing
        tryparse(Int, m.captures[1])
    end

    """
        _co2_cap_index_from_parameter(parameter_name)

    Extract the CO2-cap column index from a parameter name such as
    `CO_2_Max_Mtons_1`.

    The name must match the `CO_2_Max_Mtons_<N>` convention. The returned
    index is 1-based and corresponds to a column in `dfMaxCO2`; matching is
    case-insensitive.

    Arguments:
    - `parameter_name`: CO2-cap parameter name to parse.

    Returns:
        The parsed column index as an `Int`, or `nothing` if the name does not
        match the expected convention.
    """
    function _co2_cap_index_from_parameter(parameter_name)
        m = match(r"^co_2_max_mtons_(\d+)$"i, strip(String(parameter_name)))
        m === nothing && return nothing
        tryparse(Int, m.captures[1])
    end

    """
        _esr_index_from_parameter(parameter_name)

    Extract the energy share requirement column index from a parameter name
    such as `ESR_1`.

    The name must match the `ESR_<N>` convention. The returned index is
    1-based and corresponds to a column in `dfESR`; matching is
    case-insensitive.

    Arguments:
    - `parameter_name`: ESR parameter name to parse.

    Returns:
        The parsed column index as an `Int`, or `nothing` if the name does not
        match the expected convention.
    """
    function _esr_index_from_parameter(parameter_name)
        m = match(r"^esr_(\d+)$"i, strip(String(parameter_name)))
        m === nothing && return nothing
        tryparse(Int, m.captures[1])
    end

    """
        _capres_index_from_parameter(parameter_name)

    Extract the capacity-reserve-margin requirement column index from a
    parameter name such as `CapRes_1`.

    The name must match the `CapRes_<N>` convention. The returned index is
    1-based and corresponds to a column in `dfCapRes`; matching is
    case-insensitive.

    Arguments:
    - `parameter_name`: Capacity-reserve-margin parameter name to parse.

    Returns:
        The parsed column index as an `Int`, or `nothing` if the name does not
        match the expected convention.
    """
    function _capres_index_from_parameter(parameter_name)
        m = match(r"^capres_(\d+)$"i, strip(String(parameter_name)))
        m === nothing && return nothing
        tryparse(Int, m.captures[1])
    end

    """
        _mincap_index_from_parameter(parameter_name)

    Extract the minimum-capacity requirement index from a parameter name such
    as `MinCapReq_1`.

    The name must match the `MinCapReq_<N>` convention. The returned index is
    1-based and corresponds to an entry in `inputs["MinCapReq"]`; matching is
    case-insensitive.

    Arguments:
    - `parameter_name`: Minimum-capacity requirement parameter name to parse.

    Returns:
        The parsed requirement index as an `Int`, or `nothing` if the name does
        not match the expected convention.
    """
    function _mincap_index_from_parameter(parameter_name)
        m = match(r"^mincapreq_(\d+)$"i, strip(String(parameter_name)))
        m === nothing && return nothing
        tryparse(Int, m.captures[1])
    end

    """
        _maxcap_index_from_parameter(parameter_name)

    Extract the maximum-capacity requirement index from a parameter name such
    as `MaxCapReq_1`.

    The name must match the `MaxCapReq_<N>` convention. The returned index is
    1-based and corresponds to an entry in `inputs["MaxCapReq"]`; matching is
    case-insensitive.

    Arguments:
    - `parameter_name`: Maximum-capacity requirement parameter name to parse.

    Returns:
        The parsed requirement index as an `Int`, or `nothing` if the name does
        not match the expected convention.
    """
    function _maxcap_index_from_parameter(parameter_name)
        m = match(r"^maxcapreq_(\d+)$"i, strip(String(parameter_name)))
        m === nothing && return nothing
        tryparse(Int, m.captures[1])
    end

    """
        _zone_index_from_value(zone_value)

    Normalize a zone label and parse its numeric index.

    The function converts the value to a trimmed, lowercase string, removes
    an optional leading `z`, and attempts to parse the remainder as an integer.

    Arguments:
    - `zone_value`: Zone label or value to parse, such as `1` or `"z1"`.

    Returns:
        The parsed zone index as an `Int`, or `nothing` if the value is not an
        integer zone label.
    """
    function _zone_index_from_value(zone_value)
        zstr = lowercase(strip(string(zone_value)))
        zstr = startswith(zstr, "z") ? zstr[2:end] : zstr
        tryparse(Int, zstr)
    end

    """
        _network_line_indices_for_zone(inputs, morris_zone)

    Select transmission-line indices associated with a Morris zone selector.

    The function reads the network incidence matrix `pNet_Map` and assigns
    each line to the zone where its incidence value is `+1`. A global selector
    (missing, empty, `all`, `global`, `*`, `0`, or `z0`) selects every line.
    Invalid zones or unavailable/unsupported incidence matrices produce an
    empty index list.

    Arguments:
    - `inputs`: Model input dictionary, optionally containing `"inputs_nw"`
      with the network data.
    - `morris_zone`: Zone label or global selector from the Morris range data.

    Returns:
        A vector of 1-based transmission-line indices selected for the zone.
    """
    function _network_line_indices_for_zone(inputs, morris_zone)
        nw = _network_inputs_dict(inputs)
        if !haskey(nw, "pNet_Map")
            return Int[]
        end
        pnet = nw["pNet_Map"]
        if !(pnet isa AbstractMatrix)
            return Int[]
        end

        # Global selectors in the Zone column for network uncertainty rows.
        zone_token = lowercase(strip(string(morris_zone)))
        if ismissing(morris_zone) || zone_token == "" || zone_token in Set(["all", "global", "*", "0", "z0"])
            return collect(1:size(pnet, 1))
        end

        z = _zone_index_from_value(morris_zone)
        if z === nothing || z < 1 || z > size(pnet, 2)
            return Int[]
        end

        # Assign each transmission line to its +1 (start) zone, so zonal
        # perturbations are non-overlapping and deterministic across zones.
        findall(pnet[:, z] .== 1)
    end

    # Select the Morris range configuration from the case input directory.
    # The first matching file in the ordered checks below takes precedence;
    # specialized policy range files are checked before the general range files.
    # Stop with an error if none of the supported configurations is present.
    if isfile(joinpath(path, "Method_of_morris_energy_share_requirement_zone.csv"))
        morris_range_path = joinpath(path, "Method_of_morris_energy_share_requirement_zone.csv")
    elseif isfile(joinpath(path, "Method_of_morris_capacity_reserve_margin_zone.csv"))
        morris_range_path = joinpath(path, "Method_of_morris_capacity_reserve_margin_zone.csv")
    elseif isfile(joinpath(path, "Method_of_morris_minimum_capacity_requirement_zone.csv"))
        morris_range_path = joinpath(path, "Method_of_morris_minimum_capacity_requirement_zone.csv")
    elseif isfile(joinpath(path, "Method_of_morris_maximum_capacity_requirement_zone.csv"))
        morris_range_path = joinpath(path, "Method_of_morris_maximum_capacity_requirement_zone.csv")
    elseif isfile(joinpath(path, "Method_of_morris_minimum_capacity_requirement.csv"))
        morris_range_path = joinpath(path, "Method_of_morris_minimum_capacity_requirement.csv")
    elseif isfile(joinpath(path, "Method_of_morris_maximum_capacity_requirement.csv"))
        morris_range_path = joinpath(path, "Method_of_morris_maximum_capacity_requirement.csv")
    elseif isfile(joinpath(path, "Method_of_morris_CO2_capacity_requirement_zone.csv"))
        morris_range_path = joinpath(path, "Method_of_morris_CO2_capacity_requirement_zone.csv")
    elseif isfile(joinpath(path, "Method_of_morris_range.csv"))
        morris_range_path = joinpath(path, "Method_of_morris_range.csv")
    elseif isfile(joinpath(path, "Method_of_morris_range_zone.csv"))
        morris_range_path = joinpath(path, "Method_of_morris_range_zone.csv")    
    else
        error("No Method of Morris file found in the specified path.")
    end
    Morris_range = load_dataframe(morris_range_path)

    println(Morris_range)
    groups = Morris_range[!, :Group]
    p_steps = Morris_range[!, :p_steps]
    println("groups: ", groups)
    println("groups length: ", length(groups))
    println("p_steps: ", p_steps)
    println("p_steps length: ", length(p_steps))
    println("p_steps type: ", typeof(p_steps))
    total_num_trajectory = Morris_range[!, :total_num_trajectory][1]
    num_trajectory = Morris_range[!, :num_trajectory][1]
    len_design_mat = Morris_range[!, :len_design_mat][1]
    uncertain_columns = unique(Morris_range[!, :Parameter])
    #z = inputs["RESOURCES"]
    #in_esr=inputs["dfESR"]
    p_zone = String[]
    p_pivot = String[]
    # Energy Share Requirement
    if setup["EnergyShareRequirement"] >= 1 && morris_range_path == joinpath(path, "Method_of_morris_energy_share_requirement_zone.csv")
        # The input matrix has columns: Region_description, Network_zones, param1, param2, ...
        # Since inputs["dfESR"] is a Matrix without headers, we must reload the file to get the DataFrame.
        # The CSV is in the 'policies' directory, relative to the main case 'inputs' directory.
        # Load the full policy DataFrame to access the correct column names.
        policies_path = joinpath(path, setup["PoliciesFolder"])
        esr_filename = "Energy_share_requirement.csv"
        in_policy_df_full = load_dataframe(joinpath(policies_path, esr_filename))
        
        # Select all columns from the second one ("Network_zones") to the end.
        # This preserves the original parameter column names (ESR_1, ESR_2, etc.).
        in_policy_df = DataFrame(in_policy_df_full[:, 2:end], names(in_policy_df_full)[2:end])
        # Rename the first column to "Zone"
        rename!(in_policy_df, names(in_policy_df)[1] => "Zone")
     
        p_zone = unique(Morris_range[!, :Zone])
        p_pivot = String[]  # empty

        pivot_variable = p_zone

        # Creating the range of uncertain parameters in terms of absolute values
        sigma_rows = []
        for (i_zone, zone) in enumerate(pivot_variable)
            # Get the parameters that are actually defined for this zone in the Morris_range file
            zone_params = unique(Morris_range[Morris_range[!, :Zone] .== zone, :Parameter])
            for column in uncertain_columns
                if column in zone_params
                    zone_filter = Morris_range[(Morris_range[!, :Zone] .== zone) .& (Morris_range[!, :Parameter] .== column), :]

                    if !isempty(zone_filter)
                        lower_bound = zone_filter[!, :Lower_bound][1] / 100
                        upper_bound = zone_filter[!, :Upper_bound][1] / 100

                        # Find the correct column index by name
                        policy_col_name = column

                        # Find the correct row index by matching the zone name from the GSA file
                        # to the 'Zone' column in the policy file.
                        # We prepend "z" to the zone from the GSA file to match the policy file format (e.g., "1" -> "z1").
                        zone_to_find = string("z", zone)
                        policy_row_idx = findfirst(isequal(zone_to_find), in_policy_df[!, :Zone])

                        if !isnothing(policy_row_idx)
                            # Use correct indices to access the DataFrame
                            base_value = in_policy_df[policy_row_idx, policy_col_name]
                            sigma_lower = base_value * (1 + lower_bound)
                            sigma_upper = base_value * (1 + upper_bound)
                            push!(sigma_rows, [sigma_lower sigma_upper])
                        else
                            if isnothing(policy_row_idx)
                                @warn "Zone '$zone' from GSA file not found in policy file."
                            end
                        end
                    end
                end
            end
        end
        sigma = vcat(sigma_rows...)
    end
    # Capacity Reserve Margin
    if setup["CapacityReserveMargin"] > 0 && morris_range_path == joinpath(path, "Method_of_morris_capacity_reserve_margin_zone.csv")
        # The input matrix has columns: Network_zones, param1, param2, ...
        # Since inputs["dfCapRes"] is a Matrix without headers, we must reload the file to get the DataFrame.
        # The CSV is in the 'policies' directory, relative to the main case 'inputs' directory.
        # Load the full policy DataFrame to access the correct column names.
        policies_path = joinpath(path, setup["PoliciesFolder"])
        CapRes_filename = "Capacity_reserve_margin.csv"
        in_policy_df_full = load_dataframe(joinpath(policies_path, CapRes_filename))
        
        # Select all columns from the second one ("Network_zones") to the end.
        in_policy_df = copy(in_policy_df_full)
        rename!(in_policy_df, names(in_policy_df)[1] => "Zone")
     
        p_zone = unique(Morris_range[!, :Zone])
        p_pivot = String[]  # empty

        pivot_variable = p_zone

        # Creating the range of uncertain parameters in terms of absolute values
        sigma_rows = []
        for (i_zone, zone) in enumerate(pivot_variable)
            # Get the parameters that are actually defined for this zone in the Morris_range file
            zone_params = unique(Morris_range[Morris_range[!, :Zone] .== zone, :Parameter])
            for column in uncertain_columns
                if column in zone_params
                    zone_filter = Morris_range[(Morris_range[!, :Zone] .== zone) .& (Morris_range[!, :Parameter] .== column), :]

                    if !isempty(zone_filter)
                        lower_bound = zone_filter[!, :Lower_bound][1] / 100
                        upper_bound = zone_filter[!, :Upper_bound][1] / 100

                        # Find the correct column index by name
                        policy_col_name = column

                        # Find the correct row index by matching the zone name from the GSA file
                        # to the 'Zone' column in the policy file.
                        # We prepend "z" to the zone from the GSA file to match the policy file format (e.g., "1" -> "z1").
                        zone_to_find = string("z", zone)
                        policy_row_idx = findfirst(isequal(zone_to_find), in_policy_df[!, :Zone])

                        if !isnothing(policy_row_idx)
                            # Use correct indices to access the DataFrame
                            base_value = in_policy_df[policy_row_idx, policy_col_name]
                            sigma_lower = base_value * (1 + lower_bound)
                            sigma_upper = base_value * (1 + upper_bound)
                            push!(sigma_rows, [sigma_lower sigma_upper])
                        else
                            if isnothing(policy_row_idx)
                                @warn "Zone '$zone' from GSA file not found in policy file."
                            end
                        end
                    end
                end
            end
        end
        sigma = vcat(sigma_rows...)
    end
    if setup["MinCapReq"] == 1 && morris_range_path == joinpath(path, "Method_of_morris_minimum_capacity_requirement_zone.csv")
        in_policy = inputs["MinCapReq"]
        p_zone = unique(Morris_range[!, :Zone])
        p_pivot = String[]
        
       # MinCapReq is a Vector - create mapping from unique constraint names to indices
       unique_constraints = unique(Morris_range[!, :Parameter])
#       println("Unique constraints: ", unique_constraints)
#       println("Number of unique constraints: ", length(unique_constraints))
#       println("MinCapReq vector length: ", length(in_policy))

        # Create a dictionary mapping constraint names to their index
       constraint_to_idx = Dict(unique_constraints[i] => i for i in 1:length(unique_constraints))
#       println("Constraint to index mapping: ", constraint_to_idx)
       
       # Creating the range of uncertain parameters in terms of absolute values
       sigma_rows = []
       
       # Process each row in the CSV
       for row in eachrow(Morris_range)
           constraint_name = row[:Parameter]
           lower_bound = row[:Lower_bound] / 100
           upper_bound = row[:Upper_bound] / 100
           
#           println("Processing constraint: ", constraint_name)
           
           # Get the index for this constraint
           if haskey(constraint_to_idx, constraint_name)
               idx = constraint_to_idx[constraint_name]
               base_value = in_policy[idx]
               
               sigma_lower = base_value * (1 + lower_bound)
               sigma_upper = base_value * (1 + upper_bound)
               push!(sigma_rows, [sigma_lower sigma_upper])
               
 #              println("  Index: $idx, Base: $base_value, Range: [$sigma_lower, $sigma_upper]")
           else
               @warn "Constraint '$(constraint_name)' not found in mapping"
           end
       end
       
        sigma = vcat(sigma_rows...)
    end   
       # Maximum Capacity Requirement
    if setup["MaxCapReq"] == 1 && morris_range_path == joinpath(path, "Method_of_morris_maximum_capacity_requirement_zone.csv")
        in_policy = inputs["MaxCapReq"]
        p_zone = unique(Morris_range[!, :Zone])
        p_pivot = String[]
        pivot_variable = p_zone
        # Creating the range of uncertain parameters in terms of absolute values
        sigma_rows = []
        for zone in pivot_variable
            # Get the parameters (constraint names) that are actually defined for this zone in the Morris_range file
            zone_params = unique(Morris_range[Morris_range[!, :Zone] .== zone, :Parameter])

            for constraint_name in zone_params
                # Filter the morris range to get the bounds for this specific constraint
                constraint_filter = Morris_range[(Morris_range[!, :Zone] .== zone) .& (Morris_range[!, :Parameter] .== constraint_name), :]

                if !isempty(constraint_filter)
                    lower_bound = constraint_filter[!, :Lower_bound][1] / 100
                    upper_bound = constraint_filter[!, :Upper_bound][1] / 100

                    # Use the constraint_name (e.g., "NY_offshorewind") to look up the base value in the policy dictionary
                    if haskey(in_policy, constraint_name)
                        base_value = in_policy[constraint_name][1]
                        sigma_lower = base_value * (1 + lower_bound)
                        sigma_upper = base_value * (1 + upper_bound)
                        push!(sigma_rows, [sigma_lower sigma_upper])
                    end
                end
            end
        end
        sigma = vcat(sigma_rows...)
    end 
    # Minimum Capacity Requirement
    if setup["MinCapReq"] == 1 && morris_range_path == joinpath(path, "Method_of_morris_minimum_capacity_requirement.csv")
        in_policy = inputs["MinCapReq"]
        p_zone = String[]  # empty
        p_pivot = unique(Morris_range[!, :MinCapReqConstraint])  # Use unique and convert to symbols    
        pivot_variable = p_pivot        
        # Creating the range of uncertain parameters in terms of absolute values
        sigma_rows = []
        for constraint in pivot_variable
            # Get the parameters that are actually defined for this constraint in the Morris_range file
            constraint_params = unique(Morris_range[Morris_range[!, :MinCapReqConstraint] .== constraint, :Parameter])
            for column in uncertain_columns
                if column in constraint_params
                    constraint_filter = Morris_range[(Morris_range[!, :MinCapReqConstraint] .== constraint) .& (Morris_range[!, :Parameter] .== column), :]
                    
                    if !isempty(constraint_filter)
                        lower_bound = constraint_filter[!, :Lower_bound][1] / 100
                        upper_bound = constraint_filter[!, :Upper_bound][1] / 100
                        # Use constraint name to access the dictionary-like object
                        base_value = in_policy[constraint]
                        sigma_lower = base_value * (1 + lower_bound)
                        sigma_upper = base_value * (1 + upper_bound)
                        push!(sigma_rows, [sigma_lower sigma_upper])
                    end
                end
            end
        end
        sigma = vcat(sigma_rows...)
    end
    # Maximum Capacity Requirement
    if setup["MaxCapReq"] == 1 && morris_range_path == joinpath(path, "Method_of_morris_maximum_capacity_requirement.csv")
        in_policy = inputs["MaxCapReq"]
        p_zone = String[]  # empty
        p_pivot = unique(Morris_range[!, :MaxCapReqConstraint])  # Use unique and convert to symbols    
        pivot_variable = p_pivot        
        # Creating the range of uncertain parameters in terms of absolute values
        sigma_rows = []
        for constraint in pivot_variable
            # Get the parameters that are actually defined for this constraint in the Morris_range file
            constraint_params = unique(Morris_range[Morris_range[!, :MaxCapReqConstraint] .== constraint, :Parameter])
            for column in uncertain_columns
                if column in constraint_params
                    constraint_filter = Morris_range[(Morris_range[!, :MaxCapReqConstraint] .== constraint) .& (Morris_range[!, :Parameter] .== column), :]
                    
                    if !isempty(constraint_filter)
                        lower_bound = constraint_filter[!, :Lower_bound][1] / 100
                        upper_bound = constraint_filter[!, :Upper_bound][1] / 100
                        # Use constraint name to access the dictionary-like object
                        base_value = in_policy[constraint]
                        sigma_lower = base_value * (1 + lower_bound)
                        sigma_upper = base_value * (1 + upper_bound)
                        push!(sigma_rows, [sigma_lower sigma_upper])
                    end
                end
            end
        end
        sigma = vcat(sigma_rows...)
    end
    # CO2 Capacity Requirement
    if setup["CO2Cap"] == 1 && morris_range_path == joinpath(path, "Method_of_morris_CO2_capacity_requirement_zone.csv")
        # The input matrix has columns: Region_description, Network_zones, param1, param2, ...
        # Since inputs["dfMaxCO2"] is a Matrix without headers, we must reload the file to get the DataFrame.
        # The CSV is in the 'policies' directory, relative to the main case 'inputs' directory.
        # Load the full policy DataFrame to access the correct column names.
        policies_path = joinpath(path, setup["PoliciesFolder"])
        CO2_cap_filename = "CO2_cap.csv"
        in_policy_df_full = load_dataframe(joinpath(policies_path, CO2_cap_filename))
        
        # Select all columns from the second one ("Network_zones") to the end.
        # This preserves the original parameter column names (ESR_1, ESR_2, etc.).
        in_policy_df = DataFrame(in_policy_df_full[:, 2:end], names(in_policy_df_full)[2:end])
        # Rename the first column to "Zone"
        rename!(in_policy_df, names(in_policy_df)[1] => "Zone")
     
        p_zone = unique(Morris_range[!, :Zone])
        p_pivot = String[]  # empty

        pivot_variable = p_zone

        # Creating the range of uncertain parameters in terms of absolute values
        sigma_rows = []
        for (i_zone, zone) in enumerate(pivot_variable)
            # Get the parameters that are actually defined for this zone in the Morris_range file
            zone_params = unique(Morris_range[Morris_range[!, :Zone] .== zone, :Parameter])
            for column in uncertain_columns
                if column in zone_params
                    zone_filter = Morris_range[(Morris_range[!, :Zone] .== zone) .& (Morris_range[!, :Parameter] .== column), :]

                    if !isempty(zone_filter)
                        lower_bound = zone_filter[!, :Lower_bound][1] / 100
                        upper_bound = zone_filter[!, :Upper_bound][1] / 100

                        # Find the correct column index by name
                        policy_col_name = column

                        # Find the correct row index by matching the zone name from the GSA file
                        # to the 'Zone' column in the policy file.
                        # We prepend "z" to the zone from the GSA file to match the policy file format (e.g., "1" -> "z1").
                        zone_to_find = string("z", zone)
                        policy_row_idx = findfirst(isequal(zone_to_find), in_policy_df[!, :Zone])

                        if !isnothing(policy_row_idx)
                            # Use correct indices to access the DataFrame
                            base_value = in_policy_df[policy_row_idx, policy_col_name]
                            sigma_lower = base_value * (1 + lower_bound)
                            sigma_upper = base_value * (1 + upper_bound)
                            push!(sigma_rows, [sigma_lower sigma_upper])
                        else
                            if isnothing(policy_row_idx)
                                @warn "Zone '$zone' from GSA file not found in policy file."
                            end
                        end
                    end
                end
            end
        end
        sigma = vcat(sigma_rows...)
    end
    # General case: Method_of_morris_range.csv
    if morris_range_path == joinpath(path, "Method_of_morris_range.csv")
        p_zone = String[]  # empty
        p_pivot = String[] # empty    
        gen = inputs["RESOURCES"]
        sigma = zeros((1, 2))
        for column in uncertain_columns
            col_sym = Symbol(lowercase(column))
            # column_f is the function to get the value "column" for each generator
            column_f = isdefined(GenX, col_sym) ? getfield(GenX, col_sym) :
                    r -> getproperty(r, col_sym)
            # Extract the bounds for this parameter (should be scalar values)
            lower_bound = first(Morris_range[Morris_range[!, :Parameter] .== column, :Lower_bound]) / 100
            upper_bound = first(Morris_range[Morris_range[!, :Parameter] .== column, :Upper_bound]) / 100
            # Create a matrix with lower bounds in column 1 and upper bounds in column 2
            column_values = column_f.(gen)
            sigma_new = hcat(column_values .* (1 .+ lower_bound), 
                            column_values .* (1 .+ upper_bound))
            sigma = [sigma; sigma_new]
        end
    end
    # Zonal General case: Method_of_morris_range_zone.csv
    esr_zone_row_lookup = Dict{String, Int}()
    capres_zone_row_lookup = Dict{String, Int}()
    mincap_constraint_to_idx = Dict{String, Int}()
    maxcap_constraint_to_idx = Dict{String, Int}()
    if morris_range_path == joinpath(path, "Method_of_morris_range_zone.csv")
        p_zone = String[]  # empty
        p_pivot = String[] # empty
        active_zone_row_indices = Int[]

        if setup["EnergyShareRequirement"] >= 1 && haskey(inputs, "dfESR")
            policies_path = joinpath(path, setup["PoliciesFolder"])
            esr_policy_path = joinpath(policies_path, "Energy_share_requirement.csv")
            if isfile(esr_policy_path)
                esr_policy_df = load_dataframe(esr_policy_path)
                zone_col = if :Network_zones in names(esr_policy_df)
                    :Network_zones
                elseif :Zone in names(esr_policy_df)
                    :Zone
                else
                    nothing
                end
                if zone_col !== nothing
                    for (i, zone_val) in enumerate(esr_policy_df[!, zone_col])
                        zidx = _zone_index_from_value(zone_val)
                        if zidx !== nothing
                            esr_zone_row_lookup[string("z", zidx)] = i
                        else
                            esr_zone_row_lookup[lowercase(strip(string(zone_val)))] = i
                        end
                    end
                end
            end
        end

        if setup["CapacityReserveMargin"] > 0 && haskey(inputs, "dfCapRes")
            policies_path = joinpath(path, setup["PoliciesFolder"])
            capres_policy_path = joinpath(policies_path, "Capacity_reserve_margin.csv")
            if isfile(capres_policy_path)
                capres_policy_df = load_dataframe(capres_policy_path)
                zone_col = if :Network_zones in names(capres_policy_df)
                    :Network_zones
                elseif :Zone in names(capres_policy_df)
                    :Zone
                else
                    nothing
                end
                if zone_col !== nothing
                    for (i, zone_val) in enumerate(capres_policy_df[!, zone_col])
                        zidx = _zone_index_from_value(zone_val)
                        if zidx !== nothing
                            capres_zone_row_lookup[string("z", zidx)] = i
                        else
                            capres_zone_row_lookup[lowercase(strip(string(zone_val)))] = i
                        end
                    end
                end
            end
        end

        if setup["MinCapReq"] == 1 && haskey(inputs, "MinCapReq")
            policies_path = joinpath(path, setup["PoliciesFolder"])
            mincap_policy_path = joinpath(policies_path, "Minimum_capacity_requirement.csv")
            if isfile(mincap_policy_path)
                mincap_policy_df = load_dataframe(mincap_policy_path)
                if :MinCapReqConstraint in names(mincap_policy_df)
                    for (i, cname) in enumerate(mincap_policy_df[!, :MinCapReqConstraint])
                        mincap_constraint_to_idx[lowercase(strip(String(cname)))] = i
                    end
                end
            end
        end

        if setup["MaxCapReq"] == 1 && haskey(inputs, "MaxCapReq")
            policies_path = joinpath(path, setup["PoliciesFolder"])
            maxcap_policy_path = joinpath(policies_path, "Maximum_capacity_requirement.csv")
            if isfile(maxcap_policy_path)
                maxcap_policy_df = load_dataframe(maxcap_policy_path)
                if :MaxCapReqConstraint in names(maxcap_policy_df)
                    for (i, cname) in enumerate(maxcap_policy_df[!, :MaxCapReqConstraint])
                        maxcap_constraint_to_idx[lowercase(strip(String(cname)))] = i
                    end
                end
            end
        end
        
        # Initialize sigma once as an empty matrix to append to.
        sigma = zeros(0, 2)

        # List of input data sources to process
        # FUELS is included only for optional custom-table attribute screening.
        data_sources = ["RESOURCES", "pD", "FUELS", "NETWORK"]

        # Iterate over each rule defined in the Morris range file
        for (row_idx, row) in enumerate(eachrow(Morris_range))
            column = row[:Parameter]
            morris_zone = row[:Zone]
            lower_bound = row[:Lower_bound] / 100
            upper_bound = row[:Upper_bound] / 100

            param_name_lower = lowercase(String(column))
            if param_name_lower in screening_toggle_params || param_name_lower in screening_multiplier_params
                screening_items = _screening_items(inputs, param_name_lower)
                target_items = _target_resources_for_screening(screening_items, param_name_lower, morris_zone)
                if !isempty(target_items)
                    sigma_new = hcat([Float64(row[:Lower_bound])], [Float64(row[:Upper_bound])])
                    sigma = vcat(sigma, sigma_new)
                    push!(active_zone_row_indices, row_idx)
                end
                continue
            end

            # Fuel-name mapping (e.g., Parameter = "Hydrogen").
            # Fuel economics in GenX use inputs["fuel_costs"][fuel_name], so include a scalar
            # multiplier dimension here whenever the parameter matches a fuel key.
            fuel_name = String(column)
            if haskey(inputs, "fuel_costs") && haskey(inputs["fuel_costs"], fuel_name)
                base_multiplier = 1.0
                    # Optional custom FUELS metadata can override the default baseline multiplier.
                if haskey(inputs, "FUELS")
                    fuel_rows = filter(r -> hasproperty(r, :fuel) && string(r.fuel) == fuel_name, eachrow(inputs["FUELS"]))
                    if !isempty(fuel_rows) && hasproperty(first(fuel_rows), :fuel_price_multiplier)
                        base_multiplier = Float64(first(fuel_rows).fuel_price_multiplier)
                    end
                end
                sigma_new = hcat([base_multiplier * (1 + lower_bound)], [base_multiplier * (1 + upper_bound)])
                sigma = vcat(sigma, sigma_new)
                push!(active_zone_row_indices, row_idx)
                continue
            end

            # Demand column mapping (e.g., Parameter = "Demand_MW_z1").
            # In model construction, zonal demand is consumed from inputs["pD"];
            # treat these parameters as zonal multipliers around baseline 1.0.
            demand_zone = _demand_zone_from_parameter(column)
            if demand_zone !== nothing
                if haskey(inputs, "pD") && 1 <= demand_zone <= size(inputs["pD"], 2)
                    sigma_new = hcat([1.0 * (1 + lower_bound)], [1.0 * (1 + upper_bound)])
                    sigma = vcat(sigma, sigma_new)
                    push!(active_zone_row_indices, row_idx)
                end
                continue
            end

            # Line-level reinforcement mapping (e.g., Parameter = "Line_Max_Reinforcement_MW_L15").
            # One Morris dimension per line index N; bounds are percent-style around baseline.
            line_idx = _line_index_from_parameter(column)
            if line_idx !== nothing
                nw = _network_inputs_dict(inputs)
                if haskey(nw, "pMax_Line_Reinforcement") && 1 <= line_idx <= length(nw["pMax_Line_Reinforcement"])
                    base_val = nw["pMax_Line_Reinforcement"][line_idx]
                    sigma_new = hcat([base_val * (1 + lower_bound)], [base_val * (1 + upper_bound)])
                    sigma = vcat(sigma, sigma_new)
                    push!(active_zone_row_indices, row_idx)
                end
                continue
            end

            # CO2 mass cap mapping (e.g., Parameter = "CO_2_Max_Mtons_1").
            # sigma holds the absolute perturbed cap value (same units as dfMaxCO2).
            co2_cap_idx = _co2_cap_index_from_parameter(column)
            if co2_cap_idx !== nothing
                if setup["CO2Cap"] == 1 && haskey(inputs, "dfMaxCO2") && haskey(inputs, "dfCO2Cap")
                    zone_to_find = string("z", morris_zone)
                    nw_zones = inputs["dfCO2Cap"][!, :Network_zones]
                    policy_row = findfirst(isequal(zone_to_find), nw_zones)
                    if !isnothing(policy_row) && 1 <= co2_cap_idx <= size(inputs["dfMaxCO2"], 2)
                        base_val = inputs["dfMaxCO2"][policy_row, co2_cap_idx]
                        sigma_new = hcat([base_val * (1 + lower_bound)], [base_val * (1 + upper_bound)])
                        sigma = vcat(sigma, sigma_new)
                        push!(active_zone_row_indices, row_idx)
                    end
                end
                continue
            end

            # Minimum capacity requirement mapping (e.g., Parameter = "MinCapReq_1"
            # or policy constraint name from Minimum_capacity_requirement.csv).
            mincap_idx = _mincap_index_from_parameter(column)
            if mincap_idx === nothing && !isempty(mincap_constraint_to_idx)
                mincap_idx = get(mincap_constraint_to_idx, lowercase(strip(String(column))), nothing)
            end
            if mincap_idx !== nothing
                if setup["MinCapReq"] == 1 && haskey(inputs, "MinCapReq") && 1 <= mincap_idx <= length(inputs["MinCapReq"])
                    base_val = inputs["MinCapReq"][mincap_idx]
                    sigma_new = hcat([base_val * (1 + lower_bound)], [base_val * (1 + upper_bound)])
                    sigma = vcat(sigma, sigma_new)
                    push!(active_zone_row_indices, row_idx)
                end
                continue
            end

            # Maximum capacity requirement mapping (e.g., Parameter = "MaxCapReq_1"
            # or policy constraint name from Maximum_capacity_requirement.csv).
            maxcap_idx = _maxcap_index_from_parameter(column)
            if maxcap_idx === nothing && !isempty(maxcap_constraint_to_idx)
                maxcap_idx = get(maxcap_constraint_to_idx, lowercase(strip(String(column))), nothing)
            end
            if maxcap_idx !== nothing
                if setup["MaxCapReq"] == 1 && haskey(inputs, "MaxCapReq") && 1 <= maxcap_idx <= length(inputs["MaxCapReq"])
                    base_val = inputs["MaxCapReq"][maxcap_idx]
                    sigma_new = hcat([base_val * (1 + lower_bound)], [base_val * (1 + upper_bound)])
                    sigma = vcat(sigma, sigma_new)
                    push!(active_zone_row_indices, row_idx)
                end
                continue
            end

            # Capacity reserve margin mapping (e.g., Parameter = "CapRes_1").
            # sigma holds the absolute perturbed requirement value (same units as dfCapRes).
            capres_idx = _capres_index_from_parameter(column)
            if capres_idx !== nothing
                if setup["CapacityReserveMargin"] > 0 && haskey(inputs, "dfCapRes")
                    zone_idx = _zone_index_from_value(morris_zone)
                    zone_to_find = zone_idx === nothing ? lowercase(strip(string(morris_zone))) : string("z", zone_idx)
                    policy_row = get(capres_zone_row_lookup, zone_to_find, nothing)
                    if policy_row !== nothing && 1 <= policy_row <= size(inputs["dfCapRes"], 1) && 1 <= capres_idx <= size(inputs["dfCapRes"], 2)
                        base_val = inputs["dfCapRes"][policy_row, capres_idx]
                        sigma_new = hcat([base_val * (1 + lower_bound)], [base_val * (1 + upper_bound)])
                        sigma = vcat(sigma, sigma_new)
                        push!(active_zone_row_indices, row_idx)
                    end
                end
                continue
            end

            # ESR mapping (e.g., Parameter = "ESR_1").
            # sigma holds the absolute perturbed requirement value (same units as dfESR).
            esr_idx = _esr_index_from_parameter(column)
            if esr_idx !== nothing
                if setup["EnergyShareRequirement"] >= 1 && haskey(inputs, "dfESR")
                    zone_idx = _zone_index_from_value(morris_zone)
                    zone_to_find = zone_idx === nothing ? lowercase(strip(string(morris_zone))) : string("z", zone_idx)
                    policy_row = get(esr_zone_row_lookup, zone_to_find, nothing)
                    if policy_row !== nothing && 1 <= policy_row <= size(inputs["dfESR"], 1) && 1 <= esr_idx <= size(inputs["dfESR"], 2)
                        base_val = inputs["dfESR"][policy_row, esr_idx]
                        sigma_new = hcat([base_val * (1 + lower_bound)], [base_val * (1 + upper_bound)])
                        sigma = vcat(sigma, sigma_new)
                        push!(active_zone_row_indices, row_idx)
                    end
                end
                continue
            end

            for source_name in data_sources
                if source_name == "NETWORK"
                    data_source = _network_inputs_dict(inputs)
                    network_key = _resolve_network_key(inputs, column)
                    # Handle network parameters which are arrays in a Dict
                    if network_key !== nothing
                        if param_name_lower == "line_max_reinforcement_mw"
                            # Treat Line_Max_Reinforcement_MW as ONE global multiplier
                            # uncertainty (one Morris dimension per CSV row).
                            sigma_new = hcat([1.0 * (1 + lower_bound)], [1.0 * (1 + upper_bound)])
                            sigma = vcat(sigma, sigma_new)
                            push!(active_zone_row_indices, row_idx)
                        else
                            # For other network parameters, keep element-wise behavior.
                            # For network, 'zone' is not applicable in the same way.
                            # We assume the rule applies to all elements of the array.
                            # If zonal filtering is needed, it would require a different structure.
                            column_values = data_source[network_key]
                            sigma_new = hcat(column_values .* (1 .+ lower_bound),
                                column_values .* (1 .+ upper_bound))
                            sigma = vcat(sigma, sigma_new)
                            push!(active_zone_row_indices, row_idx)
                        end
                    end
                    continue # Move to next source
                end
                if !haskey(inputs, source_name)
                    continue # Skip if data source not in inputs
                end
                
                data_source = inputs[source_name]
                source_items = data_source isa AbstractDataFrame ? collect(eachrow(data_source)) : data_source
                
                # Check if at least one item carries this attribute. Using only
                # first(data_source) can incorrectly skip valid parameters.
                param_sym = Symbol(lowercase(column))
                if !any(item -> _find_property_symbol(item, param_sym) !== nothing, source_items)
                    continue
                end

                # Filter items by zone. If zone is missing/blank, apply to all.
                target_items = if ismissing(morris_zone) || morris_zone == ""
                    source_items # Apply to all items
                else
                    # Use robust zone matching that handles numeric/string zone tokens.
                    filter(item -> _zone_match(item, morris_zone), source_items)
                end

                if isempty(target_items)
                    continue
                end

                # Produce exactly ONE sigma dimension per CSV row regardless of how many
                # resources match in this zone. All matching resources will receive the
                # same sampled value during perturbation, keeping p_steps/groups aligned.
                # Lower_bound / Upper_bound are taken directly from the CSV as absolute
                # sampled-value bounds (consistent with screening params).
                sigma_new = hcat([Float64(row[:Lower_bound])], [Float64(row[:Upper_bound])])
                sigma = vcat(sigma, sigma_new)
                push!(active_zone_row_indices, row_idx)
                break  # Stop after the first matching data source to prevent duplicate rows.
            end
        end
    end
    p_range = [sigma[i, :] for i in 1:size(sigma, 1)]
#    if morris_range_path == joinpath(path, "Method_of_morris_range_zone.csv") && isempty(p_range)
#        available_zone_counts = Dict{String, Int}()
#        if haskey(inputs, "RESOURCES")
#            gas_targets_all = _target_resources_for_screening(inputs["RESOURCES"], "gas_retirement", "")
#            for resource in gas_targets_all
#                zone_str = try
#                    string(zone_id(resource))
#                catch
#                    "<missing>"
#                end
#                zone_norm = lowercase(strip(zone_str))
#                zone_norm = startswith(zone_norm, "z") ? zone_norm[2:end] : zone_norm
#                available_zone_counts[zone_norm] = get(available_zone_counts, zone_norm, 0) + 1
#            end
#        end
#        requested_zones = unique([lowercase(strip(string(z))) for z in Morris_range[!, :Zone]])
#        requested_zones = [startswith(z, "z") ? z[2:end] : z for z in requested_zones]
#        requested_summary = join(["$(z)=>$(get(available_zone_counts, z, 0))" for z in requested_zones], ", ")
#        available_summary = isempty(available_zone_counts) ? "none" : join(["$(k)=>$(v)" for (k, v) in sort(collect(available_zone_counts), by=first)], ", ")
#        error("No valid Method_of_morris_range_zone rows matched model resources. Requested zone target counts: [$(requested_summary)]. Available Gas_Retirement targets by zone: [$(available_summary)]. Check Zone labels and Gas_Retirement targets (Existing_natural_gas / existing thermal with can_retire).")
#    end
    if morris_range_path == joinpath(path, "Method_of_morris_range_zone.csv") && !isempty(active_zone_row_indices)
        groups = Morris_range[active_zone_row_indices, :Group]
        p_steps = Morris_range[active_zone_row_indices, :p_steps]
    end
    morris_rows_for_sampling = Morris_range
    if morris_range_path == joinpath(path, "Method_of_morris_range_zone.csv") && !isempty(active_zone_row_indices)
        morris_rows_for_sampling = Morris_range[active_zone_row_indices, :]
    end

    active_screening_params = Set(lowercase.(String.(uncertain_columns)))
    baseline_attr_set = Set{Symbol}()
    if "gas_retirement" in active_screening_params
        push!(baseline_attr_set, :can_retire)
    end
    if "nuclear_availability" in active_screening_params
        push!(baseline_attr_set, :new_build)
    end
    if "ira_invcost_multiplier" in active_screening_params
        union!(baseline_attr_set, Set([
            :inv_cost_per_mwyr,
            :inv_cost_per_mwhyr,
            :inv_cost_charge_per_mwyr,
        ]))
    end
    if !isempty(intersect(active_screening_params,
            Set(["solar_cost_multiplier", "battery_cost_multiplier", "offshorewind_cost_multiplier", "onshorewind_cost_multiplier"])))
        push!(baseline_attr_set, :inv_cost_per_mwyr)
    end
    if "siting_maxcap_multiplier" in active_screening_params
        push!(baseline_attr_set, :max_cap_mw)
    end
    if "demand_flexibility_multiplier" in active_screening_params
        push!(baseline_attr_set, :existing_cap_mw)
    end
    baseline_attrs = sort(collect(baseline_attr_set), by = string)
    baseline_resource_values = Dict{Tuple{Int64, Symbol}, Any}()
    if haskey(inputs, "RESOURCES")
        for resource in inputs["RESOURCES"]
            if !hasproperty(resource, :id)
                continue
            end
            rid = Int64(resource.id)
            for attr in baseline_attrs
                if hasproperty(resource, attr)
                    baseline_resource_values[(rid, attr)] = getproperty(resource, attr)
                end
            end
        end
    end
    baseline_pD = haskey(inputs, "pD") ? copy(inputs["pD"]) : nothing
    baseline_fuel_costs = haskey(inputs, "fuel_costs") ? Dict(k => copy(v) for (k, v) in inputs["fuel_costs"]) : Dict{Any, Any}()
    baseline_dfESR = (setup["EnergyShareRequirement"] >= 1 && haskey(inputs, "dfESR")) ? copy(inputs["dfESR"]) : nothing
    baseline_dfCapRes = (setup["CapacityReserveMargin"] > 0 && haskey(inputs, "dfCapRes")) ? copy(inputs["dfCapRes"]) : nothing
    baseline_MinCapReq = (setup["MinCapReq"] == 1 && haskey(inputs, "MinCapReq")) ? copy(inputs["MinCapReq"]) : nothing
    baseline_MaxCapReq = (setup["MaxCapReq"] == 1 && haskey(inputs, "MaxCapReq")) ? copy(inputs["MaxCapReq"]) : nothing
    baseline_dfMaxCO2 = (setup["CO2Cap"] == 1 && haskey(inputs, "dfMaxCO2")) ? copy(inputs["dfMaxCO2"]) : nothing
    baseline_network_values = Dict{String, Any}()
    if haskey(inputs, "inputs_nw")
        for (k, v) in inputs["inputs_nw"]
            if v isa AbstractArray
                baseline_network_values[String(k)] = copy(v)
            end
        end
    else
        for (k, v) in inputs
            if v isa AbstractArray
                baseline_network_values[String(k)] = copy(v)
            end
        end
    end

    # Creating a function for iteratively solving the model with different sets of input parameters
    f1 = function (sigma)
        if setup["EnergyShareRequirement"] >= 1 && morris_range_path == joinpath(path, "Method_of_morris_energy_share_requirement_zone.csv")
 #           in_policy = DataFrame(inputs["dfESR"], Symbol.(uncertain_columns))
            in_policy = inputs["dfESR"]
            p_zone = unique(Morris_range[!, :Zone])
            p_pivot = String[]
            pivot_variable = p_zone
        elseif setup["CapacityReserveMargin"] > 0 && morris_range_path == joinpath(path, "Method_of_morris_capacity_reserve_margin_zone.csv")
#            in_policy = DataFrame(inputs["dfCapRes"], Symbol.(uncertain_columns))
            in_policy = inputs["dfCapRes"]
            p_zone = unique(Morris_range[!, :Zone])
            p_pivot = String[]
            pivot_variable = p_zone
        elseif setup["MaxCapReq"] == 1 && morris_range_path == joinpath(path, "Method_of_morris_maximum_capacity_requirement.csv")
            in_policy = copy(inputs["MaxCapReq"])
            p_zone = String[]
            p_pivot = unique(Morris_range[!, :MaxCapReqConstraint])
            pivot_variable = p_pivot
        elseif setup["MaxCapReq"] == 1 && morris_range_path == joinpath(path, "Method_of_morris_maximum_capacity_requirement_zone.csv")
            in_policy = copy(inputs["MaxCapReq"])
            p_zone = unique(Morris_range[!, :Zone])
            p_pivot = String[]
            pivot_variable = p_zone
        elseif setup["MinCapReq"] == 1 && morris_range_path == joinpath(path, "Method_of_morris_minimum_capacity_requirement.csv")
            in_policy = copy(inputs["MinCapReq"])
            p_zone = String[]
            p_pivot = unique(Morris_range[!, :MinCapReqConstraint])
            pivot_variable = p_pivot
        elseif setup["MinCapReq"] == 1 && morris_range_path == joinpath(path, "Method_of_morris_minimum_capacity_requirement_zone.csv")
            in_policy = copy(inputs["MinCapReq"])
            p_zone = unique(Morris_range[!, :Zone])
            p_pivot = String[]
            # Create constraint to index mapping
            unique_constraints = unique(Morris_range[!, :Parameter])
            constraint_to_idx = Dict(unique_constraints[i] => i for i in 1:length(unique_constraints))
        elseif setup["CO2Cap"] == 1 && morris_range_path == joinpath(path, "Method_of_morris_CO2_capacity_requirement_zone.csv")
            in_policy = inputs["dfMaxCO2"]
            p_zone = unique(Morris_range[!, :Zone])
            p_pivot = String[]
            pivot_variable = p_zone        
        elseif morris_range_path == joinpath(path, "Method_of_morris_range.csv")
            p_zone = String[]
            p_pivot = String[]
            pivot_variable = String[]
        elseif morris_range_path == joinpath(path, "Method_of_morris_range_zone.csv")
            p_zone = String[] # Not used in the same way, but kept for consistency
            p_pivot = String[]
            pivot_variable = String[]
        end
        
        k = 1 # Initialize a counter for the sigma vector
        ret_cap_needs_refresh = false
        new_cap_needs_refresh = false
        retrofit_needs_refresh = false
        network_needs_refresh = false
        # Check if both p_zone and p_pivot are empty
        if morris_range_path == joinpath(path, "Method_of_morris_range_zone.csv")
            # FUELS is included only for optional custom-table attribute screening.
            data_sources = ["RESOURCES", "pD", "FUELS", "NETWORK"]
            # Iterate over each rule defined in the Morris range file to ensure order matches sigma
            for row in eachrow(morris_rows_for_sampling)
                column = row[:Parameter]
                morris_zone = row[:Zone]
                param_name_lower = lowercase(String(column))

                if param_name_lower in screening_toggle_params || param_name_lower in screening_multiplier_params
                    screening_items = _screening_items(inputs, param_name_lower)
                    target_items = _target_resources_for_screening(screening_items, param_name_lower, morris_zone)

                    if isempty(target_items)
                        # Keep sigma index aligned with design-matrix dimensions even if
                        # this row has no currently matching targets in this sample.
                        k += 1
                        continue
                    end

                    sampled_value = sigma[k]
                    for item in target_items
                        _item_set!(item, Symbol(param_name_lower), sampled_value)
                    end
                    if param_name_lower == "gas_retirement"
                        value_to_set = Int(round(clamp(sampled_value, 0, 1)))
                        for item in target_items
                            setproperty!(item, :can_retire, value_to_set)
                        end
                        ret_cap_needs_refresh = true
                    elseif param_name_lower == "nuclear_availability"
                        value_to_set = Int(round(clamp(sampled_value, 0, 1)))
                        for item in target_items
                            setproperty!(item, :new_build, value_to_set)
                        end
                        new_cap_needs_refresh = true
                    elseif param_name_lower == "ira_invcost_multiplier"
                        inv_cost_cols = [
                            :inv_cost_per_mwyr,
                            :inv_cost_per_mwhyr,
                            :inv_cost_charge_per_mwyr,
                        ]
                        for item in target_items
                            rid = Int64(item.id)
                            for attr in inv_cost_cols
                                if hasproperty(item, attr) && haskey(baseline_resource_values, (rid, attr))
                                    setproperty!(item, attr, baseline_resource_values[(rid, attr)] * sampled_value)
                                end
                            end
                        end
                    elseif param_name_lower in Set(["solar_cost_multiplier", "battery_cost_multiplier", "offshorewind_cost_multiplier", "onshorewind_cost_multiplier"])
                        for item in target_items
                            rid = Int64(item.id)
                            attr = :inv_cost_per_mwyr
                            if _find_property_symbol(item, attr) !== nothing && haskey(baseline_resource_values, (rid, attr))
                                setproperty!(item, attr, baseline_resource_values[(rid, attr)] * sampled_value)
                            end
                        end
                    elseif param_name_lower == "siting_maxcap_multiplier"
                        for item in target_items
                            rid = Int64(item.id)
                            attr = :max_cap_mw
                            if _find_property_symbol(item, attr) !== nothing && haskey(baseline_resource_values, (rid, attr))
                                setproperty!(item, attr, baseline_resource_values[(rid, attr)] * sampled_value)
                            end
                        end
                    elseif param_name_lower == "demand_flexibility_multiplier"
                        for item in target_items
                            rid = Int64(item.id)
                            attr = :existing_cap_mw
                            if _find_property_symbol(item, attr) !== nothing && haskey(baseline_resource_values, (rid, attr))
                                setproperty!(item, attr, baseline_resource_values[(rid, attr)] * sampled_value)
                            end
                        end
#                    elseif param_name_lower == "can_retrofit"
                        # Handle Can_Retrofit as a binary toggle (0 or 1).
                        # The sampled value is rounded to the nearest integer.
#                        value_to_set = Int(round(clamp(sampled_value, 0, 1)))
#                        for item in target_items
#                            setproperty!(item, :can_retrofit, value_to_set)
#                        end
                        # Changing retrofit eligibility requires rebuilding the retrofit plan.
#                        retrofit_needs_refresh = true
                    elseif param_name_lower == "fuel_price_multiplier"
                        if haskey(inputs, "fuel_costs")
                            for item in target_items
                                item.fuel_price_multiplier = sampled_value
                                fuel_name = String(item.fuel)
                                if haskey(baseline_fuel_costs, fuel_name)
                                    inputs["fuel_costs"][fuel_name] = baseline_fuel_costs[fuel_name] .* sampled_value
                                end
                            end
                        end
                    elseif param_name_lower == "load_multiplier"
                        if baseline_pD !== nothing && haskey(inputs, "pD")
                            for item in target_items
                                item.load_multiplier = sampled_value
                                z = Int(item.zone)
                                inputs["pD"][:, z] = baseline_pD[:, z] .* sampled_value
                            end
                        end
                    end
                    k += 1
                    continue
                end

                # Fuel-name mapping (e.g., "Hydrogen") to model-used fuel price trajectories.
                    line_reinforcement_reset = false
                # Updating FUELS rows alone is not sufficient because fuel costs in the objective
                # are read from inputs["fuel_costs"]. Refresh that dictionary per sample.
                fuel_name = String(column)
                if haskey(inputs, "fuel_costs") && haskey(inputs["fuel_costs"], fuel_name)
                    sampled_value = sigma[k]
                    if haskey(baseline_fuel_costs, fuel_name)
                        inputs["fuel_costs"][fuel_name] = baseline_fuel_costs[fuel_name] .* sampled_value
                    end
                    # Optional custom metadata only: standard GenX does not define inputs["FUELS"].
                    # The model uses inputs["fuel_costs"] above; mirror the multiplier here only
                    # when a custom FUELS table is present.
                    if haskey(inputs, "FUELS")
                        for fuel_row in eachrow(inputs["FUELS"])
                            if hasproperty(fuel_row, :fuel) && string(fuel_row.fuel) == fuel_name && hasproperty(fuel_row, :fuel_price_multiplier)
                                fuel_row.fuel_price_multiplier = sampled_value
                            end
                        end
                    end
                    k += 1
                    continue
                end

                demand_zone = _demand_zone_from_parameter(column)
                if demand_zone !== nothing
                    sampled_value = sigma[k]
                    # Demand_MW_z* parameters act on zonal net load consumed by the optimizer.
                    # Apply sampled multiplier directly to inputs["pD"] (power-balance RHS), and
                    # mirror it in inputs["DEMAND"].load_multiplier for consistency/traceability.
                    if baseline_pD !== nothing && haskey(inputs, "pD") && 1 <= demand_zone <= size(inputs["pD"], 2)
                        inputs["pD"][:, demand_zone] = baseline_pD[:, demand_zone] .* sampled_value
                        if haskey(inputs, "DEMAND") && demand_zone <= nrow(inputs["DEMAND"])
                            inputs["DEMAND"][demand_zone, :load_multiplier] = sampled_value
                        end
                    end
                    k += 1
                    continue
                end

                # Line-level reinforcement perturbation (e.g., Parameter = "Line_Max_Reinforcement_MW_L15").
                # sigma[k] is an absolute scaled value derived from the baseline at sigma-build time.
                line_idx = _line_index_from_parameter(column)
                if line_idx !== nothing
                    sampled_value = sigma[k]
                    nw = _network_inputs_dict(inputs)
                    key_str = "pMax_Line_Reinforcement"
                    if haskey(nw, key_str) && 1 <= line_idx <= length(nw[key_str])
                        nw[key_str][line_idx] = sampled_value
                    end
                    k += 1
                    network_needs_refresh = true
                    continue
                end

                # CO2 mass cap perturbation (e.g., Parameter = "CO_2_Max_Mtons_1").
                # sigma[k] is the absolute perturbed cap value (same scaled units as dfMaxCO2).
                co2_cap_idx = _co2_cap_index_from_parameter(column)
                if co2_cap_idx !== nothing
                    sampled_value = sigma[k]
                    if baseline_dfMaxCO2 !== nothing && haskey(inputs, "dfMaxCO2") && haskey(inputs, "dfCO2Cap")
                        zone_to_find = string("z", morris_zone)
                        nw_zones = inputs["dfCO2Cap"][!, :Network_zones]
                        policy_row = findfirst(isequal(zone_to_find), nw_zones)
                        if !isnothing(policy_row) && 1 <= co2_cap_idx <= size(inputs["dfMaxCO2"], 2)
                            inputs["dfMaxCO2"][policy_row, co2_cap_idx] = sampled_value
                        end
                    end
                    k += 1
                    continue
                end

                # Minimum capacity requirement perturbation (e.g., "MinCapReq_1"
                # or policy constraint label).
                mincap_idx = _mincap_index_from_parameter(column)
                if mincap_idx === nothing && !isempty(mincap_constraint_to_idx)
                    mincap_idx = get(mincap_constraint_to_idx, lowercase(strip(String(column))), nothing)
                end
                if mincap_idx !== nothing
                    sampled_value = sigma[k]
                    if baseline_MinCapReq !== nothing && haskey(inputs, "MinCapReq") && 1 <= mincap_idx <= length(inputs["MinCapReq"])
                        inputs["MinCapReq"][mincap_idx] = sampled_value
                    end
                    k += 1
                    continue
                end

                # Maximum capacity requirement perturbation (e.g., "MaxCapReq_1"
                # or policy constraint label).
                maxcap_idx = _maxcap_index_from_parameter(column)
                if maxcap_idx === nothing && !isempty(maxcap_constraint_to_idx)
                    maxcap_idx = get(maxcap_constraint_to_idx, lowercase(strip(String(column))), nothing)
                end
                if maxcap_idx !== nothing
                    sampled_value = sigma[k]
                    if baseline_MaxCapReq !== nothing && haskey(inputs, "MaxCapReq") && 1 <= maxcap_idx <= length(inputs["MaxCapReq"])
                        inputs["MaxCapReq"][maxcap_idx] = sampled_value
                    end
                    k += 1
                    continue
                end

                # Capacity reserve margin perturbation (e.g., Parameter = "CapRes_1").
                # sigma[k] is the absolute perturbed requirement value (same units as dfCapRes).
                capres_idx = _capres_index_from_parameter(column)
                if capres_idx !== nothing
                    sampled_value = sigma[k]
                    if baseline_dfCapRes !== nothing && haskey(inputs, "dfCapRes")
                        zone_idx = _zone_index_from_value(morris_zone)
                        zone_to_find = zone_idx === nothing ? lowercase(strip(string(morris_zone))) : string("z", zone_idx)
                        policy_row = get(capres_zone_row_lookup, zone_to_find, nothing)
                        if policy_row !== nothing && 1 <= policy_row <= size(inputs["dfCapRes"], 1) && 1 <= capres_idx <= size(inputs["dfCapRes"], 2)
                            inputs["dfCapRes"][policy_row, capres_idx] = sampled_value
                        end
                    end
                    k += 1
                    continue
                end

                # ESR perturbation (e.g., Parameter = "ESR_1").
                # sigma[k] is the absolute perturbed requirement value (same units as dfESR).
                esr_idx = _esr_index_from_parameter(column)
                if esr_idx !== nothing
                    sampled_value = sigma[k]
                    if baseline_dfESR !== nothing && haskey(inputs, "dfESR")
                        zone_idx = _zone_index_from_value(morris_zone)
                        zone_to_find = zone_idx === nothing ? lowercase(strip(string(morris_zone))) : string("z", zone_idx)
                        policy_row = get(esr_zone_row_lookup, zone_to_find, nothing)
                        if policy_row !== nothing && 1 <= policy_row <= size(inputs["dfESR"], 1) && 1 <= esr_idx <= size(inputs["dfESR"], 2)
                            inputs["dfESR"][policy_row, esr_idx] = sampled_value
                        end
                    end
                    k += 1
                    continue
                end

                for source_name in data_sources
                    if source_name == "NETWORK"
                        data_source = _network_inputs_dict(inputs)
                        network_key = _resolve_network_key(inputs, column)
                        if network_key !== nothing
                            if param_name_lower == "line_max_reinforcement_mw"
                                sampled_value = sigma[k]
                                key_str = String(network_key)
                                if !line_reinforcement_reset && haskey(baseline_network_values, key_str)
                                    data_source[network_key] .= baseline_network_values[key_str]
                                    line_reinforcement_reset = true
                                end
                                line_idxs = _network_line_indices_for_zone(inputs, morris_zone)
                                if !isempty(line_idxs)
                                    if haskey(baseline_network_values, key_str)
                                        baseline_vec = baseline_network_values[key_str]
                                        data_source[network_key][line_idxs] .= baseline_vec[line_idxs] .* sampled_value
                                    else
                                        data_source[network_key][line_idxs] .= sampled_value
                                    end
                                end
                                k += 1
                            else
                                # Update each element of the array
                                for i in 1:length(data_source[network_key])
                                    data_source[network_key][i] = sigma[k]
                                    k += 1
                                end
                            end
                            network_needs_refresh = true
                        end
                        continue # Move to next source
                    end
                    if !haskey(inputs, source_name)
                        continue
                    end

                    data_source = inputs[source_name]
                    source_items = data_source isa AbstractDataFrame ? collect(eachrow(data_source)) : data_source
                    attr_to_set = Symbol(param_name_lower)

                    if !any(item -> _find_property_symbol(item, attr_to_set) !== nothing, source_items)
                        continue
                    end

                    target_items = if ismissing(morris_zone) || morris_zone == ""
                        source_items
                    else
                        filter(item -> _zone_match(item, morris_zone), source_items)
                    end

                    if isempty(target_items)
                        continue
                    end

                    # Retrofit-related optimizer sets are cached in inputs (RETROFIT_OPTIONS,
                    # RETROFIT_CAP, RETROFIT_IDS). If Morris perturbs retrofit eligibility
                    # fields, rebuild those sets before generate_model.
                    if attr_to_set in (:retrofit, :can_retrofit, :retrofit_id)
                        retrofit_needs_refresh = true
                    end

                    # One sigma dimension was built per CSV row (not per resource), so
                    # consume exactly one k and broadcast the sampled value to all
                    # matching resources in the zone.
                    sampled_val = sigma[k]
                    k += 1
                    for item in target_items
                        _item_set!(item, attr_to_set, sampled_val)
                    end
                    break  # Stop after the first matching data source to mirror sigma building.
                end
            end
        elseif isempty(p_zone) && isempty(p_pivot)
            gen = inputs["RESOURCES"]
            for column in uncertain_columns
                attr_to_set = Symbol(lowercase(column))
                for resource in gen
                    # Check if the attribute exists before setting it
                    if _find_property_symbol(resource, attr_to_set) !== nothing
                        setproperty!(resource, attr_to_set, sigma[k])
                        k += 1
                    end
                end
            end
        elseif isempty(p_zone) # For pivot-based policies (Min/MaxCapReq)
            for (i_pv, pv) in enumerate(pivot_variable)
                for (j, column) in enumerate(uncertain_columns)
                    # Determine the correct constraint column name based on the file path
                    constraint_col_name = if morris_range_path == joinpath(path, "Method_of_morris_minimum_capacity_requirement.csv")
                        :MinCapReqConstraint
                    elseif morris_range_path == joinpath(path, "Method_of_morris_maximum_capacity_requirement.csv")
                        :MaxCapReqConstraint
                    else
                        # Fallback or error, though one of the above should be true
                        :MinCapReqConstraint 
                    end
                    constraint_filter = Morris_range[(Morris_range[!, constraint_col_name] .== pv) .& (Morris_range[!, :Parameter] .== column), :]
                    if !isempty(constraint_filter)
                        # Use the pivot variable `pv` as the key for the dictionary
                        # The value must be a vector, so we wrap sigma[k] in an array.
                        in_policy[pv] = [sigma[k]]
                        k += 1
                    end
                end
            end
#        elseif isempty(p_pivot) # For zone-based policies (ESR, CapRes, CO2Cap)
#            for (i_pv, pv) in enumerate(pivot_variable)
#                for (j, column) in enumerate(uncertain_columns)
#                    zone_filter = Morris_range[(Morris_range[!, :Zone] .== pv) .& (Morris_range[!, :Parameter] .== column), :]
#                    if !isempty(zone_filter)
#                        #in_policy[i_pv, Symbol(column)] = sigma[k]
#                        in_policy[i_pv, j] = sigma[k]
#                        k += 1
#                    end
#                end
#            end
#        end 
        elseif isempty(p_pivot) # For zone-based policies
            is_dict_policy = isa(in_policy, Dict)
           if is_dict_policy
               # This handles zone-based MinCapReq/MaxCapReq when in_policy is a Dict
               for row in eachrow(Morris_range)
                   constraint_name = row[:Parameter]
                   if haskey(in_policy, constraint_name)
                       in_policy[constraint_name] = [sigma[k]]
                       k += 1
                   end
                end 
             elseif morris_range_path == joinpath(path, "Method_of_morris_minimum_capacity_requirement_zone.csv") && isa(in_policy, AbstractVector)
              # This handles MinCapReq zone when in_policy is a Vector
              unique_constraints = unique(Morris_range[!, :Parameter])
              constraint_to_idx = Dict(unique_constraints[i] => i for i in 1:length(unique_constraints))
              
              for row in eachrow(Morris_range)
                  constraint_name = row[:Parameter]
                  if haskey(constraint_to_idx, constraint_name)
                      idx = constraint_to_idx[constraint_name]
                      in_policy[idx] = sigma[k]
                      k += 1
                  end
              end
          else
               # This handles ESR, CapRes, CO2Cap which use DataFrames/Matrices
               p_zone = unique(Morris_range[!, :Zone])
               for (i_pv, pv) in enumerate(p_zone)
                   for (j, column) in enumerate(uncertain_columns)
                       zone_filter = Morris_range[(Morris_range[!, :Zone] .== pv) .& (Morris_range[!, :Parameter] .== column), :]
                       if !isempty(zone_filter)
                           in_policy[i_pv, j] = sigma[k]
                           k += 1
                       end
                   end
               end
           end
        end  

        # Gas_Retirement perturbs can_retire per Morris sample.
        # GenX retirement constraints are indexed by inputs["RET_CAP"], not directly by can_retire.
        # Rebuild RET_CAP after sample mutations so each solve uses the correct retireable set.
        if ret_cap_needs_refresh && haskey(inputs, "RESOURCES")
            retirable = findall(r -> can_retire(r) == true, inputs["RESOURCES"])
            inputs["RET_CAP"] = intersect(retirable, ids_with_nonneg(inputs["RESOURCES"], existing_cap_mw))
        end

        # Nuclear_Availability perturbs new_build per Morris sample.
        # GenX investment variables are indexed by inputs["NEW_CAP"], not directly by new_build.
        # Rebuild NEW_CAP after sample mutations so each solve uses the correct buildable set.
        if new_cap_needs_refresh && haskey(inputs, "RESOURCES")
            buildable = findall(r -> new_build(r) == true, inputs["RESOURCES"])
            inputs["NEW_CAP"] = intersect(buildable, ids_with(inputs["RESOURCES"], max_cap_mw))
        end

        # Retrofit perturbations can change membership in optimizer-facing retrofit sets.
        # Rebuild cached RETROFIT_* indices from updated resource attributes.
        if retrofit_needs_refresh && haskey(inputs, "RESOURCES")
            gen = inputs["RESOURCES"]
            units_can_retrofit = ids_can_retrofit(gen)
            inputs["RETROFIT_CAP"] = intersect(units_can_retrofit,
                ids_with_nonneg(gen, existing_cap_mw))
            # Ensure retrofit constraints never index retirement variables at missing IDs.
            # investment_discharge constraints use both vRETROFITCAP[y] and vRETCAP[y],
            # so enforce RETROFIT_CAP ⊆ RET_CAP during Morris sample refresh.
            if haskey(inputs, "RET_CAP")
                inputs["RETROFIT_CAP"] = intersect(inputs["RETROFIT_CAP"], inputs["RET_CAP"])
            end
            inputs["RETROFIT_OPTIONS"] = ids_retrofit_options(gen)
            inputs["RETROFIT_IDS"] = Set(retrofit_id.(gen[inputs["RETROFIT_CAP"]]))
        end

        # Final Morris-side guard: normalize key model index sets to Int64 vectors and
        # re-enforce subset consistency before generating the model.
        if haskey(inputs, "RET_CAP")
            inputs["RET_CAP"] = Int64.(collect(inputs["RET_CAP"]))
            unique!(inputs["RET_CAP"])
        end
        if haskey(inputs, "RETROFIT_CAP")
            inputs["RETROFIT_CAP"] = Int64.(collect(inputs["RETROFIT_CAP"]))
            unique!(inputs["RETROFIT_CAP"])
            if haskey(inputs, "RET_CAP")
                inputs["RETROFIT_CAP"] = intersect(inputs["RETROFIT_CAP"], inputs["RET_CAP"])
            end
        end
        if haskey(inputs, "COMMIT")
            inputs["COMMIT"] = Int64.(collect(inputs["COMMIT"]))
            unique!(inputs["COMMIT"])
        end

        # Network reinforcement parameters are consumed through derived arrays/sets.
        # Rebuild these after Morris updates so transmission constraints use the sampled values.
        if network_needs_refresh
            nw = _network_inputs_dict(inputs)
            if haskey(nw, "pTrans_Max") && haskey(nw, "pMax_Line_Reinforcement")
                nw["pTrans_Max_Possible"] = nw["pTrans_Max"] .+ nw["pMax_Line_Reinforcement"]
            end
            if haskey(nw, "pMax_Line_Reinforcement")
                nw["EXPANSION_LINES"] = findall(nw["pMax_Line_Reinforcement"] .>= 0)
                nw["NO_EXPANSION_LINES"] = findall(nw["pMax_Line_Reinforcement"] .< 0)
            end
        end

#        EP = generate_model(setup, inputs, OPTIMIZER)
#        redirect_stdout((() -> optimize!(EP)), open("/dev/null", "w"))
#        [objective_value(EP)]

        # Gurobi token server outages can be transient. Retry model build/solve
        # when we detect token-server connection failures (Error 10009).
        retry_attempts = Int(get(setup, "MorrisLicenseRetryCount", 6))
        retry_base_wait_seconds = Float64(get(setup, "MorrisLicenseRetryBaseSeconds", 10.0))
        local EP
        for attempt in 1:retry_attempts
            try
                EP = generate_model(setup, inputs, OPTIMIZER)
                redirect_stdout(open("/dev/null", "w")) do
                    optimize!(EP)
                end
                break
            catch err
                err_msg = sprint(showerror, err)
                is_token_err = occursin("Gurobi Error 10009", err_msg) ||
                               occursin("Failed to connect to token server", err_msg)
                if !is_token_err || attempt == retry_attempts
                    rethrow(err)
                end
                wait_s = retry_base_wait_seconds * (2.0 ^ (attempt - 1))
                @warn "Transient Gurobi token-server error during Morris run; retrying" attempt retry_attempts wait_seconds=wait_s
                sleep(wait_s)
            end
        end

        system_results = system_outputs_table(outpath, inputs, setup, EP)
        zonal_results = zonal_outputs_table(outpath, inputs, setup, EP)

        system_vector = [
            system_results.SystemTotalCost[1],
            system_results.SystemEmissions[1],
            system_results.SystemPrice[1],
            system_results.SystemCurtailment[1],
            system_results.SystemFirmCapacity[1],
            system_results.SystemTransmissionExpansionCapacity[1],
            system_results.SystemTransmissionExpansionCost[1],
            system_results.SystemTransmissionFlow[1],
            system_results.SystemTransmissionLosses[1]
        ]

        zonal_vector = Vector{Float64}(zonal_results[1, :])

        vcat(system_vector, zonal_vector)
    end

    output_names = [
        "SystemCost",
        "SystemEmissions",
        "SystemPrice",
        "SystemCurtailment",
        "SystemFirmCapacity",
        "SystemTransExpansionCap",
        "SystemTransExpansionCost",
        "SystemTransFlow",
        "SystemTransLoss"
    ]

    # append zonal names
    zones = 1:inputs["Z"]

    append!(output_names, ["Cost_Z$(z)" for z in zones])
    append!(output_names, ["Emissions_Z$(z)" for z in zones])
    append!(output_names, ["Price_Z$(z)" for z in zones])
    append!(output_names, ["Curtailment_Z$(z)" for z in zones])
    append!(output_names, ["FirmCapacity_Z$(z)" for z in zones])
    append!(output_names, ["TransmissionFlow_Z$(z)" for z in zones])
    append!(output_names, ["TransmissionLoss_Z$(z)" for z in zones])

    # Build readable input labels from Morris rows (same row order as means/variances rows)
    input_labels = String[]
    for row in eachrow(morris_rows_for_sampling)
        param_label = string(row[:Parameter])
        zone_label = ""
        if hasproperty(row, :Zone)
            z = row[:Zone]
            z_str = ismissing(z) ? "" : strip(string(z))
            if !isempty(z_str) && lowercase(z_str) != "n/a"
                zone_label = "Zone=" * z_str
            end
        end
        group_label = ""
        if hasproperty(row, :Group)
            g = row[:Group]
            g_str = ismissing(g) ? "" : strip(string(g))
            if !isempty(g_str)
                group_label = "Group=" * g_str
            end
        end
        parts = String[param_label]
        if !isempty(zone_label)
            push!(parts, zone_label)
        end
        if !isempty(group_label)
            push!(parts, group_label)
        end
        push!(input_labels, join(parts, " | "))
    end

    # Perform the method of morris analysis
    m = my_gsa(f1,
        p_steps,
        num_trajectory,
        total_num_trajectory,
        p_range,
        len_design_mat,
        groups,
        random;
        input_labels = input_labels,
        output_labels = output_names,
        bfps_output_path = joinpath(outpath, "morris_bfps_all_outputs.csv"),
        morris_outputs_path = joinpath(outpath, "morris_outputs_all_design_points.csv"))
#    println("Prints the mean effects calculated by the Morris method")
#    println(m.means)
#    println("Prints the mean effects as a DataFrame.")
#    println(DataFrame(m.means', :auto))

    #save the mean effect of each uncertain variable on the objective fucntion
#    Morris_range[!, :mean] = DataFrame(m.means', :auto)[!, :x1]

#    println("Prints the variances of effects as a DataFrame.")
#    println(DataFrame(m.variances', :auto))
    #save the variance of effect of each uncertain variable on the objective function
#    Morris_range[!, :variance] = DataFrame(m.variances', :auto)[!, :x1]

    println("Prints the mean effects as a DataFrame.")
    # m.means is num_outputs × num_params; transpose so columns = outputs, rows = params
    means_df = DataFrame(m.means', :auto)
    if size(means_df, 2) != length(output_names)
        error("Mismatch between Morris mean-output count ($(size(means_df, 2))) and output labels ($(length(output_names))).")
    end
    rename!(means_df, output_names)
    if size(means_df, 1) == length(input_labels)
        insertcols!(means_df, 1, :InputLabel => input_labels)
    else
        fallback_labels = ["Input_$(i)" for i in 1:size(means_df, 1)]
        insertcols!(means_df, 1, :InputLabel => fallback_labels)
    end
    println(means_df)

    println("Prints the variances of effects as a DataFrame.")
    vars_df = DataFrame(m.variances', :auto)
    if size(vars_df, 2) != length(output_names)
        error("Mismatch between Morris variance-output count ($(size(vars_df, 2))) and output labels ($(length(output_names))).")
    end
    rename!(vars_df, output_names)
    if size(vars_df, 1) == length(input_labels)
        insertcols!(vars_df, 1, :InputLabel => input_labels)
    else
        fallback_labels = ["Input_$(i)" for i in 1:size(vars_df, 1)]
        insertcols!(vars_df, 1, :InputLabel => fallback_labels)
    end
    println(vars_df)

    # Save objective sensitivities for compatibility with existing workflow.
    # Use the same row subset used for sampling so row counts always align.
    morris_output_df = copy(morris_rows_for_sampling)
    morris_output_df[!, :mean] = means_df[:, "SystemCost"]
    morris_output_df[!, :variance] = vars_df[:, "SystemCost"]

    # Diagnostic table: how many elementary effects were collected per input,
    # plus SystemCost-specific EE moments to debug zero/NaN Morris rows.
    _system_effect(e) = e isa Number ? Float64(e) : Float64(e[1])
    diag_rows = NamedTuple{(:InputIndex, :InputLabel, :Group, :EffectCount, :SystemCost_EE_Mean, :SystemCost_EE_Variance),
        Tuple{Int64, String, String, Int64, Float64, Float64}}[]
    for i in 1:length(m.elementary_effects)
        ee = m.elementary_effects[i]
        n_ee = length(ee)
        if n_ee > 0
            sys_vals = [_system_effect(v) for v in ee]
            ee_mean = mean(sys_vals)
            ee_var = var(sys_vals; corrected = false)
        else
            ee_mean = 0.0
            ee_var = 0.0
        end
        label = i <= length(input_labels) ? input_labels[i] : "Input_$(i)"
        grp = i <= length(groups) ? string(groups[i]) : ""
        push!(diag_rows,
            (InputIndex = Int64(i),
                InputLabel = String(label),
                Group = String(grp),
                EffectCount = Int64(n_ee),
                SystemCost_EE_Mean = Float64(ee_mean),
                SystemCost_EE_Variance = Float64(ee_var)))
    end
    diag_df = DataFrame(diag_rows)

    # Save full Morris results
    input_map_df = DataFrame(InputIndex = 1:length(input_labels), InputLabel = input_labels)
    CSV.write(joinpath(outpath, "morris_input_labels.csv"), input_map_df)
    CSV.write(joinpath(outpath, "morris_means_all_outputs.csv"), means_df)
    CSV.write(joinpath(outpath, "morris_variances_all_outputs.csv"), vars_df)
    CSV.write(joinpath(outpath, "morris_effect_diagnostics.csv"), diag_df)
    CSV.write(joinpath(outpath, "morris.csv"), morris_output_df)
    return morris_output_df
end