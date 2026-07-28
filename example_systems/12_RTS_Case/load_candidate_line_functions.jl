line_data = CSV.read((@__DIR__)*"/edge_map.csv", DataFrame)
line_names = line_data[!, "Name"]
line_lengths = line_data[!, "Length_for_multiplier"]
line_length_mapping = Dict([line_names[i] => line_lengths[i] for i in 1:length(line_names)])

function build_network_adjacency_list(adj_mat::Matrix)
    adj_list = Vector{Vector{Int}}()
    num_lines = size(adj_mat, 1)

    for i in 1:num_lines
        src = findfirst(x -> x == -1, adj_mat[i, :])
        dst = findfirst(x -> x == 1, adj_mat[i, :])
        push!(adj_list, [src, dst])
    end

    return adj_list
end
    
function load_candidates_base(myinputs, T=168; demand_scale = 2, add_new_corridors = false, use_official_lengths = false)
    myinputs["pTrans_Max"] .*= 1
    L = myinputs["L"]
    L_exist = L
    L_cand = L
    myinputs["L_cand"] = L_cand
    myinputs["L_exist"] = L_exist
    myinputs["L"] = L * 2
    myinputs["Z_cand"] = myinputs["Z"]
    myinputs["pNet_Map"] = vcat(myinputs["pNet_Map"], myinputs["pNet_Map"])
    myinputs["pDC_OPF_coeff"] = vcat(myinputs["pDC_OPF_coeff"], myinputs["pDC_OPF_coeff"])
    myinputs["Line_Angle_Limit"] = [pi / 12 for i in 1:myinputs["L"]]
    myinputs["Line_Reinforcement_Cap_Size"] = vcat([0 for i in 1:L_exist], [i for i in myinputs["pTrans_Max"]])
    myinputs["Max_Trans_Cap"] = vcat([0 for i in 1:L_exist], [1 for i in myinputs["pTrans_Max"]])
    myinputs["pTrans_Max"] = vcat([i for i in myinputs["pTrans_Max"]], [0 for i in 1:L_cand])

    EXPANSION_LEVELS = Dict{Int, Vector}()
    for i in (L_exist + 1):(L_exist + L_cand)
        EXPANSION_LEVELS[i] = (0:1:myinputs["Max_Trans_Cap"][i])
    end
    EXPANSION_LINES = [i for i in (L_exist + 1):(L_exist + L_cand)]
    myinputs["EXPANSION_LINES"] = EXPANSION_LINES
    myinputs["CANDIDATE_LINES"] = copy(EXPANSION_LINES)
    myinputs["EXISTING_LINES"] = [i for i in 1:L_exist]
    myinputs["pPercent_Loss"] = vcat(myinputs["pPercent_Loss"], myinputs["pPercent_Loss"])

    lines = collect(get_technologies(TransmissionTechnology, p));
    lines = [l for l in lines if PSY.has_supplemental_attributes(l, ExistingCapacity)]

    myinputs["pC_Line_Reinforcement"] = zeros(myinputs["L"])
    myinputs["pC_Line_Reconductor_High"] = zeros(myinputs["L"])
    myinputs["pC_Line_Reconductor_Low"] = zeros(myinputs["L"])

    scale_factor = mysetup["ParameterScale"] == 1 ? GenX.ModelScalingFactor : 1

    CAN_RETIRE_LINES = Int[]
    CANNOT_RETIRE_LINES = Int[]
    RECONDUCTOR_LINES = Int[]
    existing_to_cand_map = Dict()

    Random.seed!(1)
    if use_official_lengths
        index_to_line = myinputs["index_to_line"]
        for i in 1:length(lines)
            line_name = index_to_line[i]
            if haskey(line_length_mapping, line_name)
                distance = line_length_mapping[line_name]
            else
                error("Line name ", line_name, " not found in length mapping")
            end
            cap_val = distance * 4524 * (1 + 0.2 * (rand() - 0.5))
            cost = cap_val * (0.044) / (1 - (1 + 0.044)^(-60))
            myinputs["pC_Line_Reinforcement"][i + L_exist] = cost
            if get_existing_capacity_mw(p, lines[i]) > 200
                push!(CANNOT_RETIRE_LINES, i)
                push!(RECONDUCTOR_LINES, i)
                existing_to_cand_map[i] = L_exist + i
                myinputs["pC_Line_Reconductor_Low"][i] = cost .* 0.3
                myinputs["pC_Line_Reconductor_High"][i] = cost .* 0.7
                myinputs["Line_Reinforcement_Cap_Size"][L_exist + i] *= 1.5
                myinputs["pDC_OPF_coeff"][L_exist + i] *= 1.5
            else
                push!(CAN_RETIRE_LINES, i)
                existing_to_cand_map[i] = L_exist + i
                myinputs["Line_Reinforcement_Cap_Size"][L_exist + i] *= 2.5
                myinputs["pDC_OPF_coeff"][L_exist + i] *= 2.5
            end
        end
    else
        for i in 1:length(lines)
            #check for reconductoring; 

            distance = 60 * rand()
            cap_val = distance * 1200
            cost = cap_val * (0.044) / (1 - (1 + 0.044)^(-60))
            myinputs["pC_Line_Reinforcement"][i + L_exist] = cost

            if get_existing_capacity_mw(p, lines[i]) > 200
                push!(CANNOT_RETIRE_LINES, i)
                push!(RECONDUCTOR_LINES, i)
                existing_to_cand_map[i] = L_exist + i
                myinputs["pC_Line_Reconductor_Low"][i] = cost .* 0.3
                myinputs["pC_Line_Reconductor_High"][i] = cost .* 0.7
                myinputs["Line_Reinforcement_Cap_Size"][L_exist + i] *= 1.5
                myinputs["pDC_OPF_coeff"][L_exist + i] *= 1.5
            else
                push!(CAN_RETIRE_LINES, i)
                existing_to_cand_map[i] = L_exist + i
                myinputs["Line_Reinforcement_Cap_Size"][L_exist + i] *= 2.5
                myinputs["pDC_OPF_coeff"][L_exist + i] *= 2.5
            end
        end
    end

    if add_new_corridors
        pD = myinputs["pD"]
        pD_by_node = sum(pD, dims = 1)[:]
        zone_idx_set = Dict(1 => [], 2 => [], 3 => [])
        for i in 1:length(buses)
            push!(zone_idx_set[zone_map[i]], i)
        end

        generating_cap = zeros(length(buses))
        for (i, r) in enumerate(myinputs["RESOURCES"])
            if !(GenX.new_build(r))
                node_id = GenX.zone_id(r)
                generating_cap[node_id] = GenX.existing_cap_mw(r)
            end
        end

        adj_list = build_network_adjacency_list(myinputs["pNet_Map"])
        pNet_Map = myinputs["pNet_Map"]

        Random.seed!(12345)
        for i in 1:3
            nodes = zone_idx_set[i]
            pD_in_zone = pD_by_node[nodes]
            generating_cap_in_zone = generating_cap[nodes]

            zone_max_demand = argmax(pD_in_zone)
            overall_demand_node = nodes[zone_max_demand]

            max_generation = sortperm(generating_cap_in_zone, rev = true)

            lines_added = [0.]
            next_index = [1]
            while lines_added[1] < 2
                next_node = max_generation[next_index[1]]
                overall_next_node = nodes[next_node]
                if overall_next_node == overall_demand_node
                    println("nodes are the same")
                end
                if !([overall_demand_node, overall_next_node] in adj_list) && !([overall_next_node, overall_demand_node] in adj_list) && overall_next_node != overall_demand_node
                    new_line = zeros(1, 73)
                    new_line[overall_next_node] = -1
                    new_line[overall_demand_node] = 1
                    pNet_Map = vcat(pNet_Map, new_line)
                    lines_added[1] += 1
                    println(overall_next_node)
                    println(overall_demand_node)

                    # Add data...
                    push!(myinputs["pPercent_Loss"], 0)
                    push!(myinputs["pTrans_Max"], 0)
                    push!(myinputs["pDC_OPF_coeff"], 2040.8)
                    push!(myinputs["Line_Angle_Limit"], pi / 12)
                    push!(myinputs["Max_Trans_Cap"], 1)
                    push!(myinputs["Line_Reinforcement_Cap_Size"], 500)
                    push!(myinputs["CANDIDATE_LINES"], myinputs["L_exist"] + length(myinputs["CANDIDATE_LINES"]) + 1)
                    if haskey(myinputs, "pC_Line_Reconductor_Low")
                        push!(myinputs["pC_Line_Reconductor_Low"], 0)
                    end
                    if haskey(myinputs, "pC_Line_Reconductor_High")
                        push!(myinputs["pC_Line_Reconductor_High"], 0)
                    end

                    if use_official_lengths
                        if lines_added[1] == 1
                            distance = 50 + rand() * 20
                            cap_val = distance * 4524
                            annuitized_cost = cap_val * (0.044) / (1 - (1 + 0.044)^(-60))
                            push!(myinputs["pC_Line_Reinforcement"], annuitized_cost)
                        else
                            distance = 35 + rand() * 10 
                            cap_val = distance * 4524
                            annuitized_cost = cap_val * (0.044) / (1 - (1 + 0.044)^(-60))
                            push!(myinputs["pC_Line_Reinforcement"], annuitized_cost)
                        end
                    else
                        if lines_added[1] == 1
                            distance = 50 + rand() * 20
                            cap_val = distance * 1500
                            annuitized_cost = cap_val * (0.044) / (1 - (1 + 0.044)^(-60))
                            push!(myinputs["pC_Line_Reinforcement"], annuitized_cost)
                        else
                            distance = 30 + rand() * 10 
                            cap_val = distance * 1500
                            annuitized_cost = cap_val * (0.044) / (1 - (1 + 0.044)^(-60))
                            push!(myinputs["pC_Line_Reinforcement"], annuitized_cost)
                        end
                    end
                end
                next_index[1] += 1
            end
        end
        myinputs["pNet_Map"] = pNet_Map
        myinputs["L_cand"] += 6
    end

    myinputs["CAN_RETIRE_LINES"] = CAN_RETIRE_LINES
    myinputs["CANNOT_RETIRE_LINES"] = CANNOT_RETIRE_LINES
    myinputs["RECONDUCTOR_LINES"] = RECONDUCTOR_LINES
    myinputs["existing_to_cand_map"] = existing_to_cand_map
    myinputs["L_cand"] = length(myinputs["CANDIDATE_LINES"])

    myinputs["hours_per_subperiod"] = T
    myinputs["INTERIOR_SUBPERIODS"] = [i for i in 2:myinputs["hours_per_subperiod"]]
    myinputs["T"] = T
    myinputs["pD"] .*= demand_scale
    myinputs["L"] = myinputs["L_exist"] + myinputs["L_cand"]

    L_exist = myinputs["L_exist"]
    L_cand = myinputs["L_cand"]
    BigM = zeros((L_exist + L_cand))
    BigM[1:L_exist] .= myinputs["pTrans_Max"][1:L_exist]
    BigM[(1+L_exist):(L_exist+L_cand)] .= myinputs["Line_Reinforcement_Cap_Size"][(1+L_exist):(L_exist+L_cand)]

    if haskey(myinputs, "RECONDUCTOR_LINES")
        if haskey(myinputs, "existing_to_cand_map")
            for k in keys(myinputs["existing_to_cand_map"])

                cline = myinputs["existing_to_cand_map"][k]
                if k in myinputs["RECONDUCTOR_LINES"]
                    BigM[k] = 1.25 * BigM[k]
                    BigM[cline] = 1.25 * BigM[cline]
                end
            end
        end
    end
    if add_new_corridors
        BigM[(L_exist * 2 + 1):(L_exist * 2 + 6)] .*= 10
    end
    myinputs["BigM"] = BigM
