"""
    _get_resource_info()

Internal function to get resource information (filename and GenX type) for each type of resource available in GenX.

# 
    resource_info (NamedTuple): A tuple containing resource information.

"""
function _get_resource_info()
    resource_info = (hydro = (filename = "Hydro.csv", type = Hydro),
        thermal = (filename = "Thermal.csv", type = Thermal),
        vre = (filename = "Vre.csv", type = Vre),
        storage = (filename = "Storage.csv", type = Storage),
        flex_demand = (filename = "Flex_demand.csv", type = FlexDemand),
        must_run = (filename = "Must_run.csv", type = MustRun),
        electrolyzer = (filename = "Electrolyzer.csv", type = Electrolyzer),
        vre_stor = (filename = "Vre_stor.csv", type = VreStorage))
    return resource_info
end

"""
    _get_policyfile_info()

Internal function to get policy file information.

# Returns
    policyfile_info (NamedTuple): A tuple containing policy file information.

"""
function _get_policyfile_info()
    # filename for each type of policy available in GenX
    esr_filenames = ["Resource_energy_share_requirement.csv"]
    cap_res_filenames = ["Resource_capacity_reserve_margin.csv"]
    min_cap_filenames = ["Resource_minimum_capacity_requirement.csv"]
    max_cap_filenames = ["Resource_maximum_capacity_requirement.csv"]

    policyfile_info = (esr = (filenames = esr_filenames,
            setup_param = "EnergyShareRequirement"),
        cap_res = (filenames = cap_res_filenames, setup_param = "CapacityReserveMargin"),
        min_cap = (filenames = min_cap_filenames, setup_param = "MinCapReq"),
        max_cap = (filenames = max_cap_filenames, setup_param = "MaxCapReq"))
    return policyfile_info
end

"""
    _get_summary_map()

Internal function to get a map of GenX resource type their corresponding names in the summary table.
"""
function _get_summary_map()
    names_map = Dict{Symbol, String}(:Electrolyzer => "Electrolyzer",
        :FlexDemand => "Flexible_demand",
        :Hydro => "Hydro",
        :Storage => "Storage",
        :Thermal => "Thermal",
        :Vre => "VRE",
        :MustRun => "Must_run",
        :VreStorage => "VRE_and_storage")
    max_length = maximum(length.(values(names_map)))
    for (k, v) in names_map
        names_map[k] = v * repeat(" ", max_length - length(v))
    end
    return names_map
end

"""
    scale_resources_data!(resource_in::DataFrame, scale_factor::Float64)

Scales resources attributes in-place if necessary. Generally, these scalings converts energy and power units from MW to GW  and \$/MW to \$M/GW. Both are done by dividing the values by 1000.
See documentation for descriptions of each column being scaled.

# Arguments
- `resource_in` (DataFrame): A dataframe containing data for a specific resource.
- `scale_factor` (Float64): A scaling factor for energy and currency units.

"""
function scale_resources_data!(resource_in::DataFrame, scale_factor::Float64)
    columns_to_scale = [:existing_charge_cap_mw,        # to GW
        :existing_cap_mwh,              # to GWh
        :existing_cap_mw,               # to GW
        :cap_size,                      # to GW
        :min_cap_mw,                    # to GW
        :min_cap_mwh,                   # to GWh
        :min_charge_cap_mw,             # to GWh
        :max_cap_mw,                    # to GW
        :max_cap_mwh,                   # to GWh
        :max_charge_cap_mw,             # to GW
        :inv_cost_per_mwyr,             # to $M/GW/yr
        :inv_cost_per_mwhyr,            # to $M/GWh/yr
        :inv_cost_charge_per_mwyr,      # to $M/GW/yr
        :fixed_om_cost_per_mwyr,        # to $M/GW/yr
        :fixed_om_cost_per_mwhyr,       # to $M/GWh/yr
        :fixed_om_cost_charge_per_mwyr, # to $M/GW/yr
        :var_om_cost_per_mwh,           # to $M/GWh
        :var_om_cost_per_mwh_in,        # to $M/GWh
        :reg_cost,                      # to $M/GW
        :rsv_cost,                      # to $M/GW
        :min_retired_cap_mw,            # to GW
        :min_retired_charge_cap_mw,     # to GW
        :min_retired_energy_cap_mw,     # to GW
        :start_cost_per_mw,             # to $M/GW
        :ccs_disposal_cost_per_metric_ton, :hydrogen_mwh_per_tonne,       # to GWh/t
    ]

    scale_columns!(resource_in, columns_to_scale, scale_factor)
    return nothing
end

"""
    scale_vre_stor_data!(vre_stor_in::DataFrame, scale_factor::Float64)

Scales vre_stor attributes in-place if necessary. Generally, these scalings converts energy and power units from MW to GW  and \$/MW to \$M/GW. Both are done by dividing the values by 1000.
See documentation for descriptions of each column being scaled.

# Arguments
- `vre_stor_in` (DataFrame): A dataframe containing data for co-located VREs and storage.
- `scale_factor` (Float64): A scaling factor for energy and currency units.

"""
function scale_vre_stor_data!(vre_stor_in::DataFrame, scale_factor::Float64)
    columns_to_scale = [:existing_cap_inverter_mw,
        :existing_cap_solar_mw,
        :existing_cap_wind_mw,
        :existing_cap_charge_dc_mw,
        :existing_cap_charge_ac_mw,
        :existing_cap_discharge_dc_mw,
        :existing_cap_discharge_ac_mw,
        :min_cap_inverter_mw,
        :max_cap_inverter_mw,
        :min_cap_solar_mw,
        :max_cap_solar_mw,
        :min_cap_wind_mw,
        :max_cap_wind_mw,
        :min_cap_charge_ac_mw,
        :max_cap_charge_ac_mw,
        :min_cap_charge_dc_mw,
        :max_cap_charge_dc_mw,
        :min_cap_discharge_ac_mw,
        :max_cap_discharge_ac_mw,
        :min_cap_discharge_dc_mw,
        :max_cap_discharge_dc_mw,
        :inv_cost_inverter_per_mwyr,
        :fixed_om_inverter_cost_per_mwyr,
        :inv_cost_solar_per_mwyr,
        :fixed_om_solar_cost_per_mwyr,
        :inv_cost_wind_per_mwyr,
        :fixed_om_wind_cost_per_mwyr,
        :inv_cost_discharge_dc_per_mwyr,
        :fixed_om_cost_discharge_dc_per_mwyr,
        :inv_cost_charge_dc_per_mwyr,
        :fixed_om_cost_charge_dc_per_mwyr,
        :inv_cost_discharge_ac_per_mwyr,
        :fixed_om_cost_discharge_ac_per_mwyr,
        :inv_cost_charge_ac_per_mwyr,
        :fixed_om_cost_charge_ac_per_mwyr,
        :var_om_cost_per_mwh_solar,
        :var_om_cost_per_mwh_wind,
        :var_om_cost_per_mwh_charge_dc,
        :var_om_cost_per_mwh_discharge_dc,
        :var_om_cost_per_mwh_charge_ac,
        :var_om_cost_per_mwh_discharge_ac,
        :min_retired_cap_inverter_mw,
        :min_retired_cap_solar_mw,
        :min_retired_cap_wind_mw,
        :min_retired_cap_charge_dc_mw,
        :min_retired_cap_charge_ac_mw,
        :min_retired_cap_discharge_dc_mw,
        :min_retired_cap_discharge_ac_mw]
    scale_columns!(vre_stor_in, columns_to_scale, scale_factor)
    return nothing
