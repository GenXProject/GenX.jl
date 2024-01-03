function _get_resource_info()
    resources = (
        hydro   = (filename="hydro.csv", type=HYDRO),
        thermal = (filename="thermal.csv", type=THERM),
        vre     = (filename="vre.csv", type=VRE),
        storage = (filename="storage.csv", type=STOR),
        flex_demand  = (filename="flex_demand.csv", type=FLEX),
        must_run = (filename="must_run.csv", type=MUST_RUN),
        electrolyzer = (filename="electrolyzer.csv", type=ELECTROLYZER)
    )
    return resources
end

function _get_policyfile_info()
    policies = (
        esr     = (filename="esr.csv", column_name="esr"),
        cap_res = (filename="cap_res.csv", column_name="derated_capacity"),
        min_cap_tags = (filename="min_cap.csv", column_name="min_cap"),
        max_cap_tags = (filename="max_cap.csv", column_name="max_cap")
    )
    return policies
end

function scale_resources_data!(resource_in::DataFrame, scale_factor::Float64)
    # See documentation for descriptions of each column
    # Generally, these scalings converts energy and power units from MW to GW
    # and $/MW to $M/GW. Both are done by dividing the values by 1000.
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

                        :ccs_disposal_cost_per_metric_ton,

                        :hydrogen_mwh_per_tonne       	# to GWh/t
                        ]

    for column in columns_to_scale
        if string(column) in names(resource_in)
            resource_in[!, column] /= scale_factor
        end
    end
    return nothing
end

# function required_columns_for_co2()
#     return ("biomass", 
#             "co2_capture_fraction", 
#             "co2_capture_fraction_startup", 
#             "ccs_disposal_cost_per_metric_ton")
# end

# function ensure_columns!(df::DataFrame)
#     # write zeros if col names are not in the gen_in dataframe
#     required_cols = [required_columns_for_co2()...,]
#     for col in required_cols
# 		ensure_column!(df, col, 0)
# 	end
# end

function _get_resource_df(path::AbstractString, scale_factor::Float64)
    # load dataframe with data of a given resource
    resource_in = load_dataframe(path)
    # rename columns lowercase
    rename!(resource_in, lowercase.(names(resource_in)))
    # scale data if necessary
    scale_resources_data!(resource_in, scale_factor)
    # return dataframe
    return resource_in
end

function _get_resource_indices(resources_in::DataFrame, offset::Int64)
    # return array of indices of resources
    range = (1,nrow(resources_in)) .+ offset
    return UnitRange{Int64}(range...)
end

function _add_indices_to_resource_df!(df::DataFrame, indices::AbstractVector)
    df[!, :id] = indices
    return nothing
end

# function dataframerow_to_tuple(dfr::DataFrameRow)
#     return NamedTuple(pairs(dfr))
# end

function _get_resource_array(resource_in::DataFrame, Resource)
    # convert dataframe to array of resources of correct type
    resources::Vector{Resource} = Resource.(dataframerow_to_dict.(eachrow(resource_in)))
    # return resources
    return resources
end

function _get_all_resources(resources_folder::AbstractString, resources_info::NamedTuple, scale_factor::Float64=1.0)
    resource_id_offset = 0
    resources = []
    # loop over available types and get all resources
    for (filename, resource_type) in values(resources_info)
        # path to resources data
        path = joinpath(resources_folder, filename)
        # if file exists, load resources
        if isfile(path)
            # load resources data of a given type
            resource_in = _get_resource_df(path, scale_factor)
            # get indices of resources for later use
            resources_indices = _get_resource_indices(resource_in, resource_id_offset)
            # add indices to dataframe
            _add_indices_to_resource_df!(resource_in, resources_indices)
            # add resources of a given type to array of resources
            resources_same_type = _get_resource_array(resource_in, resource_type)
            push!(resources, resources_same_type)
            # update id offset for next type of resources
            resource_id_offset += length(resources_same_type)
            # print log
            @info filename * " Successfully Read."
        end
    end
    # check if any resources were loaded
    isempty(resources) && error("No resources data found. Check data path or configuration file \"genx_settings.yml\" inside Settings.")
    return reduce(vcat, resources)
end

