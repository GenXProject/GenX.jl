get_max(x::MinMax) = x.max
get_min(x::MinMax) = x.min
get_in(x::InOut) = x.in
get_out(x::InOut) = x.out

get_parameter_type(t::SupplyTechnology{T}) where T = T
get_parameter_type(t::StorageTechnology{T}) where T = T
get_parameter_type(::NodalACTransportTechnology{T}) where T = T
get_existing_technologies(ec::ExistingCapacity) = ec.existing_technologies
get_storage_capacity(ers::PSY.EnergyReservoirStorage) = ers.storage_capacity

function existing_cap_mw(p::Portfolio, t::Union{ResourceTechnology, TransmissionTechnology})
    if IS.has_supplemental_attributes(ExistingCapacity, t)
        gen_names = get_existing_technologies(IS.get_supplemental_attributes(ExistingCapacity, t)[1])
        comp = PSY.get_component.(get_parameter_type(t), Ref(p.base_system), gen_names)
        return sum(PSY.get_rating(t) for t in comp) * PSY.get_base_power(p.base_system)
    else
        return 0.0
    end
end

function existing_cap_mwh(p::Portfolio, t::StorageTechnology)
    if IS.has_supplemental_attributes(ExistingCapacity, t)
        gen_names = get_existing_technologies(IS.get_supplemental_attributes(ExistingCapacity, t)[1])
        comp = PSY.get_component.(get_parameter_type(t), Ref(p.base_system), gen_names)
        return sum(PSY.get_storage_capacity(t) for t in comp) * PSY.get_base_power(p.base_system)
    else
        return 0.0
    end
end

function set_capacity!(p::Portfolio, capacities::Dict{String, DataFrame})
    inv_schedule = p.investment_schedule
    for (k, v) in capacities
        inv_schedule[k] = v
    end
    return nothing
end

function get_investment_schedule(p::Portfolio)
    return p.investment_schedule
end

function expand_new_cap_resources_to_nodal!(inputs::Dict, setup::Dict, p::Portfolio, case_path="")
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1.0
    resources = inputs["RESOURCES"]
    region_to_index = inputs["region_to_index"]
    technology_to_index = inputs["technology_to_index"]
    index_to_technology = inputs["index_to_technology"]
    new_cap_resources = GenX.AbstractResource[]
    new_cap = inputs["NEW_CAP"]
    zonal_to_nodal_new_cap = Dict{String, Vector{Int}}()
    new_cap_names = String[]
    pP_Max = inputs["pP_Max"]
    for i in new_cap
        old_resource = resources[i]
        resource_name = parent(old_resource)[:resource]
        push!(new_cap_names, resource_name)
        techs = collect(get_technologies_by_name(ResourceTechnology, p, resource_name))
        if length(techs) != 1
            error("Tech of name ", parent(old_resource)[:resource], " has length $(length(techs))")
        end
        tech = techs[1]
        regions = GenX.region(tech) #vector of nodes
        new_id_set = Int[i]
        resource_variability = zeros(1, size(pP_Max)[2])
        resource_variability[1, :] .= pP_Max[i, :]
        for j in 2:length(regions)
            new_resource = deepcopy(old_resource)#translate_resource_dict(p, tech, j)
            #scale_resources_data!(new_resource, scale_factor)
            # genx_type = get_genx_type(tech)
            # new_resource = genx_type(new_resource)
            new_region = regions[j]
            new_region_id = zone_id(new_region)
            new_zone_id = region_to_index[new_region_id]
            parent(new_resource)[:zone] = new_zone_id
            parent(new_resource)[:region] = new_region
            new_resource_id = length(resources) + length(new_cap_resources) + 1
            parent(new_resource)[:id] = new_resource_id
            push!(new_id_set, new_resource_id)
            push!(new_cap_resources, new_resource)
            index_to_technology[length(new_cap_resources) + length(resources)] = tech.id
            pP_Max = vcat(pP_Max, resource_variability)
        end
        zonal_to_nodal_new_cap[resource_name] = new_id_set
    end
    
    new_resources = vcat(resources, new_cap_resources)
    inputs["RESOURCES"] = new_resources
    inputs["new_cap_names"] = new_cap_names
    inputs["index_to_technology"] = index_to_technology
    add_resources_to_input_data!(inputs, setup, case_path, inputs["RESOURCES"])
    inputs["zonal_to_nodal_new_cap"] = zonal_to_nodal_new_cap
    inputs["pP_Max"] = pP_Max
    # len_new_cap_resources = length(new_cap_resources)
    # len_resources = length(resources)
    # new_cap_resources_set = [i for i in (1 + len_resources):(len_resources + len_new_cap_resources)]
    # new_cap_set = vcat(new_cap, new_cap_resources_set)
    # new_resources = 

    # Add map of resource name to their corresponding indices; 
    return nothing
end

