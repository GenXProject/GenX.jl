"""
    resource_types

Name of the type of resources available in the model.

Possible values:
- :Electrolyzer
- :FlexDemand
- :Hydro
- :Storage
- :Thermal
- :Vre
- :MustRun
- :VreStorage
"""
const resource_types = (:Electrolyzer, :FlexDemand, :Hydro, :Storage, :Thermal, :Vre, :MustRun, :VreStorage)

# Create composite types (structs) for each resource type in resource_types
for r in resource_types
    let dict = Symbol("dict"), r = r
        @eval begin
            struct $r{names<:Symbol, T<:Any} <: AbstractResource
                $dict::Dict{names,T}
            end
            Base.parent(e::$r) = getfield(e, $(QuoteNode(dict)))
        end
    end
end

"""
    getproperty(r::AbstractResource, sym::Symbol)

Allows to access the attributes of an `AbstractResource` object using dot syntax. It checks if the attribute exists in the object and returns its value, otherwise it throws an `ErrorException` indicating that the attribute does not exist.

# Arguments:
- `r::AbstractResource`: The resource object.
- `sym::Symbol`: The symbol representing the attribute name.

# Returns:
- The value of the attribute if it exists in the parent object.

Throws:
- `ErrorException`: If the attribute does not exist in the parent object.

"""
function Base.getproperty(r::AbstractResource, sym::Symbol)
    haskey(parent(r), sym) && return parent(r)[sym]
    throw(ErrorException("type $(nameof(typeof(r))) has no attribute $(string(sym))"))
end

"""
    setproperty!(r::AbstractResource, sym::Symbol, value)

Allows to set the attributes of an `AbstractResource` object using dot syntax. It sets the value of the attribute in the parent object.

# Arguments:
- `r::AbstractResource`: The resource object.
- `sym::Symbol`: The symbol representing the attribute name.
- `value`: The value to set for the attribute.

"""
Base.setproperty!(r::AbstractResource, sym::Symbol, value) = setindex!(parent(r), value, sym)

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
    get(r::AbstractResource, sym::Symbol, default)

Retrieves the value of a specific attribute from an `AbstractResource` object. If the attribute exists, its value is returned; otherwise, the default value is returned.

# Arguments:
- `r::AbstractResource`: The resource object.
- `sym::Symbol`: The symbol representing the attribute name.
- `default`: The default value to return if the attribute does not exist.

# Returns:
- The value of the attribute if it exists in the parent object, `default` otherwise.

"""
function Base.get(r::AbstractResource, sym::Symbol, default) 
    return haskey(r, sym) ? getproperty(r,sym) : default
end

"""
getproperty(rs::Vector{<:AbstractResource}, sym::Symbol)

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
    setproperty!(rs::Vector{<:AbstractResource}, sym::Symbol, value::Vector)

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
    for (r,v) in zip(rs, value)
        setproperty!(r, sym, v)
    end
    return rs
end

"""
    setindex!(rs::Vector{<:AbstractResource}, value::Vector, sym::Symbol)

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
    for (r,v) in zip(rs, value)
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
    for (k,v) in pairs(r)
        println(io, "$k: $v")
    end
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
Base.findall(f::Function, rs::Vector{<:AbstractResource}) = resource_id.(filter(r -> f(r), rs))

"""
    interface(name, default=default, type=AbstractResource)

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
macro interface(name, default=default, type=AbstractResource)
    quote
        function $(esc(name))(r::$(esc(type)))
            return get(r, $(QuoteNode(name)), $(esc(default)))
        end
    end
end

"""
    has_positive(name, type=AbstractResource)

Define a function for finding resources in a vector `rs` where the attribute specified by `name` is positive.

# Arguments
- `name`: The name of the attribute.
- `type`: The type of the resource.

# Returns
- `Function`: The generated function.

## Examples
```julia
julia> @has_positive max_cap_mw Vre
julia> has_positive_max_cap_mw(gen.Vre)
3-element Vector{Int64}:
 3 
 4
 5
julia> max_cap_mw(gen[3])
4.888236
```
"""
macro has_positive(name, type=AbstractResource)
    f_name = Symbol("has_positive_$(name)")
    quote
        function $(esc(f_name))(rs::Vector{<:$(esc(type))})
            return resource_id.(filter(r -> $(esc(name))(r) > 0, rs))
        end
    end