function load_scaled_resources_data(setup::Dict, case_path::AbstractString)
# Scale factor for energy and currency units
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1.0
    # get path to resources data
    resources_folder = setup["ResourcePath"]
    resources_folder = joinpath(case_path,resources_folder)
    # get type, filename and resource-key for each type of resources
    resources_info = _get_resource_info()
    # load each resource type, scale data and return array of resources
    resources = _get_all_resources(resources_folder, resources_info, scale_factor)
    # validate input before returning
    validate_resources(resources)
    return resources
end

function _add_attributes_to_resource!(resource::AbstractResource, new_symbols::Vector{Symbol}, new_values::T) where T <: DataFrameRow
    # loop over new attributes (new cols)
    for (sym, value) in zip(new_symbols, new_values)
        # add attribute to resource if value is not zero
        value ≠ 0 && setproperty!(resource, sym, value)
    end
    return nothing
end    

function add_policies_to_resources!(setup::Dict, case_path::AbstractString, resources::Vector{<:AbstractResource})
    policy_folder = setup["PolicyPath"]
    policy_folder = joinpath(case_path, policy_folder)
    # get filename and column-name for each type of policy
    resources_info = _get_policyfile_info()
    # loop over policy files
    for (filename, column_name) in values(resources_info)
        # path to policy file
        path = joinpath(policy_folder, filename)
        # if file exists, add policy to resources
        if isfile(path) 
            add_policy_to_resources!(path, filename, column_name, resources)
            # print log
            @info filename * " Successfully Read."
        end
    end
end

function add_policy_to_resources!(path::AbstractString, filename::AbstractString, column_name::AbstractString, resources::Vector{<:AbstractResource})
    # load policy file
    policy_in = load_dataframe(path)
    # check if policy file has any attributes, validate clumn names 
    validate_policy_dataframe!(filename, column_name, policy_in)
    # add policy attributes to resources
    _add_df_to_resources!(resources, policy_in)
    return nothing
end

function add_modules_to_resources!(setup::Dict, case_path::AbstractString, resources::Vector{<:AbstractResource})
    modules = Vector{DataFrame}()

    ## Load all modules and add them to the list of modules to add to resources
    # Add multistage if multistage is activated
    if setup["MultiStage"] == 1
        multistage_in = load_multistage_dataframe(case_path)
        push!(modules, multistage_in)
        @info "Multistage data successfully read."
    end
    
    
    ## Loop over modules and add attributes to resources
    add_module_to_resources!.(Ref(resources), modules)

    return nothing
end

function add_module_to_resources!(resources::Vector{<:AbstractResource}, module_in::DataFrame)
    _add_df_to_resources!(resources, module_in)
    return nothing
end

function validate_policy_dataframe!(filename::AbstractString, column_name::AbstractString, policy_in::DataFrame)
    cols = names(policy_in)
    n_cols = length(cols)
    # check if policy file has any attributes
    if n_cols == 1
        msg = "No policy attributes found in policy file: " * filename
        error(msg)
    end
    # if the single column attribute does not have a tag number, add a tag number of 1
    if n_cols == 2 && cols[2][end-2] != "_1"
        rename!(policy_in, Symbol.(cols[2]) => Symbol.(cols[2], "_1"))
    end
    # get policy column names
    cols = lowercase.(names(policy_in))
    tag_names = cols[startswith.(cols, column_name)]
    # Check that all policy columns are of the form policyname_tagnum
    # - any: at least one column matches policyname_tagnum
    # - all: all matches are found in the policy file
    if !all(any(occursin.(string(column_name, "_$tag_num"), tag_names)) for tag_num in 1:length(tag_names))
        column_names = [string(column_name, "_$tag_num") for tag_num in 1:length(tag_names)]
        msg = "Policy file $filename must have columns named $column_names, case insensitive."
        error(msg)
    end
    return nothing
end

function _add_df_to_resources!(resources::Vector{<:AbstractResource}, module_in::DataFrame)
    # rename columns lowercase to ensure consistency with resources
    rename!(module_in, lowercase.(names(module_in)))
    # extract columns of module -> new resource attributes
    new_sym = Symbol.(filter(x -> x ≠ "resource", names(module_in)))
    # loop oper rows of module and add new attributes to resources
    for row in eachrow(module_in)
        resource_name = row[:resource]
        resource = resource_by_name(resources, resource_name)
        new_values = row[new_sym]
        _add_attributes_to_resource!(resource, new_sym, new_values)
    end
    return nothing
