@doc raw"""
    load_utes_cop!(setup::Dict, resources_path::AbstractString, inputs::Dict)

Load optional UTES COP (Coefficient of Performance) lookup table from `UTES_COP.csv` in the resources folder.
If the file exists, it is used to determine COP values for dry coolers and/or chillers via linear interpolation.
If the file does not exist, or if a technology type is missing from the file, the default equation-based COP calculation is used.

The CSV file must contain the following columns:
- `Technology`: Either "dry_cooler" or "chiller" (case-insensitive, accepts "dry-cooler", "dry cooler" as alternatives)
- `Deg_Celsius`: Ambient temperature in degrees Celsius
- `Efficiency`: COP value at that temperature (must be positive)

Optional column:
- `Resource`: Resource name. If present, COP values are specified per-resource and all UTES resources must be listed.
"""
function load_utes_cop!(setup::Dict, resources_path::AbstractString, inputs::Dict)
    cop_file = joinpath(resources_path, "UTES_COP.csv")
    
    if !isfile(cop_file)
        inputs["UTES_COP_Lookup"] = nothing
        return nothing
    end
    
    # Load the COP data
    cop_df = load_dataframe(cop_file)
    
    # Validate required columns
    required_cols = ["Technology", "Deg_Celsius", "Efficiency"]
    for col in required_cols
        if col ∉ names(cop_df)
            error("UTES_COP.csv is missing required column: $col")
        end
    end
    
    # Validate all Efficiency values are positive
    if any(cop_df.Efficiency .<= 0)
        error("UTES_COP.csv contains non-positive Efficiency values. All COP values must be positive.")
    end
    
    # Normalize Technology column: lowercase, replace "-" and " " with "_"
    cop_df.Technology = map(cop_df.Technology) do tech
        normalized = lowercase(string(tech))
        normalized = replace(normalized, "-" => "_")
        normalized = replace(normalized, " " => "_")
        return normalized
    end
    
    # Validate Technology values
    valid_technologies = ["dry_cooler", "chiller"]
    for tech in unique(cop_df.Technology)
        if tech ∉ valid_technologies
            error("UTES_COP.csv contains invalid Technology value: '$tech'. Valid values are: $valid_technologies (case-insensitive, 'dry-cooler' and 'dry cooler' are also accepted)")
        end
    end
    
    # Check if Resource column exists
    has_resource_col = "Resource" in names(cop_df)
    
    # If Resource column exists, validate all UTES resources are present
    if has_resource_col && haskey(inputs, "RESOURCES") && haskey(inputs, "UTES")
        gen = inputs["RESOURCES"]
        UTES = inputs["UTES"]
        utes_resource_names = Set(resource_name(gen[y]) for y in UTES)
        csv_resource_names = Set(cop_df.Resource)
        
        missing_resources = setdiff(utes_resource_names, csv_resource_names)
        if !isempty(missing_resources)
            error("UTES_COP.csv has a Resource column but is missing entries for UTES resources: $(collect(missing_resources))")
        end
    end
    
    # Parse and store lookup tables
    # Structure: Dict("dry_cooler" => Dict(resource_name => (temps, cops)), ...)
    # If no Resource column: Dict("dry_cooler" => (temps, cops), ...)
    lookup = Dict{String, Any}()
    
    for tech in valid_technologies
        tech_df = filter(row -> row.Technology == tech, cop_df)
        
        if nrow(tech_df) == 0
            lookup[tech] = nothing
            continue
        end
        
        if has_resource_col
            # Per-resource lookup
            resource_lookup = Dict{String, Tuple{Vector{Float64}, Vector{Float64}}}()
            for resource in unique(tech_df.Resource)
                res_df = filter(row -> row.Resource == resource, tech_df)
                # Sort by temperature
                sort!(res_df, :Deg_Celsius)
                temps = collect(Float64, res_df.Deg_Celsius)
                cops = collect(Float64, res_df.Efficiency)
                resource_lookup[resource] = (temps, cops)
            end
            lookup[tech] = resource_lookup
        else
            # Global lookup for all resources
            sort!(tech_df, :Deg_Celsius)
            temps = collect(Float64, tech_df.Deg_Celsius)
            cops = collect(Float64, tech_df.Efficiency)
            lookup[tech] = (temps, cops)
        end
    end
    
    inputs["UTES_COP_Lookup"] = lookup
    println("UTES_COP.csv Successfully Read!")
    return nothing