end

function load_no_candidates(myinputs, T=168; demand_scale = 2)
    # myinputs["pTrans_Max"] .*= 2
    #myinputs["pD"] .*= 1
    # myinputs["Voll"] .*= 10
    myinputs["pTrans_Max"] .*= 1
    #myinputs["pTrans_Max"][[5,23,24,70,75]] .*= 1/70
    L = myinputs["L"]
    L_exist = L
    #L_cand = L
    myinputs["L_cand"] = 0
    myinputs["L_exist"] = L_exist
    myinputs["L"] = L_exist
    myinputs["Z_cand"] = myinputs["Z"]
    myinputs["pNet_Map"] = vcat(myinputs["pNet_Map"])
    myinputs["pDC_OPF_coeff"] = vcat(myinputs["pDC_OPF_coeff"])
    myinputs["Line_Angle_Limit"] = [pi / 12 for i in 1:myinputs["L"]]
    myinputs["Line_Reinforcement_Cap_Size"] = vcat([0 for i in 1:L_exist], [i for i in myinputs["pTrans_Max"]])
    myinputs["Max_Trans_Cap"] = vcat([0 for i in 1:L_exist], [1 for i in myinputs["pTrans_Max"]])
    L_cand = 0
    myinputs["pTrans_Max"] = vcat([i for i in myinputs["pTrans_Max"]], [0 for i in 1:L_cand])



    EXPANSION_LEVELS = Dict{Int, Vector}()
    for i in (L_exist + 1):(L_exist + L_cand)
        EXPANSION_LEVELS[i] = (0:1:myinputs["Max_Trans_Cap"][i])
    end
    EXPANSION_LINES = [i for i in (L_exist + 1):(L_exist + L_cand)]
    myinputs["EXPANSION_LINES"] = EXPANSION_LINES
    myinputs["CANDIDATE_LINES"] = []
    myinputs["EXISTING_LINES"] = [i for i in 1:L_exist]
    myinputs["pPercent_Loss"] = vcat(myinputs["pPercent_Loss"])

    lines = collect(get_technologies(TransmissionTechnology, p));
    myinputs["pC_Line_Reinforcement"] = zeros(myinputs["L"])
    myinputs["pC_Line_Reconductor_High"] = zeros(myinputs["L"])
    myinputs["pC_Line_Reconductor_Low"] = zeros(myinputs["L"])

    scale_factor = mysetup["ParameterScale"] == 1 ? GenX.ModelScalingFactor : 1

    CAN_RETIRE_LINES = Int[]
    CANNOT_RETIRE_LINES = Int[]
    RECONDUCTOR_LINES = Int[]
    existing_to_cand_map = Dict()

        #myinputs["pDC_OPF_coeff"] .*= 2000 #2000
    # myinputs["pDC_OPF_coeff"] .*= 100 #2000

    myinputs["CAN_RETIRE_LINES"] = CAN_RETIRE_LINES
    myinputs["CANNOT_RETIRE_LINES"] = CANNOT_RETIRE_LINES
    myinputs["RECONDUCTOR_LINES"] = RECONDUCTOR_LINES
    myinputs["existing_to_cand_map"] = existing_to_cand_map

    myinputs["hours_per_subperiod"] = T
    myinputs["INTERIOR_SUBPERIODS"] = [i for i in 2:myinputs["hours_per_subperiod"]]
    myinputs["T"] = T
    myinputs["pD"] .*= demand_scale
