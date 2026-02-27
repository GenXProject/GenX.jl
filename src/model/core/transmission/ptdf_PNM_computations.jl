function get_lines(matrix::Matrix)
    line_list = Vector{Tuple}()
    for i in 1:size(matrix)[1]
        from_bus = findfirst(x -> x == 1, matrix[i, :])
        to_bus = findfirst(x -> x == -1, matrix[i, :])
        push!(line_list, (from_bus, to_bus))
    end
    return line_list
end

function find_matching_index(a::Vector, b::Vector, x, y)
    for i in eachindex(a, b)
        if a[i] == x && b[i] == y
            return i
        end
    end
    return nothing 
end

function calculate_ptdf_matrices(inputs::Dict, slack_bus::Int=1; tol = eps())
    # A is adjacency matrix of size num_bus x num_bus
    # adjacency matrix is based on corridors, not individual lines
    A_I = Int[]
    A_J = Int[]
    A_V = Int8[]

    # BA is adjacency matrix times susceptance values of size num_bus x num_bus
    BA_I = Int[]
    BA_J = Int[]
    BA_V = Float64[]

    # net_map is a list of 1 and -1 values
    net_map = inputs["pNet_Map"]
    #net_map_cand = inputs["pNet_Map_cand"]
    
    # line lists are adjacency lists
    net_line_list = get_lines(net_map)
    #net_line_list_cand = get_lines(net_map_cand)

    B_net = inputs["pDC_OPF_coeff"]
    B_total = Dict() # total susceptance on a given corridor

    num_buses = size(net_map)[2]
    buses = 1:num_buses
    bus_map = Dict(i => i for i in buses)

    all_lines = [i for i in 1:inputs["L"]]
    # line_to_idx_map = Dict(line => i for (i, line) in enumerate(all_lines))
    line_to_idx_map = Dict()
    idx_to_line_map = Dict()
    # check if from - to pair is there (in either direction). 
    # if it is, then skip in the first loop
        # in the second loop make sure the sign on B_net is correct
    # Add comments to all this code; it's confusing :(
    # probably need a mapping to make sure `line_to_idx_map` correctly gives the entry; need to make sure that the sign on B_val is right
    # need to update new_line_names
    # then fix these things in the DCOPF transmission file

    for (i, line) in enumerate(net_line_list) #need to check if from_bus, to bus is in list already; 
        from_bus, to_bus = line
        idx_to_line_map[i] = (1, (from_bus, to_bus))
        push!(A_I, i)
        push!(A_J, from_bus)
        push!(A_V, 1)

        push!(A_I, i)
        push!(A_J, to_bus)
        push!(A_V, -1)
    end

    for (i, line) in enumerate(net_line_list)
        from_bus, to_bus = line

        # check if line is in added list
        push!(BA_I, from_bus)
        push!(BA_J, i)
        push!(BA_V, B_net[i])

        push!(BA_I, to_bus)
        push!(BA_J, i)
        push!(BA_V, -B_net[i])
        if haskey(B_total, line)
            B_total[line] += B_net[i]
        else
            B_total[line] = B_net[i]
        end
    end
    A =  SparseArrays.sparse(A_I, A_J, A_V)
    BA = SparseArrays.sparse(BA_I, BA_J, BA_V)
    ref_bus_position = Set([slack_bus])
    subnetworks= Dict{Int, Set{Int}}(slack_bus => Set([i for i in buses]))

    ptdf_mat = PowerNetworkMatrices._calculate_PTDF_matrix_KLU(A, BA, Set([slack_bus]), Float64[])# [1.0 for i in 1:num_buses])

    ptdf_data = PTDF(PNM.sparsify(ptdf_mat, tol), (buses, all_lines), (bus_map, line_to_idx_map), subnetworks, ref_bus_position, Base.RefValue(tol), RadialNetworkReduction())

    return ptdf_data
end


function get_ptdf_line_diff(ptdf_mat, line_idx, line_virtual_idx, idx_to_line_map)
    line_tuple = idx_to_line_map[line_idx]
    line_virtual_tuple = idx_to_line_map[line_virtual_idx]
    bus_vector = ptdf_mat.data[:, line_idx]
    diff = bus_vector[line_virtual_tuple[1]] - bus_vector[line_virtual_tuple[2]]
    return diff
end

function get_ptdf_vector(ptdf_mat, line_idx, line_to_idx_map)
    line_tuple = line_to_idx_map[line_idx]
    return ptdf_mat.data[:, line_idx]
end