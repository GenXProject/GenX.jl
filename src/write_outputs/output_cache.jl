@doc raw"""
        OutputCache

Container for extracted model outputs reused across write-output functions to
reduce repeated JuMP value materialization and large temporary allocations.

# Fields
- `scale_factor::Float64`: Output scaling multiplier (1 or `ModelScalingFactor`).
- `resource_time_scratch::Matrix{Float64}`: Reusable `G x T` workspace.
- `price::Union{Nothing, Matrix{Float64}}`: Cached locational marginal prices (`T x Z`).
- `vP::Matrix{Float64}`: Cached dispatch (`G x T`).
- `eTotalCap::Vector{Float64}`: Cached endogenously available capacity (`G`).
- `vCHARGE`, `vCHARGE_FLEX`, `vUSE`, `vCHARGE_VRE_STOR`, `vCHARGE_ALLAM`:
    optional cached charging/consumption matrices.
- `vS`, `vS_HYDRO`, `vS_FLEX`, `vS_VRE_STOR`: optional cached storage-state matrices.
- `vNSE::Union{Nothing, Array{Float64,3}}`: optional cached non-served energy tensor.
- `eEmissionsByZone::Union{Nothing, Matrix{Float64}}`: optional cached zonal emissions.
"""
struct OutputCache
    scale_factor::Float64
    resource_time_scratch::Matrix{Float64}
    price::Union{Nothing, Matrix{Float64}}
    vP::Matrix{Float64}
    eTotalCap::Vector{Float64}
    vCHARGE::Union{Nothing, Matrix{Float64}}
    vCHARGE_FLEX::Union{Nothing, Matrix{Float64}}
    vUSE::Union{Nothing, Matrix{Float64}}
    vCHARGE_VRE_STOR::Union{Nothing, Matrix{Float64}}
    vCHARGE_ALLAM::Union{Nothing, Matrix{Float64}}
    vS::Union{Nothing, Matrix{Float64}}
    vS_HYDRO::Union{Nothing, Matrix{Float64}}
    vS_FLEX::Union{Nothing, Matrix{Float64}}
    vS_VRE_STOR::Union{Nothing, Matrix{Float64}}
    vNSE::Union{Nothing, Array{Float64, 3}}
    eEmissionsByZone::Union{Nothing, Matrix{Float64}}
end

_extract_output_data(var::JuMP.Containers.DenseAxisArray) = var.data
_extract_output_data(var::AbstractArray) = var

_extract_output_matrix(var)::Matrix{Float64} = Matrix{Float64}(Array(value.(
    _extract_output_data(var))))

_extract_output_vector(var)::Vector{Float64} = vec(Array(value.(
    _extract_output_data(var))))