end

vom_dict = Dict("CC" => 2.12, "CT" => 6.94, "STEAM" => 9.18, "NUCLEAR" => 2.8, "PV" => 0, "CSP" => 3.0, "WIND" => 0)
#fom_dict = Dict("CC" => 33500, "CT" => 33500, "STEAM" => 33500, "NUCLEAR" => 175000, "PV" => 22000, "CSP" => 74000, "WIND" => 31000)
fom_dict = Dict("CC" => 33500, "CT" => 26000, "STEAM" => 33500, "NUCLEAR" => 175000, "PV" => 22000, "CSP" => 55000, "WIND" => 31000)
startup_dict = Dict("CC" => 92, "CT" => 119, "STEAM" => 124, "NUCLEAR" => 248, "PV" => 0, "CSP" => 0, "WIND" => 0)

function add_om_costs(p)
    techs = collect(get_technologies(ResourceTechnology, p))

    for t in techs
        if isa(t, StorageTechnology)
            continue
        end
        op_cost = t.operation_costs.variable

        key_val = [""]
        for key in keys(vom_dict)
            if occursin(key, t.name)
                key_val[1] = key
                break
            end
        end
        if key_val[1] == ""
            error("Technology of name $(t.name) does not have a corresponding dictionary pairing")
        end
        vom_val = vom_dict[key_val[1]]
        fom_val = fom_dict[key_val[1]]
        startup_val = startup_dict[key_val[1]]
        if isa(op_cost, CostCurve)
            new_cc = CostCurve(LinearCurve(LinearFunctionData(0, fom_val)), op_cost.power_units, LinearCurve(LinearFunctionData(vom_val, 0)))
            t.operation_costs.variable = new_cc
        elseif isa(op_cost, FuelCurve)
            new_fc = FuelCurve(op_cost.value_curve, op_cost.power_units, op_cost.fuel_cost, op_cost.startup_fuel_offtake, LinearCurve(LinearFunctionData(vom_val, 0)))
            t.operation_costs.variable = new_fc
            t.operation_costs.fixed = fom_val
            t.operation_costs.start_up = Float64(startup_val)
        else
            error("Variable Costs are of type , ", typeof(op_cost))
        end
    end
