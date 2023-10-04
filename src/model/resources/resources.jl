GenXResource = Dict{Symbol, Any}

# interface with generators_data.csv
# acts as a global variable
resource_attribute_not_set() = 0

resource_name(r::GenXResource) = r[:Resource]

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
    return e
end

@doc raw"""
    check_resource(resources::Vector{GenXResource})::Vector{String}

Validate the consistency of a vector of GenX resources
Reports any errors in a list of strings.
"""
function check_resource(resources::Vector{GenXResource})::Vector{String}
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

function validate_resources(resources::Vector{GenXResource})
    e = check_resource(resources)
    if length(e) > 0
        announce_errors_and_halt(e)
    end
end

function dataframerow_to_dict(dfr::DataFrameRow)
    return Dict(pairs(dfr))
end