@doc raw"""
    build_output_cache(
        EP::Model,
        inputs::Dict,
        setup::Dict,
        output_settings_d::Dict = setup["WriteOutputsSettingsDict"];
        selective::Bool = false)

Build an `OutputCache` for write-output routines.

When `selective=true`, only values needed by enabled outputs in
`output_settings_d` are materialized; otherwise, common output matrices are
eagerly extracted once.

# Arguments
- `EP::Model`: Solved JuMP model.
- `inputs::Dict`: Parsed GenX input data.
- `setup::Dict`: Run settings.
- `output_settings_d::Dict`: Output toggles.
- `selective::Bool=false`: Enable selective extraction.

# Returns
- `OutputCache`: Cache object shared by write-output functions.
"""
function build_output_cache(
    EP::Model,
    inputs::Dict,
    setup::Dict,
    output_settings_d::Dict = setup["WriteOutputsSettingsDict"];
    selective::Bool = false)
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1.0
    G = inputs["G"]
    T = inputs["T"]

    needs_power = output_settings_d["WritePower"] ||
                  output_settings_d["WriteCapacityFactor"] ||
                  output_settings_d["WriteCurtailment"] ||
                  output_settings_d["WriteEnergyRevenue"] ||
                  output_settings_d["WriteChargingCost"] ||
                  output_settings_d["WriteNetRevenue"]
    needs_capacity = output_settings_d["WriteCapacityFactor"] ||
                     output_settings_d["WriteCurtailment"]
    needs_charge = output_settings_d["WriteCharge"] ||
                   output_settings_d["WriteChargingCost"] ||
                   output_settings_d["WriteNetRevenue"]
    needs_storage = output_settings_d["WriteStorage"] ||
                    output_settings_d["WriteStorageDual"] ||
                    output_settings_d["WriteNetRevenue"]
    needs_price = has_duals(EP) == 1 && (
        output_settings_d["WritePrice"] ||
        output_settings_d["WriteEnergyRevenue"] ||
        output_settings_d["WriteChargingCost"] ||
        output_settings_d["WriteNetRevenue"])
    needs_scratch = needs_power || needs_capacity || needs_storage ||
                    output_settings_d["WriteNSE"] ||
                    output_settings_d["WriteEmissions"] ||
                    output_settings_d["WriteEnergyRevenue"] ||
                    output_settings_d["WriteChargingCost"]

    return OutputCache(
        scale_factor,
        selective && !needs_scratch ? zeros(Float64, 0, 0) : zeros(Float64, G, T),
        needs_price ? locational_marginal_price(EP, inputs, setup) : nothing,
        selective && !needs_power ? zeros(Float64, 0, 0) : _extract_output_matrix(EP[:vP]),
        selective && !needs_capacity ? zeros(Float64, 0) : _extract_output_vector(EP[:eTotalCap]),
        selective && !needs_charge || isempty(inputs["STOR_ALL"]) ? nothing : _extract_output_matrix(EP[:vCHARGE]),
        selective && !needs_charge || isempty(inputs["FLEX"]) ? nothing : _extract_output_matrix(EP[:vCHARGE_FLEX]),
        selective && !needs_charge || isempty(inputs["ELECTROLYZER"]) ? nothing : _extract_output_matrix(EP[:vUSE]),
        selective && !needs_charge || isempty(inputs["VRE_STOR"]) ? nothing : _extract_output_matrix(EP[:vCHARGE_VRE_STOR]),
        selective && !needs_charge || isempty(inputs["ALLAM_CYCLE_LOX"]) ? nothing : _extract_output_matrix(EP[:vCHARGE_ALLAM]),
        selective && !needs_storage || isempty(inputs["STOR_ALL"]) ? nothing : _extract_output_matrix(EP[:vS]),
        selective && !needs_storage || isempty(inputs["HYDRO_RES"]) ? nothing : _extract_output_matrix(EP[:vS_HYDRO]),
        selective && !needs_storage || isempty(inputs["FLEX"]) ? nothing : _extract_output_matrix(EP[:vS_FLEX]),
        selective && !needs_storage || isempty(inputs["VRE_STOR"]) ? nothing : _extract_output_matrix(EP[:vS_VRE_STOR]),
        output_settings_d["WriteNSE"] ? Array{Float64, 3}(Array(value.(EP[:vNSE]))) : nothing,
        output_settings_d["WriteEmissions"] ? _extract_output_matrix(EP[:eEmissionsByZone]) : nothing)
end

@doc raw"""
    resource_time_scratch!(cache::OutputCache) -> Matrix{Float64}

Clear and return the reusable `G x T` scratch matrix stored in `cache`.
"""
function resource_time_scratch!(cache::OutputCache)::Matrix{Float64}
    fill!(cache.resource_time_scratch, 0.0)
    return cache.resource_time_scratch
end

@doc raw"""
    scaled_resource_time_matrix!(cache::OutputCache, data::Matrix{Float64})

Return `data` scaled by `cache.scale_factor` while avoiding unnecessary
allocations. If scaling is not needed, returns `data`; otherwise, writes the
scaled result into cache scratch memory and returns that scratch matrix.
"""
function scaled_resource_time_matrix!(cache::OutputCache, data::Matrix{Float64})
    if cache.scale_factor == 1
        return data
    end
    scratch = resource_time_scratch!(cache)
    copyto!(scratch, data)
    rmul!(scratch, cache.scale_factor)
    return scratch
end

@doc raw"""
    materialize_output_blocks(blocks, block_ids::Vector{Vector{Int}}, T::Int)

Stack a list of `blocks` (each with `T` columns) into one dense matrix and the
corresponding flattened resource-id vector.

# Arguments
- `blocks`: Row blocks to stack.
- `block_ids::Vector{Vector{Int}}`: Resource ids for each block row.
- `T::Int`: Number of time steps (columns).

# Returns
- `(data, ids)`: `data::Matrix{Float64}` and `ids::Vector{Int}`.
"""
function materialize_output_blocks(blocks, block_ids::Vector{Vector{Int}}, T::Int)
    total_rows = sum(length, block_ids; init = 0)
    data = Matrix{Float64}(undef, total_rows, T)
    ids = Vector{Int}(undef, total_rows)

    next_row = 1
    for (block, ids_block) in zip(blocks, block_ids)
        row_count = length(ids_block)
        row_range = next_row:(next_row + row_count - 1)
        data[row_range, :] .= block
        ids[row_range] .= ids_block
        next_row += row_count
    end

    return data, ids
end