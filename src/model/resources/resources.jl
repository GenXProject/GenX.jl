# Name of the type of resources available in the model
const resources_type = (:ELECTROLYZER, :FLEX, :HYDRO, :STOR, :THERM, :VRE, :MUST_RUN, :VRE_STOR)

# Create resource types from the resources_type list
for r in resources_type
    let dict = Symbol("dict"), r = r
        @eval begin
            struct $r{names<:Symbol, T<:Any} <: AbstractResource
                $dict::Dict{names,T}
            end
            Base.parent(e::$r) = getfield(e, $(QuoteNode(dict)))
        end
    end
end

# Define dot syntax for accessing resource attributes
function Base.getproperty(r::AbstractResource, sym::Symbol)
    haskey(parent(r), sym) && return parent(r)[sym]
    throw(ErrorException("type $(nameof(typeof(r))) has no attribute $(string(sym))"))
end
Base.setproperty!(r::AbstractResource, sym::Symbol, value) = setindex!(parent(r), value, sym)

# Check if a resource has a given attribute
Base.haskey(r::AbstractResource, sym::Symbol) = haskey(parent(r), sym)

# Get a resource attribute or return a default value
function Base.get(r::AbstractResource, sym::Symbol, default) 
    return haskey(r, sym) ? getproperty(r,sym) : default
end

# Define dot syntax for accessing resource attributes for a vector of resources
# This also allows to use resources.TYPE to get all resources of a given type
function Base.getproperty(rs::Vector{<:AbstractResource}, sym::Symbol)
    # if sym is Type then return all resources of that type
    if sym ∈ resources_type 
        res_type = eval(sym)
        return Vector{res_type}(rs[isa.(rs, res_type)])
    end
    # if sym is a field of the resource then return that field for all resources
    return [getproperty(r, sym) for r in rs]
end

# Define dot syntax and []-operator for setting resource attributes for a vector of resources
function Base.setproperty!(rs::Vector{<:AbstractResource}, sym::Symbol, value::Vector)
    # if sym is a field of the resource then set that field for all resources
    @assert length(rs) == length(value)
    for (r,v) in zip(rs, value)
        setproperty!(r, sym, v)
    end
    return rs
end

function Base.setindex!(rs::Vector{<:AbstractResource}, value::Vector, sym::Symbol)
    # if sym is a field of the resource then set that field for all resources
    @assert length(rs) == length(value)
    for (r,v) in zip(rs, value)
        setproperty!(r, sym, v)
    end
    return rs
end

# Define pairs for resource types
Base.pairs(r::AbstractResource) = pairs(parent(r))

# Define how to print a resource
function Base.show(io::IO, r::AbstractResource)
    for (k,v) in pairs(r)
        println(io, "$k: $v")
    end
end

# This override the findall function to return the resource id instead of the vector index
Base.findall(f::Function, rs::Vector{<:AbstractResource}) = resource_id.(filter(r -> f(r), rs))

# Define macro to create functions for accessing resource attributes
macro interface(name, default=default, type=AbstractResource)
    quote
        function $(esc(name))(r::$(esc(type)))
            return get(r, $(QuoteNode(name)), $(esc(default)))
        end
    end
end

macro has_positive(name, type=AbstractResource)
    f_name = Symbol("has_positive_$(name)")
    quote
        function $(esc(f_name))(rs::Vector{<:$(esc(type))})
            return resource_id.(filter(r -> $(esc(name))(r) > 0, rs))
        end
    end
end

macro has_nonnegative(name, type=AbstractResource)
    f_name = Symbol("has_nonneg_$(name)")
    quote
        function $(esc(f_name))(rs::Vector{<:$(esc(type))})
            return resource_id.(filter(r -> $(esc(name))(r) >= 0, rs))
        end
    end
end

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
resource_type(r::AbstractResource) = r.resource_type

zone_id(r::AbstractResource) = r.zone
zone_id(rs::Vector{T}) where T <: AbstractResource = rs.zone

