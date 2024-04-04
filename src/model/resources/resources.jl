"""
    resource_types

Name of the type of resources available in the model.

Possible values:
- :Thermal
- :Vre
- :Hydro
- :Storage
- :MustRun
- :FlexDemand
- :VreStorage
- :Electrolyzer
"""
const resource_types = (:Thermal,
    :Vre,
    :Hydro,
    :Storage,
    :MustRun,
    :FlexDemand,
    :VreStorage,
    :Electrolyzer)

# Create composite types (structs) for each resource type in resource_types
for r in resource_types
    let dict = :dict, r = r
        @eval begin
            struct $r{names <: Symbol, T <: Any} <: AbstractResource
                $dict::Dict{names, T}
            end
            Base.parent(r::$r) = getfield(r, $(QuoteNode(dict)))
        end
    end
end

"""
    Base.getproperty(r::AbstractResource, sym::Symbol)

Allows to access the attributes of an `AbstractResource` object using dot syntax. It checks if the attribute exists in the object and returns its value, otherwise it throws an `ErrorException` indicating that the attribute does not exist.

# Arguments:
- `r::AbstractResource`: The resource object.
- `sym::Symbol`: The symbol representing the attribute name.

# Returns:
- The value of the attribute if it exists in the parent object.

Throws:
- `ErrorException`: If the attribute does not exist in the resource.

"""
function Base.getproperty(r::AbstractResource, sym::Symbol)
    haskey(parent(r), sym) && return parent(r)[sym]
    throw(ErrorException("type $(nameof(typeof(r))) has no attribute $(string(sym))"))
end

"""
    setproperty!(r::AbstractResource, sym::Symbol, value)

Allows to set the attribute `sym` of an `AbstractResource` object using dot syntax. 

# Arguments:
- `r::AbstractResource`: The resource object.
- `sym::Symbol`: The symbol representing the attribute name.
- `value`: The value to set for the attribute.

"""
Base.setproperty!(r::AbstractResource, sym::Symbol, value) = setindex!(parent(r),
    value,
    sym)

"""
    haskey(r::AbstractResource, sym::Symbol)

Check if an `AbstractResource` object has a specific attribute. It returns a boolean value indicating whether the attribute exists in the parent object.

# Arguments:
- `r::AbstractResource`: The resource object.
- `sym::Symbol`: The symbol representing the attribute name.

# Returns:
- `true` if the attribute exists in the parent object, `false` otherwise.

"""
Base.haskey(r::AbstractResource, sym::Symbol) = haskey(parent(r), sym)

"""
    Base.get(r::AbstractResource, sym::Symbol, default)

Retrieves the value of a specific attribute from an `AbstractResource` object. If the attribute exists, its value is returned; otherwise, the default value is returned.

# Arguments:
- `r::AbstractResource`: The resource object.
- `sym::Symbol`: The symbol representing the attribute name.
- `default`: The default value to return if the attribute does not exist.

# Returns:
- The value of the attribute if it exists in the parent object, `default` otherwise.

"""
function Base.get(r::AbstractResource, sym::Symbol, default)
    return haskey(r, sym) ? getproperty(r, sym) : default
end

""" 
    Base.getproperty(rs::Vector{<:AbstractResource}, sym::Symbol)

Allows to access attributes of a vector of `AbstractResource` objects using dot syntax. If the `sym` is an element of the `resource_types` constant, it returns all resources of that type. Otherwise, it returns the value of the attribute for each resource in the vector.

# Arguments:
- `rs::Vector{<:AbstractResource}`: The vector of `AbstractResource` objects.
- `sym::Symbol`: The symbol representing the attribute name or a type from `resource_types`.

# Returns:
- If `sym` is an element of the `resource_types` constant, it returns a vector containing all resources of that type.
- If `sym` is an attribute name, it returns a vector containing the value of the attribute for each resource.

## Examples
```julia
julia> vre_gen = gen.Vre;  # gen vector of resources
julia> typeof(vre_gen)
Vector{Vre} (alias for Array{Vre, 1})
julia> vre_gen.zone
```
"""
function Base.getproperty(rs::Vector{<:AbstractResource}, sym::Symbol)
    # if sym is Type then return a vector resources of that type
    if sym ∈ resource_types
        res_type = eval(sym)
        return Vector{res_type}(rs[isa.(rs, res_type)])
    end
    # if sym is a field of the resource then return that field for all resources
    return [getproperty(r, sym) for r in rs]
end

"""
    Base.setproperty!(rs::Vector{<:AbstractResource}, sym::Symbol, value::Vector)

Set the attributes specified by `sym` to the corresponding values in `value` for a vector of resources.

# Arguments
- `rs::Vector{<:AbstractResource}`: The vector of resources.
- `sym::Symbol`: The symbol representing the attribute to set.
- `value::Vector`: The vector of values to set for the attribute.

# Returns
- `rs::Vector{<:AbstractResource}`: The updated vector of resources.

"""
function Base.setproperty!(rs::Vector{<:AbstractResource}, sym::Symbol, value::Vector)
    # if sym is a field of the resource then set that field for all resources
    @assert length(rs) == length(value)
    for (r, v) in zip(rs, value)
        setproperty!(r, sym, v)
    end
    return rs
end

"""
    Base.setindex!(rs::Vector{<:AbstractResource}, value::Vector, sym::Symbol)

Define dot syntax for setting the attributes specified by `sym` to the corresponding values in `value` for a vector of resources.

# Arguments
- `rs::Vector{<:AbstractResource}`: The vector of resources.
- `value::Vector`: The vector of values to set for the attribute.
- `sym::Symbol`: The symbol representing the attribute to set.

# Returns
- `rs::Vector{<:AbstractResource}`: The updated vector of resources.

"""
function Base.setindex!(rs::Vector{<:AbstractResource}, value::Vector, sym::Symbol)
    # if sym is a field of the resource then set that field for all resources
    @assert length(rs) == length(value)
    for (r, v) in zip(rs, value)
        setproperty!(r, sym, v)
    end
    return rs
