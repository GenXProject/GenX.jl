@doc raw"""
    load_network_data!(setup::Dict, path::AbstractString, inputs_nw::Dict)

Function for reading input parameters related to the electricity transmission network
"""
function load_network_data!(setup::Dict, path::AbstractString, inputs_nw::Dict, filename::AbstractString = "Network.csv")
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    network_var = load_dataframe(joinpath(path, filename))

    as_vector(col::Symbol) = collect(skipmissing(network_var[!, col]))
    to_floats(col::Symbol) = convert(Array{Float64}, as_vector(col))

    # Number of zones in the network
    Z = maximum([length(as_vector(:Network_zones)), maximum(as_vector(:End_Zone))])
    inputs_nw["Z"] = Z
    # Number of lines in the network
    L = length(as_vector(:Network_Lines))
    inputs_nw["L"] = L

    candidate_flag = false
    if setup["DC_OPF"] == 1
        if isfile(joinpath(path, "Candidate_line.csv"))
            # Read candidate line data if it exists
            candidate_network_path = joinpath(path, "Candidate_line.csv")
            candidate_network_var = load_dataframe(candidate_network_path)
            candidate_flag = true
        else
            candidate_network_var = nothing
            @warn("Candidate line data not found. Proceeding with existing network data. 
            Because the DC_OPF flag is active and Candidate_line.csv is missing, GenX will not allow any transmission capacity expansion. 
            Set the DC_OPF flag to 0 if you want to optimize tranmission capacity expansion.")
        end
    else
        candidate_network_var = nothing
    end

    if candidate_flag
        as_vector_cand(col::Symbol) = collect(skipmissing(candidate_network_var[!, col]))
        to_floats_cand(col::Symbol) = convert(Array{Float64}, as_vector_cand(col))
        # Number of zones in the candidate network
        Z_cand = maximum([length(as_vector_cand(:Network_zones)), maximum(as_vector_cand(:End_Zone))])
        inputs_nw["Z_cand"] = Z_cand
        # Number of lines in the network
        L_cand = length(as_vector_cand(:Network_Lines))
        inputs_nw["L_cand"] = L_cand
        inputs_nw["pNet_Map_cand"] = load_network_map(candidate_network_var, Z_cand, L_cand)
    end

    # Topology of the network source-sink matrix
    inputs_nw["pNet_Map"] = load_network_map(network_var, Z, L)

    if candidate_flag
        # Number of zones in the candidate network
        Z_cand = length(as_vector_cand(:Network_zones))
        inputs_nw["Z_cand"] = Z_cand
        # Number of lines in the network
        L_cand = length(as_vector_cand(:Network_Lines))
        inputs_nw["L_cand"] = L_cand
        inputs_nw["pNet_Map_cand"] = load_network_map(candidate_network_var, Z_cand, L_cand)
    end

    # Transmission capacity of the network (in MW)
    #inputs_nw["pTrans_Max"] = zeros(Float64, L_cand)
    if !candidate_flag
        inputs_nw["pTrans_Max"] = to_floats(:Line_Max_Flow_MW) / scale_factor  # convert to GW
    else
        inputs_nw["pTrans_Max"] = create_extended_max_flow_vector(network_var, candidate_network_var) / scale_factor
    end
    
    # Loss of the existing lines in the network (in MW)
    if setup["Trans_Loss_Segments"] == 1
        # Line percentage Loss - valid for case when modeling losses as a fixed percent of absolute value of power flows
        inputs_nw["pPercent_Loss"] = to_floats(:Line_Loss_Percentage)
    elseif setup["Trans_Loss_Segments"] >= 2
        # Transmission line voltage (in kV)
        inputs_nw["kV"] = to_floats(:Line_Voltage_kV)
        # Transmission line resistance (in Ohms) - Used when modeling quadratic transmission losses
        inputs_nw["Ohms"] = to_floats(:Line_Resistance_Ohms)
    end

    if candidate_flag
        # Loss of the candidate lines in the network (in MW)
        if setup["Trans_Loss_Segments"] == 1
            # Line percentage Loss - valid for case when modeling losses as a fixed percent of absolute value of power flows
            inputs_nw["pPercent_Loss_cand"] = to_floats_cand(:Line_Loss_Percentage)
        elseif setup["Trans_Loss_Segments"] >= 2
            # Transmission line voltage (in kV)
            inputs_nw["kV_cand"] = to_floats_cand(:Line_Voltage_kV)
            # Transmission line resistance (in Ohms) - Used when modeling quadratic transmission losses
            inputs_nw["Ohms_cand"] = to_floats_cand(:Line_Resistance_Ohms)
        end
    end

    ## Inputs for the DC-OPF 
    if setup["DC_OPF"] == 1
        println("Reading DC-OPF values...")
        
        # Transmission line voltage (in kV)
        line_voltage_kV = to_floats(:Line_Voltage_kV)
        # Transmission line reactance (in Ohms)
        line_reactance_Ohms = to_floats(:Line_Reactance_Ohms)
        # Line angle limit (in radians)
        inputs_nw["Line_Angle_Limit"] = to_floats(:Angle_Limit_Rad)
        # DC-OPF coefficient for each line (in MW when not scaled, in GW when scaled) 
        # MW = (kV)^2/Ohms 
        inputs_nw["pDC_OPF_coeff"] = ((line_voltage_kV .^ 2) ./ line_reactance_Ohms) /
                                    scale_factor
                                    
        if candidate_flag
            # Transmission line voltage (in kV)
            line_voltage_kV_cand = to_floats_cand(:Line_Voltage_kV)
            # Transmission line reactance (in Ohms)
            line_reactance_Ohms_cand = to_floats_cand(:Line_Reactance_Ohms)
            # Line angle limit (in radians)
            inputs_nw["Line_Angle_Limit_cand"] = to_floats_cand(:Angle_Limit_Rad)
            # DC-OPF coefficient for each line (in MW when not scaled, in GW when scaled) 
            # MW = (kV)^2/Ohms 
            if setup["ParameterScale"] == 1
                # DC-OPF coefficient for each line (in MW when not scaled, in GW when scaled) 
                # MW = (kV)^2/Ohms 
                inputs_nw["pDC_OPF_coeff_cand"] = ((line_voltage_kV_cand .^ 2) ./ line_reactance_Ohms_cand) /
                                        scale_factor
            else
                # DC-OPF coefficient for each line (in MW when not scaled, in GW when scaled) 
                # MW = (kV)^2/Ohms 
                inputs_nw["pDC_OPF_coeff_cand"] = (1 ./ line_reactance_Ohms_cand)
            end
            # Transmission line candidate expansion capacity (in MW)
            # DC-OPF transmission capacity (in MW) expansion data:
            inputs_nw["Line_Reinforcement_Cap_Size"] = to_floats_cand(:pMax_quantized_MW) /
                                                                                        scale_factor # convert to GW
            inputs_nw["Max_Trans_Cap"] = calculate_integer_quotients(candidate_network_var)
            old_max_trans_cap = copy(inputs_nw["Max_Trans_Cap"])
            new_max_trans_cap = Dict()
            for (i, l) in enumerate((L + 1):(L_cand + L))
                new_max_trans_cap[l] = old_max_trans_cap[i]
            end
            inputs_nw["Max_Trans_Cap"] = new_max_trans_cap
        end

        
        println("DC-OPF values successfully read!")
    end

    # Maximum possible flow after reinforcement for use in linear segments of piecewise approximation
    inputs_nw["pTrans_Max_Possible"] = inputs_nw["pTrans_Max"]

    if setup["NetworkExpansion"] == 1 && !candidate_flag
        # Read between zone network reinforcement costs per peak MW of capacity added
        inputs_nw["pC_Line_Reinforcement"] = to_floats(:Line_Reinforcement_Cost_per_MWyr) /
                                             scale_factor # convert to million $/GW/yr with objective function in millions
        # Maximum reinforcement allowed in MW
        #NOTE: values <0 indicate no expansion possible
        inputs_nw["pMax_Line_Reinforcement"] = map(x -> max(0, x),
            to_floats(:Line_Max_Reinforcement_MW)) / scale_factor # convert to GW
        inputs_nw["pTrans_Max_Possible"] += inputs_nw["pMax_Line_Reinforcement"]
    elseif setup["NetworkExpansion"] == 1 && candidate_flag
            # Read between zone network reinforcement costs per peak MW of capacity added
            inputs_nw["pC_Line_Reinforcement"] = to_floats_cand(:Line_Reinforcement_Cost_per_MWyr) /
                                                 scale_factor # convert to million $/GW/yr with objective function in millions
            # Maximum reinforcement allowed in MW
            #NOTE: values <0 indicate no expansion possible
            inputs_nw["pMax_Line_Reinforcement"] = map(x -> max(0, x),
                to_floats_cand(:Line_Max_Reinforcement_MW)) / scale_factor # convert to GW
            println("Maximum line reinforcement (in GW): ", inputs_nw["pMax_Line_Reinforcement"])
            # Maximum possible flow after reinforcement for use in linear segments of piecewise approximation
            inputs_nw["pTrans_Max_Possible"] += inputs_nw["pMax_Line_Reinforcement"]
    end

    # Multi-Stage
    if setup["MultiStage"] == 1
        # Weighted Average Cost of Capital for Transmission Expansion
        if setup["NetworkExpansion"] >= 1
            inputs_nw["transmission_WACC"] = to_floats(:WACC)
            inputs_nw["Capital_Recovery_Period_Trans"] = to_floats(:Capital_Recovery_Period)
        end

        # Max Flow Possible on Each Line
        inputs_nw["pLine_Max_Flow_Possible_MW"] = to_floats(:Line_Max_Flow_Possible_MW) /
                                                  scale_factor # Convert to GW
    end

    # Transmission line (between zone) loss coefficient (resistance/voltage^2)
    inputs_nw["pTrans_Loss_Coef"] = zeros(Float64, L)
    if setup["Trans_Loss_Segments"] == 1
        inputs_nw["pTrans_Loss_Coef"] = inputs_nw["pPercent_Loss"]
    elseif setup["Trans_Loss_Segments"] >= 2
        # If zones are connected, loss coefficient is R/V^2 where R is resistance in Ohms and V is voltage in Volts
        inputs_nw["pTrans_Loss_Coef"] = (inputs_nw["Ohms"] / 10^6) ./
                                        (inputs_nw["kV"] / 10^3)^2 * scale_factor # 1/GW ***
    end

    ## Sets and indices for transmission losses and expansion
    inputs_nw["TRANS_LOSS_SEGS"] = setup["Trans_Loss_Segments"] # Number of segments used in piecewise linear approximations quadratic loss functions
    inputs_nw["LOSS_LINES"] = findall(inputs_nw["pTrans_Loss_Coef"] .!= 0) # Lines for which loss coefficients apply (are non-zero);

    if setup["NetworkExpansion"] == 1
        println("Reading Network Expansion values...")
        println(inputs_nw["pMax_Line_Reinforcement"])
        # Network lines and zones that are expandable have non-negative maximum reinforcement inputs
        inputs_nw["EXPANSION_LINES"] = findall(inputs_nw["pMax_Line_Reinforcement"] .> 0)
        inputs_nw["NO_EXPANSION_LINES"] = findall(inputs_nw["pMax_Line_Reinforcement"] .<= 0)
    end

    if candidate_flag
        build_expansion_information!(inputs_nw)
    else
        inputs_nw["EXISTING_LINES"] = [i for i in 1:L]
    end

    println(filename * " Successfully Read!")

    return network_var, candidate_network_var
end 


@doc raw"""
    load_network_data_p!(setup::Dict, p::Portfolio, inputs_nw::Dict)

Function for reading input parameters related to the electricity transmission network from portfolio
"""
function load_network_data!(setup::Dict, p::Portfolio, inputs::Dict)
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    regions = get_regions(RegionTopology, p) #FIXME: this has to be generalized to Zones
    @assert length(unique(typeof.(regions))) == 1 "All regions must either be `Zones` or `Nodes`"
        
    # DEBUG: Check what technology types are available
    println("=== DEBUGGING PORTFOLIO CONTENTS ===")
    
    # Check all available technology types - we need to try specific types
    try
        all_supply = collect(get_technologies(SupplyTechnology, p))
        println("SupplyTechnology count: ", length(all_supply))
        if !isempty(all_supply)
            println("SupplyTechnology types: ", unique(typeof.(all_supply)))
        end
    catch e
        println("No SupplyTechnology found: ", e)
    end
    
    try
        all_storage = collect(get_technologies(StorageTechnology, p))
        println("StorageTechnology count: ", length(all_storage))
        if !isempty(all_storage)
            println("StorageTechnology types: ", unique(typeof.(all_storage)))
        end
    catch e
        println("No StorageTechnology found: ", e)
    end
    
    # Try different technology types
    try
        agg_transport = collect(get_technologies(AggregateTransportTechnology, p))
        println("AggregateTransportTechnology count: ", length(agg_transport))
        if !isempty(agg_transport)
            println("AggregateTransportTechnology types: ", unique(typeof.(agg_transport)))
        end
    catch e
        println("No AggregateTransportTechnology found: ", e)
    end
    
    try
        transmission = collect(get_technologies(TransmissionTechnology, p))
        println("TransmissionTechnology count: ", length(transmission))
        if !isempty(transmission)
            println("TransmissionTechnology types: ", unique(typeof.(transmission)))
        end
    catch e
        println("No TransmissionTechnology found: ", e)
    end
    
    # Check what's actually in the portfolio at a high level
    println("Portfolio summary:")
    try
        println("  - Has supply technologies: ", has_technologies(SupplyTechnology, p))
    catch e
        println("  - Error checking supply technologies: ", e)
    end
    
    try
        println("  - Has storage technologies: ", has_technologies(StorageTechnology, p))
    catch e
        println("  - Error checking storage technologies: ", e)
    end
    
    try
        println("  - Has aggregate transport technologies: ", has_technologies(AggregateTransportTechnology, p))
    catch e
        println("  - Error checking aggregate transport technologies: ", e)
    end
    
    try
        println("  - Has transmission technologies: ", has_technologies(TransmissionTechnology, p))
    catch e
        println("  - Error checking transmission technologies: ", e)
    end
    
    println("====================================")
    
    # Try to get any technologies that exist
    agg_transport = collect(get_technologies(AggregateTransportTechnology, p))
    transmission = collect(get_technologies(TransmissionTechnology, p))
    
    # Use whichever collection has data
    lines = if !isempty(agg_transport)
        println("Using AggregateTransportTechnology")
        agg_transport
    elseif !isempty(transmission)
        println("Using TransmissionTechnology")
        transmission
    else
        error("No transmission technologies found in portfolio. Check if your portfolio has network data loaded.")
    end

    lines = [l for l in lines if PSY.has_supplemental_attributes(l, ExistingCapacity)]
    # Number of zones in the network
    Z = length(regions)
    inputs["Z"] = Z
    # Number of lines in the network
    L = length(lines)
    inputs["L"] = L
    println("Number of zones: ", Z)
    println("Number of regions: ", Z)
    println("Number of lines: ", L)
    #println("Number of transmission technologies: ", lines)
    
    # Only proceed if we have lines
    if L > 0
        # Topology of the network source-sink matrix
        mat, region_to_index, index_to_region, region_to_area = load_network_map(lines, Z, L, p)
        index_to_line = Dict{Int, String}()
        for (i, line) in enumerate(lines)
            index_to_line[i] = line.name
        end
        inputs["pNet_Map"] = mat
        inputs["region_to_index"] = region_to_index
        inputs["index_to_region"] = index_to_region
        inputs["region_to_area"] = region_to_area
        inputs["index_to_line"] = index_to_line

        # Transmission capacity of the network (in MW)
        inputs["pTrans_Max"] = [PSIP.get_existing_capacity_mw(p, l) for l in lines] / scale_factor  # convert to GW
        
        if setup["Trans_Loss_Segments"] == 1
            # Line percentage Loss - valid for case when modeling losses as a fixed percent of absolute value of power flows
            inputs["pPercent_Loss"] = [line_loss(l) for l in lines]
        elseif setup["Trans_Loss_Segments"] >= 2
            # Transmission line voltage (in kV)
            sys = p.base_system
            inputs["kV"] = [PSY.get_base_voltage(first(get_components_by_name(Bus, sys, l.start_node.name))) for l in lines]#[voltage(l) for l in lines]
            # Transmission line resistance (in Ohms) - Used when modeling quadratic transmission losses
            inputs["Ohms"] = [resistance(l) for l in lines]
        end

        println("ENTERING DCOPF")
        ## Inputs for the DC-OPF
        if setup["DC_OPF"] == 1
            println("Reading DC-OPF values...")
            # Transmission line voltage (in kV)
            sys = p.base_system
            line_voltage_kV = [PSY.get_base_voltage(first(PSY.get_components_by_name(PSY.Bus, sys, l.start_node.name))) for l in lines]#[voltage(l) for l in lines]
            # Transmission line reactance (in Ohms)
            line_reactance_Ohms = [reactance(l) for l in lines]

            for l in 1:length(lines)
                if line_voltage_kV[l] == 0
                    line_voltage_kV[l] = 10
                end
            end

            # Line angle limit (in radians)
            inputs["Line_Angle_Limit"] = [pi/12 for l in lines]
            # DC-OPF coefficient for each line (in MW when not scaled, in GW when scaled) 
            # MW = (kV)^2/Ohms 
            inputs["pDC_OPF_coeff"] = ((line_voltage_kV .^ 2) ./ line_reactance_Ohms) /
                                        scale_factor
        end

        # Maximum possible flow after reinforcement for use in linear segments of piecewise approximation
        inputs["pTrans_Max_Possible"] = inputs["pTrans_Max"]

        if setup["NetworkExpansion"] == 1
            # Read between zone network reinforcement costs per peak MW of capacity added
            inputs["pC_Line_Reinforcement"] = [line_reinforcement_cost(l) for l in lines] /
                                                scale_factor # convert to million $/GW/yr with objective function in millions
            # Maximum reinforcement allowed in MW
            #NOTE: values <0 indicate no expansion possible
            inputs["pMax_Line_Reinforcement"] = map(x -> max(0, x),
                [line_reinforcement_max(l) for l in lines]) / scale_factor # convert to GW
            inputs["pTrans_Max_Possible"] += inputs["pMax_Line_Reinforcement"]
        end

        # Multi-Stage
        # Confirm this works later when I can test a multi-stage problem
        if setup["MultiStage"] == 1
            # Weighted Average Cost of Capital for Transmission Expansion
            if setup["NetworkExpansion"] >= 1
                inputs["transmission_WACC"] = [get_wacc(l) for l in lines]
                inputs["Capital_Recovery_Period_Trans"] = [get_capital_recovery_factor(l) for l in lines]
            end

            # Max Flow Possible on Each Line
            inputs["pLine_Max_Flow_Possible_MW"] = to_floats(:Line_Max_Flow_Possible_MW) /
                                                    scale_factor # Convert to GW
        end

        # Transmission line (between zone) loss coefficient (resistance/voltage^2)
        inputs["pTrans_Loss_Coef"] = zeros(Float64, L)
        if setup["Trans_Loss_Segments"] == 1
            inputs["pTrans_Loss_Coef"] = inputs["pPercent_Loss"]
        elseif setup["Trans_Loss_Segments"] >= 2
            # If zones are connected, loss coefficient is R/V^2 where R is resistance in Ohms and V is voltage in Volts
            inputs["pTrans_Loss_Coef"] = (inputs["Ohms"] / 10^6) ./
                                            (inputs["kV"] / 10^3)^2 * scale_factor # 1/GW ***
        end

        ## Sets and indices for transmission losses and expansion
        inputs["TRANS_LOSS_SEGS"] = setup["Trans_Loss_Segments"] # Number of segments used in piecewise linear approximations quadratic loss functions
        inputs["LOSS_LINES"] = findall(inputs["pTrans_Loss_Coef"] .!= 0) # Lines for which loss coefficients apply (are non-zero);

        if setup["NetworkExpansion"] == 1
            # Network lines and zones that are expandable have non-negative maximum reinforcement inputs
            inputs["EXPANSION_LINES"] = findall(inputs["pMax_Line_Reinforcement"] .>= 0)
            inputs["NO_EXPANSION_LINES"] = findall(inputs["pMax_Line_Reinforcement"] .< 0)
        end

        println("Network Data Successfully Read!")
    else
        @warn("No transmission lines found in portfolio. Network functionality will be limited.")
        inputs["pNet_Map"] = zeros(0, Z)
        inputs["pTrans_Max"] = Float64[]
    end

    if haskey(inputs, "pNet_Map_cand")
        build_expansion_information!(inputs)
    else
        inputs["EXISTING_LINES"] = [i for i in 1:L]
    end

end

@doc raw"""
    load_network_map_port(lines::Vector{NodalACTransportTechnology}, Z, L)

Loads the network map from a list-style interface from portfolio
```
..., Network_Lines, Start_Zone, End_Zone, ...
                 1,           1,       2,
                 2,           1,       3,
```
"""
function load_network_map(lines::Vector{TransmissionTechnology}, Z, L)
    mat = zeros(L, Z)
    start_regions = [start_region(l) for l in lines]
    end_regions = [end_region(l) for l in lines]
    for l in 1:L
        mat[l, zone_id(start_regions[l])] = 1
        mat[l, zone_id(end_regions[l])] = -1
    end
    mat
end

function region_sorting(lines::Vector{TransmissionTechnology}, Z, L, p::Portfolio, inputs::Dict)
    # Sort regions based on their IDs
    sorted_regions = sort(unique([start_region(l) for l in lines] ∪ [end_region(l) for l in lines]))
    region_to_index = Dict(region => i for (i, region) in enumerate(sorted_regions))
    inputs["region_to_index"] = region_to_index
end

function load_network_map(lines::Vector{Tech}, Z, L, p::Portfolio) where {Tech<:Union{TransmissionTechnology, AggregateTransportTechnology}}
    mat = zeros(L, Z)
    start_regions = [start_region(l) for l in lines]
    end_regions = [end_region(l) for l in lines]
    
    # Get sorted region IDs for mapping
    sorted_regions = sort([i.id for i in zone_id(RegionTopology, p)])
    regions = zone_id(RegionTopology, p)

    #region_to_index = Dict(get_id(region) => i for (i, region) in enumerate(sorted_regions))

    region_to_index = Dict{Int, Int}()
    index_to_region = Dict{Int, Int}()
    region_to_area = Dict{Int, Int}()
    buses = collect(PSY.get_components(PSY.Bus, p.base_system))
    areas = unique([bus.area.name for bus in buses])
    area_map = Dict{String, Int}()
    for i in areas
        area_idx = parse(Int, match(r"\d+$", i).match)
        area_map[i] = area_idx
    end
    area_nums = sort([parse(Int, match(r"\d+$", s).match) for s in areas])
    if last(area_nums) != length(area_nums)
        @warn "area numbers on PSY buses are not consecutive"
    end

    for (i, region) in enumerate(regions)
        region_to_index[region.id] = i
        index_to_region[i] = region.id
        bus = first(PSY.get_components_by_name(PSY.Bus, p.base_system, region.name))
        area = bus.area.name
        region_to_area[region.id] = area_map[area]
    end
    
    for l in 1:L
        start_idx = region_to_index[zone_id_inter(start_regions[l])]
        end_idx = region_to_index[zone_id_inter(end_regions[l])]

        mat[l, start_idx] = 1
        mat[l, end_idx] = -1
    end
    mat, region_to_index, index_to_region, region_to_area
end

@doc raw"""
    load_network_map_from_list(network_var::DataFrame, Z, L, list_columns)

Loads the network map from a list-style interface
```
..., Network_Lines, Start_Zone, End_Zone, ...
                 1,           1,       2,
                 2,           1,       3,
```
"""
function load_network_map_from_list(network_var::DataFrame, Z, L, list_columns)
    start_col, end_col = list_columns
    mat = zeros(L, Z)
    start_zones = collect(skipmissing(network_var[!, start_col]))
    end_zones = collect(skipmissing(network_var[!, end_col]))
    for l in 1:L
        mat[l, start_zones[l]] = 1
        mat[l, end_zones[l]] = -1
    end
    mat
end

function calculate_integer_quotients(df::DataFrame)
    quotients = Int[] # Initialize an empty vector of Ints
    for row in eachrow(df)
        quotient = row.Line_Max_Reinforcement_MW / row.pMax_quantized_MW
        integer_quotient = floor(Int, quotient) # Approximate to nearest integer <= quotient
        push!(quotients, integer_quotient)
    end
    return quotients
end



@doc raw"""
    load_network_map_from_matrix(network_var::DataFrame, Z, L)

Loads the network map from a matrix-style interface
```
..., Network_Lines, z1, z2, z3, ...
                 1,  1, -1,  0,
                 2,  1,  0, -1,
```
This is equivalent to the list-style interface where the zone zN with entry +1 is the
starting zone of the line and the zone with entry -1 is the ending zone of the line.
"""
function load_network_map_from_matrix(network_var::DataFrame, Z, L)
    # Topology of the network source-sink matrix
    network_map_matrix_format_deprecation_warning()
    col = findall(s -> s == "z1", names(network_var))[1]
    mat = Matrix{Float64}(network_var[1:L, col:(col + Z - 1)])

    # Check if the matrix is square
    if size(mat, 1) != L || size(mat, 2) != Z
        error("The network map matrix is not square. Please check the input data.")
    end

    # Check if the matrix contains only 0, 1, -1 values
    if any(x -> x != 0 && x != 1 && x != -1, mat)
        error("The network map matrix contains invalid values. Please check the input data.")
    end

    # Convert to Float64
    mat = Float64.(mat)
end

function load_network_map(network_var::DataFrame, Z, L)
    columns = names(network_var)

    list_columns = ["Start_Zone", "End_Zone"]
    has_network_list = all([c in columns for c in list_columns])

    zones_as_strings = ["z" * string(i) for i in 1:Z]
    has_network_matrix = all([c in columns for c in zones_as_strings])

    instructions = """The transmission network should be specified in the form of a matrix
           (with columns z1, z2, ... zN) or in the form of lists (with Start_Zone, End_Zone),
           but not both. See the documentation for examples."""

    if has_network_list && has_network_matrix
        error("two types of transmission network map were provided.\n" * instructions)
    elseif !(has_network_list || has_network_matrix)
        error("no transmission network map was detected.\n" * instructions)
    elseif has_network_list
        load_network_map_from_list(network_var, Z, L, list_columns)
    elseif has_network_matrix
        load_network_map_from_matrix(network_var, Z, L)
    end
end

function network_map_matrix_format_deprecation_warning()
    @warn """Specifying the network map as a matrix is deprecated as of v0.4
  and will be removed in v0.5. Instead, use the more compact list-style format.

  ..., Network_Lines, Start_Zone, End_Zone, ...
                   1,          1,        2,
                   2,          1,        3,
                   3,          2,        3,
  """ maxlog=1
end

function create_extended_max_flow_vector(network_df::DataFrame, candidate_df::DataFrame)

    # Check if Line_Max_Flow_MW column exists in network_df
    if !("Line_Max_Flow_MW" in names(network_df))
        error("Column 'Line_Max_Flow_MW' not found in Network.csv.")
    end

    as_vector(col::Symbol) = collect(skipmissing(network_df[!, col]))

    as_vector_cand(col::Symbol) = collect(skipmissing(candidate_df[!, col]))
    to_floats(col::Symbol) = convert(Array{Float64}, as_vector(col))
    # Extract the Line_Max_Flow_MW values from network_df
    max_flow_values = convert(Array{Float64}, as_vector(:Line_Max_Flow_MW))

    # Calculate the number of additional rows
    additional_rows =  length(as_vector_cand(:Network_Lines)) #- length(as_vector(:Network_Lines))
    println("Number of rows in candidate_df: ", length(as_vector_cand(:Network_Lines)))
    println("Number of rows in network_df: ", length(as_vector(:Network_Lines)))
    println("Number of additional rows: ", additional_rows)
    # Check if the number of additional rows is positive
    if additional_rows < 0
        error("The candidate DataFrame has fewer rows than the network DataFrame.")
    end

    # Append 0.0 for the additional rows
    append!(max_flow_values, zeros(Float64, additional_rows))

    return max_flow_values
end

function _get_adjacency_list(pNet_Map, pNet_Map_cand)
    line_list = Vector{Tuple}()
    line_list_cand = Vector{Tuple}()
    L = size(pNet_Map)[1]
    L_cand = size(pNet_Map_cand)[1]

    for i in 1:size(pNet_Map)[1]
        from_bus = findfirst(x -> x == 1, pNet_Map[i, :])
        to_bus = findfirst(x -> x == -1, pNet_Map[i, :])
        push!(line_list, (from_bus, to_bus))
    end
    for i in 1:size(pNet_Map_cand)[1]
        from_bus = findfirst(x -> x == 1, pNet_Map_cand[i, :])
        to_bus = findfirst(x -> x == -1, pNet_Map_cand[i, :])
        push!(line_list_cand, (from_bus, to_bus))
    end

    # candidate lines (for now) can only have one option per corridor; there can be more than one existing lines on corridors, but not candidates
    if length(line_list_cand) != length(unique(line_list_cand))
        error("Multiple candidate lines exist on the same corridor; this is not currently supported")
    end
    existing_to_cand_map = Dict()
    cand_to_existing_map = Dict()
    CAN_RETIRE_LINES = Int[]
    CANNOT_RETIRE_LINES = Int[]
    for (i, edge) in enumerate(line_list)
        from_bus, to_bus = edge
        if (from_bus, to_bus) in line_list_cand
            cand_idx = findfirst(x -> x == edge, line_list_cand) + L
            existing_to_cand_map[i] = cand_idx
            if haskey(cand_to_existing_map, cand_idx)
                push!(cand_to_existing_map[cand_idx], i)
            else
                cand_to_existing_map[cand_idx] = [i]
            end
            push!(CAN_RETIRE_LINES, i)
        elseif (to_bus, from_bus) in line_list_cand
            error("Candidate Lines are in opposite directon of existing lines; this should not happen; update your data") #TODO: Make this more robust and support these other types of data
        else
            push!(CANNOT_RETIRE_LINES, i)
        end
    end

    return line_list, line_list_cand, existing_to_cand_map, cand_to_existing_map, CAN_RETIRE_LINES, CANNOT_RETIRE_LINES
end

function build_expansion_information!(myinputs::Dict) # call this inside an "if candidate_flag" statement
    L = myinputs["L"]
    L_cand = myinputs["L_cand"]
    pNet_Map = myinputs["pNet_Map"]
    pNet_Map_cand = myinputs["pNet_Map_cand"]

    LINES = [i for i in 1:(L + L_cand)]
    EXISTING_LINES = [i for i in 1:L]
    CANDIDATE_LINES = [i for i in (L + 1):(L + L_cand)]

    adj_list, adj_list_cand, existing_to_cand_map, cand_to_existing_map, CAN_RETIRE_LINES, CANNOT_RETIRE_LINES = _get_adjacency_list(pNet_Map, pNet_Map_cand)
    pNet_Map_all = vcat(pNet_Map, pNet_Map_cand)

    myinputs["adj_list"] = adj_list
    myinputs["adj_list_cand"] = adj_list_cand
    myinputs["existing_to_cand_map"] = existing_to_cand_map
    myinputs["cand_to_existing_map"] = cand_to_existing_map
    myinputs["LINES"] = LINES
    myinputs["EXISTING_LINES"] = EXISTING_LINES
    myinputs["CANDIDATE_LINES"] = CANDIDATE_LINES
    #myinputs["CAN_RETIRE_LINES"] = CAN_RETIRE_LINES
    #myinputs["CANNOT_RETIRE_LINES"] = CANNOT_RETIRE_LINES
end