max_cap_mw(r::AbstractResource) = get(r, :max_cap_mw, -1)
min_cap_mw(r::AbstractResource) = get(r, :min_cap_mw, -1)

max_cap_mwh(r::AbstractResource) = get(r, :max_cap_mwh, -1)
min_cap_mwh(r::AbstractResource) = get(r, :min_cap_mwh, -1)

max_charge_cap_mw(r::AbstractResource) = get(r, :max_charge_cap_mw, -1)
min_charge_cap_mw(r::AbstractResource) = get(r, :min_charge_cap_mw, -1)

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
efficiency_up(r::T) where T <: Union{HYDRO,STOR} = get(r, :eff_up, 1.0)
efficiency_down(r::T) where T <: Union{HYDRO,STOR} = get(r, :eff_down, 1.0)

# Ramp up and down
const TCOMMIT = Union{ELECTROLYZER, HYDRO, THERM}
min_power(r::TCOMMIT) = get(r, :min_power, default)
ramp_up_percentage(r::TCOMMIT) = get(r, :ramp_up_percentage, 1.0)
ramp_down_percentage(r::TCOMMIT) = get(r, :ramp_dn_percentage, 1.0)

# Retrofit
has_retrofit(rs::Vector{T}) where T <: AbstractResource = findall(r -> get(r, :retro, default) > 0, rs)

# Retirement
lifetime(r::STOR) = get(r, :lifetime, 15)
lifetime(r::AbstractResource) = get(r, :lifetime, 30)
capital_recovery_period(r::STOR) = get(r, :capital_recovery_period, 15)
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
has_mga_on(rs::Vector{T}) where T <: AbstractResource = findall(r -> mga(r) > 0, rs)

# policies
esr(r::AbstractResource; tag::Int64) = get(r, Symbol("esr_$tag"), default)
min_cap(r::AbstractResource; tag::Int64) = get(r, Symbol("min_cap_$tag"), default)
max_cap(r::AbstractResource; tag::Int64) = get(r, Symbol("max_cap_$tag"), default)
eligible_cap_res(r::AbstractResource; tag::Int64) = get(r, Symbol("eligible_cap_res_$tag"), default)

# write_outputs
region(r::AbstractResource) = r.region
cluster(r::AbstractResource) = r.cluster

# Utility functions for working with resources
is_buildable(rs::Vector{T}) where T <: AbstractResource = findall(r -> get(r, :new_build, default) == 1, rs)
is_retirable(rs::Vector{T}) where T <: AbstractResource = findall(r -> get(r, :can_retire, default) == 1, rs)

has_max_cap_mw(rs::Vector{T}) where T <: AbstractResource = findall(r -> max_cap_mw(r) != 0, rs)
has_positive_max_cap_mw(rs::Vector{T}) where T <: AbstractResource = findall(r -> max_cap_mw(r) > 0, rs)
has_positive_min_cap_mw(rs::Vector{T}) where T <: AbstractResource = findall(r -> min_cap_mw(r) > 0, rs)

has_existing_cap_mw(rs::Vector{T}) where T <: AbstractResource = findall(r -> existing_cap_mw(r) >= 0, rs)

has_fuel(rs::Vector{T}) where T <: AbstractResource = findall(r -> fuel(r) != "None", rs)

is_LDS(rs::Vector{T}) where T <: AbstractResource = findall(r -> get(r, :lds, default) > 0, rs)
is_SDS(rs::Vector{T}) where T <: AbstractResource = findall(r -> get(r, :lds, default) == 0, rs)