end

"""
    pairs(r::AbstractResource)

Return an iterator of key-value pairs with the attributes of a given resource.

# Arguments
- `r::AbstractResource`: The resource.

# Returns
- `Pairs`: An iterator of key-value pairs over the attributes.

"""
Base.pairs(r::AbstractResource) = pairs(parent(r))

"""
    show(io::IO, r::AbstractResource)

Print the attributes of the given resource.

# Arguments
- `io::IO`: The IO stream to print to.
- `r::AbstractResource`: The resource.

"""
function Base.show(io::IO, r::AbstractResource)
    key_length = maximum(length.(string.(attributes(r))))
    value_length = length(resource_name(r)) + 3
    println(io, "\nResource: $(r.resource) (id: $(r.id))")
    println(io, repeat("-", key_length + value_length))
    for (k, v) in pairs(r)
        k, v = string(k), string(v)
        k = k * repeat(" ", key_length - length(k))
        println(io, "$k | $v")
    end
    println(io, repeat("-", key_length + value_length))
end

"""
    attributes(r::AbstractResource)

Returns a tuple of the attribute names of the given resource.

# Arguments
- `r::AbstractResource`: The resource.

# Returns
- `Tuple`: A tuple with symbols representing the attribute names.

"""
function attributes(r::AbstractResource)
    return tuple(keys(parent(r))...)
end

"""
    findall(f::Function, rs::Vector{<:AbstractResource})

Find all resources in the vector `rs` that satisfy the condition given by the function `f`.
Return the resource id instead of the vector index.

# Arguments
- `f::Function`: The condition function.
- `rs::Vector{<:AbstractResource}`: The vector of resources.

# Returns
- `Vector`: The vector of resource ids.

## Examples
```julia
julia> findall(r -> max_cap_mwh(r) != 0, gen.Storage)
3-element Vector{Int64}:
 48
 49
 50
```
"""
Base.findall(f::Function, rs::Vector{<:AbstractResource}) = resource_id.(filter(r -> f(r),
    rs))

"""
    interface(name, default=default_zero, type=AbstractResource)

Define a function interface for accessing the attribute specified by `name` in a resource of type `type`.

# Arguments
- `name`: The name of the attribute.
- `default`: The default value to return if the attribute is not found.
- `type`: The type of the resource.

# Returns
- `Function`: The generated function.

## Examples
```julia
julia> @interface max_cap_mw 0 Vre
julia> max_cap_mw(gen.Vre[3])
4.888236
julia> max_cap_mw.(gen.Vre) # vectorized
5-element Vector{Float64}:
  0.0
  0.0
  4.888236
 20.835569
  9.848441999999999
```
"""
macro interface(name, default = default_zero, type = AbstractResource)
    quote
        function $(esc(name))(r::$(esc(type)))
            return get(r, $(QuoteNode(name)), $(esc(default)))
        end
    end
end

"""
    ids_with_positive(rs::Vector{T}, f::Function) where T <: AbstractResource

Function for finding indices of resources in a vector `rs` where the attribute specified by `f` is positive.

# Arguments
- `rs::Vector{<:AbstractResource}`: The vector of resources.
- `f::Function`: The getter of the attribute.

# Returns
- `ids (Vector{Int64})`: The vector of resource ids with positive attribute.

## Examples
```julia
julia> ids_with_positive(gen, max_cap_mw)
3-element Vector{Int64}:
 3 
 4
 5
julia> max_cap_mw(gen[3])
4.888236
```
"""
function ids_with_positive(rs::Vector{T}, f::Function) where {T <: AbstractResource}
    return findall(r -> f(r) > 0, rs)
end

"""
    ids_with_positive(rs::Vector{T}, name::Symbol) where T <: AbstractResource

Function for finding indices of resources in a vector `rs` where the attribute specified by `name` is positive.

# Arguments
- `rs::Vector{<:AbstractResource}`: The vector of resources.
- `name::Symbol`: The name of the attribute.

# Returns
- `Vector{Int64}`: The vector of resource ids with positive attribute.

## Examples
```julia
julia> ids_with_positive(gen, :max_cap_mw)
3-element Vector{Int64}:
 3 
 4
 5
julia> max_cap_mw(gen[3])
4.888236
```
"""
function ids_with_positive(rs::Vector{T}, name::Symbol) where {T <: AbstractResource}
    # if the getter function exists in GenX then use it, otherwise get the attribute directly
    f = isdefined(GenX, name) ? getfield(GenX, name) : r -> getproperty(r, name)
    return ids_with_positive(rs, f)
end

function ids_with_positive(rs::Vector{T},
    name::AbstractString) where {T <: AbstractResource}
    return ids_with_positive(rs, Symbol(lowercase(name)))
end

"""
    ids_with_nonneg(rs::Vector{T}, f::Function) where T <: AbstractResource

Function for finding resources in a vector `rs` where the attribute specified by `f` is non-negative.

# Arguments
- `rs::Vector{<:AbstractResource}`: The vector of resources.
- `f::Function`: The getter of the attribute.

# Returns
- `ids (Vector{Int64})`: The vector of resource ids with non-negative attribute.

## Examples
```julia
julia> ids_with_nonneg(gen, max_cap_mw)
```
"""
function ids_with_nonneg(rs::Vector{T}, f::Function) where {T <: AbstractResource}
    return findall(r -> f(r) >= 0, rs)
end