end

"""
    scale_columns!(df::DataFrame, columns_to_scale::Vector{Symbol}, scale_factor::Float64)

Scales in-place the columns in `columns_to_scale` of a dataframe `df` by a `scale_factor`.

# Arguments
- `df` (DataFrame): A dataframe containing data to scale.
- `columns_to_scale` (Vector{Symbol}): A vector of column names to scale.
- `scale_factor` (Float64): A scaling factor for energy and currency units.

"""
function scale_columns!(df::DataFrame,
    columns_to_scale::Vector{Symbol},
    scale_factor::Float64)
    for column in columns_to_scale
        if string(column) in names(df)
            df[!, column] /= scale_factor
        end
    end
    return nothing
end

"""
    load_resource_df(path::AbstractString, scale_factor::Float64, resource_type::Type)

Function to load and scale the dataframe of a given resource.

# Arguments
- `path::AbstractString`: Path to the resource dataframe.
- `scale_factor::Float64`: Scaling factor for the resource data.
- `resource_type::Type`: GenX type of the resource.

# Returns
- `resource_in::DataFrame`: The loaded and scaled resource data.

"""
function load_resource_df(path::AbstractString, scale_factor::Float64, resource_type::Type)
    resource_in = load_dataframe(path)
    # rename columns lowercase for internal consistency
    rename!(resource_in, lowercase.(names(resource_in)))
    scale_resources_data!(resource_in, scale_factor)
    # scale vre_stor columns if necessary
    resource_type == VreStorage && scale_vre_stor_data!(resource_in, scale_factor)
    return resource_in
end

"""
    compute_resource_indices(resources_in::DataFrame, offset::Int64)

Computes the indices for the resources loaded from a single dataframe by shifting the indices by an offset value. 

# Arguments
- `resources_in::DataFrame`: The input DataFrame containing the resources.
- `offset::Int64`: The offset value to be added to the indices.

# Returns
- `UnitRange{Int64}`: An array of indices.

"""
function compute_resource_indices(resources_in::DataFrame, offset::Int64)
    range = (1, nrow(resources_in)) .+ offset
    return UnitRange{Int64}(range...)
end

"""
    add_id_to_resource_df!(df::DataFrame, indices::AbstractVector)

Adds a new column 'id' to the DataFrame with the provided resource indices. The dataframe is modified in-place.

# Arguments
- `df::DataFrame`: The input DataFrame to which the indices are to be added.
- `indices::AbstractVector`: The array of indices to be added as a new column.
"""
function add_id_to_resource_df!(df::DataFrame, indices::AbstractVector)
    df[!, :id] = indices
    return nothing
end

"""
    dataframerow_to_dict(dfr::DataFrameRow)

Converts a DataFrameRow to a Dict.

# Arguments
- `dfr::DataFrameRow`: The DataFrameRow to be converted.

# Returns
- `Dict`: Dictionary containing the DataFrameRow data.
"""
function dataframerow_to_dict(dfr::DataFrameRow)
    return Dict(pairs(dfr))
end

"""
    create_resources_sametype(resource_in::DataFrame, ResourceType)

This function takes a DataFrame `resource_in` and a GenX `ResourceType` type, and converts the DataFrame to an array of AbstractResource of the specified type.

# Arguments
- `resource_in::DataFrame`: The input DataFrame containing the resources belonging to a specific type.
- `ResourceType`: The GenX type of resources to be converted to.

# Returns
- `resources::Vector{ResourceType}`: An array of resources of the specified type.
"""
function create_resources_sametype(resource_in::DataFrame, ResourceType)
    # convert dataframe to array of resources of correct type
    resources::Vector{ResourceType} = ResourceType.(dataframerow_to_dict.(eachrow(resource_in)))
    return resources
end

"""
    create_resource_array(resource_folder::AbstractString, resources_info::NamedTuple, scale_factor::Float64=1.0)

Construct the array of resources from multiple files of different types located in the specified `resource_folder`. The `resources_info` NamedTuple contains the filename and GenX type for each type of resource available in GenX.

# Arguments
- `resource_folder::AbstractString`: The path to the folder containing the resource files.
- `resources_info::NamedTuple`: A NamedTuple that maps a resource type to its filename and GenX type.
- `scale_factor::Float64`: A scaling factor to adjust the attributes of the resources (default: 1.0).

# Returns
- `Vector{<:AbstractResource}`: An array of GenX resources.

# Raises
- `Error`: If no resources data is found. Check the data path or the configuration file "genx_settings.yml" inside Settings.

"""
function create_resource_array(resource_folder::AbstractString,
    resources_info::NamedTuple,
    scale_factor::Float64 = 1.0)
    resource_id_offset = 0
    resources = []
    # loop over available types and load all resources in resource_folder
    for (filename, resource_type) in values(resources_info)
        df_path = joinpath(resource_folder, filename)
        # if file exists, load resources of a single resource_type
        if isfile(df_path)
            resource_in = load_resource_df(df_path, scale_factor, resource_type)
            # compute indices for resources of a given type and add them to dataframe
            resources_indices = compute_resource_indices(resource_in, resource_id_offset)
            add_id_to_resource_df!(resource_in, resources_indices)
            resources_same_type = create_resources_sametype(resource_in, resource_type)
            push!(resources, resources_same_type)
            # update id offset for next type of resources
            resource_id_offset += length(resources_same_type)
            @info filename * " Successfully Read."
        end
    end
    isempty(resources) &&
        error("No resources data found. Check data path or configuration file \"genx_settings.yml\" inside Settings.")
    return reduce(vcat, resources)
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
        e = string("Resource ", resource_name(r), " is of MUST_RUN type but :Reg_Max = ",
            reg_max_r, ".\n",
            "MUST_RUN units must have Reg_Max = 0 since they cannot contribute to reserves.")
        push!(error_strings, e)
    end

    rsv_max_r = rsv_max(r)
    if rsv_max_r != 0
        e = string("Resource ", resource_name(r), " is of MUST_RUN type but :Rsv_Max = ",
            rsv_max_r, ".\n",
            "MUST_RUN units must have Rsv_Max = 0 since they cannot contribute to reserves.")
        push!(error_strings, e)
    end
    return ErrorMsg.(error_strings)
end

function check_LDS_applicability(r::AbstractResource)
    applicable_resources = Union{Storage, Hydro}
    error_strings = String[]

    not_set = default_zero
    lds_value = get(r, :lds, not_set)

    # LDS is available only for Hydro and Storage
    if !isa(r, applicable_resources) && lds_value > 0
        e = string("Resource ", resource_name(r), " has :lds = ", lds_value, ".\n",
            "This setting is valid only for resources where the type is one of $applicable_resources.")
        push!(error_strings, e)
    end
    return ErrorMsg.(error_strings)
end

function check_maintenance_applicability(r::AbstractResource)
    applicable_resources = Thermal

    not_set = default_zero
    maint_value = get(r, :maint, not_set)

    error_strings = String[]

    if maint_value == not_set
        # not MAINT so the rest is not applicable
        return error_strings
    end

    # MAINT is available only for Thermal
    if !isa(r, applicable_resources) && maint_value > 0
        e = string("Resource ", resource_name(r), " has :maint = ", maint_value, ".\n",
            "This setting is valid only for resources where the type is one of $applicable_resources.")
        push!(error_strings, e)
    end
    if get(r, :model, not_set) == 2
        e = string("Resource ", resource_name(r), " has :maint = ", maint_value, ".\n",
            "This is valid only for resources with unit commitment (:model = 1);\n",
            "this has :model = 2.")
        push!(error_strings, e)
    end
    return ErrorMsg.(error_strings)
