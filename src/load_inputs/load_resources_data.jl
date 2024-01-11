function _get_resource_info()
    resources = (
        hydro   = (filename="Hydro.csv", type=HYDRO),
        thermal = (filename="Thermal.csv", type=THERM),
        vre     = (filename="Vre.csv", type=VRE),
        storage = (filename="Storage.csv", type=STOR),
        flex_demand  = (filename="Flex_demand.csv", type=FLEX),
        must_run = (filename="Must_run.csv", type=MUST_RUN),
        electrolyzer = (filename="Electrolyzer.csv", type=ELECTROLYZER),
        vre_stor = (filename="Vre_stor.csv", type=VRE_STOR)
    )
    return resources
end

function _get_policyfile_info()
    policies = (
        esr     = (filename="Res_energy_share_requirement.csv"),
        cap_res = (filename="Res_capacity_reserve_margin.csv"),
        min_cap_tags = (filename="Res_minimum_capacity_requirement.csv"),
        max_cap_tags = (filename="Res_maximum_capacity_requirement.csv"),
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

    scale_columns!(resource_in, columns_to_scale, scale_factor)
end

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
end

function scale_columns!(df::DataFrame, columns_to_scale::Vector{Symbol}, scale_factor::Float64)
    for column in columns_to_scale
        if string(column) in names(df)
            df[!, column] /= scale_factor
        end
    end
    return nothing
end

function _get_resource_df(path::AbstractString, scale_factor::Float64, resource_type::Type)
    # load dataframe with data of a given resource
    resource_in = load_dataframe(path)
    # rename columns lowercase
    rename!(resource_in, lowercase.(names(resource_in)))
    # scale data if necessary
    scale_resources_data!(resource_in, scale_factor)
    # scale vre_stor data if necessary
    resource_type == VRE_STOR && scale_vre_stor_data!(resource_in, scale_factor)
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
            resource_in = _get_resource_df(path, scale_factor, resource_type)
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
    # validate input before returning resources
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
    policy_folder = setup["ResourcePath"]
    policy_folder = joinpath(case_path, policy_folder)
    # get filename and column-name for each type of policy
    resources_info = _get_policyfile_info()
    # loop over policy files
    for filename in values(resources_info)
        # path to policy file
        path = joinpath(policy_folder, filename)
        # if file exists, add policy to resources
        if isfile(path) 
            add_policy_to_resources!(path, filename, resources)
            # print log
            @info filename * " Successfully Read."
        end
    end
end

function add_policy_to_resources!(path::AbstractString, filename::AbstractString, resources::Vector{<:AbstractResource})
    # load policy file
    policy_in = load_dataframe(path)
    # check if policy file has any attributes, validate clumn names 
    validate_policy_dataframe!(filename, policy_in)
    # add policy attributes to resources
    _add_df_to_resources!(resources, policy_in)
    return nothing
end

function add_modules_to_resources!(setup::Dict, case_path::AbstractString, resources::Vector{<:AbstractResource})
    modules = Vector{DataFrame}()

    module_folder = setup["ResourcePath"]
    module_folder = joinpath(case_path, module_folder)

    ## Load all modules and add them to the list of modules to add to resources
    # Add multistage if multistage is activated
    if setup["MultiStage"] == 1
        filename = joinpath(module_folder, "Res_multistage_data.csv")
        multistage_in = load_multistage_dataframe(filename)
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

function validate_policy_dataframe!(filename::AbstractString, policy_in::DataFrame)
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
    filter!(col -> col ≠ "resource",cols)
    
    accepted_cols = ["eligible_cap_res", "esr", "esr_vrestor",
                        [string(cap, type) for cap in ["min_cap", "max_cap"] for type in ("", "_stor", "_solar", "_wind")]...]

    # Check that all policy columns have accepter names
    if !all(x -> replace(x, r"(_*|_*\d*)$" => "") in accepted_cols, cols)
        msg = "The accepted policy columns are: " * join(accepted_cols, ", ")
        msg *= "\nCheck policy file: " * filename
        error(msg)
    end
    if !all(any([occursin(Regex("$(y)")*r"_\d", col) for y in accepted_cols]) for col in cols)
        msg = "Columns in policy file $filename must have names with format \"[policy_name]_[tagnum]\", case insensitive. (e.g., ESR_1, Min_Cap_1, Max_Cap_2, etc.)."
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

@doc raw"""
    split_storage_resources!(gen::Vector{<:AbstractResource}, inputs::Dict)

For co-located VRE-storage resources, this function returns the storage type 
	(1. long-duration or short-duration storage, 2. symmetric or asymmetric storage)
    for charging and discharging capacities
"""
function split_storage_resources!(gen::Vector{<:AbstractResource}, inputs::Dict)

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
	inputs["VS_SYM_DC"] = intersect(inputs["VS_SYM_DC_CHARGE"], inputs["VS_SYM_DC_DISCHARGE"])
    inputs["VS_SYM_AC"] = intersect(inputs["VS_SYM_AC_CHARGE"], inputs["VS_SYM_AC_DISCHARGE"])

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

function add_resources_to_input_data!(setup::Dict, case_path::AbstractString, inputs::Dict, gen::Vector{<:AbstractResource})
    
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
        inputs["HYDRO_RES_KNOWN_CAP"] = intersect(inputs["HYDRO_RES"], has_hydro_energy_to_power_ratio(gen))
    end

    ## STORAGE
    # Set of storage resources with symmetric charge/discharge capacity
    inputs["STOR_SYMMETRIC"] = symmetric_storage(gen)
    # Set of storage resources with asymmetric (separte) charge/discharge capacity components
    inputs["STOR_ASYMMETRIC"] = asymmetric_storage(gen)
    # Set of all storage resources
    inputs["STOR_ALL"] = union(inputs["STOR_SYMMETRIC"],inputs["STOR_ASYMMETRIC"])

    # Set of storage resources with long duration storage capabilitites
    inputs["STOR_HYDRO_LONG_DURATION"] = intersect(inputs["HYDRO_RES"], is_LDS(gen))
    inputs["STOR_LONG_DURATION"] = intersect(inputs["STOR_ALL"], is_LDS(gen))	    
    inputs["STOR_SHORT_DURATION"] = intersect(inputs["STOR_ALL"], is_SDS(gen))

    ## VRE
    # Set of controllable variable renewable resources
    inputs["VRE"] = vre(gen)

    ## FLEX
    # Set of flexible demand-side resources
    inputs["FLEX"] = flex_demand(gen)

    ## TODO: MUST_RUN
    # Set of must-run plants - could be behind-the-meter PV, hydro run-of-river, must-run fossil or thermal plants
    inputs["MUST_RUN"] = must_run(gen)

    ## ELECTROLYZER
    # Set of hydrogen electolyzer resources:
    inputs["ELECTROLYZER"] = electrolyzer(gen)

    ## Retrofit ## TODO: ask how to add it
    inputs["RETRO"] = []

    ## Reserves
    if setup["Reserves"] >= 1
        # Set for resources with regulation reserve requirements
        inputs["REG"] = has_regulation_reserve_requirements(gen)
        # Set for resources with spinning reserve requirements
        inputs["RSV"] = has_spinning_reserve_requirements(gen)
    end

    ## THERM
    # Set of all thermal resources
    inputs["THERM_ALL"] = thermal(gen)
    # Unit commitment
    if setup["UCommit"] >= 1
        # Set of thermal resources with unit commitment
        inputs["THERM_COMMIT"] = has_unit_commitment(gen)
        # Set of thermal resources without unit commitment
        inputs["THERM_NO_COMMIT"] = no_unit_commitment(gen)
        # Start-up cost is sum of fixed cost per start startup
		inputs["C_Start"] = zeros(Float64, G, T)
        for g in inputs["THERM_COMMIT"]
            start_up_cost = start_cost_per_mw(gen[g]) * cap_size(gen[g])
            inputs["C_Start"][g,:] .= start_up_cost
        end
        # Piecewise fuel usage option
        inputs["PWFU_Num_Segments"] = 0
        inputs["THERM_COMMIT_PWFU"] = Int64[]
        process_piecewisefuelusage!(setup, case_path, gen, inputs)
    else
        # Set of thermal resources with unit commitment
        inputs["THERM_COMMIT"] = []
        # Set of thermal resources without unit commitment
        inputs["THERM_NO_COMMIT"] = inputs["THERM_ALL"]
    end
    # For now, the only resources eligible for UC are themal resources
    inputs["COMMIT"] = inputs["THERM_COMMIT"]

    buildable = is_buildable(gen)
    retirable = is_retirable(gen)

    # Set of all resources eligible for new capacity
    inputs["NEW_CAP"] = intersect(buildable, has_max_cap_mw(gen))
    # Set of all resources eligible for capacity retirements
    inputs["RET_CAP"] = intersect(retirable, has_existing_cap_mw(gen))

    new_cap_energy = Set{Int64}()
    ret_cap_energy = Set{Int64}()
    if !isempty(inputs["STOR_ALL"])
        # Set of all storage resources eligible for new energy capacity
        new_cap_energy = intersect(buildable, has_max_cap_mwh(gen), inputs["STOR_ALL"])
        # Set of all storage resources eligible for energy capacity retirements
        ret_cap_energy = intersect(retirable, has_existing_cap_mwh(gen), inputs["STOR_ALL"])
    end
    inputs["NEW_CAP_ENERGY"] = new_cap_energy
    inputs["RET_CAP_ENERGY"] = ret_cap_energy

	new_cap_charge = Set{Int64}()
	ret_cap_charge = Set{Int64}()
	if !isempty(inputs["STOR_ASYMMETRIC"])
		# Set of asymmetric charge/discharge storage resources eligible for new charge capacity
        new_cap_charge = intersect(buildable, has_max_charge_cap_mw(gen), inputs["STOR_ASYMMETRIC"])
		# Set of asymmetric charge/discharge storage resources eligible for charge capacity retirements
        ret_cap_charge = intersect(buildable, has_existing_charge_capacity_mw(gen), inputs["STOR_ASYMMETRIC"])
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
        inputs["VS_DC"] = union(storage_dc_discharge(gen), storage_dc_charge(gen), solar(gen))

        # Wind Resources
        inputs["VS_WIND"] = wind(gen)

        # Storage Resources
        split_storage_resources!(gen, inputs)

        gen_VRE_STOR = gen[inputs["VRE_STOR"]]
        # Set of all VRE-STOR resources eligible for new solar capacity
        inputs["NEW_CAP_SOLAR"] = intersect(buildable, solar(gen), has_max_cap_solar_mw(gen_VRE_STOR))
        # Set of all VRE_STOR resources eligible for solar capacity retirements
        inputs["RET_CAP_SOLAR"] = intersect(retirable,  solar(gen), has_nonneg_existing_cap_solar_mw(gen_VRE_STOR))
        # Set of all VRE-STOR resources eligible for new wind capacity
        inputs["NEW_CAP_WIND"] = intersect(buildable, wind(gen), has_max_cap_wind_mw(gen_VRE_STOR))
        # Set of all VRE_STOR resources eligible for wind capacity retirements
        inputs["RET_CAP_WIND"] = intersect(retirable, wind(gen), has_nonneg_existing_cap_wind_mw(gen_VRE_STOR))
        # Set of all VRE-STOR resources eligible for new inverter capacity
        inputs["NEW_CAP_DC"] = intersect(buildable, has_max_cap_inverter_mw(gen_VRE_STOR), inputs["VS_DC"])
        # Set of all VRE_STOR resources eligible for inverter capacity retirements
        inputs["RET_CAP_DC"] = intersect(retirable, has_nonneg_existing_cap_inverter_mw(gen_VRE_STOR), inputs["VS_DC"])
        # Set of all storage resources eligible for new energy capacity
        inputs["NEW_CAP_STOR"] = intersect(buildable, has_max_cap_mwh(gen_VRE_STOR), inputs["VS_STOR"])
        # Set of all storage resources eligible for energy capacity retirements
        inputs["RET_CAP_STOR"] = intersect(retirable, has_existing_cap_mwh(gen_VRE_STOR), inputs["VS_STOR"])
        if !isempty(inputs["VS_ASYM"])
            # Set of asymmetric charge DC storage resources eligible for new charge capacity
            inputs["NEW_CAP_CHARGE_DC"] = intersect(buildable, has_max_cap_charge_dc_mw(gen_VRE_STOR), inputs["VS_ASYM_DC_CHARGE"]) 
            # Set of asymmetric charge DC storage resources eligible for charge capacity retirements
            inputs["RET_CAP_CHARGE_DC"] = intersect(retirable, has_nonneg_existing_cap_charge_dc_mw(gen_VRE_STOR), inputs["VS_ASYM_DC_CHARGE"])
            # Set of asymmetric discharge DC storage resources eligible for new discharge capacity
            inputs["NEW_CAP_DISCHARGE_DC"] = intersect(buildable, has_max_cap_discharge_dc_mw(gen_VRE_STOR), inputs["VS_ASYM_DC_DISCHARGE"]) 
            # Set of asymmetric discharge DC storage resources eligible for discharge capacity retirements
            inputs["RET_CAP_DISCHARGE_DC"] = intersect(retirable, has_nonneg_existing_cap_discharge_dc_mw(gen_VRE_STOR), inputs["VS_ASYM_DC_DISCHARGE"]) 
            # Set of asymmetric charge AC storage resources eligible for new charge capacity
            inputs["NEW_CAP_CHARGE_AC"] = intersect(buildable, has_max_cap_charge_ac_mw(gen_VRE_STOR), inputs["VS_ASYM_AC_CHARGE"]) 
            # Set of asymmetric charge AC storage resources eligible for charge capacity retirements
            inputs["RET_CAP_CHARGE_AC"] = intersect(retirable, has_nonneg_existing_cap_charge_ac_mw(gen_VRE_STOR), inputs["VS_ASYM_AC_CHARGE"]) 
            # Set of asymmetric discharge AC storage resources eligible for new discharge capacity
            inputs["NEW_CAP_DISCHARGE_AC"] = intersect(buildable, has_max_cap_discharge_ac_mw(gen_VRE_STOR), inputs["VS_ASYM_AC_DISCHARGE"]) 
            # Set of asymmetric discharge AC storage resources eligible for discharge capacity retirements
            inputs["RET_CAP_DISCHARGE_AC"] = intersect(retirable, has_nonneg_existing_cap_discharge_ac_mw(gen_VRE_STOR), inputs["VS_ASYM_AC_DISCHARGE"]) 
        end 

        # Names for systemwide resources
        inputs["RESOURCES_VRE_STOR"] = resource_name(gen_VRE_STOR)

        # Names for writing outputs
        inputs["RESOURCES_SOLAR"] = resource_name(gen[inputs["VS_SOLAR"]])
        inputs["RESOURCES_WIND"] = resource_name(gen[inputs["VS_WIND"]])
        inputs["RESOURCES_DC_DISCHARGE"] = resource_name(gen[storage_dc_discharge(gen)])
        inputs["RESOURCES_AC_DISCHARGE"] = resource_name(gen[storage_ac_discharge(gen)])
        inputs["RESOURCES_DC_CHARGE"] = resource_name(gen[storage_dc_charge(gen)])
        inputs["RESOURCES_AC_CHARGE"] = resource_name(gen[storage_ac_charge(gen)])
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
    inputs["HAS_FUEL"] = has_fuel(gen)

    inputs["RESOURCES"] = gen
    return nothing
end

function load_resources_data!(setup::Dict, case_path::AbstractString, input_data::Dict)
    if isfile(joinpath(case_path, "Generators_data.csv"))
        Base.depwarn(
            "The `Generators_data.csv` file was deprecated in release v0.4. " *
            "Please use the new interface for generators creation, and see the documentation for additional details.",
            :load_resources_data!, force=true)
        error("Exiting GenX...")
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