end

"""
    has_nonnegative(name, type=AbstractResource)

Define a function for finding resources in a vector `rs` where the attribute specified by `name` is non-negative.

# Arguments
- `name`: The name of the attribute.
- `type`: The type of the resource.

# Returns
- `Function`: The generated function.

## Examples
```julia
julia> @has_nonnegative max_cap_mw Thermal
julia> has_nonnegative_max_cap_mw(gen.Thermal)
```
"""
macro has_nonnegative(name, type=AbstractResource)
    f_name = Symbol("has_nonneg_$(name)")
    quote
        function $(esc(f_name))(rs::Vector{<:$(esc(type))})
            return resource_id.(filter(r -> $(esc(name))(r) >= 0, rs))
        end
    end
end

"""
    has_attribute(name, type=AbstractResource)

Define a function for finding resources in a vector `rs` where the attribute specified by `name` is not equal to zero.

# Arguments
- `name`: The name of the attribute.
- `type`: The type of the resource.

# Returns
- `Function`: The generated function.

## Examples
```julia
julia> @has_attribute existing_cap_mw Thermal
julia> has_existing_cap_mw(gen.Thermal)
4-element Vector{Int64}:
 21
 22
 23
 24
julia> existing_cap_mw(gen[21])
7.0773
```
"""
macro has_attribute(name, type=AbstractResource)
    f_name = Symbol("has_$(name)")
    quote
        function $(esc(f_name))(rs::Vector{<:$(esc(type))})
            return resource_id.(filter(r -> $(esc(name))(r) != 0, rs))
        end
    end
end


resource_attribute_not_set() = 0
const default = 0   # default value for resource attributes

# INTERFACE FOR ALL RESOURCES
resource_name(r::AbstractResource) = r.resource
resource_name(rs::Vector{T}) where T <: AbstractResource = rs.resource

resource_id(r::AbstractResource)::Int64 = r.id
resource_id(rs::Vector{T}) where T <: AbstractResource = resource_id.(rs)
resource_type_mga(r::AbstractResource) = r.resource_type

zone_id(r::AbstractResource) = r.zone
zone_id(rs::Vector{T}) where T <: AbstractResource = rs.zone

const default_minmax_cap = -1.
max_cap_mw(r::AbstractResource) = get(r, :max_cap_mw, default_minmax_cap)
min_cap_mw(r::AbstractResource) = get(r, :min_cap_mw, default_minmax_cap)

max_cap_mwh(r::AbstractResource) = get(r, :max_cap_mwh, default_minmax_cap)
min_cap_mwh(r::AbstractResource) = get(r, :min_cap_mwh, default_minmax_cap)

max_charge_cap_mw(r::AbstractResource) = get(r, :max_charge_cap_mw, default_minmax_cap)
min_charge_cap_mw(r::AbstractResource) = get(r, :min_charge_cap_mw, default_minmax_cap)

existing_cap_mw(r::AbstractResource) = r.existing_cap_mw
existing_cap_mwh(r::AbstractResource) = get(r, :existing_cap_mwh, default)
existing_charge_capacity_mw(r::AbstractResource) = get(r, :existing_charge_cap_mw, default)

cap_size(r::AbstractResource) = get(r, :cap_size, default)

num_vre_bins(r::AbstractResource) = get(r, :num_vre_bins, default)

hydro_energy_to_power_ratio(r::AbstractResource) = get(r, :hydro_energy_to_power_ratio, default)

qualified_hydrogen_supply(r::AbstractResource) = get(r, :qualified_hydrogen_supply, default)

