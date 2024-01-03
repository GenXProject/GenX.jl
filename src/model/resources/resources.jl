# Name of the type of resources available in the model
const resources_type = (:ELECTROLYZER, :FLEX, :HYDRO, :STOR, :THERM, :VRE, :MUST_RUN, :VRE_STOR)

# Create resource types from the resources_type list
for r in resources_type
    let nt = Symbol("nt"), r = r
        @eval begin
            struct $r{names,T} <: AbstractResource
                $nt::Dict{names,T}
            end
            Base.parent(e::$r) = getfield(e, $(QuoteNode(nt)))
        end
    end
end

# Define dot syntax for accessing resource attributes
function Base.getproperty(r::AbstractResource, sym::Symbol)
    # haskey(parent(r), sym) && return getproperty(parent(r), sym)
    haskey(parent(r), sym) && return parent(r)[sym]
    throw(ErrorException("type $(nameof(typeof(r))) has no field $(string(sym))"))
end
Base.setproperty!(r::AbstractResource, sym::Symbol, value) = setindex!(parent(r), value, sym)

# This make the resource type immutable
# Base.setproperty!(r::AbstractResource, sym::Symbol, value) = throw(ErrorException("setfield!: immutable struct of type $(nameof(typeof(r))) cannot be changed"))

# Check if a resource has a given attribute
Base.haskey(r::AbstractResource, sym::Symbol) = haskey(parent(r), sym)

# Get a resource attribute or return a default value
function Base.get(r::AbstractResource, sym::Symbol, default) 
    return haskey(r, sym) ? getproperty(r,sym) : default
end

# Define dot syntax for accessing resource attributes for a vector of resources
# This also allows to use resources.TYPE to get all resources of a given type
function Base.getproperty(rs::Vector{AbstractResource}, sym::Symbol)
    # if sym is Type then return all resources of that type
    sym ∈ resources_type && return rs[isa.(rs, GenX.eval(sym))]
    # if sym is a field of the resource then return that field for all resources
    return [getproperty(r, sym) for r in rs]
end

function Base.setproperty!(rs::Vector{AbstractResource}, sym::Symbol, value::Vector)
    # if sym is a field of the resource then set that field for all resources
    @assert length(rs) == length(value)
    for (r,v) in zip(rs, value)
        setproperty!(r, sym, v)
    end
    return rs
end

function Base.setindex!(rs::Vector{AbstractResource}, value::Vector, sym::Symbol)
    # if sym is a field of the resource then set that field for all resources
    @assert length(rs) == length(value)
    for (r,v) in zip(rs, value)
        setproperty!(r, sym, v)
    end
    return rs
end

# Define pairs for resource types
Base.pairs(r::AbstractResource) = pairs(parent(r))

# Define show for resource types
function Base.show(io::IO, r::AbstractResource)
    for (k,v) in pairs(r)
        println(io, "$k: $v")
    end
end

const GenXResource = Dict{Symbol, Any}

# interface with generators_data.csv
# acts as a global variable
resource_attribute_not_set() = 0
const default = 0


# INTERFACE FOR ALL RESOURCES  # TODO: check default values for resource attributes

resource_name(r::GenXResource) = r[:Resource]
resource_name(r::AbstractResource) = r.resource
resource_name(rs::Vector{T}) where T <: AbstractResource = rs.resource

resource_id(r::AbstractResource) = r.id
resource_id(rs::Vector{T}) where T <: AbstractResource = rs.id

resource_type(r::AbstractResource) = r.resource_type

zone_id(r::GenXResource) = r[:Zone]
zone_id(r::AbstractResource) = r.zone
zone_id(rs::Vector{T}) where T <: AbstractResource = rs.zone

# TODO: some of these are not required (use get() instead)
max_capacity_mw(r::AbstractResource) = r.max_cap_mw
min_capacity_mw(r::AbstractResource) = r.min_cap_mw

max_capacity_mwh(r::AbstractResource) = get(r, :max_cap_mwh, -1)
min_capacity_mwh(r::AbstractResource) = get(r, :min_cap_mwh, default)
max_charge_capacity_mw(r::AbstractResource) = get(r, :max_charge_cap_mw, -1)
min_charge_capacity_mw(r::AbstractResource) = get(r, :min_charge_cap_mw, default)

existing_capacity_mw(r::AbstractResource) = r.existing_cap_mw
existing_capacity_mwh(r::AbstractResource) = get(r, :existing_cap_mwh, default)
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
inv_cost_per_mwyr(r::AbstractResource) = r.inv_cost_per_mwyr
fixed_om_cost_per_mwyr(r::AbstractResource) = r.fixed_om_cost_per_mwyr
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
function has_retrofit(rs::Vector{T}) where T <: AbstractResource
    return findall(r -> get(r, :retro, default) > 0, rs)
end

