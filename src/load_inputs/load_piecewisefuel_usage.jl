"""
	process_piecewisefuelusage!(setup::Dict, case_path::AbstractString, gen::Vector{<:AbstractResource}, inputs::Dict)

Reads piecewise fuel usage data from the file "Resource_piecewisefuel_usage.csv" in the resource folder, create a PWFU_data that contain processed intercept and slope (i.e., heat rate) and add them to the inputs dictionary. 

# Arguments
- `setup::Dict`: The dictionary containing the setup parameters
- `case_path::AbstractString`: The path to the case folder
- `gen::Vector{<:AbstractResource}`: The vector of generators in the model
- `inputs::Dict`: The dictionary containing the input data
"""
function process_piecewisefuelusage!(setup::Dict, case_path::AbstractString, gen::Vector{<:AbstractResource}, inputs::Dict)
	filename = "Resource_piecewisefuel_usage.csv"
	resource_folder = setup["ResourcePath"]
	filepath = joinpath(case_path, resource_folder, filename)
	
	if isfile(filepath)
		piecewisefuel_in = load_dataframe(filepath)

		# get the resource names from the dataframe
		resource_with_pwfu = resource_ids(piecewisefuel_in)
		# get all the resource names
		resource_without_pwfu = setdiff(resource_name.(gen), resource_with_pwfu)
		# fill dataframe with zeros for resources without piecewise fuel usage
		for resource in resource_without_pwfu
			new_row = (resource, zeros(ncol(piecewisefuel_in)-1)...)	# first column is resource name
			push!(piecewisefuel_in, new_row)
		end

		# sort dataframe by resource names and return the sorted names
		resource_in_df = sort_dataframe_by_resource_names!(piecewisefuel_in, gen)
		
		heat_rate_mat = extract_matrix_from_dataframe(piecewisefuel_in, "PWFU_Heat_Rate_MMBTU_per_MWh")
		load_point_mat = extract_matrix_from_dataframe(piecewisefuel_in, "PWFU_Load_Point_MW")
		
		# check data input 
		validate_piecewisefuelusage(heat_rate_mat, load_point_mat)

        # determine if a generator contains piecewise fuel usage segment based on non-zero heatrate
		nonzero_rows = any(heat_rate_mat .!= 0 , dims = 2)[:]
		HAS_PWFU = resource_id.(resources_by_names(gen, resource_in_df))[nonzero_rows]
		num_segments =  size(heat_rate_mat)[2]

		# translate the inital fuel usage, heat rate, and load points into intercept for each segment
		fuel_usage_zero_load = piecewisefuel_in[!,"PWFU_Fuel_Usage_Zero_Load_MMBTU_per_h"]
		# construct a matrix for intercept
		intercept_mat = zeros(size(heat_rate_mat))
		# PWFU_Fuel_Usage_MMBTU_per_h is always the intercept of the first segment
		intercept_mat[:,1] = fuel_usage_zero_load

		# create a function to compute intercept if we have more than one segment
		function calculate_intercepts(slope, intercept_1, load_point)
			m, n = size(slope)
			# Initialize the intercepts matrix with zeros
			intercepts = zeros(m, n)
			# The first segment's intercepts should be intercept_1 vector
			intercepts[:, 1] = intercept_1
			# Calculate intercepts for the other segments using the load points (i.e., intersection points)
			for j in 1:n-1
				for i in 1:m
					current_slope = slope[i, j+1]
					previous_slope = slope[i, j]
					# If the current slope is 0, then skip the calculation and return 0
					if current_slope == 0
						intercepts[i, j+1] = 0.0
					else
						# y = a*x + b; => b = y - ax
						# Calculate y-coordinate of the intersection
						y = previous_slope * load_point[i, j] + intercepts[i, j]	
						# determine the new intercept
						b = y - current_slope * load_point[i, j]
						intercepts[i, j+1] = b
					end
				end
			end	 
			return intercepts
		end
		
		if num_segments > 1
			# determine the intercept for the rest of segment if num_segments > 1
			intercept_mat = calculate_intercepts(heat_rate_mat, fuel_usage_zero_load, load_point_mat)
		end

		# create a PWFU_data that contain processed intercept and slope (i.e., heat rate)
		intercept_cols = [Symbol("PWFU_Intercept_", i) for i in 1:num_segments]
		intercept_df = DataFrame(intercept_mat, Symbol.(intercept_cols))
		slope_cols = Symbol.(filter(colname -> startswith(string(colname),"PWFU_Heat_Rate_MMBTU_per_MWh"),names(piecewisefuel_in)))
		slope_df = DataFrame(heat_rate_mat, Symbol.(slope_cols))
		PWFU_data = hcat(slope_df, intercept_df)
		# no need to scale sclope, but intercept should be scaled when parameterscale is on (MMBTU -> billion BTU)
		scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
		PWFU_data[!, intercept_cols] ./= scale_factor

		inputs["slope_cols"] = slope_cols
		inputs["intercept_cols"] = intercept_cols
		inputs["PWFU_data"] = PWFU_data
		inputs["PWFU_Num_Segments"] = num_segments
		inputs["THERM_COMMIT_PWFU"] = intersect(thermal(gen), resource_id.(gen[HAS_PWFU]))

		@info "Piecewise fuel usage data successfully read!"
	end
	return nothing
end

function validate_piecewisefuelusage(heat_rate_mat, load_point_mat)
	# it's possible to construct piecewise fuel consumption with n of heat rate and n-1 of load point. 
	# if a user feed n of heat rate and more than n of load point, throw a error message, and then use 
	# n of heat rate and n-1 load point to construct the piecewise fuel usage fuction  
	if size(heat_rate_mat)[2] < size(load_point_mat)[2]
		@error """ The numbers of heatrate data are less than load points, we found $(size(heat_rate_mat)[2]) of heat rate,
		and $(size(load_point_mat)[2]) of load points. We will just use $(size(heat_rate_mat)[2]) of heat rate, and $(size(heat_rate_mat)[2]-1)
		load point to create piecewise fuel usage
		"""
	end

	# check if values for piecewise fuel consumption make sense. Negative heat rate or load point are not allowed
	if any(heat_rate_mat .< 0) | any(load_point_mat .< 0)
		@error """ Neither heat rate nor load point can be negative
		"""
		error("Invalid inputs detected for piecewise fuel usage")
	end
	# for non-zero values, heat rates and load points should follow an increasing trend 
	if any([any(diff(filter(!=(0), row)) .< 0) for row in eachrow(heat_rate_mat)]) 
		@error """ Heat rates should follow an increasing trend
		"""
		error("Invalid inputs detected for piecewise fuel usage")
	elseif  any([any(diff(filter(!=(0), row)) .< 0) for row in eachrow(load_point_mat)])
		@error """load points should follow an increasing trend
		"""
		error("Invalid inputs detected for piecewise fuel usage")
	end
end