"""
    ids_with_nonneg(rs::Vector{T}, f::Function) where T <: AbstractResource

Function for finding resources in a vector `rs` where the attribute specified by `name` is non-negative.

# Arguments
- `rs::Vector{<:AbstractResource}`: The vector of resources.
- `name::Symbol`: The name of the attribute.

# Returns
- `ids (Vector{Int64})`: The vector of resource ids with non-negative attribute.

## Examples
```julia
julia> ids_with_nonneg(gen, max_cap_mw)
```
"""
function ids_with_nonneg(rs::Vector{T}, name::Symbol) where {T <: AbstractResource}
    # if the getter function exists in GenX then use it, otherwise get the attribute directly
    f = isdefined(GenX, name) ? getfield(GenX, name) : r -> getproperty(r, name)
    return ids_with_nonneg(rs, f)
end

function ids_with_nonneg(rs::Vector{T}, name::AbstractString) where {T <: AbstractResource}
    return ids_with_nonneg(rs, Symbol(lowercase(name)))
end

"""
    ids_with(rs::Vector{T}, f::Function, default=default_zero) where T <: AbstractResource

Function for finding resources in a vector `rs` where the attribute specified by `f` is not equal to `default`.

# Arguments
- `rs::Vector{<:AbstractResource}`: The vector of resources.
- `f::Function`: The getter of the attribute.
- `default`: The default value of the attribute.


# Returns
- `ids (Vector{Int64})`: The vector of resource ids with attribute not equal to `default`.

## Examples
```julia
julia> ids_with(gen.Thermal, existing_cap_mw)
4-element Vector{Int64}:
 21
 22
 23
 24
julia> existing_cap_mw(gen[21])
7.0773
```
"""
function ids_with(rs::Vector{T},
    f::Function,
    default = default_zero) where {T <: AbstractResource}
    return findall(r -> f(r) != default, rs)
end

"""
    ids_with(rs::Vector{T}, name::Symbol, default=default_zero) where T <: AbstractResource

Function for finding resources in a vector `rs` where the attribute specified by `name` is not equal to the default value of the attribute.

# Arguments
- `rs::Vector{<:AbstractResource}`: The vector of resources.
- `name::Symbol`: The name of the attribute.
- `default`: The default value of the attribute.

# Returns
- `ids (Vector{Int64})`: The vector of resource ids with attribute not equal to `default`.

## Examples
```julia
julia> ids_with(gen.Thermal, :existing_cap_mw)
4-element Vector{Int64}:
 21
 22
 23
 24
julia> existing_cap_mw(gen[21])
7.0773
```
"""
function ids_with(rs::Vector{T},
    name::Symbol,
    default = default_zero) where {T <: AbstractResource}
    # if the getter function exists in GenX then use it, otherwise get the attribute directly
    f = isdefined(GenX, name) ? getfield(GenX, name) : r -> getproperty(r, name)
    return ids_with(rs, f, default)
end

function ids_with(rs::Vector{T},
    name::AbstractString,
    default = default_zero) where {T <: AbstractResource}
    return ids_with(rs, Symbol(lowercase(name)), default)
end

"""
    ids_with_policy(rs::Vector{T}, f::Function; tag::Int64) where T <: AbstractResource

Function for finding resources in a vector `rs` where the policy specified by `f` with tag equal to `tag` is positive.

# Arguments
- `rs::Vector{<:AbstractResource}`: The vector of resources.
- `f::Function`: The policy getter function.
- `tag::Int64`: The tag of the policy.

# Returns
- `ids (Vector{Int64})`: The vector of resource ids with a positive value for policy `f` and tag `tag`.
"""
function ids_with_policy(rs::Vector{T},
    f::Function;
    tag::Int64) where {T <: AbstractResource}
    return findall(r -> f(r, tag = tag) > 0, rs)
end

"""
ids_with_policy(rs::Vector{T}, name::Symbol; tag::Int64) where T <: AbstractResource

Function for finding resources in a vector `rs` where the policy specified by `name` with tag equal to `tag` is positive.

# Arguments
- `rs::Vector{<:AbstractResource}`: The vector of resources.
- `name::Symbol`: The name of the policy.
- `tag::Int64`: The tag of the policy.

# Returns
- `ids (Vector{Int64})`: The vector of resource ids with a positive value for policy `name` and tag `tag`.
"""
function ids_with_policy(rs::Vector{T},
    name::Symbol;
    tag::Int64) where {T <: AbstractResource}
    # if the getter function exists in GenX then use it, otherwise get the attribute directly
    if isdefined(GenX, name)
        f = getfield(GenX, name)
        return ids_with_policy(rs, f, tag = tag)
    end
    return findall(r -> getproperty(r, Symbol(string(name, "_$tag"))) > 0, rs)
end

function ids_with_policy(rs::Vector{T},
    name::AbstractString;
    tag::Int64) where {T <: AbstractResource}
    return ids_with_policy(rs, Symbol(lowercase(name)), tag = tag)
end

"""
    const default_zero = 0

Default value for resource attributes.
"""
const default_zero = 0

# INTERFACE FOR ALL RESOURCES
resource_name(r::AbstractResource) = r.resource
resource_name(rs::Vector{T}) where {T <: AbstractResource} = rs.resource

resource_id(r::AbstractResource)::Int64 = r.id
resource_id(rs::Vector{T}) where {T <: AbstractResource} = resource_id.(rs)
resource_type_mga(r::AbstractResource) = r.resource_type

zone_id(r::AbstractResource) = r.zone
zone_id(rs::Vector{T}) where {T <: AbstractResource} = rs.zone

# getter for boolean attributes (true or false) with validation
function new_build(r::AbstractResource)
    validate_boolean_attribute(r, :new_build)
    return Bool(get(r, :new_build, false))
end

function can_retire(r::AbstractResource)
    validate_boolean_attribute(r, :can_retire)
    return Bool(get(r, :can_retire, false))
end

function can_retrofit(r::AbstractResource)
    validate_boolean_attribute(r, :can_retrofit)
    return Bool(get(r, :can_retrofit, false))
end