end

function check_retrofit_resource(r::AbstractResource)
    error_strings = String[]

    # check that retrofit_id is set only for retrofitting units and not for new builds or units that can retire
    if can_retrofit(r) == true && can_retire(r) == false
        e = string("Resource ", resource_name(r), " has :can_retrofit = ", can_retrofit(r),
            " but :can_retire = ", can_retire(r), ".\n",
            "A unit that can be retrofitted must also be eligible for retirement (:can_retire = 1)")
        push!(error_strings, e)
    elseif is_retrofit_option(r) == true && new_build(r) == false
        e = string("Resource ", resource_name(r), " has :retrofit = ",
            is_retrofit_option(r), " but :new_build = ", new_build(r), ".\n",
            "This setting is valid only for resources that have :new_build = 1")
        push!(error_strings, e)
    end
    return ErrorMsg.(error_strings)
end

function check_resource(r::AbstractResource)
    e = []
    e = [e; check_LDS_applicability(r)]
    e = [e; check_maintenance_applicability(r)]
    e = [e; check_mustrun_reserve_contribution(r)]
    e = [e; check_retrofit_resource(r)]
    return e
end

function check_retrofit_id(rs::Vector{T}) where {T <: AbstractResource}
    warning_strings = String[]

    units_can_retrofit = ids_can_retrofit(rs)
    retrofit_options = ids_retrofit_options(rs)

    # check that all retrofit_ids for resources that can retrofit and retrofit options match
    if Set(rs[units_can_retrofit].retrofit_id) != Set(rs[retrofit_options].retrofit_id)
        msg = string("Retrofit IDs for resources that \"can retrofit\" and \"retrofit options\" do not match.\n" *
                     "All retrofitting units must be associated with a retrofit option.")
        push!(warning_strings, msg)
    end

    return WarnMsg.(warning_strings)
end

@doc raw"""
    check_resource(resources::Vector{T})::Vector{String} where T <: AbstractResource

Validate the consistency of a vector of GenX resources
Reports any errors/warnings as a vector of messages.
"""
function check_resource(resources::Vector{T}) where {T <: AbstractResource}
    e = []
    for r in resources
        e = [e; check_resource(r)]
    end
    e = [e; check_retrofit_id(resources)]
    return e
end

function halt_with_error_count(error_count::Int)
    s = string(error_count, " problems were detected with the input data. Halting.")
    error(s)
end

function announce_errors_and_halt(e::Vector)
    error_count = 0
    for log_message in e
        if isa(log_message, ErrorMsg)
            error_count += 1
            @error(log_message.msg)
        elseif isa(log_message, WarnMsg)
            @warn(log_message.msg)
        else
            @warn("Unknown log message type: ", log_message)
        end
    end
    error_count > 0 && halt_with_error_count(error_count)
    return nothing
end

function validate_resources(resources::Vector{T}) where {T <: AbstractResource}
    e = check_resource(resources)
    if length(e) > 0
        announce_errors_and_halt(e)
    end
end

"""
    create_resource_array(setup::Dict, resources_path::AbstractString)

Function that loads and scales resources data from folder specified in resources_path and returns an array of GenX resources.

# Arguments
- `setup (Dict)`: Dictionary containing GenX settings.
- `resources_path (AbstractString)`: The path to the resources folder.

# Returns
- `resources (Vector{<:AbstractResource})`: An array of scaled resources.

"""
function create_resource_array(setup::Dict, resources_path::AbstractString)
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1.0

    # get filename and GenX type for each type of resources available in GenX
    resources_info = _get_resource_info()

    # load each resource type, scale data and return array of resources
    resources = create_resource_array(resources_path, resources_info, scale_factor)
    # validate input before returning resources
    validate_resources(resources)
    return resources
end

"""
    validate_policy_files(resource_policies_path::AbstractString, setup::Dict)

Validate the policy files by checking if they exist in the specified folder and if the setup flags are consistent with the files found.

# Arguments
- `resource_policies_path::AbstractString`: The path to the policy files.
- `setup::Dict`: Dictionary containing GenX settings.

# Returns
- warning messages if the polcies are set to 1 in settings but the files are not found in the resource_policies_path.
!isfile(joinpath(resource_policies_path, filename))
"""
function validate_policy_files(resource_policies_path::AbstractString, setup::Dict)
    policyfile_info = _get_policyfile_info()
    for (filenames, setup_param) in values(policyfile_info)
        if setup[setup_param] == 1 &&
           any(!isfile(joinpath(resource_policies_path, filename)) for filename in filenames)
            msg = string(setup_param,
                " is set to 1 in settings but the required file(s) ",
                filenames,
                " was (were) not found in ",
                resource_policies_path)
            @warn(msg)
        end
    end
    return nothing
end

"""
    validate_policy_dataframe!(filename::AbstractString, policy_in::DataFrame)

Validate the policy dataframe by checking if it has any attributes and if the column names are valid. The dataframe is modified in-place.

# Arguments
- `filename::AbstractString`: The name of the policy file.
- `policy_in::DataFrame`: The policy dataframe.
"""
function validate_policy_dataframe!(filename::AbstractString, policy_in::DataFrame)
    cols = names(policy_in)
    n_cols = length(cols)
    # check if policy file has any attributes
    if n_cols == 1
        msg = "No policy attributes found in policy file: " * filename
        error(msg)
    end
    # if the single column attribute does not have a tag number, add a tag number of 1
    if n_cols == 2 && cols[2][(end - 1):end] != "_1"
        rename!(policy_in, Symbol.(cols[2]) => Symbol.(cols[2], "_1"))
    end
    # get policy column names
    cols = lowercase.(names(policy_in))
    filter!(col -> col ≠ "resource", cols)

    accepted_cols = ["derating_factor", "esr", "esr_vrestor",
        [string(cap, type) for cap in ["min_cap", "max_cap"]
         for type in ("", "_stor", "_solar", "_wind")]...]

    # Check that all policy columns have names in accepted_cols
    if !all(x -> replace(x, r"(_*|_*\d*)$" => "") in accepted_cols, cols)
        msg = "The accepted policy columns are: " * join(accepted_cols, ", ")
        msg *= "\nCheck policy file: " * filename
        error(msg)
    end
    # Check that all policy columns have names with format "[policy_name]_[tagnum]"
    if !all(any([occursin(Regex("$(y)") * r"_\d", col) for y in accepted_cols])
            for col in cols)
        msg = "Columns in policy file $filename must have names with format \"[policy_name]_[tagnum]\", case insensitive. (e.g., ESR_1, Min_Cap_1, Max_Cap_2, etc.)."
        error(msg)
    end
    return nothing
end

"""
    add_attributes_to_resource!(resource::AbstractResource, new_symbols::Vector{Symbol}, new_values::T) where T <: DataFrameRow

Adds a set of new attributes (names and corresponding values) to a resource. The resource is modified in-place.

# Arguments
- `resource::AbstractResource`: The resource to add attributes to.
- `new_symbols::Vector{Symbol}`: Vector of symbols containing the names of the new attributes.
- `new_values::DataFrameRow`: DataFrameRow containing the values of the new attributes.

"""
function add_attributes_to_resource!(resource::AbstractResource,
    new_symbols::Vector{Symbol},
    new_values::T) where {T <: DataFrameRow}
    # loop over new attributes
    for (sym, value) in zip(new_symbols, new_values)
        # add attribute to resource
        setproperty!(resource, sym, value)
    end
    return nothing