end

inv_cost_dict = Dict("CC" => 144000, "CT" => 130000, "STEAM" => 441000, "NUCLEAR" => 830000, "PV" => 120000, "CSP" => 347000, "WIND" => 160000)
# inv_cost_dict = Dict("CC" => 144000, "CT" => 130000, "STEAM" => 441000, "NUCLEAR" => 830000, "PV" => 84000, "CSP" => 347000, "WIND" => 160000)

function update_fuel_and_investment_costs(myinputs)
    myinputs["fuel_costs"]

    for k in keys(myinputs["fuel_costs"])
        if occursin("NATURAL_GAS", k)
            myinputs["fuel_costs"][k] .= 3.88722
        elseif occursin("NUCLEAR", k)
            myinputs["fuel_costs"][k] .= 0.810
        elseif occursin("COAL", k)
            myinputs["fuel_costs"][k] .= 2.11399
        elseif occursin("DISTILLATE", k)
            myinputs["fuel_costs"][k] .= 10.3494
        end
    end

    for (i, r) in enumerate(myinputs["RESOURCES"])
        if isa(r, GenX.Storage)
            continue
        end

        key_val = [""]
        for key in keys(inv_cost_dict)
            if occursin(key, GenX.resource_name(r))
                key_val[1] = key
                break
            end
        end
        if key_val[1] == ""
            error("Technology of name $(GenX.resource_name(r)) does not have a corresponding dictionary pairing")
        end
        inv_cost = inv_cost_dict[key_val[1]]
        parent(r)[:inv_cost_per_mwyr] = inv_cost

        if isa(r, GenX.Thermal)
            fuel = GenX.fuel(r)
            parent(r)[:fuel_costs] = myinputs["fuel_costs"][fuel][1]
        end
    end
