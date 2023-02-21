"""
GenX: An Configurable Capacity Expansion Model
Copyright (C) 2021,  Massachusetts Institute of Technology
This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
A complete copy of the GNU General Public License v2 (GPLv2) is available
in LICENSE.txt.  Users uncompressing this from an archive may not have
received this license file.  If not, see <http://www.gnu.org/licenses/>.
"""

@doc raw"""
    morris(EP::Model, path::AbstractString, setup::Dict, inputs::Dict, outpath::AbstractString, OPTIMIZER)

We apply the Method of Morris developed by [Morris, M., 1991](https://www.jstor.org/stable/1269043) in order to identify the input parameters that produce the largest change on total system cost. Method of Morris falls under the simplest class of one-factor-at-a-time (OAT) screening techniques. It assumes l levels per input factor and generates a set of trajectories through the input space. As such, the Method of Morris generates a grid of uncertain model input parameters, $x_i, i=1, ..., k$,, where the range $[x_i^{-}, x_i^{+}$ of each uncertain input parameter i is split into l intervals of equal length. Each trajectory starts at different realizations of input parameters chosen at random and are built by successively selecting one of the inputs randomly and moving it to an adjacent level. These trajectories are used to estimate the mean and the standard deviation of each input parameter on total system cost. A high estimated mean indicates that the input parameter is important; a high estimated standard deviation indicates important interactions between that input parameter and other inputs.
"""
struct MatSpread{T1,T2}
    mat::T1
    spread::T2
end

struct MorrisResult{T1,T2}
    means::T1
    means_star::T1
    variances::T1
    elementary_effects::T2
end
function generate_design_matrix(p_range, p_steps, rng;len_design_mat,groups,lb,ub)
    ps = [range(p_range[i][1], stop=p_range[i][2], length=p_steps[i]) for i in 1:length(p_range)]
    indices = [rand(rng, 1:i) for i in p_steps]
    all_idxs_original = Vector{typeof(indices)}(undef,len_design_mat)

    for i in 1:len_design_mat
        j = rand(rng, 1:length(p_range))
        indices[j] += (rand(rng) < 0.5 ? -1 : 1)
        if indices[j] > p_steps[j]
            indices[j] -= 2
        elseif indices[j] < 1.0
            indices[j] += 2
        end
        all_idxs_original[i] = copy(indices)
    end

    df_all_idx_original = DataFrame(all_idxs_original,:auto)
    all_idxs = similar(df_all_idx_original)
    for g in unique(groups)
        temp = findall(x->x==g, groups)
        for k in temp
            all_idxs[k,:] = df_all_idx_original[temp[1],:]
        end
    end
    for i in 1:length(p_range)
        if lb[i]==0 && ub[i]==0
            all_idxs[i,:] .= 1
        end
    end

    B = Array{Array{Float64}}(undef,len_design_mat)
    for j in 1:len_design_mat
        cur_p = [ps[u][(all_idxs[:,j][u])] for u in 1:length(p_range)]
        B[j] = cur_p
    end
    reduce(hcat, B)
end

function calculate_spread(matrix)
    spread = 0.0
    for i in 2:size(matrix,2)
        spread += sqrt(sum(abs2.(matrix[:,i] - matrix[:,i-1])))
    end
    spread
end

function check_trajectory_numbers(num_trajectory, total_num_trajectory)
    if total_num_trajectory<num_trajectory
        println("For the Morris sensitivity analysis,")
        println("total_num_trajectory is ", total_num_trajectory)
        println("num_trajectory is ", num_trajectory)
        error("but total_num_trajectory should be greater than num_trajectory, preferably 3-4 times higher")
    end
end

