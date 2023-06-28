function evaluate_model(x::Vector{Float64},setup::Dict, inputs::Dict,gsa_df::DataFrame,OPTIMIZER::MOI.OptimizerWithAttributes)

    inputs_new = deepcopy(inputs);
    np = length(gsa_df.Resource);
    for i = 1:np
        ix =  findfirst(unique(gsa_df.Group) .== gsa_df.Group[i]);
        #### p = pnom + (min_perc_change/100 + x*(max_perc_change - min_pec_change)/100) where x ∈ [0,1]
        inputs_new["dfGen"][inputs_new["dfGen"].Resource.==gsa_df.Resource[i],Symbol(gsa_df.Parameter[i])].= 
            (1 + gsa_df.Min_percentage[i]/100 + x[ix]*(gsa_df.Max_percentage[i] - gsa_df.Min_percentage[i])/100).*(inputs["dfGen"][inputs["dfGen"].Resource.==gsa_df.Resource[i],Symbol(gsa_df.Parameter[i])]);
    end
    print(".")
    oldstd = stdout;
    redirect_stdout(devnull);
    EP = generate_model(setup, inputs_new, OPTIMIZER);
    redirect_stdout(oldstd);

    set_silent(EP)
    optimize!(EP)

    return objective_value(EP)

end

function evaluate_distributed_model(X,setup::Dict,inputs::Dict,gsa_df::DataFrame,OPTIMIZER::MOI.OptimizerWithAttributes)

    X_vec = distribute([X[:,i] for i in 1:size(X,2)]);

    p_id = workers();
    np_id = length(p_id);

    dist_results = [Dict() for k in 1:np_id];
    
    @sync for k in 1:np_id
        @async dist_results[k]= @fetchfrom p_id[k] evaluate_local_helper(localpart(X_vec),localindices(X_vec)[1],setup,inputs,gsa_df,OPTIMIZER); ### This is equivalent to fetch(@spawnat p .....)
    end
    dist_results = merge(dist_results...);

    out = zeros(1,size(X,2));
    for j in 1:size(X,2)
        out[1,j] = dist_results[j];
    end
    
    return out
end

function evaluate_local_helper(X_local::Vector{Vector{Float64}},index_local::UnitRange{Int64},setup::Dict,inputs::Dict,gsa_df::DataFrame,OPTIMIZER::MOI.OptimizerWithAttributes)

    n = length(X_local)

    local_sol=Dict();

    for i in 1:n
        local_sol[index_local[i]] = evaluate_model(X_local[i],setup, inputs,gsa_df,OPTIMIZER);
    end

    return local_sol

end

function gsa_morris(inpath::AbstractString, setup::Dict, inputs::Dict, outpath::AbstractString, OPTIMIZER::MOI.OptimizerWithAttributes)
    
    gsa_df = load_dataframe(joinpath(inpath, "Global_sensitivity_analysis_range.csv"));

    lb,ub = make_lower_upper_bounds(inputs,gsa_df);

    f(x) =  evaluate_model(x,setup,inputs,gsa_df,OPTIMIZER);
    
    total_num_traj = gsa_df[!,:total_num_trajectory][1];
    num_traj = gsa_df[!,:num_trajectory][1];
    p_steps = gsa_df[!,:p_steps]
    len_design_mat = gsa_df[!,:len_design_mat][1]

    m = gsa(f,Morris(total_num_trajectory=total_num_traj,num_trajectory=num_traj,p_steps=p_steps,len_design_mat=len_design_mat),[[lb[i],ub[i]] for i in 1:length(ub)]);

    mean_groups = DataFrame(m.means', :auto)[!,:x1];
    variance_groups = DataFrame(m.variances', :auto)[!,:x1];
    mean_all = [mean_groups[findfirst(unique(gsa_df.Group).==gsa_df.Group[i])] for i in 1:length(gsa_df.Resource)];
    variance_all = [variance_groups[findfirst(unique(gsa_df.Group).==gsa_df.Group[i])] for i in 1:length(gsa_df.Resource)];

    #save the mean effect of each uncertain variable on the objective fucntion
    gsa_df[!,:mean] = mean_all
    #save the variance of effect of each uncertain variable on the objective function
    gsa_df[!,:variance] = variance_all
    
    CSV.write(joinpath(outpath, "my_morris.csv"), gsa_df)
    println("")
end


function gsa_sobol(inpath::AbstractString, setup::Dict, inputs::Dict, outpath::AbstractString, OPTIMIZER::MOI.OptimizerWithAttributes)
    
    sampler = SobolSample()

    gsa_df = load_dataframe(joinpath(inpath, "Global_sensitivity_analysis_range.csv"));

    lb,ub = make_lower_upper_bounds(inputs,gsa_df);

    num_samples = gsa_df[!,:sobol_samples][1];

    A,B = QuasiMonteCarlo.generate_design_matrices(num_samples,lb,ub,sampler)

    f(x) =  evaluate_model(x,setup,inputs,gsa_df,OPTIMIZER);
    m = gsa(f,Sobol(),A,B);

    ST_all = [m.ST[findfirst(unique(gsa_df.Group).==gsa_df.Group[i])] for i in 1:length(gsa_df.Resource)];
    S1_all = [m.S1[findfirst(unique(gsa_df.Group).==gsa_df.Group[i])] for i in 1:length(gsa_df.Resource)];

    gsa_df[!,:SobolTotal] = ST_all;
    gsa_df[!,:SobolFirstOrder] = S1_all;
    CSV.write(joinpath(outpath, "sobol.csv"), gsa_df)
    println("")
end

function gsa_sobol_dist(inpath::AbstractString, setup::Dict, inputs::Dict, outpath::AbstractString, OPTIMIZER::MOI.OptimizerWithAttributes)
    
    
    sampler = SobolSample()

    gsa_df = load_dataframe(joinpath(inpath, "Global_sensitivity_analysis_range.csv"));

    lb,ub = make_lower_upper_bounds(inputs,gsa_df);

    num_samples = gsa_df[!,:sobol_samples][1];

    A,B = QuasiMonteCarlo.generate_design_matrices(num_samples,lb,ub,sampler)

    f(x) = evaluate_distributed_model(x,setup,inputs,gsa_df,OPTIMIZER);
    m = gsa(f,Sobol(),A,B,batch=true)
   
    ST_all = [m.ST[findfirst(unique(gsa_df.Group).==gsa_df.Group[i])] for i in 1:length(gsa_df.Resource)];
    S1_all = [m.S1[findfirst(unique(gsa_df.Group).==gsa_df.Group[i])] for i in 1:length(gsa_df.Resource)];

    gsa_df[!,:SobolTotal] = ST_all;
    gsa_df[!,:SobolFirstOrder] = S1_all;
    CSV.write(joinpath(outpath, "sobol.csv"), gsa_df)
    println("")
end

function make_lower_upper_bounds(inputs::Dict,gsa_df::DataFrame)
    par2group = unique(gsa_df.Group)
    nx = length(par2group);
    lb = zeros(nx);
    ub = ones(nx);
    return lb,ub
end