end

function map_generator_to_node(inputs::Dict, node_to_zone_map::Dict, num_zones::Int)
    # node_to_zone_map is a node index to zone index
    resources = inputs["RESOURCES"]
    zone_to_generator_map = Dict{Int, Vector{Int}}()
    generator_to_zone_map = Dict{Int, Int}()
    generator_to_node_map = Dict{Int, Int}()
    for i in 1:num_zones
        zone_to_generator_map[i] = Int[]
    end 
    for r in resources
        r_dict = parent(r)
        zone = node_to_zone_map[r_dict[:zone]]
        push!(zone_to_generator_map[zone], r_dict[:id])
        generator_to_zone_map[r_dict[:id]] = zone
        generator_to_node_map[r_dict[:id]] = r_dict[:zone]
    end

    return generator_to_zone_map, zone_to_generator_map, generator_to_node_map
end


function build_nodal_adjacency_matrix(adj_mat::Matrix, node_to_zone_map::Dict, node_to_node_map::Dict, zone::Int)
    adj_list = build_network_adjacency_list(adj_mat)

    #shortened_adj_list = Vector{Vector{Int}}()
    new_adj_list = Vector{Vector{Int}}()
    line_to_line_map = Dict{Int, Int}()
    line_list = Vector{Int}()

    for (i, edge) in enumerate(adj_list)
        src, dst = edge
        src_zone = node_to_zone_map[src]
        dst_zone = node_to_zone_map[dst]

        if src_zone == zone && dst_zone == zone
            #push!(shortened_adj_list, edge)
            new_edge = [node_to_node_map[src], node_to_node_map[dst]]
            push!(new_adj_list, new_edge)
            push!(line_list, i)
            line_to_line_map[i] = length(new_adj_list)
        end
    end

    new_adj_mat = zeros(Int, length(new_adj_list), length(node_to_node_map))
    for (i, edge) in enumerate(new_adj_list)
        new_adj_mat[i, edge[1]] = -1
        new_adj_mat[i, edge[2]] = 1
    end

    return new_adj_mat, new_adj_list, line_list, line_to_line_map