has_max_cap_mwh(rs::Vector{T}) where T <: AbstractResource = findall(r -> max_cap_mwh(r) != 0, rs)
has_positive_max_cap_mwh(rs::Vector{T}) where T <: AbstractResource = findall(r -> max_cap_mwh(r) > 0, rs)
has_nonneg_max_cap_mwh(rs::Vector{T}) where T <: AbstractResource = findall(r -> max_cap_mwh(r) >= 0, rs)
has_positive_min_cap_mwh(rs::Vector{T}) where T <: AbstractResource = findall(r -> min_cap_mwh(r) > 0, rs)
has_existing_cap_mwh(rs::Vector{T}) where T <: AbstractResource = findall(r -> existing_cap_mwh(r) >= 0, rs)
has_max_charge_cap_mw(rs::Vector{T}) where T <: AbstractResource = findall(r -> max_charge_cap_mw(r) != 0, rs)
has_positive_max_charge_cap_mw(rs::Vector{T}) where T <: AbstractResource = findall(r -> max_charge_cap_mw(r) > 0, rs)
has_positive_min_charge_cap_mw(rs::Vector{T}) where T <: AbstractResource = findall(r -> min_charge_cap_mw(r) > 0, rs)
has_existing_charge_capacity_mw(rs::Vector{T}) where T <: AbstractResource = findall(r -> existing_charge_capacity_mw(r) >= 0, rs)

function has_qualified_hydrogen_supply(rs::Vector{T}) where T <: AbstractResource
    condition::BitVector = qualified_hydrogen_supply.(rs) .== 1
    return resource_id.(rs[condition])
end

## policies
# energy share requirement
has_esr(rs::Vector{T}; tag::Int64=1) where T <: AbstractResource = findall(r -> esr(r,tag=tag) > 0, rs)

# min cap requirement
has_min_cap(rs::Vector{T}; tag::Int64) where T <: AbstractResource = findall(r -> min_cap(r,tag=tag) > 0, rs)

# max cap requirement
has_max_cap(rs::Vector{T}; tag::Int64) where T <: AbstractResource = findall(r -> max_cap(r,tag=tag) > 0, rs)

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

# STOR interface
storage(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,STOR), rs)

self_discharge(r::STOR) = r.self_disch

min_duration(r::STOR) = r.min_duration
max_duration(r::STOR) = r.max_duration

var_om_cost_per_mwh_in(r::STOR) = get(r, :var_om_cost_per_mwh_in, default)

symmetric_storage(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,STOR) && r.model == 1, rs)
asymmetric_storage(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,STOR) && r.model == 2, rs)


# HYDRO interface
hydro(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,HYDRO), rs)
has_hydro_energy_to_power_ratio(rs::Vector{T}) where T <: AbstractResource = findall(r -> hydro_energy_to_power_ratio(r) > 0, rs)


## THERM interface
thermal(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,THERM), rs)
# Unit commitment
up_time(r::THERM) = get(r, :up_time, default)
down_time(r::THERM) = get(r, :down_time, default)
has_unit_commitment(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,THERM) && r.model == 1, rs)
# Without unit commitment
no_unit_commitment(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,THERM) && r.model == 2, rs)


# VRE interface
vre(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,VRE), rs)
has_positive_num_vre_bins(rs::Vector{T}) where T <: AbstractResource = findall(r -> num_vre_bins(r) >= 1, rs)


# ELECTROLYZER interface
electrolyzer(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,ELECTROLYZER), rs)
electrolyzer_min_kt(r::ELECTROLYZER) = r.electrolyzer_min_kt
hydrogen_mwh_per_tonne(r::ELECTROLYZER) = r.hydrogen_mwh_per_tonne
hydrogen_price_per_tonne(r::ELECTROLYZER) = r.hydrogen_price_per_tonne


# FLEX interface
flex_demand(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,FLEX), rs)
flexible_demand_energy_eff(r::FLEX) = r.flexible_demand_energy_eff
max_flexible_demand_delay(r::FLEX) = r.max_flexible_demand_delay
max_flexible_demand_advance(r::FLEX) = r.max_flexible_demand_advance
var_om_cost_per_mwh_in(r::FLEX) = get(r, :var_om_cost_per_mwh_in, default)


# MUST_RUN interface
must_run(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,MUST_RUN), rs)


# VRE_STOR
technology(r::VRE_STOR) = r.technology
self_discharge(r::VRE_STOR) = r.self_disch