function is_retrofit_option(r::AbstractResource)
    validate_boolean_attribute(r, :retrofit)
    return Bool(get(r, :retrofit, false))
end

function can_contribute_min_retirement(r::AbstractResource)
    validate_boolean_attribute(r, :contribute_min_retirement)
    return Bool(get(r, :contribute_min_retirement, true))
end

const default_minmax_cap = -1.0
max_cap_mw(r::AbstractResource) = get(r, :max_cap_mw, default_minmax_cap)
min_cap_mw(r::AbstractResource) = get(r, :min_cap_mw, default_minmax_cap)

max_cap_mwh(r::AbstractResource) = get(r, :max_cap_mwh, default_minmax_cap)
min_cap_mwh(r::AbstractResource) = get(r, :min_cap_mwh, default_minmax_cap)

max_charge_cap_mw(r::AbstractResource) = get(r, :max_charge_cap_mw, default_minmax_cap)
min_charge_cap_mw(r::AbstractResource) = get(r, :min_charge_cap_mw, default_minmax_cap)

existing_cap_mw(r::AbstractResource) = r.existing_cap_mw
existing_cap_mwh(r::AbstractResource) = get(r, :existing_cap_mwh, default_zero)
existing_charge_cap_mw(r::AbstractResource) = get(r, :existing_charge_cap_mw, default_zero)

cap_size(r::AbstractResource) = get(r, :cap_size, default_zero)

num_vre_bins(r::AbstractResource) = get(r, :num_vre_bins, default_zero)

function hydro_energy_to_power_ratio(r::AbstractResource)
    get(r, :hydro_energy_to_power_ratio, default_zero)
end

function qualified_hydrogen_supply(r::AbstractResource)
    get(r, :qualified_hydrogen_supply, default_zero)
end

retrofit_id(r::AbstractResource)::String = get(r, :retrofit_id, "None")
function retrofit_efficiency(r::AbstractResource)
    is_retrofit_option(r) && return get(r, :retrofit_efficiency, 1.0)
    msg = "Retrofit efficiency is not defined for resource $(resource_name(r)).\n" *
          "It's only valid for retrofit options."
    throw(ErrorException(msg))
end

# costs
reg_cost(r::AbstractResource) = get(r, :reg_cost, default_zero)
reg_max(r::AbstractResource)::Float64 = get(r, :reg_max, default_zero)
rsv_cost(r::AbstractResource) = get(r, :rsv_cost, default_zero)
rsv_max(r::AbstractResource) = get(r, :rsv_max, default_zero)
inv_cost_per_mwyr(r::AbstractResource) = get(r, :inv_cost_per_mwyr, default_zero)
fixed_om_cost_per_mwyr(r::AbstractResource) = get(r, :fixed_om_cost_per_mwyr, default_zero)
var_om_cost_per_mwh(r::AbstractResource) = get(r, :var_om_cost_per_mwh, default_zero)
inv_cost_per_mwhyr(r::AbstractResource) = get(r, :inv_cost_per_mwhyr, default_zero)
function fixed_om_cost_per_mwhyr(r::AbstractResource)
    get(r, :fixed_om_cost_per_mwhyr, default_zero)
end
function inv_cost_charge_per_mwyr(r::AbstractResource)
    get(r, :inv_cost_charge_per_mwyr, default_zero)
end
function fixed_om_cost_charge_per_mwyr(r::AbstractResource)
    get(r, :fixed_om_cost_charge_per_mwyr, default_zero)
end
start_cost_per_mw(r::AbstractResource) = get(r, :start_cost_per_mw, default_zero)

# fuel
fuel(r::AbstractResource) = get(r, :fuel, "None")
function start_fuel_mmbtu_per_mw(r::AbstractResource)
    get(r, :start_fuel_mmbtu_per_mw, default_zero)
end
function heat_rate_mmbtu_per_mwh(r::AbstractResource)
    get(r, :heat_rate_mmbtu_per_mwh, default_zero)
end
co2_capture_fraction(r::AbstractResource) = get(r, :co2_capture_fraction, default_zero)
function co2_capture_fraction_startup(r::AbstractResource)
    get(r, :co2_capture_fraction_startup, default_zero)
end
function ccs_disposal_cost_per_metric_ton(r::AbstractResource)
    get(r, :ccs_disposal_cost_per_metric_ton, default_zero)
end
biomass(r::AbstractResource) = get(r, :biomass, default_zero)
multi_fuels(r::AbstractResource) = get(r, :multi_fuels, default_zero)
fuel_cols(r::AbstractResource; tag::Int64) = get(r, Symbol(string("fuel", tag)), "None")
num_fuels(r::AbstractResource) = get(r, :num_fuels, default_zero)
function heat_rate_cols(r::AbstractResource; tag::Int64)
    get(r, Symbol(string("heat_rate", tag, "_mmbtu_per_mwh")), default_zero)
end
function max_cofire_cols(r::AbstractResource; tag::Int64)
    get(r, Symbol(string("fuel", tag, "_max_cofire_level")), 1)
end
function min_cofire_cols(r::AbstractResource; tag::Int64)
    get(r, Symbol(string("fuel", tag, "_min_cofire_level")), default_zero)
end
function max_cofire_start_cols(r::AbstractResource; tag::Int64)
    get(r, Symbol(string("fuel", tag, "_max_cofire_level_start")), 1)
end
function min_cofire_start_cols(r::AbstractResource; tag::Int64)
    get(r, Symbol(string("fuel", tag, "_min_cofire_level_start")), default_zero)
end

# Reservoir hydro and storage
const default_percent = 1.0
efficiency_up(r::T) where {T <: Union{Hydro, Storage}} = get(r, :eff_up, default_percent)
function efficiency_down(r::T) where {T <: Union{Hydro, Storage}}
    get(r, :eff_down, default_percent)
end