# costs
reg_cost(r::AbstractResource) = get(r, :reg_cost, default)
reg_max(r::AbstractResource)::Float64 = get(r, :reg_max, default)
rsv_cost(r::AbstractResource) = get(r, :rsv_cost, default)
rsv_max(r::AbstractResource) = get(r, :rsv_max, default)
inv_cost_per_mwyr(r::AbstractResource) = get(r, :inv_cost_per_mwyr, default)
fixed_om_cost_per_mwyr(r::AbstractResource) = get(r, :fixed_om_cost_per_mwyr, default)
var_om_cost_per_mwh(r::AbstractResource) = get(r, :var_om_cost_per_mwh, default)
inv_cost_per_mwhyr(r::AbstractResource) = get(r, :inv_cost_per_mwhyr, default)
fixed_om_cost_per_mwhyr(r::AbstractResource) = get(r, :fixed_om_cost_per_mwhyr, default)
inv_cost_charge_per_mwyr(r::AbstractResource) = get(r, :inv_cost_charge_per_mwyr, default)
fixed_om_cost_charge_per_mwyr(r::AbstractResource) = get(r, :fixed_om_cost_charge_per_mwyr, default)
start_cost_per_mw(r::AbstractResource) = get(r, :start_cost_per_mw, default)

# fuel
fuel(r::AbstractResource) = get(r, :fuel, "None")
start_fuel_mmbtu_per_mw(r::AbstractResource) = r.start_fuel_mmbtu_per_mw
heat_rate_mmbtu_per_mwh(r::AbstractResource) = r.heat_rate_mmbtu_per_mwh
co2_capture_fraction(r::AbstractResource) = get(r, :co2_capture_fraction, default)
co2_capture_fraction_startup(r::AbstractResource) = get(r, :co2_capture_fraction_startup, default)
ccs_disposal_cost_per_metric_ton(r::AbstractResource) = get(r, :ccs_disposal_cost_per_metric_ton, default)
biomass(r::AbstractResource) = get(r, :biomass, default)

# Reservoir hydro and storage
const default_percent = 1.0
efficiency_up(r::T) where T <: Union{Hydro,Storage} = get(r, :eff_up, default_percent)
efficiency_down(r::T) where T <: Union{Hydro,Storage} = get(r, :eff_down, default_percent)

# Ramp up and down
const VarPower = Union{Electrolyzer, Hydro, Thermal}
min_power(r::VarPower) = get(r, :min_power, default)
ramp_up_percentage(r::VarPower) = get(r, :ramp_up_percentage, default_percent)
ramp_down_percentage(r::VarPower) = get(r, :ramp_dn_percentage, default_percent)

# Retirement
lifetime(r::Storage) = get(r, :lifetime, 15)
lifetime(r::AbstractResource) = get(r, :lifetime, 30)
capital_recovery_period(r::Storage) = get(r, :capital_recovery_period, 15)
capital_recovery_period(r::AbstractResource) = get(r, :capital_recovery_period, 30)
tech_wacc(r::AbstractResource) = get(r, :wacc, default)
min_retired_cap_mw(r::AbstractResource) = get(r, :min_retired_cap_mw, default)
min_retired_energy_cap_mw(r::AbstractResource) = get(r, :min_retired_energy_cap_mw, default)
min_retired_charge_cap_mw(r::AbstractResource) = get(r, :min_retired_charge_cap_mw, default)
cum_min_retired_cap_mw(r::AbstractResource) = r.cum_min_retired_cap_mw
cum_min_retired_energy_cap_mw(r::AbstractResource) = r.cum_min_retired_energy_cap_mw
cum_min_retired_charge_cap_mw(r::AbstractResource) = r.cum_min_retired_charge_cap_mw

# MGA
mga(r::AbstractResource) = get(r, :mga, default)

# policies
esr(r::AbstractResource; tag::Int64) = get(r, Symbol("esr_$tag"), default)
min_cap(r::AbstractResource; tag::Int64) = get(r, Symbol("min_cap_$tag"), default)
max_cap(r::AbstractResource; tag::Int64) = get(r, Symbol("max_cap_$tag"), default)
eligible_cap_res(r::AbstractResource; tag::Int64) = get(r, Symbol("eligible_cap_res_$tag"), default)

