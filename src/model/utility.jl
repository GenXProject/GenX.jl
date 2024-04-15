@doc raw"""
    hoursbefore(p::Int, t::Int, b::Int)

Determines the time index b hours before index t in
a landscape starting from t=1 which is separated
into distinct periods of length p.

For example, if p = 10,
1 hour before t=1 is t=10,
1 hour before t=10 is t=9
1 hour before t=11 is t=20
"""
function hoursbefore(p::Int, t::Int, b::Int)::Int
    period = div(t - 1, p)
    return period * p + mod1(t - b, p)
end

@doc raw"""
    hoursbefore(p::Int, t::Int, b::UnitRange)

This is a generalization of hoursbefore(... b::Int)
to allow for example b=1:3 to fetch a Vector{Int} of the three hours before
time index t.
"""
function hoursbefore(p::Int, t::Int, b::UnitRange{Int})::Vector{Int}
    period = div(t - 1, p)
    return period * p .+ mod1.(t .- b, p)
end

@doc raw"""
    hoursafter(p::Int, t::Int, a::Int)

Determines the time index a hours after index t in
a landscape starting from t=1 which is separated
into distinct periods of length p.

For example, if p = 10,
1 hour after t=9 is t=10,
1 hour after t=10 is t=1,
1 hour after t=11 is t=2
"""
function hoursafter(p::Int, t::Int, a::Int)::Int
    period = div(t - 1, p)
    return period * p + mod1(t + a, p)
end

@doc raw"""
    hoursafter(p::Int, t::Int, b::UnitRange)

This is a generalization of hoursafter(... b::Int)
to allow for example a=1:3 to fetch a Vector{Int} of the three hours after
time index t.
"""
function hoursafter(p::Int, t::Int, a::UnitRange{Int})::Vector{Int}
    period = div(t - 1, p)
    return period * p .+ mod1.(t .+ a, p)
end

@doc raw"""
    is_nonzero(df::DataFrame, col::Symbol)::BitVector

This function checks if a column in a dataframe is all zeros.
"""
function is_nonzero(df::DataFrame, col::Symbol)::BitVector
    convert(BitVector, df[!, col] .> 0)::BitVector
end

function is_nonzero(rs::Vector{<:AbstractResource}, col::Symbol)
    !isnothing(findfirst(r -> get(r, col, 0) ≠ 0, rs))
end

@doc raw""" 
    by_rid_res(rid::Integer, sym::Symbol, rs::Vector{<:AbstractResource})
    
    This function returns the value of the attribute `sym` for the resource given by the ID `rid`.
"""
function by_rid_res(rid::Integer, sym::Symbol, rs::Vector{<:AbstractResource})
    r = rs[findfirst(resource_id.(rs) .== rid)]
    # use getter function for attribute `sym` if exists in GenX, otherwise get the attribute directly
    f = isdefined(GenX, sym) ? getfield(GenX, sym) : x -> getproperty(x, sym)
    return f(r)
end

@doc raw"""
    (inputs_dict::Dict, num_stages::Int)

This function validates that all the resources do not switch from havig `can_retire = 0` to `can_retire = 1` during the multi-stage optimization.

# Arguments
- `inputs_dict::Dict`: A dictionary containing the inputs for each stage.
- `num_stages::Int`: The number of stages in the multi-stage optimization.

# Returns
- Throws an error if a resource switches from `can_retire = 0` to `can_retire = 1` between stages.
"""
function validate_can_retire_multistage(inputs_dict::Dict, num_stages::Int)
    for stage in 2:num_stages   # note: loop starts from 2 because we are comparing stage t with stage t-1
        can_retire_current = can_retire.(inputs_dict[stage]["RESOURCES"])
        can_retire_previous = can_retire.(inputs_dict[stage - 1]["RESOURCES"])

        # Check if any resource switched from can_retire = 0 to can_retire = 1 between stage t-1 and t
        if any(can_retire_current .- can_retire_previous .> 0)
            # Find the resources that switched from can_retire = 0 to can_retire = 1 and throw an error
            retire_switch_ids = findall(can_retire_current .- can_retire_previous .> 0)
            resources_switched = inputs_dict[stage]["RESOURCES"][retire_switch_ids]
            for resource in resources_switched
                @warn "Resource `$(resource_name(resource))` with id = $(resource_id(resource)) switched " *
                      "from can_retire = 0 to can_retire = 1 between stages $(stage - 1) and $stage"
            end
            msg = "Current implementation of multi-stage optimization does not allow resources " *
                  "to switch from can_retire = 0 to can_retire = 1 between stages."
            error(msg)
        end
    end
    return nothing
end