end

function build_single_nodal_input(inputs::Dict, node_to_zone_map::Dict, zone::Int, zone_to_generator_map::Dict, node_to_node_map::Dict)
    nodal_inputs = deepcopy(inputs)
    nodes_in_zone = sort(collect(keys(node_to_node_map))) #index of original node numbers
    num_nodes = length(node_to_node_map)
    nodal_inputs["N"] = num_nodes
    nodal_inputs["nodes_in_zone"] = nodes_in_zone
    nodal_inputs["n2n_map"] = node_to_node_map

    resources = nodal_inputs["RESOURCES"]
    resource_names = nodal_inputs["RESOURCE_NAMES"]
    nodal_resources = Vector{GenX.AbstractResource}()
    gen_to_gen_map = Dict{Int, Int}() # maps original generator id to new generator id

    nodal_resource_names = Vector{String}()
    nodal_resource_zones = Vector{String}()
    nodal_r_zones = Vector()
    generator_list = zone_to_generator_map[zone]
    nodal_inputs["G"] = length(generator_list)
    pP_Max = inputs["pP_Max"]
    new_pP_Max_data = zeros(nodal_inputs["G"], size(pP_Max, 2))
    g2n_map = Dict()
    n2g_map = Dict()
    for (i, g_idx) in enumerate(generator_list)
        next_resource = resources[g_idx]
        resource_name = resource_names[g_idx]
        g_dict = parent(next_resource)
        original_node = g_dict[:zone]
        original_id = g_dict[:id]
        gen_to_gen_map[original_id] = i
        new_zone = node_to_node_map[original_node]
        g_dict[:zone] = new_zone
        g_dict[:id] = i

        new_pP_Max_data[i, :] .= pP_Max[original_id, :]
        g2n_map[g_idx] = i
        n2g_map[i] = g_idx
        push!(nodal_resources, next_resource)
        push!(nodal_resource_names, resource_name)
        push!(nodal_resource_zones, resource_name * "_z" * string(new_zone))
        push!(nodal_r_zones, new_zone)
    end
    nodal_inputs["g2n_map"] = g2n_map
    nodal_inputs["n2g_map"] = n2g_map
    nodal_inputs["RESOURCES"] = nodal_resources
    nodal_inputs["RESOURCE_NAMES"] = nodal_resource_names
    nodal_inputs["RESOURCE_ZONES"] = nodal_resource_zones
    nodal_inputs["R_ZONES"] = nodal_r_zones
    nodal_inputs["Z"] = num_nodes
    nodal_inputs["pP_Max"] = new_pP_Max_data
    old_generator_indices = sort(collect(keys(gen_to_gen_map)))

    # these keys are all vectors of generator indices
    generator_data_keys = [
        "THERM_NO_COMMIT",
        "COMMIT",
        "THERM_ALL",
        "THERM_COMMIT",
        "THERM_COMMIT_PWFU",
        "MUST_RUN",
        "HAS_FUEL",
        "MULTI_FUELS",
        "SINGLE_FUEL",
        "FLEX",
        "CCS",
        "STOR_ALL",
        "STOR_SHORT_DURATION",
        "STOR_LONG_DURATION",
        "STOR_SYMMETRIC",
        "STOR_ASYMMETRIC",
        "STOR_HYDRO_SHORT_DURATION",
        "STOR_HYDRO_LONG_DURATION",
        "HYDRO_RES",
        "VRE_STOR",
        "VRE",
        "ELECTROLYZER",
        "HYDRO_RES_KNOWN_CAP",
        "RETROFIT_CAP",
        "RET_CAP",
        "NEW_CAP",
        "NEW_CAP_ENERGY",
        "RET_CAP_ENERGY",
        "RET_CAP_CHARGE",
        "NEW_CAP_CHARGE"
    ]

    for key in generator_data_keys
        if haskey(inputs, key)
            generator_data = inputs[key]
            new_generator_data = Vector{Int}()
            for g in generator_data
                if g in keys(gen_to_gen_map)
                    push!(new_generator_data, gen_to_gen_map[g])
                end
            end
            nodal_inputs[key] = new_generator_data
        end
    end

    # these keys are matrices
    generator_matrix_keys = [
        "C_Start"
    ]

    for key in generator_matrix_keys
        if haskey(inputs, key)
            generator_matrix = inputs[key]

            new_generator_matrix = generator_matrix[old_generator_indices, :]
            nodal_inputs[key] = new_generator_matrix
        end
    end

    new_adj_mat, new_adj_list, line_list, l2l_map = build_nodal_adjacency_matrix(inputs["pNet_Map"], node_to_zone_map, node_to_node_map, zone)

    nodal_inputs["pNet_Map"] = new_adj_mat
    nodal_inputs["pNet_Adj_List"] = new_adj_list
    nodal_inputs["line_list"] = line_list
    nodal_inputs["l2l_map"] = l2l_map
    nodal_inputs["L"] = length(new_adj_list)
    
    line_keys = [ "pPercent_Loss", "pTrans_Loss_Coeff", "pTrans_Max", "pDC_OPF_coeff", "Line_Angle_Limit", "pDC_OPF_coeff_cand", "Line_Angle_Limit_cand", "Line_Reinforcement_Cap_Size", "pC_Line_Reinforcement", "Max_Trans_Cap", "BigM"] # "pTrans_Max_Possible",

    for key in line_keys
        if haskey(inputs, key)
            new_data = Real[]
            for i in line_list
                push!(new_data, inputs[key][i])
            end
            nodal_inputs[key] = new_data
        end
    end

    
    nodal_inputs["pD"] = inputs["pD"][:, nodes_in_zone]

    EXISTING_LINES = Int[]
    CANDIDATE_LINES = Int[]
    RECONDUCTOR_LINES = Int[]
    CANNOT_RETIRE_LINES = Int[]
    CAN_RETIRE_LINES = Int[]
    existing_to_cand_map = Dict()

    l2l_map_rev = Dict()
    for i in keys(l2l_map)
        l2l_map_rev[l2l_map[i]] = i
    end
    nodal_inputs["l2l_map_rev"] = l2l_map_rev

    for l in sort(collect(keys(l2l_map_rev)))
        old_line = l2l_map_rev[l]
        if old_line in inputs["EXISTING_LINES"]
            push!(EXISTING_LINES, l)
        end
        if old_line in inputs["CANDIDATE_LINES"]
            push!(CANDIDATE_LINES, l)
        end
        if old_line in inputs["RECONDUCTOR_LINES"]
            push!(RECONDUCTOR_LINES, l)
        end
        if old_line in inputs["CANNOT_RETIRE_LINES"]
            push!(CANNOT_RETIRE_LINES, l)
            if haskey(inputs["existing_to_cand_map"], old_line)
                old_cand_line = inputs["existing_to_cand_map"][old_line]
                cand_line_replacement = l2l_map[old_cand_line]
                existing_to_cand_map[l] = cand_line_replacement
            end
        end
        if old_line in inputs["CAN_RETIRE_LINES"]
            push!(CAN_RETIRE_LINES, l)
            old_cand_line = inputs["existing_to_cand_map"][old_line]
            cand_line_replacement = l2l_map[old_cand_line]
            existing_to_cand_map[l] = cand_line_replacement
        end
    end

    nodal_inputs["EXISTING_LINES"] = EXISTING_LINES
    nodal_inputs["CANDIDATE_LINES"] = CANDIDATE_LINES
    nodal_inputs["RECONDUCTOR_LINES"] = RECONDUCTOR_LINES
    nodal_inputs["CANNOT_RETIRE_LINES"] = CANNOT_RETIRE_LINES
    nodal_inputs["CAN_RETIRE_LINES"] = CAN_RETIRE_LINES
    nodal_inputs["existing_to_cand_map"] = existing_to_cand_map
    nodal_inputs["L_exist"] = length(EXISTING_LINES)
    nodal_inputs["L_cand"] = length(CANDIDATE_LINES)
    nodal_inputs["L"] = length(EXISTING_LINES) + length(CANDIDATE_LINES)

    @assert nodal_inputs["L"] == size(nodal_inputs["pNet_Map"], 1)

    return nodal_inputs