# write_outputs
region(r::AbstractResource) = r.region
cluster(r::AbstractResource) = r.cluster

# UTILITY FUNCTIONS for working with resources
is_LDS(rs::Vector{T}) where T <: AbstractResource = findall(r -> get(r, :lds, default) > 0, rs)
is_SDS(rs::Vector{T}) where T <: AbstractResource = findall(r -> get(r, :lds, default) == 0, rs)

has_mga_on(rs::Vector{T}) where T <: AbstractResource = findall(r -> mga(r) > 0, rs)

has_retrofit(rs::Vector{T}) where T <: AbstractResource = findall(r -> get(r, :retro, default) > 0, rs)

has_fuel(rs::Vector{T}) where T <: AbstractResource = findall(r -> fuel(r) != "None", rs)

is_buildable(rs::Vector{T}) where T <: AbstractResource = findall(r -> get(r, :new_build, default) == 1, rs)
is_retirable(rs::Vector{T}) where T <: AbstractResource = findall(r -> get(r, :can_retire, default) == 1, rs)

# Unit commitment
has_unit_commitment(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,Thermal) && r.model == 1, rs)
# Without unit commitment
no_unit_commitment(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,Thermal) && r.model == 2, rs)

has_max_cap_mw(rs::Vector{T}) where T <: AbstractResource = findall(r -> max_cap_mw(r) != 0, rs)
has_positive_max_cap_mw(rs::Vector{T}) where T <: AbstractResource = findall(r -> max_cap_mw(r) > 0, rs)
has_positive_min_cap_mw(rs::Vector{T}) where T <: AbstractResource = findall(r -> min_cap_mw(r) > 0, rs)

has_existing_cap_mw(rs::Vector{T}) where T <: AbstractResource = findall(r -> existing_cap_mw(r) >= 0, rs)

has_max_cap_mwh(rs::Vector{T}) where T <: AbstractResource = findall(r -> max_cap_mwh(r) != 0, rs)
has_positive_max_cap_mwh(rs::Vector{T}) where T <: AbstractResource = findall(r -> max_cap_mwh(r) > 0, rs)
has_positive_min_cap_mwh(rs::Vector{T}) where T <: AbstractResource = findall(r -> min_cap_mwh(r) > 0, rs)
has_nonnegative_max_cap_mwh(rs::Vector{T}) where T <: AbstractResource = findall(r -> max_cap_mwh(r) >= 0, rs)

has_max_charge_cap_mw(rs::Vector{T}) where T <: AbstractResource = findall(r -> max_charge_cap_mw(r) != 0, rs)
has_positive_max_charge_cap_mw(rs::Vector{T}) where T <: AbstractResource = findall(r -> max_charge_cap_mw(r) > 0, rs)
has_positive_min_charge_cap_mw(rs::Vector{T}) where T <: AbstractResource = findall(r -> min_charge_cap_mw(r) > 0, rs)

has_existing_cap_mwh(rs::Vector{T}) where T <: AbstractResource = findall(r -> existing_cap_mwh(r) >= 0, rs)
has_existing_charge_capacity_mw(rs::Vector{T}) where T <: AbstractResource = findall(r -> existing_charge_capacity_mw(r) >= 0, rs)

has_qualified_hydrogen_supply(rs::Vector{T}) where T <: AbstractResource = findall(r -> qualified_hydrogen_supply(r) == 1, rs)

# policies
has_esr(rs::Vector{T}; tag::Int64=1) where T <: AbstractResource = findall(r -> esr(r,tag=tag) > 0, rs)
has_min_cap(rs::Vector{T}; tag::Int64) where T <: AbstractResource = findall(r -> min_cap(r,tag=tag) > 0, rs)
has_max_cap(rs::Vector{T}; tag::Int64) where T <: AbstractResource = findall(r -> max_cap(r,tag=tag) > 0, rs)

# STORAGE interface
"""
    storage(rs::Vector{T}) where T <: AbstractResource

Returns the indices of all storage resources in the vector `rs`.
"""
storage(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,Storage), rs)