# Retirement
lifetime(r::AbstractResource) = r.lifetime
capital_recovery_period(r::AbstractResource) = r.capital_recovery_period
tech_wacc(r::AbstractResource) = get(r, :wacc, default)
min_retired_cap_mw(r::AbstractResource) = get(r, :min_retired_cap_mw, default)
min_retired_energy_cap_mw(r::AbstractResource) = get(r, :min_retired_energy_cap_mw, default)
min_retired_charge_cap_mw(r::AbstractResource) = get(r, :min_retired_charge_cap_mw, default)
cum_min_retired_cap_mw(r::AbstractResource) = r.cum_min_retired_cap_mw
cum_min_retired_energy_cap_mw(r::AbstractResource) = r.cum_min_retired_energy_cap_mw
cum_min_retired_charge_cap_mw(r::AbstractResource) = r.cum_min_retired_charge_cap_mw

# MGA
has_mga_on(rs::Vector{T}) where T <: AbstractResource = findall(r -> get(r, :mga, default) == 1, rs)

# policies
esr(r::AbstractResource; tag::Int64) = get(r, Symbol("esr_$tag"), default)
min_cap(r::AbstractResource; tag::Int64) = get(r, Symbol("min_cap_$tag"), default)
max_cap(r::AbstractResource; tag::Int64) = get(r, Symbol("max_cap_$tag"), default)
derated_capacity(r::AbstractResource; tag::Int64) = get(r, Symbol("derated_capacity_$tag"), default)

# write_outputs
region(r::AbstractResource) = r.region
cluster(r::AbstractResource) = r.cluster

function is_buildable(rs::Vector{T}) where T <: AbstractResource
    return findall(r -> get(r, :new_build, default) == 1, rs)
end

function is_retirable(rs::Vector{T}) where T <: AbstractResource
    return findall(r -> get(r, :can_retire, default) == 1, rs)
end

function has_max_capacity_mw(rs::Vector{T}) where T <: AbstractResource
    return findall(r -> max_capacity_mw(r) != 0, rs)
end

function has_positive_max_capacity_mw(rs::Vector{T}) where T <: AbstractResource
    return findall(r -> max_capacity_mw(r) > 0, rs)
end

function has_positive_min_capacity_mw(rs::Vector{T}) where T <: AbstractResource
    return findall(r -> min_capacity_mw(r) > 0, rs)
end

function has_existing_capacity_mw(rs::Vector{T}) where T <: AbstractResource
    return findall(r -> existing_capacity_mw(r) >= 0, rs)
end

function has_fuel(rs::Vector{T}) where T <: AbstractResource
    return findall(r -> fuel(r) != "None", rs)
end

function is_LDS(rs::Vector{T}) where T <: AbstractResource
    return findall(r -> get(r, :lds, default) > 0, rs)
end

function is_SDS(rs::Vector{T}) where T <: AbstractResource
    return findall(r -> get(r, :lds, default) == 0, rs)
end

function has_max_capacity_mwh(rs::Vector{T}) where T <: AbstractResource
    return findall(r -> max_capacity_mwh(r) != 0, rs)
end

function has_positive_max_capacity_mwh(rs::Vector{T}) where T <: AbstractResource
    return findall(r -> max_capacity_mwh(r) > 0, rs)
end

function has_positive_min_capacity_mwh(rs::Vector{T}) where T <: AbstractResource
    return findall(r -> min_capacity_mwh(r) > 0, rs)
end

function has_existing_capacity_mwh(rs::Vector{T}) where T <: AbstractResource
    return findall(r -> existing_capacity_mwh(r) >= 0, rs)
end

function has_max_charge_capacity_mw(rs::Vector{T}) where T <: AbstractResource
    return findall(r -> max_charge_capacity_mw(r) != 0, rs)
end

function has_positive_max_charge_capacity_mw(rs::Vector{T}) where T <: AbstractResource
    return findall(r -> max_charge_capacity_mw(r) > 0, rs)
end

function has_positive_min_charge_capacity_mw(rs::Vector{T}) where T <: AbstractResource
    return findall(r -> min_charge_capacity_mw(r) > 0, rs)
end

function has_existing_charge_capacity_mw(rs::Vector{T}) where T <: AbstractResource
    return findall(r -> existing_charge_capacity_mw(r) >= 0, rs)
end

function has_qualified_hydrogen_supply(rs::Vector{T}) where T <: AbstractResource
    condition::BitVector = qualified_hydrogen_supply.(rs) .== 1
    return resource_id.(rs[condition])
end

## policies
# energy share requirement
function has_esr(rs::Vector{T}; tag::Int64=1) where T <: AbstractResource
    return findall(r -> esr(r,tag=tag) > 0, rs)
end

# min cap requirement
function has_min_cap(rs::Vector{T}; tag::Int64) where T <: AbstractResource
    return findall(r -> min_cap(r,tag=tag) > 0, rs)