vre_stor(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,VRE_STOR), rs)
solar(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,VRE_STOR) && r.solar != 0, rs)
wind(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,VRE_STOR) && r.wind != 0, rs)

storage_dc_discharge(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,VRE_STOR) && r.stor_dc_discharge >= 1, rs)
storage_sym_dc_discharge(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,VRE_STOR) && r.stor_dc_discharge == 1, rs)
storage_asym_dc_discharge(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,VRE_STOR) && r.stor_dc_discharge == 2, rs)

storage_dc_charge(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,VRE_STOR) && r.stor_dc_charge >= 1, rs)
storage_sym_dc_charge(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,VRE_STOR) && r.stor_dc_charge == 1, rs)
storage_asym_dc_charge(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,VRE_STOR) && r.stor_dc_charge == 2, rs)

storage_ac_discharge(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,VRE_STOR) && r.stor_ac_discharge >= 1, rs)
storage_sym_ac_discharge(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,VRE_STOR) && r.stor_ac_discharge == 1, rs)
storage_asym_ac_discharge(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,VRE_STOR) && r.stor_ac_discharge == 2, rs)

storage_ac_charge(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,VRE_STOR) && r.stor_ac_charge >= 1, rs)
storage_sym_ac_charge(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,VRE_STOR) && r.stor_ac_charge == 1, rs)
storage_asym_ac_charge(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,VRE_STOR) && r.stor_ac_charge == 2, rs)

is_LDS_VRE_STOR(rs::Vector{T}) where T <: AbstractResource = findall(r -> get(r, :lds_vre_stor, default) != 0, rs)

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
    @eval @interface $attr default VRE_STOR
end

# MultiStage 
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
    @eval @interface $attr default VRE_STOR
end

# Endogenous retirement
for attr in (:min_retired_cap_inverter_mw, 
             :min_retired_cap_solar_mw,
             :min_retired_cap_wind_mw,
             :min_retired_cap_discharge_dc_mw,
             :min_retired_cap_charge_dc_mw,
             :min_retired_cap_discharge_ac_mw,
             :min_retired_cap_charge_ac_mw,)
    @eval @interface $attr default VRE_STOR
    cum_attr = Symbol("cum_"*String(attr))
    @eval @interface $cum_attr default VRE_STOR
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


## Utility functions for working with resources
in_zone(r::AbstractResource, zone::Int) = zone_id(r) == zone
resources_in_zone(rs::Vector{AbstractResource}, zone::Int) = filter(r -> in_zone(r, zone), rs)

@doc raw"""
    resources_in_zone_by_name(inputs::Dict, zone::Int)::Vector{String}
Find names of resources in a zone.
"""
function resources_in_zone_by_name(inputs::Dict, zone::Int)
    resources_d = inputs["resources_d"]
    return resource_name.(resources_in_zone(resources_d, zone))
end

@doc raw"""
    resources_in_zone_by_rid(df::DataFrame, zone::Int)::Vector{Int}
Find R_ID's of resources in a zone.
"""
function resources_in_zone_by_rid(df::DataFrame, zone::Int)::Vector{Int}
    return df[df.Zone .== zone, :R_ID]
end

@doc raw"""
    resources_in_zone_by_rid(inputs::Dict, zone::Int)::Vector{Int}
Find R_ID's of resources in a zone.
"""
function resources_in_zone_by_rid(inputs::Dict, zone::Int)::Vector{Int}
    df = inputs["dfGen"]
    return resources_in_zone_by_rid(df, zone)
end

function resources_in_zone_by_rid(rs::Vector{<:AbstractResource}, zone::Int)
    return resource_id.(rs[zone_id.(rs) .== zone])
end

function resource_by_name(rs::Vector{AbstractResource}, name::AbstractString)
    r_id = findfirst(r -> resource_name(r) == name, rs)
    # check that the resource exists
    isnothing(r_id) && error("Resource $name not found in resource data. \nHint: Make sure that the resource names in input files match the ones in the \"resource\" folder.\n")
    return rs[r_id]