end

"""
    add_df_to_resources!(resources::Vector{<:AbstractResource}, module_in::DataFrame)

Adds the data contained in a `DataFrame` to a vector of resources. Each row in the `DataFrame` corresponds to a resource. If the name of the resource in the `DataFrame` matches a name of a resource in the model, all the columns of that DataFrameRow are added as new attributes to the corresponding resource. 

# Arguments
- `resources::Vector{<:AbstractResource}`: A vector of resources.
- `module_in::DataFrame`: The dataframe to add.
"""
function add_df_to_resources!(resources::Vector{<:AbstractResource}, module_in::DataFrame)
    # rename columns lowercase to ensure consistency with resources
    rename!(module_in, lowercase.(names(module_in)))
    # extract columns of module. They will be added as new attributes to resources
    new_sym = Symbol.(filter(x -> x ≠ "resource", names(module_in)))
    # loop oper rows of module and add new attributes to resources
    for row in eachrow(module_in)
        resource_name = row[:resource]
        resource = resource_by_name(resources, resource_name)
        new_values = row[new_sym]
        add_attributes_to_resource!(resource, new_sym, new_values)
    end
    return nothing
end

"""
    add_policy_to_resources!(resources::Vector{<:AbstractResource}, path::AbstractString, filename::AbstractString)

Loads a single policy file and adds the columns as new attributes to resources in the model if the resource name in the policy file matches a resource name in the model. The policy file is assumed to have a column named "resource" containing the resource names.

# Arguments
- `resources::Vector{<:AbstractResource}`: A vector of resources.
- `path::AbstractString`: The path to the policy file.
- `filename::AbstractString`: The name of the policy file.
"""
function add_policy_to_resources!(resources::Vector{<:AbstractResource},
    path::AbstractString,
    filename::AbstractString)
    policy_in = load_dataframe(path)
    # check if policy file has any attributes, validate column names 
    validate_policy_dataframe!(filename, policy_in)
    # add policy columns to resources as new attributes
    add_df_to_resources!(resources, policy_in)
    return nothing
end

"""
    add_policies_to_resources!(resources::Vector{<:AbstractResource}, resources_path::AbstractString)

Reads policy files and adds policies-related attributes to resources in the model.

# Arguments
- `resources::Vector{<:AbstractResource}`: Vector of resources in the model.
- `resources_path::AbstractString`: The path to the resources folder.
"""
function add_policies_to_resources!(resources::Vector{<:AbstractResource},
    resource_policy_path::AbstractString)
    # get filename for each type of policy available in GenX
    policies_info = _get_policyfile_info()
    # loop over policy files
    for (filenames, _) in values(policies_info)
        for filename in filenames
            path = joinpath(resource_policy_path, filename)
            # if file exists, add policy to resources
            if isfile(path)
                add_policy_to_resources!(resources, path, filename)
                @info filename * " Successfully Read."
            end
        end
    end
    return nothing
end

"""
    add_module_to_resources!(resources::Vector{<:AbstractResource}, module_in::DataFrame)

Reads module dataframe and adds columns as new attributes to the resources in the model if the resource name in the module file matches a resource name in the model. The module file is assumed to have a column named "resource" containing the resource names.

# Arguments
- `resources::Vector{<:AbstractResource}`: A vector of resources.
- `module_in::DataFrame`: The dataframe with the columns to add to the resources.
"""
function add_module_to_resources!(resources::Vector{<:AbstractResource},
    module_in::DataFrame)
    # add module columns to resources as new attributes
    add_df_to_resources!(resources, module_in)
    return nothing
end

"""
    add_modules_to_resources!(resources::Vector{<:AbstractResource}, setup::Dict, resources_path::AbstractString)

Reads module dataframes, loops over files and adds columns as new attributes to the resources in the model.

# Arguments
- `resources::Vector{<:AbstractResource}`: A vector of resources.
- `setup (Dict)`: A dictionary containing GenX settings.
- `resources_path::AbstractString`: The path to the resources folder.
"""
function add_modules_to_resources!(resources::Vector{<:AbstractResource},
    setup::Dict,
    resources_path::AbstractString)
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1.0

    modules = Vector{DataFrame}()

    ## Load all modules and add them to the list of modules to be added to resources
    # Add multistage if multistage is activated
    if setup["MultiStage"] == 1
        filename = joinpath(resources_path, "Resource_multistage_data.csv")
        multistage_in = load_multistage_dataframe(filename, scale_factor)
        push!(modules, multistage_in)
        @info "Multistage data successfully read."
    end

    ## Loop over modules and add attributes to resources
    add_module_to_resources!.(Ref(resources), modules)

    return nothing
end

function validate_piecewisefuelusage(heat_rate_mat, load_point_mat)
    # it's possible to construct piecewise fuel consumption with n of heat rate and n-1 of load point. 
    # if a user feed n of heat rate and more than n of load point, throw a error message, and then use 
    # n of heat rate and n-1 load point to construct the piecewise fuel usage fuction  
    if size(heat_rate_mat)[2] < size(load_point_mat)[2]
        @error """ The numbers of heatrate data are less than load points, we found $(size(heat_rate_mat)[2]) of heat rate,
        and $(size(load_point_mat)[2]) of load points. We will just use $(size(heat_rate_mat)[2]) of heat rate, and $(size(heat_rate_mat)[2]-1)
        load point to create piecewise fuel usage
        """
    end

    # check if values for piecewise fuel consumption make sense. Negative heat rate or load point are not allowed
    if any(heat_rate_mat .< 0) | any(load_point_mat .< 0)
        @error """ Neither heat rate nor load point can be negative
        """
        error("Invalid inputs detected for piecewise fuel usage")
    end
    # for non-zero values, heat rates and load points should follow an increasing trend 
    if any([any(diff(filter(!=(0), row)) .< 0) for row in eachrow(heat_rate_mat)])
        @error """ Heat rates should follow an increasing trend
        """
        error("Invalid inputs detected for piecewise fuel usage")
    elseif any([any(diff(filter(!=(0), row)) .< 0) for row in eachrow(load_point_mat)])
        @error """load points should follow an increasing trend
        """
        error("Invalid inputs detected for piecewise fuel usage")
    end
end