end

function build_nodal_inputs(inputs::Dict, node_to_zone_map::Dict, num_zones::Int)
    g2z_map, z2g_map, g2n_map = map_generator_to_node(inputs, node_to_zone_map, num_zones)

    zone_to_node_map = Dict{Int, Vector{Int}}() # map each zone to the vector of its nodes
    node_to_node_map_by_zone = Dict{Int, Dict{Int, Int}}()
    for i in 1:num_zones
        zone_to_node_map[i] = Int[]
    end
    for (node, zone) in node_to_zone_map
        push!(zone_to_node_map[zone], node)
    end
    for zone in keys(zone_to_node_map)
        node_to_node_map = Dict{Int, Int}() # maps the original node index to the NEW node index
        z2n_vector = sort(zone_to_node_map[zone]) # sorted vector of nodes in the zone
        zone_to_node_map[zone] = z2n_vector # reset value to be sorted

        for (i, idx) in enumerate(z2n_vector)
            node_to_node_map[idx] = i
        end
        node_to_node_map_by_zone[zone] = node_to_node_map
    end
    nodal_inputs = Dict{Int, Dict}()

    for i in 1:num_zones
        nodal_inputs[i] = build_single_nodal_input(inputs, node_to_zone_map, i, z2g_map, node_to_node_map_by_zone[i])
    end

    return nodal_inputs
end