function sample_matrices(p_range,p_steps, rng;num_trajectory,total_num_trajectory,len_design_mat,groups,lb,ub)
    matrix_array = []
    check_trajectory_numbers(num_trajectory, total_num_trajectory)
    for i in 1:total_num_trajectory
        mat = generate_design_matrix(p_range, p_steps, rng;len_design_mat,groups,lb,ub)
        spread = calculate_spread(mat)
        push!(matrix_array,MatSpread(mat,spread))
    end
    sort!(matrix_array,by = x -> x.spread,rev=true)
    matrices = [i.mat for i in matrix_array[1:num_trajectory]]
    reduce(hcat,matrices)
end

function my_gsa(f, p_steps, num_trajectory, total_num_trajectory, p_range::AbstractVector,len_design_mat,groups,lb,ub)
    rng = Random.default_rng()
    design_matrices_original = sample_matrices(p_range, p_steps, rng;num_trajectory,
                                        total_num_trajectory,len_design_mat,groups,lb,ub)
    L = DataFrame(design_matrices_original,:auto)

    distinct_trajectories = zero(1)
    design_matrices = Matrix(DataFrame(unique(last, pairs(eachcol(L[!,1:len_design_mat])))))
    distinct_trajectories = [distinct_trajectories;length(design_matrices[1,:])]
    if num_trajectory > 1
        for i in 2:num_trajectory
            new_mat = Matrix(DataFrame(unique(last, pairs(eachcol(L[!,(i-1)*len_design_mat+1:i*len_design_mat])))))
            design_matrices = hcat(design_matrices, new_mat)
            distinct_trajectories = [distinct_trajectories; length(new_mat[1,:])]
        end
    end
    distinct_trajectories = cumsum(distinct_trajectories)

    multioutput = false
    desol = false
    local y_size

    _y = [f(design_matrices[:,i]) for i in 1:size(design_matrices,2)]
    multioutput = !(eltype(_y) <: Number)
    if eltype(_y) <: RecursiveArrayTools.AbstractVectorOfArray
        y_size = size(_y[1])
        _y = vec.(_y)
        desol = true
    end
    all_y = multioutput ? reduce(hcat,_y) : _y
    effects = []
    while(length(effects) < length(groups))
        push!(effects,Vector{Float64}[])
    end

    for i in 1:num_trajectory
        len_design_mat = distinct_trajectories[i]
        y1 = multioutput ? all_y[:,2+distinct_trajectories[i]] : all_y[2+distinct_trajectories[i]]
        for j in 1+distinct_trajectories[i] : distinct_trajectories[i+1] - 1
            y2 = y1
            del = design_matrices[:,j+1] - design_matrices[:,j]
            change_index = 0
            for k in 1:length(del)
                if abs(del[k]) > 0
                    change_index = k
                    break
                end
            end
            del = sum(del)
            y1 = multioutput ? all_y[:,j+1] : all_y[j+1]
            effect = @. (y1-y2)/(del)
            elem_effect = typeof(y1) <: Number ? effect : mean(effect, dims = 2)
            temp_g_index = findall(x->x==groups[change_index], groups)
            for g in temp_g_index
                push!(effects[g],elem_effect)
            end
        end
    end

    means, means_star, variances = computestatistics(effects)

    if desol
        f_shape = x -> [reshape(x[:,i],y_size) for i in 1:size(x,2)]
        means = map(f_shape,means)
        means_star = map(f_shape,means_star)
        variances = map(f_shape,variances)
    end
    MorrisResult(reduce(hcat, means),reduce(hcat, means_star),reduce(hcat, variances),effects)
end

function computestatistics(effects)
    means = eltype(effects[1])[]
    means_star = eltype(effects[1])[]
    variances = eltype(effects[1])[]
    for k in 1:length(effects)
        if !isempty(effects[k])
            push!(means, mean(effects[k]))
            push!(means_star, mean(x -> abs.(x), effects[k]))
            push!(variances, var(effects[k]))
        else
            push!(means, zeros(1))
            push!(means_star, zeros(1))
            push!(variances, zeros(1))
            push!(effects[k], zeros(1))
        end
    end
    return means, means_star, variances
