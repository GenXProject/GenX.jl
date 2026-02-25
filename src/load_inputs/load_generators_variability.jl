@doc raw"""
    load_generators_variability!(setup::Dict, path::AbstractString, inputs::Dict)

Read input parameters related to hourly maximum capacity factors for generators, storage, and flexible demand resources
"""
const PSIP = PowerSystemsInvestmentsPortfolios
function load_generators_variability!(setup::Dict, path::AbstractString, inputs::Dict)

    # Hourly capacity factors
    TDR_directory = joinpath(path, setup["TimeDomainReductionFolder"])
    # if TDR is used, my_dir = TDR_directory, else my_dir = "system"
    my_dir = get_systemfiles_path(setup, TDR_directory, path)

    filename = "Generators_variability.csv"
    gen_var = load_dataframe(joinpath(my_dir, filename))

    all_resources = inputs["RESOURCE_NAMES"]

    existing_variability = names(gen_var)
    for r in all_resources
        if r ∉ existing_variability
            @info "assuming availability of 1.0 for resource $r."
            ensure_column!(gen_var, r, 1.0)
        end
    end

    # Reorder DataFrame to R_ID order
    select!(gen_var, [:Time_Index; Symbol.(all_resources)])

    # Maximum power output and variability of each energy resource
    inputs["pP_Max"] = transpose(Matrix{Float64}(gen_var[1:inputs["T"],
        2:(inputs["G"] + 1)]))

    println(filename * " Successfully Read!")
end