end

function add_resources_to_input_data!(setup::Dict, case_path::AbstractString, input_data::Dict, gen::Vector{<:AbstractResource})
    
    # Number of resources
    G = length(gen)
    input_data["G"] = G

    # Scale factor
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    # Number of time steps (periods)
    T = input_data["T"]
    
    ## HYDRO
    # Set of all reservoir hydro resources
    input_data["HYDRO_RES"] = hydro(gen)
    # Set of hydro resources modeled with known reservoir energy capacity
    if !isempty(input_data["HYDRO_RES"])
        input_data["HYDRO_RES_KNOWN_CAP"] = intersect(input_data["HYDRO_RES"], has_hydro_energy_to_power_ratio(gen))
    end

    ## STORAGE
    # Set of storage resources with symmetric charge/discharge capacity
    input_data["STOR_SYMMETRIC"] = symmetric_storage(gen)
    # Set of storage resources with asymmetric (separte) charge/discharge capacity components
    input_data["STOR_ASYMMETRIC"] = asymmetric_storage(gen)
    # Set of all storage resources
    input_data["STOR_ALL"] = union(input_data["STOR_SYMMETRIC"],input_data["STOR_ASYMMETRIC"])

    # Set of storage resources with long duration storage capabilitites
    input_data["STOR_HYDRO_LONG_DURATION"] = intersect(input_data["HYDRO_RES"], is_LDS(gen))
    input_data["STOR_LONG_DURATION"] = intersect(input_data["STOR_ALL"], is_LDS(gen))	    
    input_data["STOR_SHORT_DURATION"] = intersect(input_data["STOR_ALL"], is_SDS(gen))

    ## VRE
    # Set of controllable variable renewable resources
    input_data["VRE"] = vre(gen)

    ## FLEX
    # Set of flexible demand-side resources
    input_data["FLEX"] = flex_demand(gen)

    ## TODO: MUST_RUN
    # Set of must-run plants - could be behind-the-meter PV, hydro run-of-river, must-run fossil or thermal plants
    input_data["MUST_RUN"] = must_run(gen)

    ## ELECTROLYZER
    # Set of hydrogen electolyzer resources:
    input_data["ELECTROLYZER"] = electrolyzer(gen)

    ## Retrofit ## TODO: ask how to add it
    input_data["RETRO"] = []

    ## Reserves
    if setup["Reserves"] >= 1
        # Set for resources with regulation reserve requirements
        input_data["REG"] = has_regulation_reserve_requirements(gen)
        # Set for resources with spinning reserve requirements
        input_data["RSV"] = has_spinning_reserve_requirements(gen)
    end

    ## THERM
    # Set of all thermal resources
    input_data["THERM_ALL"] = thermal(gen)
    # Unit commitment
    if setup["UCommit"] >= 1
        # Set of thermal resources with unit commitment
        input_data["THERM_COMMIT"] = has_unit_commitment(gen)
        # Set of thermal resources without unit commitment
        input_data["THERM_NO_COMMIT"] = no_unit_commitment(gen)
        # Start-up cost is sum of fixed cost per start startup
		input_data["C_Start"] = zeros(Float64, G, T)
        for g in input_data["THERM_COMMIT"]
            start_up_cost = start_cost_per_mw(gen[g]) * cap_size(gen[g])
            input_data["C_Start"][g,:] .= start_up_cost
        end
        # Piecewise fuel usage option
        input_data["PWFU_Num_Segments"] = 0
        input_data["THERM_COMMIT_PWFU"] = Int64[]
        process_piecewisefuelusage!(input_data, case_path, gen, scale_factor)
    else
        # Set of thermal resources with unit commitment
        input_data["THERM_COMMIT"] = []
        # Set of thermal resources without unit commitment
        input_data["THERM_NO_COMMIT"] = input_data["THERM_ALL"]
    end
    # For now, the only resources eligible for UC are themal resources
    input_data["COMMIT"] = input_data["THERM_COMMIT"]

    ## Co-located resources
    # VRE and storage
    input_data["VRE_STOR"] = []
    # load_vre_stor_data!(input_data, setup, path)

    buildable = is_buildable(gen)
    retirable = is_retirable(gen)

    # Set of all resources eligible for new capacity
    input_data["NEW_CAP"] = intersect(buildable, has_max_capacity_mw(gen))
    # Set of all resources eligible for capacity retirements
    input_data["RET_CAP"] = intersect(retirable, has_existing_capacity_mw(gen))

    new_cap_energy = Set{Int64}()
    ret_cap_energy = Set{Int64}()
    if !isempty(input_data["STOR_ALL"])
        # Set of all storage resources eligible for new energy capacity
        new_cap_energy = intersect(buildable, has_max_capacity_mwh(gen), input_data["STOR_ALL"])
        # Set of all storage resources eligible for energy capacity retirements
        ret_cap_energy = intersect(retirable, has_existing_capacity_mwh(gen), input_data["STOR_ALL"])
    end
    input_data["NEW_CAP_ENERGY"] = new_cap_energy
    input_data["RET_CAP_ENERGY"] = ret_cap_energy

	new_cap_charge = Set{Int64}()
	ret_cap_charge = Set{Int64}()
	if !isempty(input_data["STOR_ASYMMETRIC"])
		# Set of asymmetric charge/discharge storage resources eligible for new charge capacity
        new_cap_charge = intersect(buildable, has_max_charge_capacity_mw(gen), input_data["STOR_ASYMMETRIC"])
		# Set of asymmetric charge/discharge storage resources eligible for charge capacity retirements
        ret_cap_charge = intersect(buildable, has_existing_charge_capacity_mw(gen), input_data["STOR_ASYMMETRIC"])
	end
	input_data["NEW_CAP_CHARGE"] = new_cap_charge
	input_data["RET_CAP_CHARGE"] = ret_cap_charge

    # Names of resources
    input_data["RESOURCE_NAMES"] = resource_name.(gen)

    # Zones resources are located in
    zones = zone_id.(gen)
    
    # Resource identifiers by zone (just zones in resource order + resource and zone concatenated)
    input_data["R_ZONES"] = zones
    input_data["RESOURCE_ZONES"] = input_data["RESOURCE_NAMES"] .* "_z" .* string.(zones)

    # Fuel
    input_data["HAS_FUEL"] = has_fuel(gen)

    input_data["RESOURCES"] = gen
    return nothing
