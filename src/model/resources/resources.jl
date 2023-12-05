GenXResource = Dict{Symbol, Any}

# interface with generators_data.csv
# acts as a global variable
resource_attribute_not_set() = 0

resource_name(r::GenXResource) = r[:Resource]

function find_indexed_keys(r::GenXResource,
        keyprefix::AbstractString;
        prefixseparator='_')::Vector{Int}
    all_keys = string.(keys(r))
    # if prefix is "ESR", the key name should be like "ESR_1"
    function is_of_this_key_type(k)
        startswith(k, keyprefix) &&
        length(k) >= length(keyprefix) + 2 &&
        k[length(keyprefix) + 1] == prefixseparator &&
        !isnothing(get_integer_part(k))
    end
    # 2 is the length of the '_' connector plus one for indexing
    get_integer_part(k) = tryparse(Int, k[length(keyprefix)+2:end])
    ks = filter(is_of_this_key_type, all_keys)
    keynumbers = sort!(get_integer_part.(ks))
    return keynumbers
end

@doc raw"""
    extract_sequential_keys(r::GenXResource, keyprefix::AbstractString)

Finds all keys in the dataframe which are of the form keyprefix_[Integer],
and extracts them in order into a vector. The function also checks that there's at least
one key with this prefix, and that all keys numbered from 1...N exist.
"""
function extract_sequential_keys(r::GenXResource, keyprefix::AbstractString; prefixseparator='_')
    all_keys = keys(r)
    keynumbers = find_indexed_keys(r,
                                   keyprefix,
                                   prefixseparator=prefixseparator)

    if length(keynumbers) == 0
        msg = """an input dataframe with keys $all_keys was searched for
        numbered keys starting with $keyprefix, but nothing was found."""
        error(msg)
    end

    # check that the sequence of column numbers is 1..N
    if keynumbers != collect(1:length(keynumbers))
        msg = """the keys $keys in an input file must be numbered in
        a complete sequence from 1...N. It looks like some of the sequence is missing.
        This error could also occur if there are two keys with the same number."""
        error(msg)
    end

    sorted_keys = Symbol.(keyprefix .* prefixseparator .* string.(keynumbers))
    return get.(Ref(r), sorted_keys, nothing)
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
    check_fusion_applicability(r::GenXResource)

Check whether the FUSION flag is set appropriately
"""
function check_fusion_applicability(r::GenXResource)
    applicable_resources = [:THERM]

    not_set = resource_attribute_not_set()
    value = get(r, :FUSION, not_set)

    error_strings = String[]

    if value == not_set
        # not FUSION so the rest is not applicable
        return error_strings
    end

    check_for_flag_set(el) = get(r, el, not_set) > 0
    statuses = check_for_flag_set.(applicable_resources)

    if count(statuses) == 0
        e = string("Resource ", resource_name(r), " has :FUSION = ", value, ".\n",
                   "This setting is valid only for resources where the type is \n",
                   "one of $applicable_resources. \n",
                  )
        push!(error_strings, e)
    end

    if get(r, :THERM, not_set) == 2
        e = string("Resource ", resource_name(r), " has :FUSION = ", value, ".\n",
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
    e = [e; check_fusion_applicability(r)]
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
