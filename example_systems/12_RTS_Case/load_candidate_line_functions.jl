line_data = CSV.read((@__DIR__)*"/edge_map.csv", DataFrame)
line_names = line_data[!, "Name"]
line_lengths = line_data[!, "Length_for_multiplier"]
line_length_mapping = Dict([line_names[i] => line_lengths[i] for i in 1:length(line_names)])

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
    myinputs["Line_Angle_Limit"] = [6.282 for i in 1:myinputs["L"]]
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
                    push!(myinputs["Line_Angle_Limit"], 6.282)
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
    myinputs["Line_Angle_Limit"] = [6.282 for i in 1:myinputs["L"]]
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

# for t in techs
#     if has_time_series(t) && !(has_supplemental_attributes(t))
#         tkeys = get_time_series_keys(t)
#         vom_key = [""]
#         for k in tkeys
#             if occursin("fom", k.name) || occursin("ixed", k.name)
#             # if occursin("vom", k.name) || occursin("Var", k.name)
#                 vom_key[1] = k.name
#                 break
#             end
#         end
#         if vom_key[1] == ""
#             println()
#             println()
#             println(t.name, "    ", length(tkeys), "   ", tkeys)
#             println()
#             println()
            
#         else
#             tvalues = get_time_series_values(SingleTimeSeries, t, vom_key[1])
#             vom_val = tvalues[16]
#             println(t.name, "   ", vom_val)
#             if vom_val == 0
#                 println("ZERO VALUE FOR ", t.name)
#             end
#             push!(voms, vom_val)
#         end
        
#     end
# end
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
        :ccs_disposal_cost_per_metric_ton, :hydrogen_mwh_per_tonne       # to GWh/t
    ]
function scale_resource(resource, scale_factor)
    
    resource_dict = parent(resource)
    for col in columns_to_scale
        if haskey(resource_dict, col)
            resource_dict[col] /= scale_factor
        end
    end
end


function scale_inputs(inputs::Dict, scale_factor = GenX.ModelScalingFactor)
    keys_to_scale = ["pD", "pC_D_curtail", "pTrans_Max_Possible", "pMax_Line_Reinforcement", "pMax_D_Curtail", "pC_Line_Reconductor_High", "pC_Line_Reconductor_Low", "pC_Line_Reinforcement", "Line_Reinforcement_Cap_Size", "pTrans_Max", "C_Start"]
    
    for k in keys_to_scale
        if haskey(inputs, k)
            inputs[k] ./= scale_factor
        end
    end

    for k in keys(inputs["fuel_costs"])
        inputs["fuel_costs"][k] ./= scale_factor
    end

    for r in inputs["RESOURCES"]
        scale_resource(r, scale_factor)
    end
    # "pC_D_Curtail"
# "pTrans_Max_Possible" #only used for losses and multistage; not necessary for now; not loaded properly for now
# "pMax_Line_Reinforcement" # only used for the non DCOPF, integer case
# "pMax_D_Curtail" - I don't think we need this one, but probably should check its role
# "MinCapReq
# "pC_Line_Reconductor_High"
# "pC_Line_Reconductor_Low"
# "fuel_costs"
# "pC_Line_Reinforcement"
# "Line_Reinforcement_Cap_Size
# "pTrans_Max"
# "RESOURCES"
end