@doc raw"""
    load_generators_variability!(setup::Dict, p::Portfolio, inputs::Dict)

Read input parameters from portfolio related to hourly maximum capacity factors for generators, storage, and flexible demand resources
"""
function load_generators_variability!(setup::Dict, p::Portfolio, inputs::Dict)

    # Collect all resources that need variability data
    resources = Vector{Any}()
    gen = collect(get_technologies(SupplyTechnology, p))
    storage = collect(get_technologies(StorageTechnology, p))
    append!(resources, gen)
    append!(resources, storage)
    
    # Sort resources by ID for consistent ordering
    sort!(resources, by = r -> r.id)
    
    T = inputs["T"]
    G = inputs["G"]

    index_to_technology = inputs["index_to_technology"]

    # Initialize the pP_Max matrix (G resources x T time steps)
    inputs["pP_Max"] = ones(Float64, G, T)
    
    # Create mapping from resource ID to matrix row index
    all_resources = inputs["RESOURCE_NAMES"]
    resource_id_to_index = Dict{Int, Int}()
    for (idx, resource_name) in enumerate(all_resources)
        # Find the resource with this name to get its ID
        for r in resources
            if r.name == resource_name
                resource_id_to_index[r.id] = idx #points from PSIP tech id to resource id
                break
            end
        end
    end
    
    # Track which resources need CSV fallback
    resources_needing_csv = Vector{Any}()
    
    # First pass: Try to load from portfolio time series
    for r in resources
        rid = r.id
        if haskey(resource_id_to_index, rid)
            row_idx = resource_id_to_index[rid]
            
            # Try to get time series data for this resource from portfolio
            portfolio_data_loaded = false
            try
                var_data = Float64[]
                keys_ = IS.get_time_series_keys(r)
                
                if !isempty(keys_)
                    # Extract time series metadata
                    names = [x.name for x in keys_]
                    types = [x.time_series_type for x in keys_]
                    
                    # Filter for capacity_factor time series only
                    capacity_factor_indices = findall(name -> name == "capacity_factor", names)
                    
                    if !isempty(capacity_factor_indices)
                        # Use first capacity_factor time series found
                        cf_idx = capacity_factor_indices[1]
                        cf_name = names[cf_idx]
                        cf_type = types[cf_idx]
                        
                        # Extract time series values for capacity_factor
                        ts_vals = IS.get_time_series_values(cf_type, r, cf_name)
                        if !isempty(ts_vals)
                            var_data = reduce(vcat, ts_vals)
                            
                            # Check if data is valid (length >= T and not all zeros)
                            if length(var_data) >= T && !all(x -> x == 0.0, var_data)
                                # Take only the first T values if longer than T
                                inputs["pP_Max"][row_idx, :] = var_data[1:T]
                                @info "Portfolio capacity factor data loaded for resource $(r.name) (used first $T of $(length(var_data)) values)"
                                portfolio_data_loaded = true
                            elseif length(var_data) >= T && all(x -> x == 0.0, var_data)
                                @info "Portfolio capacity factor data for resource $(r.name) is all zeros. Will try CSV fallback."
                            else
                                @info "Portfolio capacity factor time series too short for resource $(r.name). Expected at least $T, got $(length(var_data)). Will try CSV fallback."
                            end
                        else
                            @info "No portfolio capacity factor time series values found for resource $(r.name). Will try CSV fallback."
                        end
                    else
                        @info "No capacity_factor time series found in portfolio for resource $(r.name). Will try CSV fallback."
                    end
                else
                    @info "No time series keys found in portfolio for resource $(r.name). Will try CSV fallback."
                end
                
            catch e
                @warn "Error loading portfolio time series for resource $(r.name): $e. Will try CSV fallback."
            end
            
            # If portfolio data wasn't loaded successfully, add to CSV fallback list
            if !portfolio_data_loaded
                push!(resources_needing_csv, r)
            end
        else
            @warn "Resource ID $rid not found in resource mapping. Skipping."
        end
    end
    
    # Second pass: CSV fallback for resources that need it
    if !isempty(resources_needing_csv)
        @info "Loading CSV fallback data for $(length(resources_needing_csv)) resources"
        
        # Pre-load CSV data for different technology types
        csv_data_cache = Dict{String, Matrix{Float64}}()
        
        # Define technology type mappings and their CSV files
        tech_mappings = [
            (["wind"], "WIND/DAY_AHEAD_wind.csv"),
            (["pv", "solar"], "PV/DAY_AHEAD_pv.csv"),
            (["rtpv"], "RTPV/DAY_AHEAD_rtpv.csv"),
            (["csp", "thermal_solar"], "CSP/DAY_AHEAD_Natural_Inflow.csv"),
            (["hydro", "hydroelectric"], "Hydro/DAY_AHEAD_hydro.csv")
        ]
        
        # Load CSV data into cache
        for (keywords, csv_file) in tech_mappings
            try
                ts_path = joinpath(dirname(dirname(@__DIR__)), "example_systems", "RTS_Case_Latest", "RTS_Data", "timeseries_data_files", csv_file)
                
                if isfile(ts_path)
                    ts_df = load_dataframe(ts_path)
                    
                    # Extract all numeric columns (excluding Year, Month, Day, Period)
                    numeric_cols = []
                    for col_name in names(ts_df)
                        if col_name ∉ ["Year", "Month", "Day", "Period"] && eltype(ts_df[!, col_name]) <: Union{Number, Missing}
                            push!(numeric_cols, col_name)
                        end
                    end
                    
                    if !isempty(numeric_cols)
                        # Extract data matrix (T x number of columns)
                        data_matrix = Matrix{Float64}(ts_df[1:min(T, nrow(ts_df)), numeric_cols])
                        
                        # Pad with ones if data is shorter than T
                        if size(data_matrix, 1) < T
                            padding = ones(Float64, T - size(data_matrix, 1), size(data_matrix, 2))
                            data_matrix = vcat(data_matrix, padding)
                        end
                        
                        # Store in cache with the first keyword as key
                        csv_data_cache[keywords[1]] = data_matrix
                        @info "Loaded CSV data for $(keywords[1]) from $csv_file: $(size(data_matrix)) matrix"
                    end
                else
                    @warn "CSV file not found: $ts_path"
                end
            catch e
                @warn "Error loading CSV file $csv_file: $e"
            end
        end
        
        # Group resources needing CSV by technology type based on name matching
        resource_groups = Dict{String, Vector{Tuple{Any, Int}}}()
        
        for r in resources_needing_csv
            rid = r.id
            if haskey(resource_id_to_index, rid)
                row_idx = resource_id_to_index[rid]
                resource_name_lower = lowercase(r.name)
                
                # Find matching technology type
                matched_tech = nothing
                for (keywords, _) in tech_mappings
                    for keyword in keywords
                        if occursin(keyword, resource_name_lower)
                            matched_tech = keywords[1]  # Use first keyword as the key
                            break
                        end
                    end
                    if matched_tech !== nothing
                        break
                    end
                end
                
                if matched_tech !== nothing
                    if !haskey(resource_groups, matched_tech)
                        resource_groups[matched_tech] = Vector{Tuple{Any, Int}}()
                    end
                    push!(resource_groups[matched_tech], (r, row_idx))
                else
                    @info "No technology type match found for resource $(r.name). Keeping default availability of 1.0."
                end
            end
        end
        
        # Assign CSV data to resources with repetition as needed
        for (tech_type, resource_list) in resource_groups
            if haskey(csv_data_cache, tech_type)
                data_matrix = csv_data_cache[tech_type]
                num_csv_columns = size(data_matrix, 2)
                num_resources = length(resource_list)
                
                @info "Assigning $tech_type CSV data: $num_resources resources, $num_csv_columns CSV columns"
                
                for (i, (r, row_idx)) in enumerate(resource_list)
                    # Use modulo to cycle through available CSV columns
                    csv_col_idx = ((i - 1) % num_csv_columns) + 1
                    
                    # Assign the time series data
                    inputs["pP_Max"][row_idx, :] = data_matrix[:, csv_col_idx]
                    
                    @info "Assigned $tech_type CSV column $csv_col_idx to resource $(r.name) (row $row_idx)"
                end
            else
                @warn "No CSV data available for technology type: $tech_type"
            end
        end
    end

    println("Variable Generation Data Successfully Read!")
end