self_discharge(r::Storage) = r.self_disch
min_duration(r::Storage) = r.min_duration
max_duration(r::Storage) = r.max_duration
var_om_cost_per_mwh_in(r::Storage) = get(r, :var_om_cost_per_mwh_in, default)
symmetric_storage(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,Storage) && r.model == 1, rs)
asymmetric_storage(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,Storage) && r.model == 2, rs)

# HYDRO interface
"""
    hydro(rs::Vector{T}) where T <: AbstractResource

Returns the indices of all hydro resources in the vector `rs`.
"""
hydro(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,Hydro), rs)
has_hydro_energy_to_power_ratio(rs::Vector{T}) where T <: AbstractResource = findall(r -> hydro_energy_to_power_ratio(r) > 0, rs)

# THERM interface
"""
    thermal(rs::Vector{T}) where T <: AbstractResource

Returns the indices of all thermal resources in the vector `rs`.
"""
thermal(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,Thermal), rs)
up_time(r::Thermal) = get(r, :up_time, default)
down_time(r::Thermal) = get(r, :down_time, default)

# VRE interface
"""
    vre(rs::Vector{T}) where T <: AbstractResource

Returns the indices of all Vre resources in the vector `rs`.
"""
vre(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,Vre), rs)
has_positive_num_vre_bins(rs::Vector{T}) where T <: AbstractResource = findall(r -> num_vre_bins(r) >= 1, rs)

# ELECTROLYZER interface
"""
    electrolyzer(rs::Vector{T}) where T <: AbstractResource

Returns the indices of all electrolyzer resources in the vector `rs`.
"""
electrolyzer(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,Electrolyzer), rs)
electrolyzer_min_kt(r::Electrolyzer) = r.electrolyzer_min_kt
hydrogen_mwh_per_tonne(r::Electrolyzer) = r.hydrogen_mwh_per_tonne
hydrogen_price_per_tonne(r::Electrolyzer) = r.hydrogen_price_per_tonne

# FLEX_DEMAND interface
"""
    flex_demand(rs::Vector{T}) where T <: AbstractResource

Returns the indices of all flexible demand resources in the vector `rs`.
"""
flex_demand(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,FlexDemand), rs)
flexible_demand_energy_eff(r::FlexDemand) = r.flexible_demand_energy_eff
max_flexible_demand_delay(r::FlexDemand) = r.max_flexible_demand_delay
max_flexible_demand_advance(r::FlexDemand) = r.max_flexible_demand_advance
var_om_cost_per_mwh_in(r::FlexDemand) = get(r, :var_om_cost_per_mwh_in, default)

# MUST_RUN interface
"""
    must_run(rs::Vector{T}) where T <: AbstractResource

Returns the indices of all must-run resources in the vector `rs`.
"""
must_run(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,MustRun), rs)

# VRE_STOR interface
"""
    vre_stor(rs::Vector{T}) where T <: AbstractResource

Returns the indices of all VRE_STOR resources in the vector `rs`.
"""
vre_stor(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,VreStorage), rs)
technology(r::VreStorage) = r.technology
self_discharge(r::VreStorage) = r.self_disch

"""
    solar(rs::Vector{T}) where T <: AbstractResource

Returns the indices of all co-located solar resources in the vector `rs`.
"""
solar(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,VreStorage) && r.solar != 0, rs)

"""
    wind(rs::Vector{T}) where T <: AbstractResource

Returns the indices of all co-located wind resources in the vector `rs`.
"""
wind(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,VreStorage) && r.wind != 0, rs)

"""
    storage_dc_discharge(rs::Vector{T}) where T <: AbstractResource
Returns the indices of all co-located storage resources in the vector `rs` that discharge DC.
"""
storage_dc_discharge(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,VreStorage) && r.stor_dc_discharge >= 1, rs)
storage_sym_dc_discharge(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,VreStorage) && r.stor_dc_discharge == 1, rs)
storage_asym_dc_discharge(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,VreStorage) && r.stor_dc_discharge == 2, rs)