end

# max cap requirement
function has_max_cap(rs::Vector{T}; tag::Int64) where T <: AbstractResource
    return findall(r -> max_cap(r,tag=tag) > 0, rs)
end

## Reserves
# cap reserve margin
function has_cap_reserve_margin(rs::Vector{T}; tag::Int64) where T <: AbstractResource
    return findall(r -> derated_capacity(r,tag=tag) > 0, rs)
end

function has_regulation_reserve_requirements(rs::Vector{T}) where T <: AbstractResource
    return findall(r -> reg_max(r) > 0, rs)
end

function has_spinning_reserve_requirements(rs::Vector{T}) where T <: AbstractResource
    return findall(r -> rsv_max(r) > 0, rs)
end

# Maintenance
function resources_with_maintenance(rs::Vector{T}) where T <: AbstractResource
    return findall(r -> get(r, :maint, default) > 0, rs)
end


# STOR interface
storage(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,STOR), rs)

self_discharge(r::STOR) = r.self_disch

min_duration(r::STOR) = r.min_duration
max_duration(r::STOR) = r.max_duration

var_om_cost_per_mwh_in(r::STOR) = get(r, :var_om_cost_per_mwh_in, default)

function symmetric_storage(rs::Vector{T}) where T <: AbstractResource
    return findall(r -> isa(r,STOR) && r.model == 1, rs)
end

function asymmetric_storage(rs::Vector{T}) where T <: AbstractResource
    return findall(r -> isa(r,STOR) && r.model == 2, rs)
end


# HYDRO interface
hydro(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,HYDRO), rs)

function has_hydro_energy_to_power_ratio(rs::Vector{T}) where T <: AbstractResource
    return findall(r -> hydro_energy_to_power_ratio(r) > 0, rs)
end


## THERM interface
thermal(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,THERM), rs)
# Unit commitment
up_time(r::THERM) = get(r, :up_time, default)
down_time(r::THERM) = get(r, :down_time, default)
function has_unit_commitment(rs::Vector{T}) where T <: AbstractResource
    return findall(r -> isa(r,THERM) && r.model == 1, rs)
end
# Without unit commitment
function no_unit_commitment(rs::Vector{T}) where T <: AbstractResource
    return findall(r -> isa(r,THERM) && r.model == 2, rs)
end


# VRE interface
vre(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,VRE), rs)
function has_positive_num_vre_bins(rs::Vector{T}) where T <: AbstractResource
    return findall(r -> num_vre_bins(r) >= 1, rs)
end


# ELECTROLYZER interface
electrolyzer(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,ELECTROLYZER), rs)
electrolyzer_min_kt(r::ELECTROLYZER) = r.electrolyzer_min_kt
hydrogen_mwh_per_tonne(r::ELECTROLYZER) = r.hydrogen_mwh_per_tonne
hydrogen_price_per_tonne(r::ELECTROLYZER) = r.hydrogen_price_per_tonne


# FLEX interface
flex_demand(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,FLEX), rs)
var_om_cost_per_mwh_in(r::FLEX) = r.var_om_cost_per_mwh_in
flexible_demand_energy_eff(r::FLEX) = r.flexible_demand_energy_eff
max_flexible_demand_delay(r::FLEX) = r.max_flexible_demand_delay
max_flexible_demand_advance(r::FLEX) = r.max_flexible_demand_advance


# MUST_RUN interface
must_run(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,MUST_RUN), rs)

# VRE_STOR
vre_stor(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,VRE_STOR), rs)

## Utility functions for working with resources

function in_zone(resource::GenXResource, zone::Int)::Bool
    zone_id(resource) == zone
end
in_zone(r::AbstractResource, zone::Int) = r.zone == zone

@doc raw"""
    resources_in_zone(resources::Vector{GenXResource}, zone::Int)::Vector{GenXResources)
Find resources in a zone.
"""
function resources_in_zone(resources::Vector{GenXResource}, zone::Int)::Vector{GenXResource}
    return filter(r -> in_zone(r, zone), resources)
end
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

function resources_in_zone_by_rid(rs::Vector{AbstractResource}, zone::Int)
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
	check_resource_type_flags(r::GenXResource)

Make sure that a resource is not more than one of a set of mutually-exclusive models
"""
function check_resource_type_flags(r::GenXResource)
    exclusive_flags = [:THERM, :MUST_RUN, :STOR, :FLEX, :HYDRO, :VRE, :VRE_STOR, :ELECTROLYZER]
    not_set = resource_attribute_not_set()
    check_for_flag_set(el) = get(r, el, not_set) > 0

    statuses = check_for_flag_set.(exclusive_flags)
    number_set = count(statuses)

    error_strings = String[]
    if number_set == 0
        e = string("Resource ", resource_name(r), " has none of ", exclusive_flags, " set.\n",
                   "Exactly one of these should be non-$not_set.")
        push!(error_strings, e)
    elseif number_set > 1
        set_flags = exclusive_flags[statuses]
        e = string("Resource ", resource_name(r), " has both ", set_flags, " ≠ $not_set.\n",
                   "Exactly one of these should be non-$not_set.")
        push!(error_strings, e)
    end
    return error_strings
end

@doc raw"""
	check_mustrun_reserve_contribution(r::GenXResource)