"""
	process_piecewisefuelusage!(setup::Dict, case_path::AbstractString, gen::Vector{<:AbstractResource}, inputs::Dict)

Reads piecewise fuel usage data from the vector of generators, create a PWFU_data that contain processed intercept and slope (i.e., heat rate) and add them to the inputs dictionary. 

# Arguments
- `setup::Dict`: The dictionary containing the setup parameters
- `case_path::AbstractString`: The path to the case folder
- `gen::Vector{<:AbstractResource}`: The vector of generators in the model
- `inputs::Dict`: The dictionary containing the input data
"""
function process_piecewisefuelusage!(setup::Dict,
    gen::Vector{<:AbstractResource},
    inputs::Dict)
    inputs["PWFU_Num_Segments"] = 0
    inputs["THERM_COMMIT_PWFU"] = Int64[]

    if any(haskey.(gen, :pwfu_fuel_usage_zero_load_mmbtu_per_h))
        thermal_gen = gen.Thermal
        has_pwfu = haskey.(thermal_gen, :pwfu_fuel_usage_zero_load_mmbtu_per_h)
        @assert all(has_pwfu) "Piecewise fuel usage data is not consistent across thermal generators"

        heat_rate_mat_therm = extract_matrix_from_resources(thermal_gen,
            "pwfu_heat_rate_mmbtu_per_mwh")
        load_point_mat_therm = extract_matrix_from_resources(thermal_gen,
            "pwfu_load_point_mw")

        num_segments = size(heat_rate_mat_therm)[2]

        # create a matrix to store the heat rate and load point for each generator in the model 
        heat_rate_mat = zeros(length(gen), num_segments)
        load_point_mat = zeros(length(gen), num_segments)
        THERM = thermal(gen)
        heat_rate_mat[THERM, :] = heat_rate_mat_therm
        load_point_mat[THERM, :] = load_point_mat_therm

        # check data input 
        validate_piecewisefuelusage(heat_rate_mat, load_point_mat)

        # determine if a generator contains piecewise fuel usage segment based on non-zero heatrate
        nonzero_rows = any(heat_rate_mat .!= 0, dims = 2)[:]
        HAS_PWFU = resource_id.(gen[nonzero_rows])

        # translate the inital fuel usage, heat rate, and load points into intercept for each segment
        fuel_usage_zero_load = zeros(length(gen))
        fuel_usage_zero_load[THERM] = pwfu_fuel_usage_zero_load_mmbtu_per_h.(thermal_gen)
        # construct a matrix for intercept
        intercept_mat = zeros(size(heat_rate_mat))
        # PWFU_Fuel_Usage_MMBTU_per_h is always the intercept of the first segment
        intercept_mat[:, 1] = fuel_usage_zero_load

        # create a function to compute intercept if we have more than one segment
        function calculate_intercepts(slope, intercept_1, load_point)
            m, n = size(slope)
            # Initialize the intercepts matrix with zeros
            intercepts = zeros(m, n)
            # The first segment's intercepts should be intercept_1 vector
            intercepts[:, 1] = intercept_1
            # Calculate intercepts for the other segments using the load points (i.e., intersection points)
            for j in 1:(n - 1)
                for i in 1:m
                    current_slope = slope[i, j + 1]
                    previous_slope = slope[i, j]
                    # If the current slope is 0, then skip the calculation and return 0
                    if current_slope == 0
                        intercepts[i, j + 1] = 0.0
                    else
                        # y = a*x + b; => b = y - ax
                        # Calculate y-coordinate of the intersection
                        y = previous_slope * load_point[i, j] + intercepts[i, j]
                        # determine the new intercept
                        b = y - current_slope * load_point[i, j]
                        intercepts[i, j + 1] = b
                    end
                end
            end
            return intercepts
        end

        if num_segments > 1
            # determine the intercept for the rest of segment if num_segments > 1
            intercept_mat = calculate_intercepts(heat_rate_mat,
                fuel_usage_zero_load,
                load_point_mat)
        end

        # create a PWFU_data that contain processed intercept and slope (i.e., heat rate)
        intercept_cols = [Symbol("pwfu_intercept_", i) for i in 1:num_segments]
        intercept_df = DataFrame(intercept_mat, Symbol.(intercept_cols))
        slope_cols = Symbol.(filter(colname -> startswith(string(colname),
                "pwfu_heat_rate_mmbtu_per_mwh"),
            collect(attributes(thermal_gen[1]))))
        sort!(slope_cols, by = x -> parse(Int, split(string(x), "_")[end]))
        slope_df = DataFrame(heat_rate_mat, Symbol.(slope_cols))
        PWFU_data = hcat(slope_df, intercept_df)
        # no need to scale sclope, but intercept should be scaled when parameterscale is on (MMBTU -> billion BTU)
        scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
        PWFU_data[!, intercept_cols] ./= scale_factor

        inputs["slope_cols"] = slope_cols
        inputs["intercept_cols"] = intercept_cols
        inputs["PWFU_data"] = PWFU_data
        inputs["PWFU_Num_Segments"] = num_segments
        inputs["THERM_COMMIT_PWFU"] = intersect(ids_with_unit_commitment(gen), HAS_PWFU)

        @info "Piecewise fuel usage data successfully read!"
    end
    return nothing
end

@doc raw"""
    split_storage_resources!(inputs::Dict, gen::Vector{<:AbstractResource})

For co-located VRE-storage resources, this function returns the storage type 
	(1. long-duration or short-duration storage, 2. symmetric or asymmetric storage)
    for charging and discharging capacities
"""
function split_storage_resources!(inputs::Dict, gen::Vector{<:AbstractResource})

    # All Storage Resources
    inputs["VS_STOR"] = union(storage_dc_charge(gen), storage_dc_discharge(gen),
        storage_ac_charge(gen), storage_ac_discharge(gen))

    STOR = inputs["VS_STOR"]

    # Storage DC Discharge Resources
    inputs["VS_STOR_DC_DISCHARGE"] = storage_dc_discharge(gen)
    inputs["VS_SYM_DC_DISCHARGE"] = storage_sym_dc_discharge(gen)
    inputs["VS_ASYM_DC_DISCHARGE"] = storage_asym_dc_discharge(gen)

    # Storage DC Charge Resources
    inputs["VS_STOR_DC_CHARGE"] = storage_dc_charge(gen)
    inputs["VS_SYM_DC_CHARGE"] = storage_sym_dc_charge(gen)
    inputs["VS_ASYM_DC_CHARGE"] = storage_asym_dc_charge(gen)

    # Storage AC Discharge Resources
    inputs["VS_STOR_AC_DISCHARGE"] = storage_ac_discharge(gen)
    inputs["VS_SYM_AC_DISCHARGE"] = storage_sym_ac_discharge(gen)
    inputs["VS_ASYM_AC_DISCHARGE"] = storage_asym_ac_discharge(gen)

    # Storage AC Charge Resources
    inputs["VS_STOR_AC_CHARGE"] = storage_ac_charge(gen)
    inputs["VS_SYM_AC_CHARGE"] = storage_sym_ac_charge(gen)
    inputs["VS_ASYM_AC_CHARGE"] = storage_asym_ac_charge(gen)

    # Storage LDS & Non-LDS Resources
    inputs["VS_LDS"] = is_LDS_VRE_STOR(gen)
    inputs["VS_nonLDS"] = setdiff(STOR, inputs["VS_LDS"])

    # Symmetric and asymmetric storage resources
    inputs["VS_ASYM"] = union(inputs["VS_ASYM_DC_CHARGE"], inputs["VS_ASYM_DC_DISCHARGE"],
        inputs["VS_ASYM_AC_DISCHARGE"], inputs["VS_ASYM_AC_CHARGE"])
    inputs["VS_SYM_DC"] = intersect(inputs["VS_SYM_DC_CHARGE"],
        inputs["VS_SYM_DC_DISCHARGE"])
    inputs["VS_SYM_AC"] = intersect(inputs["VS_SYM_AC_CHARGE"],
        inputs["VS_SYM_AC_DISCHARGE"])

    # Send warnings for symmetric/asymmetric resources
    if (!isempty(setdiff(inputs["VS_SYM_DC_DISCHARGE"], inputs["VS_SYM_DC_CHARGE"]))
        || !isempty(setdiff(inputs["VS_SYM_DC_CHARGE"], inputs["VS_SYM_DC_DISCHARGE"]))
        || !isempty(setdiff(inputs["VS_SYM_AC_DISCHARGE"], inputs["VS_SYM_AC_CHARGE"]))
        || !isempty(setdiff(inputs["VS_SYM_AC_CHARGE"], inputs["VS_SYM_AC_DISCHARGE"])))
        @warn("Symmetric capacities must both be DC or AC.")
    end

    # Send warnings for battery resources discharging
    if !isempty(intersect(inputs["VS_STOR_DC_DISCHARGE"], inputs["VS_STOR_AC_DISCHARGE"]))
        @warn("Both AC and DC discharging functionalities are turned on.")
    end

    # Send warnings for battery resources charging
    if !isempty(intersect(inputs["VS_STOR_DC_CHARGE"], inputs["VS_STOR_AC_CHARGE"]))
        @warn("Both AC and DC charging functionalities are turned on.")
    end