end

function set_random_seed!(setup::Dict)
    key = "MethodofMorrisRandomSeed"
    if haskey(setup, key)
        seed = setup[key]
        Random.seed!(seed)
    end
end

### functions for imputing zero rows so that not all generators need to be included
lonely_row_names() = ["total_num_trajectory", "num_trajectory", "len_design_mat", "policy"]

function get_lonely_information(df::DataFrame)::Dict
    lonely_rows = lonely_row_names()
    dfr = df[1, lonely_rows]
    Dict(names(dfr) .=> values(dfr))
end

function reset_lonely_information!(df::DataFrame, lonely_row::Dict)
    for col in keys(lonely_row)
        new_vec = similar(df[:, col])
        new_vec .= missing
        new_vec[1] = lonely_row[col]

        df[!, col] = new_vec
    end
end

function construct_new_row_data(df::DataFrame, row_dict::Dict)
    col_names = names(df)
    lonely_names = lonely_row_names()
    zero_names = ["Upper_bound", "Lower_bound", "p_steps"]
    group_names = ["Group"]
    r = Any[]
    for c in col_names
        if c in keys(row_dict)
            push!(r, row_dict[c])
        elseif c in lonely_names
            push!(r, missing)
        elseif c in zero_names
            push!(r, 0)
        elseif c in group_names
            push!(r, "nogroup")
        else
            error("Unknown column ", c, " encountered")
        end
    end
    return r
end

function fancyinsert!(df::DataFrame, rownum::Int, newrow::Vector{Any})
    # https://stackoverflow.com/questions/51505007/julia-dataframes-insert-new-row-at-specific-index
    foreach((c, v) -> insert!(c, rownum, v), eachcol(df), newrow)
end


function insert_absent_resource_rows!(df::DataFrame, df_from_file::Dict, inputs::Dict)
    final = nrow(df)
    i = 1
    j = 1

    resource_for_file(file) = inputs[df_from_file[file]][:, [:Resource, :Zone]]

    function next_correct_row(file, parameter, block, j)
        Dict("File"=>file, "Parameter"=>parameter,
            "Resource"=>block[j, :Resource], "Zone"=>block[j, :Zone])
    end

    length_remaining = 0
    file = ""
    parameter = ""
    block = DataFrame()
    while i <= final
        if length_remaining == 0
            j = 1
            file = df[i, :File]
            block = resource_for_file(file)
            parameter = df[i, :Parameter]
            length_remaining = nrow(block)
        end

        row_dict = next_correct_row(file, parameter, block, j)

        this_resource = df[i, :Resource]
        this_parameter = df[i, :Parameter]
        this_file = df[i, :File]
        if this_resource != row_dict["Resource"] || this_parameter != row_dict["Parameter"] || this_file != row_dict["File"]
            new_row_data = construct_new_row_data(df, row_dict)
            fancyinsert!(df, i, new_row_data)
            final += 1
        end

        length_remaining -= 1

        i += 1
        j += 1
    end

    # begin 'extra innings' to complete the last cycle
    if i == final + 1 && length_remaining > 0
        final += length_remaining
        for i in i:final
            row_dict = next_correct_row(file, parameter, block, j)
            new_row_data = construct_new_row_data(df, row_dict)
            fancyinsert!(df, i, new_row_data)
            j += 1
        end
    end
end

function impute_morris_instructions!(df::DataFrame, df_from_file::Dict, inputs::Dict)
    lonely_data = get_lonely_information(df)
    insert_absent_resource_rows!(df, df_from_file, inputs)
    reset_lonely_information!(df, lonely_data)
end