Make sure that a MUST_RUN resource has Reg_Max and Rsv_Max set to 0 (since they cannot contribute to reserves).
"""
function check_mustrun_reserve_contribution(r::GenXResource)
    not_set = resource_attribute_not_set()
    value = get(r, :MUST_RUN, not_set)

    error_strings = String[]

    if value == not_set
        # not MUST_RUN so the rest is not applicable
        return error_strings
    end

    reg_max = get(r, :Reg_Max, not_set)
    if reg_max != 0
        e = string("Resource ", resource_name(r), " has :MUST_RUN = ", value, " but :Reg_Max = ", reg_max, ".\n",
                    "MUST_RUN units must have Reg_Max = 0 since they cannot contribute to reserves.")
        push!(error_strings, e)
    end
    rsv_max = get(r, :Rsv_Max, not_set)
    if rsv_max != 0
        e = string("Resource ", resource_name(r), " has :MUST_RUN = ", value, " but :Rsv_Max = ", rsv_max, ".\n",
                   "MUST_RUN units must have Rsv_Max = 0 since they cannot contribute to reserves.")
        push!(error_strings, e)
    end
    return error_strings
end

@doc raw"""
	check_longdurationstorage_applicability(r::GenXResource)

Check whether the LDS flag is set appropriately
"""
function check_longdurationstorage_applicability(r::GenXResource)
    applicable_resources = [:STOR, :HYDRO]

    not_set = resource_attribute_not_set()
    lds_value = get(r, :LDS, not_set)

    error_strings = String[]

    if lds_value == not_set
        # not LDS so the rest is not applicable
        return error_strings
    end

    check_for_flag_set(el) = get(r, el, not_set) > 0
    statuses = check_for_flag_set.(applicable_resources)

    if count(statuses) == 0
        e = string("Resource ", resource_name(r), " has :LDS = ", lds_value, ".\n",
                   "This setting is valid only for resources where the type is one of $applicable_resources.")
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

@doc raw"""
	check_maintenance_applicability(r::GenXResource)

Check whether the MAINT flag is set appropriately
"""
function check_maintenance_applicability(r::GenXResource)
    applicable_resources = [:THERM]

    not_set = resource_attribute_not_set()
    value = get(r, :MAINT, not_set)

    error_strings = String[]

    if value == not_set
        # not MAINT so the rest is not applicable
        return error_strings
    end

    check_for_flag_set(el) = get(r, el, not_set) > 0
    statuses = check_for_flag_set.(applicable_resources)

    if count(statuses) == 0
        e = string("Resource ", resource_name(r), " has :MAINT = ", value, ".\n",
                   "This setting is valid only for resources where the type is \n",
                   "one of $applicable_resources. \n",
                  )
        push!(error_strings, e)
    end
    if get(r, :THERM, not_set) == 2
        e = string("Resource ", resource_name(r), " has :MAINT = ", value, ".\n",
                   "This is valid only for resources with unit commitment (:THERM = 1);\n",
                   "this has :THERM = 2.")
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

@doc raw"""
    check_resource(r::GenXResource)::Vector{String}

Top-level function for validating the self-consistency of a GenX resource.
Reports any errors in a list of strings.
"""
function check_resource(r::GenXResource)::Vector{String}
    e = String[]
    e = [e; check_resource_type_flags(r)]
    e = [e; check_longdurationstorage_applicability(r)]
    e = [e; check_maintenance_applicability(r)]
    e = [e; check_mustrun_reserve_contribution(r)]
    return e
end

function check_resource(r::AbstractResource)::Vector{String}
    e = String[]
    e = [e; check_LDS_applicability(r)]
    e = [e; check_maintenance_applicability(r)]
    return e
end

@doc raw"""
    check_resource(resources::Vector{GenXResource})::Vector{String}

Validate the consistency of a vector of GenX resources
Reports any errors in a list of strings.
"""
function check_resource(resources::T)::Vector{String} where T <: Union{Vector{GenXResource}, Vector{AbstractResource}}
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

function validate_resources(resources::T) where T <: Union{Vector{GenXResource}, Vector{AbstractResource}}
    e = check_resource(resources)
    if length(e) > 0
        announce_errors_and_halt(e)
    end
end

function dataframerow_to_dict(dfr::DataFrameRow)
    return Dict(pairs(dfr))
end
