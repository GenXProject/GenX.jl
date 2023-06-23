function make_lower_upper_bounds(inputs::Dict,gsa_df::DataFrame)
    np = length(gsa_df.Parameter);
    lb = zeros(np);
    ub = zeros(np);
    for i = 1:np
        lb[i] = inputs["dfGen"][inputs["dfGen"].Resource.==gsa_df.Resource[i],Symbol(gsa_df.Parameter[i])][1]*(1+gsa_df.Min_percentage[i]/100)
        ub[i] = inputs["dfGen"][inputs["dfGen"].Resource.==gsa_df.Resource[i],Symbol(gsa_df.Parameter[i])][1]*(1+gsa_df.Max_percentage[i]/100)
    end
    return lb,ub
end

function evaluate_model(x::Vector{Float64},setup::Dict, inputs::Dict,gsa_df::DataFrame,OPTIMIZER::MOI.OptimizerWithAttributes)

    inputs_new = deepcopy(inputs);
    np = length(x);
    for i = 1:np
        inputs_new["dfGen"][inputs["dfGen"].Resource.==gsa_df.Resource[i],Symbol(gsa_df.Parameter[i])].= x[i];
    end
    println("")
    EP = generate_model(setup, inputs_new, OPTIMIZER)
    set_silent(EP)
    optimize!(EP)

    return objective_value(EP)

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

    #save the mean effect of each uncertain variable on the objective fucntion
    gsa_df[!,:mean] = DataFrame(m.means', :auto)[!,:x1]
    #save the variance of effect of each uncertain variable on the objective function
    gsa_df[!,:variance] = DataFrame(m.variances', :auto)[!,:x1]
    
    CSV.write(joinpath(outpath, "my_morris.csv"), gsa_df)
    
end


function gsa_sobol(inpath::AbstractString, setup::Dict, inputs::Dict, outpath::AbstractString, OPTIMIZER::MOI.OptimizerWithAttributes)
    
    
    sampler = SobolSample()

    gsa_df = load_dataframe(joinpath(inpath, "Global_sensitivity_analysis_range.csv"));

    lb,ub = make_lower_upper_bounds(inputs,gsa_df);

    num_samples = gsa_df[!,:sobol_samples][1];

    X,Y = QuasiMonteCarlo.generate_design_matrices(num_samples,lb,ub,sampler)

    f(x) =  evaluate_model(x,setup,inputs,gsa_df,OPTIMIZER);
        
    m = gsa(f,Sobol(),X,Y)
    gsa_df[!,:SobolTotal] = DataFrame([m.ST], :auto)[!,:x1]
    gsa_df[!,:SobolFirstOrder] = DataFrame([m.S1], :auto)[!,:x1]
    CSV.write(joinpath(outpath, "sobol.csv"), gsa_df)
    
end