end

"""
    update_retrofit_id(r::AbstractResource)

Updates the retrofit_id of a resource that can be retrofit or is a retrofit option by appending the region to the retrofit_id.

# Arguments
- `r::AbstractResource`: The resource to update.
"""
function update_retrofit_id(r::AbstractResource)
    if haskey(r, :retrofit_id) && (can_retrofit(r) == true || is_retrofit_option(r) == true)
        r.retrofit_id = string(r.retrofit_id, "_", region(r))
    else
        r.retrofit_id = string("None")
    end
end

"""
    add_resources_to_input_data!(inputs::Dict, setup::Dict, case_path::AbstractString, gen::Vector{<:AbstractResource})

Adds resources to the `inputs` `Dict` with the key "RESOURCES" together with sevaral sets of resource indices that are used inside GenX to construct the optimization problem. The `inputs` `Dict` is modified in-place.

# Arguments
- `inputs (Dict)`: Dictionary to store the GenX input data.
- `setup (Dict)`: Dictionary containing GenX settings.
- `case_path (AbstractString)`: Path to the case.
- `gen (Vector{<:AbstractResource})`: Array of GenX resources.

"""
function add_resources_to_input_data!(inputs::Dict,
    setup::Dict,
    case_path::AbstractString,
    gen::Vector{<:AbstractResource})

    # Number of resources
    G = length(gen)
    inputs["G"] = G

    # Number of time steps (periods)
    T = inputs["T"]

    ## HYDRO
    # Set of all reservoir hydro resources
    inputs["HYDRO_RES"] = hydro(gen)
    # Set of hydro resources modeled with known reservoir energy capacity
    if !isempty(inputs["HYDRO_RES"])
        inputs["HYDRO_RES_KNOWN_CAP"] = intersect(inputs["HYDRO_RES"],
            ids_with_positive(gen, hydro_energy_to_power_ratio))
    end

    ## STORAGE
    # Set of storage resources with symmetric charge/discharge capacity
    inputs["STOR_SYMMETRIC"] = symmetric_storage(gen)
    # Set of storage resources with asymmetric (separte) charge/discharge capacity components
    inputs["STOR_ASYMMETRIC"] = asymmetric_storage(gen)
    # Set of all storage resources
    inputs["STOR_ALL"] = union(inputs["STOR_SYMMETRIC"], inputs["STOR_ASYMMETRIC"])

    # Set of storage resources with long duration storage capabilitites
    inputs["STOR_HYDRO_LONG_DURATION"] = intersect(inputs["HYDRO_RES"], is_LDS(gen))
    inputs["STOR_HYDRO_SHORT_DURATION"] = intersect(inputs["HYDRO_RES"], is_SDS(gen))
    inputs["STOR_LONG_DURATION"] = intersect(inputs["STOR_ALL"], is_LDS(gen))
    inputs["STOR_SHORT_DURATION"] = intersect(inputs["STOR_ALL"], is_SDS(gen))

    ## VRE
    # Set of controllable variable renewable resources
    inputs["VRE"] = vre(gen)

    ## FLEX
    # Set of flexible demand-side resources
    inputs["FLEX"] = flex_demand(gen)

    ## MUST_RUN
    # Set of must-run plants - could be behind-the-meter PV, hydro run-of-river, must-run fossil or thermal plants
    inputs["MUST_RUN"] = must_run(gen)

    ## ELECTROLYZER
    # Set of hydrogen electolyzer resources:
    inputs["ELECTROLYZER"] = electrolyzer(gen)

    ## Operational Reserves
    if setup["OperationalReserves"] >= 1
        # Set for resources with regulation reserve requirements
        inputs["REG"] = ids_with_regulation_reserve_requirements(gen)
        # Set for resources with spinning reserve requirements
        inputs["RSV"] = ids_with_spinning_reserve_requirements(gen)
    end

    ## THERM
    # Set of all thermal resources
    inputs["THERM_ALL"] = thermal(gen)
    # Unit commitment
    if setup["UCommit"] >= 1
        # Set of thermal resources with unit commitment
        inputs["THERM_COMMIT"] = ids_with_unit_commitment(gen)
        # Set of thermal resources without unit commitment
        inputs["THERM_NO_COMMIT"] = no_unit_commitment(gen)
        # Start-up cost is sum of fixed cost per start startup
        inputs["C_Start"] = zeros(Float64, G, T)
        for g in inputs["THERM_COMMIT"]
            start_up_cost = start_cost_per_mw(gen[g]) * cap_size(gen[g])
            inputs["C_Start"][g, :] .= start_up_cost
        end
        # Piecewise fuel usage option
        process_piecewisefuelusage!(setup, gen, inputs)
    else
        # Set of thermal resources with unit commitment
        inputs["THERM_COMMIT"] = []
        # Set of thermal resources without unit commitment
        inputs["THERM_NO_COMMIT"] = inputs["THERM_ALL"]
    end
    # For now, the only resources eligible for UC are themal resources
    inputs["COMMIT"] = inputs["THERM_COMMIT"]

    # Set of CCS resources (optional set):
    inputs["CCS"] = ids_with_positive(gen, co2_capture_fraction)

    # Single-fuel resources
    inputs["SINGLE_FUEL"] = ids_with_singlefuel(gen)
    # Multi-fuel resources
    inputs["MULTI_FUELS"] = ids_with_multifuels(gen)
    if !isempty(inputs["MULTI_FUELS"]) # If there are any resources using multi fuels, read relevant data
        load_multi_fuels_data!(inputs, gen, setup, case_path)
    end

    buildable = is_buildable(gen)
    retirable = is_retirable(gen)
    units_can_retrofit = ids_can_retrofit(gen)

    # Set of all resources eligible for new capacity
    inputs["NEW_CAP"] = intersect(buildable, ids_with(gen, max_cap_mw))
    # Set of all resources eligible for capacity retirements
    inputs["RET_CAP"] = intersect(retirable, ids_with_nonneg(gen, existing_cap_mw))
    # Set of all resources eligible for capacity retrofitting (by Yifu, same with retirement)
    inputs["RETROFIT_CAP"] = intersect(units_can_retrofit,
        ids_with_nonneg(gen, existing_cap_mw))
    inputs["RETROFIT_OPTIONS"] = ids_retrofit_options(gen)

    # Retrofit
    # append region name to the retrofit_id if it is not None
    update_retrofit_id.(gen)
    # store a unique set of retrofit_ids
    inputs["RETROFIT_IDS"] = Set(retrofit_id.(gen[inputs["RETROFIT_CAP"]]))
    if (!isempty(inputs["RETROFIT_CAP"]) || !isempty(inputs["RETROFIT_OPTIONS"]))
        # min retired capacity constraint for retrofitting units is only applicable if retrofit options
        # in the same cluster either all have Contribute_Min_Retirement set to 1 or none of them do
        if setup["MultiStage"] == 1
            for retrofit_res in inputs["RETROFIT_CAP"]
                if !has_all_options_contributing(gen[retrofit_res], gen) &&
                   !has_all_options_not_contributing(gen[retrofit_res], gen)
                    msg = "Retrofit options in the same cluster either all have Contribute_Min_Retirement set to 1 or none of them do. \n" *
                          "Check column Contribute_Min_Retirement in the \"Resource_multistage_data.csv\" file for resource $(resource_name(gen[retrofit_res]))."
                    @error msg
                    error("Invalid input detected for Contribute_Min_Retirement.")
                end
                if has_all_options_not_contributing(gen[retrofit_res], gen) &&
                   setup["MultiStageSettingsDict"]["Myopic"] == 1
                    @error "When performing myopic multistage expansion all retrofit options need to have Contribute_Min_Retirement set to 1 to avoid model infeasibilities."
                    error("Invalid input detected for Contribute_Min_Retirement.")
                end
            end
        end
    end

    new_cap_energy = Set{Int64}()
    ret_cap_energy = Set{Int64}()
    if !isempty(inputs["STOR_ALL"])
        # Set of all storage resources eligible for new energy capacity
        new_cap_energy = intersect(buildable,
            ids_with(gen, max_cap_mwh),
            inputs["STOR_ALL"])
        # Set of all storage resources eligible for energy capacity retirements
        ret_cap_energy = intersect(retirable,
            ids_with_nonneg(gen, existing_cap_mwh),
            inputs["STOR_ALL"])
    end
    inputs["NEW_CAP_ENERGY"] = new_cap_energy
    inputs["RET_CAP_ENERGY"] = ret_cap_energy

    new_cap_charge = Set{Int64}()
    ret_cap_charge = Set{Int64}()
    if !isempty(inputs["STOR_ASYMMETRIC"])
        # Set of asymmetric charge/discharge storage resources eligible for new charge capacity
        new_cap_charge = intersect(buildable,
            ids_with(gen, max_charge_cap_mw),
            inputs["STOR_ASYMMETRIC"])
        # Set of asymmetric charge/discharge storage resources eligible for charge capacity retirements
        ret_cap_charge = intersect(retirable,
            ids_with_nonneg(gen, existing_charge_cap_mw),
            inputs["STOR_ASYMMETRIC"])
    end
    inputs["NEW_CAP_CHARGE"] = new_cap_charge
    inputs["RET_CAP_CHARGE"] = ret_cap_charge

    ## Co-located resources
    # VRE and storage
    inputs["VRE_STOR"] = vre_stor(gen)
    # Check if VRE-STOR resources exist
    if !isempty(inputs["VRE_STOR"])
        # Solar PV Resources
        inputs["VS_SOLAR"] = solar(gen)

        # DC Resources
        inputs["VS_DC"] = union(storage_dc_discharge(gen),
            storage_dc_charge(gen),
            solar(gen))

        # Wind Resources
        inputs["VS_WIND"] = wind(gen)

        # Storage Resources
        split_storage_resources!(inputs, gen)

        gen_VRE_STOR = gen.VreStorage
        # Set of all VRE-STOR resources eligible for new solar capacity
        inputs["NEW_CAP_SOLAR"] = intersect(buildable,
            solar(gen),
            ids_with(gen_VRE_STOR, max_cap_solar_mw))
        # Set of all VRE_STOR resources eligible for solar capacity retirements
        inputs["RET_CAP_SOLAR"] = intersect(retirable,
            solar(gen),
            ids_with_nonneg(gen_VRE_STOR, existing_cap_solar_mw))
        # Set of all VRE-STOR resources eligible for new wind capacity
        inputs["NEW_CAP_WIND"] = intersect(buildable,
            wind(gen),
            ids_with(gen_VRE_STOR, max_cap_wind_mw))
        # Set of all VRE_STOR resources eligible for wind capacity retirements
        inputs["RET_CAP_WIND"] = intersect(retirable,
            wind(gen),
            ids_with_nonneg(gen_VRE_STOR, existing_cap_wind_mw))
        # Set of all VRE-STOR resources eligible for new inverter capacity
        inputs["NEW_CAP_DC"] = intersect(buildable,
            ids_with(gen_VRE_STOR, max_cap_inverter_mw),
            inputs["VS_DC"])
        # Set of all VRE_STOR resources eligible for inverter capacity retirements
        inputs["RET_CAP_DC"] = intersect(retirable,
            ids_with_nonneg(gen_VRE_STOR, existing_cap_inverter_mw),
            inputs["VS_DC"])
        # Set of all storage resources eligible for new energy capacity
        inputs["NEW_CAP_STOR"] = intersect(buildable,
            ids_with(gen_VRE_STOR, max_cap_mwh),
            inputs["VS_STOR"])
        # Set of all storage resources eligible for energy capacity retirements
        inputs["RET_CAP_STOR"] = intersect(retirable,
            ids_with_nonneg(gen_VRE_STOR, existing_cap_mwh),
            inputs["VS_STOR"])
        if !isempty(inputs["VS_ASYM"])
            # Set of asymmetric charge DC storage resources eligible for new charge capacity
            inputs["NEW_CAP_CHARGE_DC"] = intersect(buildable,
                ids_with(gen_VRE_STOR, max_cap_charge_dc_mw),
                inputs["VS_ASYM_DC_CHARGE"])
            # Set of asymmetric charge DC storage resources eligible for charge capacity retirements
            inputs["RET_CAP_CHARGE_DC"] = intersect(retirable,
                ids_with_nonneg(gen_VRE_STOR, existing_cap_charge_dc_mw),
                inputs["VS_ASYM_DC_CHARGE"])
            # Set of asymmetric discharge DC storage resources eligible for new discharge capacity
            inputs["NEW_CAP_DISCHARGE_DC"] = intersect(buildable,
                ids_with(gen_VRE_STOR, max_cap_discharge_dc_mw),
                inputs["VS_ASYM_DC_DISCHARGE"])
            # Set of asymmetric discharge DC storage resources eligible for discharge capacity retirements
            inputs["RET_CAP_DISCHARGE_DC"] = intersect(retirable,
                ids_with_nonneg(gen_VRE_STOR, existing_cap_discharge_dc_mw),
                inputs["VS_ASYM_DC_DISCHARGE"])
            # Set of asymmetric charge AC storage resources eligible for new charge capacity
            inputs["NEW_CAP_CHARGE_AC"] = intersect(buildable,
                ids_with(gen_VRE_STOR, max_cap_charge_ac_mw),
                inputs["VS_ASYM_AC_CHARGE"])
            # Set of asymmetric charge AC storage resources eligible for charge capacity retirements
            inputs["RET_CAP_CHARGE_AC"] = intersect(retirable,
                ids_with_nonneg(gen_VRE_STOR, existing_cap_charge_ac_mw),
                inputs["VS_ASYM_AC_CHARGE"])
            # Set of asymmetric discharge AC storage resources eligible for new discharge capacity
            inputs["NEW_CAP_DISCHARGE_AC"] = intersect(buildable,
                ids_with(gen_VRE_STOR, max_cap_discharge_ac_mw),
                inputs["VS_ASYM_AC_DISCHARGE"])
            # Set of asymmetric discharge AC storage resources eligible for discharge capacity retirements
            inputs["RET_CAP_DISCHARGE_AC"] = intersect(retirable,
                ids_with_nonneg(gen_VRE_STOR, existing_cap_discharge_ac_mw),
                inputs["VS_ASYM_AC_DISCHARGE"])
        end

        # Names for systemwide resources
        inputs["RESOURCE_NAMES_VRE_STOR"] = resource_name(gen_VRE_STOR)

        # Names for writing outputs
        inputs["RESOURCE_NAMES_SOLAR"] = resource_name(gen[inputs["VS_SOLAR"]])
        inputs["RESOURCE_NAMES_WIND"] = resource_name(gen[inputs["VS_WIND"]])
        inputs["RESOURCE_NAMES_DC_DISCHARGE"] = resource_name(gen[storage_dc_discharge(gen)])
        inputs["RESOURCE_NAMES_AC_DISCHARGE"] = resource_name(gen[storage_ac_discharge(gen)])
        inputs["RESOURCE_NAMES_DC_CHARGE"] = resource_name(gen[storage_dc_charge(gen)])
        inputs["RESOURCE_NAMES_AC_CHARGE"] = resource_name(gen[storage_ac_charge(gen)])

        inputs["ZONES_SOLAR"] = zone_id(gen[inputs["VS_SOLAR"]])
        inputs["ZONES_WIND"] = zone_id(gen[inputs["VS_WIND"]])
        inputs["ZONES_DC_DISCHARGE"] = zone_id(gen[storage_dc_discharge(gen)])
        inputs["ZONES_AC_DISCHARGE"] = zone_id(gen[storage_ac_discharge(gen)])
        inputs["ZONES_DC_CHARGE"] = zone_id(gen[storage_dc_charge(gen)])
        inputs["ZONES_AC_CHARGE"] = zone_id(gen[storage_ac_charge(gen)])
    end

    # Names of resources
    inputs["RESOURCE_NAMES"] = resource_name(gen)

    # Zones resources are located in
    zones = zone_id(gen)

    # Resource identifiers by zone (just zones in resource order + resource and zone concatenated)
    inputs["R_ZONES"] = zones
    inputs["RESOURCE_ZONES"] = inputs["RESOURCE_NAMES"] .* "_z" .* string.(zones)

    # Fuel
    inputs["HAS_FUEL"] = ids_with_fuel(gen)
    if !isempty(inputs["MULTI_FUELS"])
        inputs["HAS_FUEL"] = union(inputs["HAS_FUEL"], inputs["MULTI_FUELS"])
        sort!(inputs["HAS_FUEL"])
    end

    inputs["RESOURCES"] = gen
    return nothing