end

@doc raw"""
    interpolate_cop(temp::Float64, temps::Vector{Float64}, cops::Vector{Float64}, 
                    warned_ref::Ref{Bool}, tech_name::String)

Perform linear interpolation to find COP value at a given ambient temperature.
If temperature is outside the lookup table range, clamp to boundary value and warn once.

# Arguments
- `temp`: Ambient temperature to interpolate at
- `temps`: Sorted vector of temperatures from lookup table  
- `cops`: Vector of COP values corresponding to temperatures
- `warned_ref`: Reference to boolean flag for tracking if warning has been issued
- `tech_name`: Technology name for warning message

# Returns
- Interpolated (or clamped) COP value
"""
function interpolate_cop(temp::Float64, temps::Vector{Float64}, cops::Vector{Float64}, 
                         warned_ref::Ref{Bool}, tech_name::String)
    n = length(temps)
    
    # Handle edge cases with clamping
    if temp <= temps[1]
        if !warned_ref[] && temp < temps[1]
            @warn "Ambient temperature $(round(temp, digits=2))C is below the minimum temperature $(round(temps[1], digits=2))C in UTES_COP.csv for $tech_name. Clamping to boundary COP value."
            warned_ref[] = true
        end
        return cops[1]
    end
    
    if temp >= temps[n]
        if !warned_ref[] && temp > temps[n]
            @warn "Ambient temperature $(round(temp, digits=2))C is above the maximum temperature $(round(temps[n], digits=2))C in UTES_COP.csv for $tech_name. Clamping to boundary COP value."
            warned_ref[] = true
        end
        return cops[n]
    end
    
    # Binary search to find bracketing indices
    lo, hi = 1, n
    while hi - lo > 1
        mid = (lo + hi) ÷ 2
        if temps[mid] <= temp
            lo = mid
        else
            hi = mid
        end
    end
    
    # Linear interpolation
    t1, t2 = temps[lo], temps[hi]
    c1, c2 = cops[lo], cops[hi]
    
    cop = c1 + (c2 - c1) * (temp - t1) / (t2 - t1)
    
    return cop
end

