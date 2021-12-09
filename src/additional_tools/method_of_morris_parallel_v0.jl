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

We are in the process of implementing Method of Morris for global sensitivity analysis
"""
function morris(EP::Model, path::AbstractString, setup::Dict, inputs::Dict, outpath::AbstractString, OPTIMIZER)

    Morris_range = CSV.read(string(path, "/Method_of_morris_range.csv"), header=true, copycols=true)
    save_parameters = zeros(length(Morris_range[!,:Parameter]))
    f1 = function(sigma)
        print(sigma)
        print("\n")
        #save_parameters = hcat(save_parameters, sigma)

        inv_index = findall(s -> s == "Inv_Cost_per_MWyr", Morris_range[!,:Parameter])
        inputs["dfGen"][!,:Inv_Cost_per_MWyr] = sigma[first(inv_index):last(inv_index)]

        fom_index = findall(s -> s == "Fixed_OM_Cost_per_MWyr", Morris_range[!,:Parameter])
        inputs["dfGen"][!,:Fixed_OM_Cost_per_MWyr] = sigma[first(fom_index):last(fom_index)]

        EP = generate_model(setup, inputs, OPTIMIZER)
        #EP, solve_time = solve_model(EP, setup)
        redirect_stdout((()->optimize!(EP)),open("/dev/null", "w"))
        [objective_value(EP)]
    end

    sigma_inv = [inputs["dfGen"][!,:Inv_Cost_per_MWyr] .* (1 .+ Morris_range[Morris_range[!,:Parameter] .== "Inv_Cost_per_MWyr", :Lower_bound] ./100) inputs["dfGen"][!,:Inv_Cost_per_MWyr] .* (1 .+ Morris_range[Morris_range[!,:Parameter] .== "Inv_Cost_per_MWyr", :Upper_bound] ./100)]
    sigma_fom = [inputs["dfGen"][!,:Fixed_OM_Cost_per_MWyr] .* (1 .+ Morris_range[Morris_range[!,:Parameter] .== "Fixed_OM_Cost_per_MWyr", :Lower_bound] ./100) inputs["dfGen"][!,:Fixed_OM_Cost_per_MWyr] .* (1 .+ Morris_range[Morris_range[!,:Parameter] .== "Fixed_OM_Cost_per_MWyr", :Upper_bound] ./100)]
    sigma = [sigma_inv; sigma_fom]
    sigma = mapslices(x->[x], sigma, dims=2)[:]

    # Perform the method of morris analysis
    m = gsa(f1,Morris(total_num_trajectory=3,num_trajectory=2),sigma)

    #save the mean effect of each uncertain variable on the objective fucntion
    Morris_range[!,:mean] = DataFrame(m.means')[!,:x1]

    #save the variance of effect of each uncertain variable on the objective function
    Morris_range[!,:variance] = DataFrame(m.variances')[!,:x1]

    if setup["MacOrWindows"]=="Mac"
		sep = "/"
	else
		sep = "\U005c"
	end

    CSV.write(string(outpath,sep,"morris.csv"), Morris_range)

end