function morris(EP::Model, path::AbstractString, setup::Dict, inputs::Dict, outpath::AbstractString, OPTIMIZER)

    # Reading the input parameters
    set_random_seed!(setup)
    Morris_range = load_dataframe(joinpath(path, "Method_of_morris_range.csv"))
    dataframe_for_file = Dict("Generators_data"=>"dfGen",
                              "Fleccs_data"=>"dfGen_ccs",
                              "Thermal_storage"=>"dfTS")
    impute_morris_instructions!(Morris_range, dataframe_for_file, inputs)
    groups = Morris_range[!,:Group]
    p_steps = Morris_range[!,:p_steps]
    p_steps[p_steps .< 1] .= 1
    total_num_trajectory = Morris_range[1,:total_num_trajectory]
    num_trajectory = Morris_range[1,:num_trajectory]
    len_design_mat = Morris_range[1,:len_design_mat]
    files = unique(Morris_range[!,:File])
    lb = Morris_range[!,:Lower_bound]
    ub = Morris_range[!,:Upper_bound]
    save_parameters = zeros(nrow(Morris_range))


    # Creating the range of uncertain parameters in terms of absolute values
    lower_sigmas = Float64[]
    upper_sigmas = Float64[]
    for f in files
        my_df = inputs[dataframe_for_file[f]]
        entries_for_file = Morris_range[!, :File].==f
        uncertain_columns = unique(Morris_range[entries_for_file, :Parameter])
        for column in uncertain_columns
            entries_for_param = Morris_range[!, :Parameter].==column
            sel = entries_for_file .& entries_for_param
            lower_sigma = my_df[!,Symbol(column)] .* (1 .+ Morris_range[sel, :Lower_bound] ./100)
            upper_sigma = my_df[!,Symbol(column)] .* (1 .+ Morris_range[sel, :Upper_bound] ./100)
            append!(lower_sigmas, lower_sigma)
            append!(upper_sigmas, upper_sigma)
        end
    end

    p_range = mapslices(x->[x], [lower_sigmas upper_sigmas], dims=2)[:]
    obj_val = zeros(1)

    # Creating a function for iteratively solving the model with different sets of input parameters
    f1 = function(sigma)
        save_parameters = hcat(save_parameters, sigma)

        for f in files
            my_df = inputs[dataframe_for_file[f]]
            entries_for_file = Morris_range[!, :File].==f
            uncertain_columns = unique(Morris_range[entries_for_file, :Parameter])
            for column in uncertain_columns
                entries_for_param = Morris_range[!, :Parameter].==column
                sel = entries_for_file .& entries_for_param
                index = (1:length(sel))[sel]
                my_df[!,Symbol(column)] = sigma[first(index):last(index)]
            end
        end

        EP = generate_model(setup, inputs, OPTIMIZER)
        #EP, solve_time = solve_model(EP, setup)
        redirect_stdout((()->optimize!(EP)),open("/dev/null", "w"))
        [objective_value(EP)]
        obj_val = hcat(obj_val, objective_value(EP))
    end

    # Perform the method of morris analysis
    m = my_gsa(f1,p_steps,num_trajectory,total_num_trajectory,p_range,len_design_mat,groups,lb,ub)
    #save the mean effect of each uncertain variable on the objective fucntion
    Morris_range[!,:mean] = DataFrame(m.means', :auto)[!,:x1]
    #save the variance of effect of each uncertain variable on the objective function
    Morris_range[!,:variance] = DataFrame(m.variances', :auto)[!,:x1]
    Morris_range[!,:means_star] = DataFrame(m.means_star', :auto)[!,:x1]

    CSV.write(joinpath(outpath,"morris.csv"), Morris_range)
    CSV.write(joinpath(outpath,"morris_objective.csv"), DataFrame(obj_val,:auto))
    CSV.write(joinpath(outpath,"morris_parameters.csv"), DataFrame(save_parameters,:auto))
    # TODO this should be converted to a dataframe somehow, if we want it?
    # writedlm was from the DelimitedFiles package
    #writedlm(joinpath(outpath,"morris_elementary_effects.csv"),  m.elementary_effects, ',')

end