@doc raw"""
    compute_utes_cop!(inputs::Dict, setup::Dict)

Pre-compute COP values for all UTES resources and time steps.
Uses lookup table interpolation if available, otherwise uses default equations.
Stores results in `inputs["COP_DC"]` and `inputs["COP_Chiller"]` as Dict{Int, Vector{Float64}}.

# Arguments
- `inputs`: Dictionary containing input data including UTES resources and ambient temperature
- `setup`: Dictionary containing setup parameters
"""
function compute_utes_cop!(inputs::Dict, setup::Dict)
    # Check if CoolingDemand is enabled and UTES resources exist
    if setup["CoolingDemand"] != 1 || !haskey(inputs, "UTES") || isempty(inputs["UTES"])
        return nothing
    end
    
    gen = inputs["RESOURCES"]
    T = inputs["T"]
    UTES = inputs["UTES"]
    pAmbientTemp = inputs["pAmbientTemp"]
    
    lookup = get(inputs, "UTES_COP_Lookup", nothing)
    
    # Determine which method to use for each technology
    use_lookup_dc = false
    use_lookup_chiller = false
    
    if lookup !== nothing
        use_lookup_dc = lookup["dry_cooler"] !== nothing
        use_lookup_chiller = lookup["chiller"] !== nothing
    end
    
    # Print status messages
    if use_lookup_dc
        println("Dry cooler COP: using lookup table from UTES_COP.csv")
    else
        println("Dry cooler COP: using default equation")
    end
    
    if use_lookup_chiller
        println("Chiller COP: using lookup table from UTES_COP.csv")
    else
        println("Chiller COP: using default equation")
    end
    
    # Initialize storage
    COP_DC = Dict{Int, Vector{Float64}}()
    COP_Chiller = Dict{Int, Vector{Float64}}()
    
    # Warning flags (one per technology, not per resource)
    warned_dc_low = Ref(false)
    warned_dc_high = Ref(false)
    warned_chiller_low = Ref(false)
    warned_chiller_high = Ref(false)
    
    for y in UTES
        resource_nm = resource_name(gen[y])
        zone = gen[y].zone
        
        cop_dc_vec = Vector{Float64}(undef, T)
        cop_chiller_vec = Vector{Float64}(undef, T)
        
        # Get lookup tables for this resource if available
        dc_lookup = nothing
        chiller_lookup = nothing
        
        if use_lookup_dc
            dc_data = lookup["dry_cooler"]
            if dc_data isa Dict  # Per-resource lookup
                dc_lookup = get(dc_data, resource_nm, nothing)
            else  # Global lookup
                dc_lookup = dc_data
            end
        end
        
        if use_lookup_chiller
            chiller_data = lookup["chiller"]
            if chiller_data isa Dict  # Per-resource lookup
                chiller_lookup = get(chiller_data, resource_nm, nothing)
            else  # Global lookup
                chiller_lookup = chiller_data
            end
        end
        
        for t in 1:T
            ambient_temp = pAmbientTemp[zone, t]
            
            # Compute dry cooler COP
            if dc_lookup !== nothing
                temps, cops = dc_lookup
                # Use combined warning ref for both low and high
                warned_dc = Ref(warned_dc_low[] || warned_dc_high[])
                cop_dc_vec[t] = interpolate_cop(ambient_temp, temps, cops, warned_dc, "dry_cooler")
                if warned_dc[] && !warned_dc_low[] && !warned_dc_high[]
                    if ambient_temp < temps[1]
                        warned_dc_low[] = true
                    else
                        warned_dc_high[] = true
                    end
                end
            else
                # Default equation from dry_cooler.jl
                # Calculate numerator for COP check
                dc_numerator = gen[y].temp_data_center_out_c - gen[y].approach_temp_dry_cooler - ambient_temp
                if dc_numerator > 0
                    cop_dc_vec[t] = 1000 * 1.2 * gen[y].fan_coefficient_dry_cooler * 1.013 * 
                        dc_numerator / 
                        (gen[y].fractional_pressure_dry_cooler_fan * gen[y].ambient_pressure_pa)
                else
                    # Dry cooler cannot operate given constraints (Effective COP -> 0)
                    cop_dc_vec[t] = 1e-6
                end
            end
            
            # Compute chiller COP
            if chiller_lookup !== nothing
                temps, cops = chiller_lookup
                warned_chiller = Ref(warned_chiller_low[] || warned_chiller_high[])
                cop_chiller_vec[t] = interpolate_cop(ambient_temp, temps, cops, warned_chiller, "chiller")
                if warned_chiller[] && !warned_chiller_low[] && !warned_chiller_high[]
                    if ambient_temp < temps[1]
                        warned_chiller_low[] = true
                    else
                        warned_chiller_high[] = true
                    end
                end
            else
                # Default equation from chiller.jl
                denominator = ambient_temp + gen[y].temp_lift_chiller_c + 
                    gen[y].temp_approach_chiller_c - gen[y].temp_evaporator_chiller_c
                if denominator > 0
                    cop_chiller_vec[t] = gen[y].irreversibility_factor_chiller * 
                        (gen[y].temp_evaporator_chiller_c + 273.15) / denominator
                else
                    # Chiller not needed or in invalid range (Low ambient)
                    # Set to epsilon so Dry Cooler (with high COP) wins
                    cop_chiller_vec[t] = 1e-6
                end
            end
        end
        
        # Validate COP values are positive
        if any(cop_dc_vec .<= 0)
            error("Computed dry cooler COP contains non-positive values for resource $resource_nm. Check input parameters or lookup table.")
        end
        if any(cop_chiller_vec .<= 0)
            error("Computed chiller COP contains non-positive values for resource $resource_nm. Check input parameters or lookup table.")
        end
        
        COP_DC[y] = cop_dc_vec
        COP_Chiller[y] = cop_chiller_vec
    end
    
    inputs["COP_DC"] = COP_DC
    inputs["COP_Chiller"] = COP_Chiller
    
    return nothing
end
