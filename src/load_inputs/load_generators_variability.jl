@doc raw"""
	load_generators_variability!(setup::Dict, path::AbstractString, inputs::Dict)

Read input parameters related to hourly maximum capacity factors for generators, storage, and flexible demand resources
"""
function load_generators_variability!(setup::Dict, path::AbstractString, inputs::Dict)

	# Hourly capacity factors
	data_directory = joinpath(path, setup["TimeDomainReductionFolder"])
    if setup["TimeDomainReduction"] == 1  && time_domain_reduced_files_exist(data_directory)
        my_dir = data_directory
	else
        my_dir = path
	end
    filename = "Generators_variability.csv"
    gen_var = load_dataframe(joinpath(my_dir, filename))

	# Reorder DataFrame to R_ID order (order provided in Generators_data.csv)
	variability_names = inputs["VARIABILITY"]
	existing_variability <- names(gen_var)
	temp = zeros(inputs["T"], inputs["G"])
	for g = 1: inputs["G"]
		r = variability_names[g]
		if r ∉ existing_variability
			ensure_column!(gen_var, r, 1.0)
		end
		existing_variability <- names(gen_var)
		location = findfirst(x -> x == r, existing_variability)
		temp[:, g] = Vector{Float64}(gen_var[:, location])
    end

	# Maximum power output and variability of each energy resource
	inputs["pP_Max"] = transpose(temp)

	println(filename * " Successfully Read!")

end