end

"""
    summary(rs::Vector{<:AbstractResource})

Prints a summary of the resources loaded into the model.

# Arguments
- `rs (Vector{<:AbstractResource})`: An array of GenX resources.
"""
function summary(rs::Vector{<:AbstractResource})
    rs_summary_names = _get_summary_map()
    line_width = 55
    println("\nSummary of resources loaded into the model:")
    println(repeat("-", line_width))
    println("\tResource type \t\tNumber of resources")
    println(repeat("=", line_width))
    for r_type in resource_types
        num_rs = length(rs[nameof.(typeof.(rs)) .== r_type])
        if num_rs > 0
            r_type ∉ keys(rs_summary_names) &&
                error("Resource type $r_type not found in summary map. Please add it to the map.")
            println("\t", rs_summary_names[r_type], "\t\t", num_rs)
        end
    end
    println(repeat("=", line_width))
    println("Total number of resources: ", length(rs))
    println(repeat("-", line_width))
    return nothing
end

"""
    load_resources_data!(inputs::Dict, setup::Dict, case_path::AbstractString, resources_path::AbstractString)

This function loads resources data from the resources_path folder and create the GenX data structures and add them to the `inputs` `Dict`. 

# Arguments
- `inputs (Dict)`: A dictionary to store the input data.
- `setup (Dict)`: A dictionary containing GenX settings.
- `case_path (AbstractString)`: The path to the case folder.
- `resources_path (AbstractString)`: The path to the case resources folder.

Raises:
    DeprecationWarning: If the `Generators_data.csv` file is found, a deprecation warning is issued, together with an error message.
"""
function load_resources_data!(inputs::Dict,
    setup::Dict,
    case_path::AbstractString,
    resources_path::AbstractString)
    if isfile(joinpath(case_path, "Generators_data.csv"))
        msg = "The `Generators_data.csv` file was deprecated in release v0.4. " *
              "Please use the new interface for generators creation, and see the documentation for additional details."
        Base.depwarn(msg, :load_resources_data!, force = true)
        error("Exiting GenX...")
    end
    # create vector of resources from dataframes
    resources = create_resource_array(setup, resources_path)

    # read policy files and add policies-related attributes to resource dataframe
    resource_policies_path = joinpath(resources_path, setup["ResourcePoliciesFolder"])
    validate_policy_files(resource_policies_path, setup)
    add_policies_to_resources!(resources, resource_policies_path)

    # read module files add module-related attributes to resource dataframe
    add_modules_to_resources!(resources, setup, resources_path)

    # add resources information to inputs dict
    add_resources_to_input_data!(inputs, setup, case_path, resources)

    # print summary of resources
    summary(resources)

    return nothing
