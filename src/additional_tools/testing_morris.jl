using OrdinaryDiffEq, Statistics, Random, RecursiveArrayTools #load packages Plots,

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
function generate_design_matrix(p_range, p_steps, rng;len_design_mat)
    ps = [range(p_range[i][1], stop=p_range[i][2], length=p_steps[i]) for i in 1:length(p_range)]
    indices = [rand(rng, 1:i) for i in p_steps]
    all_idxs = Vector{typeof(indices)}(undef,len_design_mat)
    
    for i in 1:len_design_mat
        j = rand(rng, 1:length(p_range))
        indices[j] += (rand(rng) < 0.5 ? -1 : 1)
        if indices[j] > p_steps[j]
            indices[j] -= 2
        elseif indices[j] < 1.0
            indices[j] += 2
        end
        all_idxs[i] = copy(indices)
    end

    B = Array{Array{Float64}}(undef,len_design_mat)
    for j in 1:len_design_mat
        cur_p = [ps[u][(all_idxs[j][u])] for u in 1:length(p_range)]
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

function sample_matrices(p_range,p_steps, rng;num_trajectory,total_num_trajectory,len_design_mat)
    matrix_array = []
    println(num_trajectory)
    println(total_num_trajectory)
    if total_num_trajectory<num_trajectory
        error("total_num_trajectory should be greater than num_trajectory preferably atleast 3-4 times higher")
    end
    for i in 1:total_num_trajectory
        mat = generate_design_matrix(p_range, p_steps, rng;len_design_mat)
        spread = calculate_spread(mat)
        push!(matrix_array,MatSpread(mat,spread))
    end
    sort!(matrix_array,by = x -> x.spread,rev=true)
    matrices = [i.mat for i in matrix_array[1:num_trajectory]]
    reduce(hcat,matrices)
end

function my_gsa(f, p_steps, num_trajectory, total_num_trajectory, p_range::AbstractVector,len_design_mat)
    rng = Random.default_rng()
    design_matrices_original = sample_matrices(p_range, p_steps, rng;num_trajectory,
                                        total_num_trajectory,len_design_mat)
    println(design_matrices_original)
    design_matrices = similar(design_matrices_original, Float64)
    for g in unique(groups)
        temp = findall(x->x==g, groups)
        for k in temp
            design_matrices[k,:] = design_matrices_original[temp[1],:]
        end
    end
    println(design_matrices)
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
    for i in 1:num_trajectory
        y1 = multioutput ? all_y[:,(i-1)*len_design_mat+1] : all_y[(i-1)*len_design_mat+1]
        for j in (i-1)*len_design_mat+1:(i*len_design_mat)-1
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
            if length(effects) >= change_index && change_index > 0
                push!(effects[change_index],elem_effect)
            elseif change_index > 0
                while(length(effects) < change_index-1)
                    push!(effects,typeof(elem_effect)[])
                end
                push!(effects,[elem_effect])
            end
        end
    end
    means = eltype(effects[1])[]
    means_star = eltype(effects[1])[]
    variances = eltype(effects[1])[]
    for k in effects
        if !isempty(k)
            push!(means, mean(k))
            push!(means_star, mean(x -> abs.(x), k))
            push!(variances, var(k))
        else
            push!(means, zero(effects[1][1]))
            push!(means_star, zero(effects[1][1]))
            push!(variances, zero(effects[1][1]))
        end
    end
    if desol
        f_shape = x -> [reshape(x[:,i],y_size) for i in 1:size(x,2)]
        means = map(f_shape,means)
        means_star = map(f_shape,means_star)
        variances = map(f_shape,variances)
    end
    MorrisResult(reduce(hcat, means),reduce(hcat, means_star),reduce(hcat, variances),effects)
end


function f(du,u,p,t)
    du[1] = p[1]*u[1] - p[2]*u[1]*u[2] #prey
    du[2] = -p[3]*u[2] + p[4]*u[1]*u[2] #predator
end
  u0 = [1.0;1.0]
  tspan = (0.0,10.0)
  p = [1.5,1.0,3.0,1.0]
  prob = ODEProblem(f,u0,tspan,p)
  t = collect(range(0, stop=10, length=200))

  f1 = function (p)
    prob1 = remake(prob;p=p)
    sol = solve(prob1,Tsit5();saveat=t)
    [mean(sol[1,:]), maximum(sol[2,:])]
  end
  p_steps=[3,3,3,3]
  total_num_trajectory=3
  num_trajectory=1
  p_range=[[1,5],[1,5],[1,5],[1,5]]
  groups=["s","b","b","s"]
  len_design_mat = 10
  m = my_gsa(f1,p_steps,num_trajectory,total_num_trajectory,p_range,len_design_mat)

  #scatter(m.means[1,:], m.variances[1,:],series_annotations=[:a,:b,:c,:d],color=:gray)

  