# Ramp up and down
const VarPower = Union{Electrolyzer, Hydro, Thermal}
min_power(r::VarPower) = get(r, :min_power, default_zero)
ramp_up_fraction(r::VarPower) = get(r, :ramp_up_percentage, default_percent)
ramp_down_fraction(r::VarPower) = get(r, :ramp_dn_percentage, default_percent)

# Retirement - Multistage
lifetime(r::Storage) = get(r, :lifetime, 15)
lifetime(r::AbstractResource) = get(r, :lifetime, 30)
capital_recovery_period(r::Storage) = get(r, :capital_recovery_period, 15)
capital_recovery_period(r::AbstractResource) = get(r, :capital_recovery_period, 30)
tech_wacc(r::AbstractResource) = get(r, :wacc, default_zero)
min_retired_cap_mw(r::AbstractResource) = get(r, :min_retired_cap_mw, default_zero)
function min_retired_energy_cap_mw(r::AbstractResource)
    get(r, :min_retired_energy_cap_mw, default_zero)
end
function min_retired_charge_cap_mw(r::AbstractResource)
    get(r, :min_retired_charge_cap_mw, default_zero)
end
cum_min_retired_cap_mw(r::AbstractResource) = r.cum_min_retired_cap_mw
cum_min_retired_energy_cap_mw(r::AbstractResource) = r.cum_min_retired_energy_cap_mw
cum_min_retired_charge_cap_mw(r::AbstractResource) = r.cum_min_retired_charge_cap_mw

# MGA
mga(r::AbstractResource) = get(r, :mga, default_zero)

# policies
esr(r::AbstractResource; tag::Int64) = get(r, Symbol("esr_$tag"), default_zero)
min_cap(r::AbstractResource; tag::Int64) = get(r, Symbol("min_cap_$tag"), default_zero)
max_cap(r::AbstractResource; tag::Int64) = get(r, Symbol("max_cap_$tag"), default_zero)
function derating_factor(r::AbstractResource; tag::Int64)
    get(r, Symbol("derating_factor_$tag"), default_zero)
end

# write_outputs
region(r::AbstractResource) = r.region
cluster(r::AbstractResource) = r.cluster

# UTILITY FUNCTIONS for working with resources
function is_LDS(rs::Vector{T}) where {T <: AbstractResource}
    findall(r -> get(r, :lds, default_zero) == 1, rs)
end
function is_SDS(rs::Vector{T}) where {T <: AbstractResource}
    findall(r -> get(r, :lds, default_zero) == 0, rs)
end

ids_with_mga(rs::Vector{T}) where {T <: AbstractResource} = findall(r -> mga(r) == 1, rs)

function ids_with_fuel(rs::Vector{T}) where {T <: AbstractResource}
    findall(r -> fuel(r) != "None", rs)
end

function ids_with_singlefuel(rs::Vector{T}) where {T <: AbstractResource}
    findall(r -> multi_fuels(r) == 0, rs)
end
function ids_with_multifuels(rs::Vector{T}) where {T <: AbstractResource}
    findall(r -> multi_fuels(r) == 1, rs)
end

function is_buildable(rs::Vector{T}) where {T <: AbstractResource}
    findall(r -> new_build(r) == true, rs)
end
function is_retirable(rs::Vector{T}) where {T <: AbstractResource}
    findall(r -> can_retire(r) == true, rs)
end
function ids_can_retrofit(rs::Vector{T}) where {T <: AbstractResource}
    findall(r -> can_retrofit(r) == true, rs)
end
function ids_retrofit_options(rs::Vector{T}) where {T <: AbstractResource}
    findall(r -> is_retrofit_option(r) == true, rs)
end

# Unit commitment
function ids_with_unit_commitment(rs::Vector{T}) where {T <: AbstractResource}
    findall(r -> isa(r, Thermal) && r.model == 1, rs)
end
# Without unit commitment
function no_unit_commitment(rs::Vector{T}) where {T <: AbstractResource}
    findall(r -> isa(r, Thermal) && r.model == 2, rs)
end

# Operational Reserves
function ids_with_regulation_reserve_requirements(rs::Vector{
    T,
}) where {T <: AbstractResource}
    findall(r -> reg_max(r) > 0, rs)
end
function ids_with_spinning_reserve_requirements(rs::Vector{T}) where {T <: AbstractResource}
    findall(r -> rsv_max(r) > 0, rs)
end

# Maintenance
function ids_with_maintenance(rs::Vector{T}) where {T <: AbstractResource}
    findall(r -> get(r, :maint, default_zero) == 1, rs)
end
maintenance_duration(r::AbstractResource) = get(r, :maintenance_duration, default_zero)
function maintenance_cycle_length_years(r::AbstractResource)
    get(r, :maintenance_cycle_length_years, default_zero)
end
function maintenance_begin_cadence(r::AbstractResource)
    get(r, :maintenance_begin_cadence, default_zero)
end

function ids_contribute_min_retirement(rs::Vector{T}) where {T <: AbstractResource}
    findall(r -> can_contribute_min_retirement(r) == true, rs)
end
function ids_not_contribute_min_retirement(rs::Vector{T}) where {T <: AbstractResource}
    findall(r -> can_contribute_min_retirement(r) == false, rs)
end

# STORAGE interface
"""
    storage(rs::Vector{T}) where T <: AbstractResource

Returns the indices of all storage resources in the vector `rs`.
"""
storage(rs::Vector{T}) where {T <: AbstractResource} = findall(r -> isa(r, Storage), rs)

self_discharge(r::Storage) = r.self_disch
min_duration(r::Storage) = r.min_duration
max_duration(r::Storage) = r.max_duration
var_om_cost_per_mwh_in(r::Storage) = get(r, :var_om_cost_per_mwh_in, default_zero)
function symmetric_storage(rs::Vector{T}) where {T <: AbstractResource}
    findall(r -> isa(r, Storage) && r.model == 1, rs)