end

@doc raw"""
	load_multi_fuels_data!(inputs::Dict, gen::Vector{<:AbstractResource}, setup::Dict, path::AbstractString)

Function for reading input parameters related to multi fuels
"""
function load_multi_fuels_data!(inputs::Dict,
    gen::Vector{<:AbstractResource},
    setup::Dict,
    path::AbstractString)
    inputs["NUM_FUELS"] = num_fuels.(gen)   # Number of fuels that this resource can use
    max_fuels = maximum(inputs["NUM_FUELS"])
    inputs["FUEL_COLS"] = [Symbol(string("Fuel", f)) for f in 1:max_fuels]
    fuel_types = [fuel_cols.(gen, tag = f) for f in 1:max_fuels]
    heat_rates = [heat_rate_cols.(gen, tag = f) for f in 1:max_fuels]
    max_cofire = [max_cofire_cols.(gen, tag = f) for f in 1:max_fuels]
    min_cofire = [min_cofire_cols.(gen, tag = f) for f in 1:max_fuels]
    max_cofire_start = [max_cofire_start_cols.(gen, tag = f) for f in 1:max_fuels]
    min_cofire_start = [min_cofire_start_cols.(gen, tag = f) for f in 1:max_fuels]
    inputs["HEAT_RATES"] = heat_rates
    inputs["MAX_COFIRE"] = max_cofire
    inputs["MIN_COFIRE"] = min_cofire
    inputs["MAX_COFIRE_START"] = max_cofire_start
    inputs["MIN_COFIRE_START"] = min_cofire_start
    inputs["FUEL_TYPES"] = fuel_types
    inputs["MAX_NUM_FUELS"] = max_fuels
    inputs["MAX_NUM_FUELS"] = max_fuels

    # check whether non-zero heat rates are used for resources that only use a single fuel
    for f in 1:max_fuels
        for hr in heat_rates[f][inputs["SINGLE_FUEL"]]
            if hr > 0
                error("Heat rates for multi fuels must be zero when only one fuel is used")
            end
        end
    end
    # do not allow the multi-fuel option when piece-wise heat rates are used
    if haskey(inputs, "THERM_COMMIT_PWFU") && !isempty(inputs["THERM_COMMIT_PWFU"])
        error("Multi-fuel option is not available when piece-wise heat rates are used. Please remove multi fuels to avoid this error.")
    end
end
