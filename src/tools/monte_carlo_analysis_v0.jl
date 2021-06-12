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