end
function asymmetric_storage(rs::Vector{T}) where {T <: AbstractResource}
    findall(r -> isa(r, Storage) && r.model == 2, rs)
end

# HYDRO interface
"""
    hydro(rs::Vector{T}) where T <: AbstractResource

Returns the indices of all hydro resources in the vector `rs`.
"""
hydro(rs::Vector{T}) where {T <: AbstractResource} = findall(r -> isa(r, Hydro), rs)

# THERMAL interface
"""
    thermal(rs::Vector{T}) where T <: AbstractResource

Returns the indices of all thermal resources in the vector `rs`.
"""
thermal(rs::Vector{T}) where {T <: AbstractResource} = findall(r -> isa(r, Thermal), rs)
up_time(r::Thermal) = get(r, :up_time, default_zero)
down_time(r::Thermal) = get(r, :down_time, default_zero)
function pwfu_fuel_usage_zero_load_mmbtu_per_h(r::Thermal)
    get(r, :pwfu_fuel_usage_zero_load_mmbtu_per_h, default_zero)
end

# VRE interface
"""
    vre(rs::Vector{T}) where T <: AbstractResource

Returns the indices of all Vre resources in the vector `rs`.
"""
vre(rs::Vector{T}) where {T <: AbstractResource} = findall(r -> isa(r, Vre), rs)

# ELECTROLYZER interface
"""
    electrolyzer(rs::Vector{T}) where T <: AbstractResource

Returns the indices of all electrolyzer resources in the vector `rs`.
"""
electrolyzer(rs::Vector{T}) where {T <: AbstractResource} = findall(r -> isa(r,
        Electrolyzer),
    rs)
electrolyzer_min_kt(r::Electrolyzer) = r.electrolyzer_min_kt
hydrogen_mwh_per_tonne(r::Electrolyzer) = r.hydrogen_mwh_per_tonne
hydrogen_price_per_tonne(r::Electrolyzer) = r.hydrogen_price_per_tonne

# FLEX_DEMAND interface
"""
    flex_demand(rs::Vector{T}) where T <: AbstractResource

Returns the indices of all flexible demand resources in the vector `rs`.
"""
flex_demand(rs::Vector{T}) where {T <: AbstractResource} = findall(r -> isa(r, FlexDemand),
    rs)
flexible_demand_energy_eff(r::FlexDemand) = r.flexible_demand_energy_eff
max_flexible_demand_delay(r::FlexDemand) = r.max_flexible_demand_delay
max_flexible_demand_advance(r::FlexDemand) = r.max_flexible_demand_advance
var_om_cost_per_mwh_in(r::FlexDemand) = get(r, :var_om_cost_per_mwh_in, default_zero)

# MUST_RUN interface
"""
    must_run(rs::Vector{T}) where T <: AbstractResource

Returns the indices of all must-run resources in the vector `rs`.
"""
must_run(rs::Vector{T}) where {T <: AbstractResource} = findall(r -> isa(r, MustRun), rs)

# VRE_STOR interface
"""
    vre_stor(rs::Vector{T}) where T <: AbstractResource

Returns the indices of all VRE_STOR resources in the vector `rs`.
"""
vre_stor(rs::Vector{T}) where {T <: AbstractResource} = findall(r -> isa(r, VreStorage), rs)
technology(r::VreStorage) = r.technology
self_discharge(r::VreStorage) = r.self_disch

"""
    solar(rs::Vector{T}) where T <: AbstractResource

Returns the indices of all co-located solar resources in the vector `rs`.
"""
solar(rs::Vector{T}) where {T <: AbstractResource} = findall(r -> isa(r, VreStorage) &&
        r.solar != 0,
    rs)

"""
    wind(rs::Vector{T}) where T <: AbstractResource

Returns the indices of all co-located wind resources in the vector `rs`.
"""
wind(rs::Vector{T}) where {T <: AbstractResource} = findall(r -> isa(r, VreStorage) &&
        r.wind != 0,
    rs)

"""
    storage_dc_discharge(rs::Vector{T}) where T <: AbstractResource
Returns the indices of all co-located storage resources in the vector `rs` that discharge DC.
"""
storage_dc_discharge(rs::Vector{T}) where {T <: AbstractResource} = findall(r -> isa(r,
        VreStorage) && r.stor_dc_discharge >= 1,
    rs)
function storage_sym_dc_discharge(rs::Vector{T}) where {T <: AbstractResource}
    findall(r -> isa(r, VreStorage) && r.stor_dc_discharge == 1, rs)
end
function storage_asym_dc_discharge(rs::Vector{T}) where {T <: AbstractResource}
    findall(r -> isa(r, VreStorage) && r.stor_dc_discharge == 2, rs)
end

""" 
    storage_dc_charge(rs::Vector{T}) where T <: AbstractResource
    Returns the indices of all co-located storage resources in the vector `rs` that charge DC.
"""
storage_dc_charge(rs::Vector{T}) where {T <: AbstractResource} = findall(r -> isa(r,
        VreStorage) && r.stor_dc_charge >= 1,
    rs)
function storage_sym_dc_charge(rs::Vector{T}) where {T <: AbstractResource}
    findall(r -> isa(r, VreStorage) && r.stor_dc_charge == 1, rs)
end
function storage_asym_dc_charge(rs::Vector{T}) where {T <: AbstractResource}
    findall(r -> isa(r, VreStorage) && r.stor_dc_charge == 2, rs)
end

""" 
    storage_ac_discharge(rs::Vector{T}) where T <: AbstractResource
Returns the indices of all co-located storage resources in the vector `rs` that discharge AC.
"""
storage_ac_discharge(rs::Vector{T}) where {T <: AbstractResource} = findall(r -> isa(r,
        VreStorage) && r.stor_ac_discharge >= 1,
    rs)