end

function load_resources_data!(setup::Dict, case_path::AbstractString, input_data::Dict)
    if isfile(joinpath(case_path, "Generators_data.csv"))
        Base.depwarn(
            "The `Generators_data.csv` file was deprecated in release v0.4. " *
            "Please use the new interface for generators creation, and see the documentation for additional details.",
            :load_resources_data!, force=true)
        error("Exiting GenX...")
        # load_generators_data!(setup, case_path, input_data)
        # translate_generators_data!(setup, input_data)
    else
        # load resources data and scale it if necessary
        resources = load_scaled_resources_data(setup, case_path)

        # add policies-related attributes to resource dataframe
        add_policies_to_resources!(setup, case_path, resources)

        # add module-related attributes to resource dataframe
        add_modules_to_resources!(setup, case_path, resources)
        
        # add resources to input_data dict
        add_resources_to_input_data!(setup, case_path, input_data, resources)

        return nothing
    end
end

function translate_generators_data!(setup::Dict, inputs_gen::Dict)
end

# function extract_matrix_from_resources(resources::Vector{<:AbstractResource}, columnprefix::AbstractString, prefixseparator='_')
    
#     for i in eachindex(resources)
#     end

#     all_columns = string.(keys(resource))
#     columnnumbers = _find_matrix_columns(all_columns, columnprefix, prefixseparator)

#     if length(columnnumbers) == 0
#         msg = """an input dataframe with columns $all_columns was searched for
#         numbered columns starting with $columnprefix, but nothing was found."""
#         error(msg)
#     end

#     # check that the sequence of column numbers is 1..N
#     if columnnumbers != collect(1:length(columnnumbers))
#         msg = """the columns $columns in an input file must be numbered in
#         a complete sequence from 1...N. It looks like some of the sequence is missing.
#         This error could also occur if there are two columns with the same number."""
#         error(msg)
#     end

#     sorted_columns = columnprefix .* prefixseparator .* string.(columnnumbers)
# end



