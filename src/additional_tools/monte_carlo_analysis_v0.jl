@doc raw"""
	morris(EP::Model, path::AbstractString, setup::Dict, inputs::Dict, outpath::AbstractString)

We are in the process of implementing Method of Morris for global sensitivity analysis
"""
function mga(EP::Model, path::AbstractString, setup::Dict, inputs::Dict, outpath::AbstractString)

    MonteCarlo_range = CSV.read(string(path, "/Monte_carlo_range.csv"), header=true)

    no_products = length(MonteCarlo_range[!, :Inv_Cost_per_MWyr_variance])
    N = 4
    samples = Array{Float64}(undef,no_products,N)

    for j in 1:no_products
        samples[j,:] = rand( Normal(myinputs["dfGen"][j,:Inv_Cost_per_MWyr], myinputs["dfGen"][1,:sigma]/10), N)
    end

    pi_samples = Array{Float64}(undef, N)
    for k in 1:N
        myinputs["dfGen"][!,:Inv_Cost_per_MWyr]=samples[:,k]
        EP = generate_model(mysetup, myinputs, OPTIMIZER)
        EP, solve_time = solve_model(EP, mysetup)
        pi_samples[k] = objective_value(EP)
    end

end