function save_zonal_capacity_results!(mz::Model, inputs::Dict, z_inputs::Dict)
    zonal_new_cap = z_inputs["NEW_CAP"]
    zonal_resources = z_inputs["RESOURCES"]
    name_to_cap = Dict{String, Float64}()
    
    if haskey(z_inputs, "new_cap_names")
        new_cap_names = z_inputs["new_cap_names"] 
        zonal_to_nodal_new_cap = z_inputs["zonal_to_nodal_new_cap"] #map of name to idx)
        for name in new_cap_names
            name_to_cap[name] = sum(value(mz[:vCAP][idx]) for idx in zonal_to_nodal_new_cap[name])
        end
    else
        for (i, idx) in enumerate(zonal_new_cap)
            resource_name = parent(zonal_resources[idx])[:resource]
            name_to_cap[resource_name] = value(mz[:vCAP][idx])
        end
    end
    
    inputs["Zonal_Capacity_Results"] = name_to_cap
end

function get_resources_by_name(inputs::Dict, name::String)
    resources = GenX.AbstractResource[]
    for resource in inputs["RESOURCES"]
        if parent(resource)[:resource] == name
            push!(resources, resource)
        end
    end
    if length(resources) == 0
        error("No resources found with name $name")
    else
        return resources
    end
end

function get_resource_ids_by_name(inputs::Dict, name::String)
    resources = Int[]
    for (i, resource) in enumerate(inputs["RESOURCES"])
        if parent(resource)[:resource] == name
            push!(resources, i)
        end
    end
    if length(resources) == 0
        error("No resources found with name $name")
    else
        return resources
    end
end

function filter_candidate_lines(inputs, lines_to_keep)
    sort!(lines_to_keep)
    
    CANDIDATE_LINES = inputs["CANDIDATE_LINES"]
    EXISTING_LINES = inputs["EXISTING_LINES"]
    CAN_RETIRE_LINES = inputs["CAN_RETIRE_LINES"]
    CANNOT_RETIRE_LINES = inputs["CANNOT_RETIRE_LINES"]
    @assert all(x -> x in CANDIDATE_LINES, lines_to_keep)

    pnet_map = inputs["pNet_Map"]
    all_lines = vcat(EXISTING_LINES, lines_to_keep)
    inputs["pNet_Map"] = pnet_map[all_lines, :]
    line_keys = [ "pPercent_Loss", "pTrans_Max", "pDC_OPF_coeff", "Line_Angle_Limit", "Line_Reinforcement_Cap_Size", "pC_Line_Reinforcement", "Max_Trans_Cap", "BigM"] # "pTrans_Max_Possible","pTrans_Loss_Coeff", 

    for key in line_keys
        if haskey(inputs, key)
            inputs[key] = inputs[key][all_lines]
        end
    end
    inputs["L_cand"] = length(lines_to_keep)
    inputs["L"] = length(all_lines)

    L_exist = inputs["L_exist"]
    L_cand = inputs["L_cand"]

    existing_to_cand_map = inputs["existing_to_cand_map"]
    cand_new_idx = Dict(l => i + L_exist for (i, l) in enumerate(lines_to_keep))
    cand_to_existing_map = Dict(existing_to_cand_map[l] => l for l in keys(existing_to_cand_map))

    for l in EXISTING_LINES
        if haskey(existing_to_cand_map, l)
            cand_line = existing_to_cand_map[l]
            if (cand_line in lines_to_keep) # if it is in the lines_to_keep
                existing_to_cand_map[l] = cand_new_idx[cand_line]
            end
            if l in CAN_RETIRE_LINES 
                if !(cand_line in lines_to_keep)
                    idx = findfirst(==(l), CAN_RETIRE_LINES)
                    deleteat!(CAN_RETIRE_LINES, idx)
                    delete!(existing_to_cand_map, l)
                    push!(CANNOT_RETIRE_LINES, l)
                end
            end
        end
    end


    sort!(CANNOT_RETIRE_LINES)
    inputs["CAN_RETIRE_LINES"] = sort(CAN_RETIRE_LINES)
    inputs["CANNOT_RETIRE_LINES"] = sort(CANNOT_RETIRE_LINES)
    inputs["existing_to_cand_map"] = existing_to_cand_map
    inputs["CANDIDATE_LINES"] = [i for i in (L_exist + 1):(L_exist + L_cand)]

    if haskey(inputs, "Line_Map")
        new_line_map = Dict()
        old_line_map = inputs["Line_Map"]
        for l in EXISTING_LINES
            new_lines_map[l] = old_line_map[l]
        end
        for (i, l) in enumerate(lines_to_keep)
            new_lines_map[i + L_exist] = old_line_map[l]
        end
        myinputs["Line_Map"] = new_lines_map
    end


end

# load in inputs
# build zonal inputs
# solve zonal model
# add new resources to inputs dictionary
# build nodal inputs
# fix capacity decisions for nodal problems (sum vcap by name) = solution
# go through the names of zonal solution keys => call get_resource_ids_by_name