function storage_sym_ac_discharge(rs::Vector{T}) where {T <: AbstractResource}
    findall(r -> isa(r, VreStorage) && r.stor_ac_discharge == 1, rs)
end
function storage_asym_ac_discharge(rs::Vector{T}) where {T <: AbstractResource}
    findall(r -> isa(r, VreStorage) && r.stor_ac_discharge == 2, rs)
end

""" 
    storage_ac_charge(rs::Vector{T}) where T <: AbstractResource
Returns the indices of all co-located storage resources in the vector `rs` that charge AC.
"""
storage_ac_charge(rs::Vector{T}) where {T <: AbstractResource} = findall(r -> isa(r,
        VreStorage) && r.stor_ac_charge >= 1,
    rs)
function storage_sym_ac_charge(rs::Vector{T}) where {T <: AbstractResource}
    findall(r -> isa(r, VreStorage) && r.stor_ac_charge == 1, rs)
end
function storage_asym_ac_charge(rs::Vector{T}) where {T <: AbstractResource}
    findall(r -> isa(r, VreStorage) && r.stor_ac_charge == 2, rs)
end

function is_LDS_VRE_STOR(rs::Vector{T}) where {T <: AbstractResource}
    findall(r -> get(r, :lds_vre_stor, default_zero) != 0, rs)
end

# loop over the above attributes and define function interfaces for each one
for attr in (:existing_cap_solar_mw,
    :existing_cap_wind_mw,
    :existing_cap_inverter_mw,
    :existing_cap_charge_dc_mw,
    :existing_cap_charge_ac_mw,
    :existing_cap_discharge_dc_mw,
    :existing_cap_discharge_ac_mw)
    @eval @interface $attr
end

for attr in (:max_cap_solar_mw,
    :max_cap_wind_mw,
    :max_cap_inverter_mw,
    :max_cap_charge_dc_mw,
    :max_cap_charge_ac_mw,
    :max_cap_discharge_dc_mw,
    :max_cap_discharge_ac_mw,
    :min_cap_solar_mw,
    :min_cap_wind_mw,
    :min_cap_inverter_mw,
    :min_cap_charge_dc_mw,
    :min_cap_charge_ac_mw,
    :min_cap_discharge_dc_mw,
    :min_cap_discharge_ac_mw,
    :inverter_ratio_solar,
    :inverter_ratio_wind)
    @eval @interface $attr default_minmax_cap
end

for attr in (:etainverter,
    :inv_cost_inverter_per_mwyr,
    :inv_cost_solar_per_mwyr,
    :inv_cost_wind_per_mwyr,
    :inv_cost_discharge_dc_per_mwyr,
    :inv_cost_charge_dc_per_mwyr,
    :inv_cost_discharge_ac_per_mwyr,
    :inv_cost_charge_ac_per_mwyr,
    :fixed_om_inverter_cost_per_mwyr,
    :fixed_om_solar_cost_per_mwyr,
    :fixed_om_wind_cost_per_mwyr,
    :fixed_om_cost_discharge_dc_per_mwyr,
    :fixed_om_cost_charge_dc_per_mwyr,
    :fixed_om_cost_discharge_ac_per_mwyr,
    :fixed_om_cost_charge_ac_per_mwyr,
    :var_om_cost_per_mwh_solar,
    :var_om_cost_per_mwh_wind,
    :var_om_cost_per_mwh_charge_dc,
    :var_om_cost_per_mwh_discharge_dc,
    :var_om_cost_per_mwh_charge_ac,
    :var_om_cost_per_mwh_discharge_ac,
    :eff_up_ac,
    :eff_down_ac,
    :eff_up_dc,
    :eff_down_dc,
    :power_to_energy_ac,
    :power_to_energy_dc)
    @eval @interface $attr default_zero VreStorage
end

# Multistage
for attr in (:capital_recovery_period_dc,
    :capital_recovery_period_solar,
    :capital_recovery_period_wind,
    :capital_recovery_period_charge_dc,
    :capital_recovery_period_discharge_dc,
    :capital_recovery_period_charge_ac,
    :capital_recovery_period_discharge_ac,
    :tech_wacc_dc,
    :tech_wacc_solar,
    :tech_wacc_wind,
    :tech_wacc_charge_dc,
    :tech_wacc_discharge_dc,
    :tech_wacc_charge_ac,
    :tech_wacc_discharge_ac)
    @eval @interface $attr default_zero VreStorage
end

# Endogenous retirement
for attr in (:min_retired_cap_inverter_mw,
    :min_retired_cap_solar_mw,
    :min_retired_cap_wind_mw,
    :min_retired_cap_discharge_dc_mw,
    :min_retired_cap_charge_dc_mw,
    :min_retired_cap_discharge_ac_mw,
    :min_retired_cap_charge_ac_mw)
    @eval @interface $attr default_zero
    cum_attr = Symbol("cum_" * String(attr))
    @eval @interface $cum_attr default_zero
end

## policies
# co-located storage
function esr_vrestor(r::AbstractResource; tag::Int64)
    get(r, Symbol("esr_vrestor_$tag"), default_zero)
end
function min_cap_stor(r::AbstractResource; tag::Int64)
    get(r, Symbol("min_cap_stor_$tag"), default_zero)
end
function max_cap_stor(r::AbstractResource; tag::Int64)
    get(r, Symbol("max_cap_stor_$tag"), default_zero)
end
# vre part
function min_cap_solar(r::AbstractResource; tag::Int64)
    get(r, Symbol("min_cap_solar_$tag"), default_zero)
end
function max_cap_solar(r::AbstractResource; tag::Int64)
    get(r, Symbol("max_cap_solar_$tag"), default_zero)
end
function min_cap_wind(r::AbstractResource; tag::Int64)
    get(r, Symbol("min_cap_wind_$tag"), default_zero)