""" 
    storage_dc_charge(rs::Vector{T}) where T <: AbstractResource
    Returns the indices of all co-located storage resources in the vector `rs` that charge DC.
"""
storage_dc_charge(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,VreStorage) && r.stor_dc_charge >= 1, rs)
storage_sym_dc_charge(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,VreStorage) && r.stor_dc_charge == 1, rs)
storage_asym_dc_charge(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,VreStorage) && r.stor_dc_charge == 2, rs)

""" 
    storage_ac_discharge(rs::Vector{T}) where T <: AbstractResource
Returns the indices of all co-located storage resources in the vector `rs` that discharge AC.
"""
storage_ac_discharge(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,VreStorage) && r.stor_ac_discharge >= 1, rs)
storage_sym_ac_discharge(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,VreStorage) && r.stor_ac_discharge == 1, rs)
storage_asym_ac_discharge(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,VreStorage) && r.stor_ac_discharge == 2, rs)

""" 
    storage_ac_charge(rs::Vector{T}) where T <: AbstractResource
Returns the indices of all co-located storage resources in the vector `rs` that charge AC.
"""
storage_ac_charge(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,VreStorage) && r.stor_ac_charge >= 1, rs)
storage_sym_ac_charge(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,VreStorage) && r.stor_ac_charge == 1, rs)
storage_asym_ac_charge(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,VreStorage) && r.stor_ac_charge == 2, rs)

is_LDS_VRE_STOR(rs::Vector{T}) where T <: AbstractResource = findall(r -> get(r, :lds_vre_stor, default) != 0, rs)

# loop over the above attributes and define function interfaces for each one
for attr in (:existing_cap_solar_mw, 
             :existing_cap_wind_mw,
             :existing_cap_inverter_mw,
             :existing_cap_charge_dc_mw,
             :existing_cap_charge_ac_mw,
             :existing_cap_discharge_dc_mw,
             :existing_cap_discharge_ac_mw)
    @eval @interface $attr
    @eval @has_nonnegative $attr
end

for attr in (:max_cap_solar_mw, 
             :max_cap_wind_mw, 
             :max_cap_inverter_mw, 
             :max_cap_charge_dc_mw, 
             :max_cap_charge_ac_mw, 
             :max_cap_discharge_dc_mw, 
             :max_cap_discharge_ac_mw)
    @eval @interface $attr
    @eval @has_attribute $attr
    @eval @has_nonnegative $attr
end

for attr in (:min_cap_solar_mw, 
             :min_cap_wind_mw, 
             :min_cap_inverter_mw, 
             :min_cap_charge_dc_mw, 
             :min_cap_charge_ac_mw, 
             :min_cap_discharge_dc_mw, 
             :min_cap_discharge_ac_mw,
             :inverter_ratio_solar,
             :inverter_ratio_wind,)
    @eval @interface $attr
    @eval @has_positive $attr
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
    @eval @interface $attr default VreStorage
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
    @eval @interface $attr default VreStorage
end

# Endogenous retirement
for attr in (:min_retired_cap_inverter_mw, 
             :min_retired_cap_solar_mw,
             :min_retired_cap_wind_mw,
             :min_retired_cap_discharge_dc_mw,
             :min_retired_cap_charge_dc_mw,
             :min_retired_cap_discharge_ac_mw,
             :min_retired_cap_charge_ac_mw,)
    @eval @interface $attr default VreStorage
    cum_attr = Symbol("cum_"*String(attr))
    @eval @interface $cum_attr default VreStorage
end

## policies
# co-located storage
esr_vrestor(r::AbstractResource; tag::Int64) = get(r, Symbol("esr_vrestor_$tag"), default)
min_cap_stor(r::AbstractResource; tag::Int64) = get(r, Symbol("min_cap_stor_$tag"), default)
max_cap_stor(r::AbstractResource; tag::Int64) = get(r, Symbol("max_cap_stor_$tag"), default)
# vre part
min_cap_solar(r::AbstractResource; tag::Int64) = get(r, Symbol("min_cap_solar_$tag"), default)
max_cap_solar(r::AbstractResource; tag::Int64) = get(r, Symbol("max_cap_solar_$tag"), default)
min_cap_wind(r::AbstractResource; tag::Int64) = get(r, Symbol("min_cap_wind_$tag"), default)
max_cap_wind(r::AbstractResource; tag::Int64) = get(r, Symbol("max_cap_wind_$tag"), default)