end

function resources_by_names(rs::Vector{AbstractResource}, names::Vector{String})
    return rs[findall(r -> resource_name(r) ∈ names, rs)]
end

@doc raw"""
	check_mustrun_reserve_contribution(r::AbstractResource)

Make sure that a MUST_RUN resource has Reg_Max and Rsv_Max set to 0 (since they cannot contribute to reserves).
"""
function check_mustrun_reserve_contribution(r::AbstractResource)
    applicable_resources = MustRun
    error_strings = String[]

    if !isa(r, applicable_resources)
        # not MUST_RUN so the rest is not applicable
        return error_strings
    end

    reg_max_r = reg_max(r)
    if reg_max_r != 0
        e = string("Resource ", resource_name(r), " is of MUST_RUN type but :Reg_Max = ", reg_max_r, ".\n",
                    "MUST_RUN units must have Reg_Max = 0 since they cannot contribute to reserves.")
        push!(error_strings, e)
    end
    
    rsv_max_r = rsv_max(r)
    if rsv_max_r != 0
        e = string("Resource ", resource_name(r), " is of MUST_RUN type but :Rsv_Max = ", rsv_max_r, ".\n",
                   "MUST_RUN units must have Rsv_Max = 0 since they cannot contribute to reserves.")
        push!(error_strings, e)
    end
    return error_strings
end

function check_LDS_applicability(r::AbstractResource)
    applicable_resources = Union{STOR, HYDRO}
    not_set = resource_attribute_not_set()
    error_strings = String[]
    lds_value = get(r, :LDS, not_set)
    # LDS is available onlåy for Hydro and Storage
    if !isa(r, applicable_resources) && lds_value > 0
        e = string("Resource ", resource_name(r), " has :LDS = ", lds_value, ".\n",
                   "This setting is valid only for resources where the type is one of $applicable_resources.")
        push!(error_strings, e)
    end
    return error_strings
end

function check_maintenance_applicability(r::AbstractResource)
    applicable_resources = THERM

    not_set = resource_attribute_not_set()
    maint_value = get(r, :MAINT, not_set)
    
    error_strings = String[]
    
    if maint_value == not_set
        # not MAINT so the rest is not applicable
        return error_strings
    end

    # MAINT is available only for Thermal
    if !isa(r, applicable_resources) && maint_value > 0
        e = string("Resource ", resource_name(r), " has :MAINT = ", maint_value, ".\n",
                   "This setting is valid only for resources where the type is one of $applicable_resources.")
        push!(error_strings, e)
    end
    if get(r, :THERM, not_set) == 2
        e = string("Resource ", resource_name(r), " has :MAINT = ", maint_value, ".\n",
                   "This is valid only for resources with unit commitment (:THERM = 1);\n",
                   "this has :THERM = 2.")
        push!(error_strings, e)
    end
    return error_strings
end

function check_resource(r::AbstractResource)::Vector{String}
    e = String[]
    e = [e; check_LDS_applicability(r)]
    e = [e; check_maintenance_applicability(r)]    
    e = [e; check_mustrun_reserve_contribution(r)]
    return e
end

@doc raw"""
    check_resource(resources::Vector{GenXResource})::Vector{String}

Validate the consistency of a vector of GenX resources
Reports any errors in a list of strings.
"""
function check_resource(resources::T)::Vector{String} where T <: Vector{AbstractResource}
    e = String[]
    for r in resources
        e = [e; check_resource(r)]
    end
    return e
end

function announce_errors_and_halt(e::Vector{String})    
    error_count = length(e)
    for error_message in e
        @error(error_message)
    end
    s = string(error_count, " problems were detected with the input data. Halting.")
    error(s)
end

function validate_resources(resources::T) where T <: Vector{AbstractResource}
    e = check_resource(resources)
    if length(e) > 0
        announce_errors_and_halt(e)
    end
end

function dataframerow_to_dict(dfr::DataFrameRow)
    return Dict(pairs(dfr))
end