end
function max_cap_wind(r::AbstractResource; tag::Int64)
    get(r, Symbol("max_cap_wind_$tag"), default_zero)
end

## Utility functions for working with resources
in_zone(r::AbstractResource, zone::Int) = zone_id(r) == zone
function resources_in_zone(rs::Vector{<:AbstractResource}, zone::Int)
    filter(r -> in_zone(r, zone), rs)
end

@doc raw"""
    resources_in_zone_by_rid(rs::Vector{<:AbstractResource}, zone::Int)
Find R_ID's of resources in a zone.
"""
function resources_in_zone_by_rid(rs::Vector{<:AbstractResource}, zone::Int)
    return resource_id.(rs[zone_id.(rs) .== zone])
end

@doc raw"""
    resources_in_retrofit_cluster_by_rid(rs::Vector{<:AbstractResource}, cluster_id::String)

Find R_ID's of resources with retrofit cluster id `cluster_id`.

# Arguments
- `rs::Vector{<:AbstractResource}`: The vector of resources.
- `cluster_id::String`: The retrofit cluster id.

# Returns
- `Vector{Int64}`: The vector of resource ids in the retrofit cluster.
"""
function resources_in_retrofit_cluster_by_rid(rs::Vector{<:AbstractResource},
    cluster_id::String)
    return resource_id.(rs[retrofit_id.(rs) .== cluster_id])
end

"""
    resource_by_name(rs::Vector{<:AbstractResource}, name::AbstractString)

Find the resource with `name` in the vector `rs`.

# Arguments
- `rs`: A vector of resources.
- `name`: The name of the resource.

# Returns
- `AbstractResource`: The resource with the name `name`.
"""
function resource_by_name(rs::Vector{<:AbstractResource}, name::AbstractString)
    r_id = findfirst(r -> resource_name(r) == name, rs)
    # check that the resource exists
    isnothing(r_id) &&
        error("Resource $name not found in resource data. \nHint: Make sure that the resource names in input files match the ones in the \"resource\" folder.\n")
    return rs[r_id]
end

"""
    validate_boolean_attribute(r::AbstractResource, attr::Symbol)

Validate that the attribute `attr` in the resource `r` is boolean {0, 1}.

# Arguments
- `r::AbstractResource`: The resource.
- `attr::Symbol`: The name of the attribute.
"""
function validate_boolean_attribute(r::AbstractResource, attr::Symbol)
    attr_value = get(r, attr, 0)
    if attr_value != 0 && attr_value != 1
        error("Attribute $attr in resource $(resource_name(r)) must be boolean." *
              "The only valid values are {0,1}, not $attr_value.")
    end
end

"""
    ids_with_all_options_contributing(rs::Vector{T}) where T <: AbstractResource

Find the resource ids of the retrofit units in the vector `rs` where all retrofit options contribute to min retirement.

# Arguments
- `rs::Vector{T}`: The vector of resources.

# Returns
- `Vector{Int64}`: The vector of resource ids.
"""
function ids_with_all_options_contributing(rs::Vector{T}) where {T <: AbstractResource}
    # select resources that can retrofit
    units_can_retrofit = ids_can_retrofit(rs)
    # check if all retrofit options in the retrofit cluster of each retrofit resource contribute to min retirement
    condition::Vector{Bool} = has_all_options_contributing.(rs[units_can_retrofit], Ref(rs))
    return units_can_retrofit[condition]
end

"""
    has_all_options_contributing(retrofit_res::AbstractResource, rs::Vector{T}) where T <: AbstractResource

Check if all retrofit options in the retrofit cluster of the retrofit resource `retrofit_res` contribute to min retirement.

# Arguments
- `retrofit_res::AbstractResource`: The retrofit resource.
- `rs::Vector{T}`: The vector of resources.

# Returns
- `Bool`: True if all retrofit options contribute to min retirement, otherwise false.
"""
function has_all_options_contributing(retrofit_res::AbstractResource,
    rs::Vector{T}) where {T <: AbstractResource}
    retro_id = retrofit_id(retrofit_res)
    return isempty(intersect(resources_in_retrofit_cluster_by_rid(rs, retro_id),
        ids_retrofit_options(rs),
        ids_not_contribute_min_retirement(rs)))
end

"""
    ids_with_all_options_not_contributing(rs::Vector{T}) where T <: AbstractResource

Find the resource ids of the retrofit units in the vector `rs` where all retrofit options do not contribute to min retirement.

# Arguments
- `rs::Vector{T}`: The vector of resources.

# Returns
- `Vector{Int64}`: The vector of resource ids.
"""
function ids_with_all_options_not_contributing(rs::Vector{T}) where {T <: AbstractResource}
    # select resources that can retrofit
    units_can_retrofit = ids_can_retrofit(rs)
    # check if all retrofit options in the retrofit cluster of each retrofit resource contribute to min retirement
    condition::Vector{Bool} = has_all_options_not_contributing.(rs[units_can_retrofit],
        Ref(rs))
    return units_can_retrofit[condition]
end

"""
    has_all_options_not_contributing(retrofit_res::AbstractResource, rs::Vector{T}) where T <: AbstractResource

Check if all retrofit options in the retrofit cluster of the retrofit resource `retrofit_res` do not contribute to min retirement.

# Arguments
- `retrofit_res::AbstractResource`: The retrofit resource.
- `rs::Vector{T}`: The vector of resources.

# Returns
- `Bool`: True if all retrofit options do not contribute to min retirement, otherwise false.
"""
function has_all_options_not_contributing(retrofit_res::AbstractResource,
    rs::Vector{T}) where {T <: AbstractResource}
    retro_id = retrofit_id(retrofit_res)
    return isempty(intersect(resources_in_retrofit_cluster_by_rid(rs, retro_id),
        ids_retrofit_options(rs),
        ids_contribute_min_retirement(rs)))
end