# energy share requirement
has_esr_vrestor(rs::Vector{T}; tag::Int64=1) where T <: AbstractResource = findall(r -> esr_vrestor(r,tag=tag) > 0, rs)

# min cap requirement
has_min_cap_solar(rs::Vector{T}; tag::Int64) where T <: AbstractResource = findall(r -> min_cap_solar(r,tag=tag) == 1, rs)
has_min_cap_wind(rs::Vector{T}; tag::Int64) where T <: AbstractResource = findall(r -> min_cap_wind(r,tag=tag) == 1, rs)
has_min_cap_stor(rs::Vector{T}; tag::Int64) where T <: AbstractResource = findall(r -> min_cap_stor(r,tag=tag) == 1, rs)

# max cap requirement
has_max_cap_solar(rs::Vector{T}; tag::Int64) where T <: AbstractResource = findall(r -> max_cap_solar(r,tag=tag) == 1, rs)
has_max_cap_wind(rs::Vector{T}; tag::Int64) where T <: AbstractResource = findall(r -> max_cap_wind(r,tag=tag) == 1, rs)
has_max_cap_stor(rs::Vector{T}; tag::Int64) where T <: AbstractResource = findall(r -> max_cap_stor(r,tag=tag) == 1, rs)

## Reserves
# cap reserve margin
has_cap_reserve_margin(rs::Vector{T}; tag::Int64) where T <: AbstractResource = findall(r -> eligible_cap_res(r,tag=tag) > 0, rs)
has_regulation_reserve_requirements(rs::Vector{T}) where T <: AbstractResource = findall(r -> reg_max(r) > 0, rs)
has_spinning_reserve_requirements(rs::Vector{T}) where T <: AbstractResource = findall(r -> rsv_max(r) > 0, rs)

# Maintenance
resources_with_maintenance(rs::Vector{T}) where T <: AbstractResource = findall(r -> get(r, :maint, default) > 0, rs)
maintenance_duration(r::AbstractResource) = get(r, :maintenance_duration, default)
maintenance_cycle_length_years(r::AbstractResource) = get(r, :maintenance_cycle_length_years, default)
maintenance_begin_cadence(r::AbstractResource) = get(r, :maintenance_begin_cadence, default)

## Utility functions for working with resources
in_zone(r::AbstractResource, zone::Int) = zone_id(r) == zone
resources_in_zone(rs::Vector{AbstractResource}, zone::Int) = filter(r -> in_zone(r, zone), rs)

@doc raw"""
    resources_in_zone_by_rid(rs::Vector{<:AbstractResource}, zone::Int)
Find R_ID's of resources in a zone.
"""
function resources_in_zone_by_rid(rs::Vector{<:AbstractResource}, zone::Int)
    return resource_id.(rs[zone_id.(rs) .== zone])
end

"""
    resource_by_name(rs::Vector{AbstractResource}, name::AbstractString)

Find the resource with `name` in the vector `rs`.

# Arguments
- `rs`: A vector of resources.
- `name`: The name of the resource.

# Returns
- `AbstractResource`: The resource with the name `name`.
"""
function resource_by_name(rs::Vector{AbstractResource}, name::AbstractString)
    r_id = findfirst(r -> resource_name(r) == name, rs)
    # check that the resource exists
    isnothing(r_id) && error("Resource $name not found in resource data. \nHint: Make sure that the resource names in input files match the ones in the \"resource\" folder.\n")
    return rs[r_id]
end

function resources_by_names(rs::Vector{AbstractResource}, names::Vector{String})
    return rs[findall(r -> resource_name(r) ∈ names, rs)]
end


