const UTES_COP_VALID_TECHNOLOGIES = ["dry_cooler", "chiller"]
const UTES_COP_PURPOSES = ["data_center", "reservoir"]
const UTES_COP_PURPOSE_FILENAMES = Dict(
    "data_center" => "UTES_COP_Data_Center.csv",
    "reservoir" => "UTES_COP_Reservoir.csv",
)

function normalize_utes_cop_technology(tech)
    normalized = lowercase(string(tech))
    normalized = replace(normalized, "-" => "_")
    normalized = replace(normalized, " " => "_")
    return normalized
end

function validate_and_parse_utes_cop!(cop_df, filename::AbstractString, inputs::Dict)
    required_cols = ["Technology", "Deg_Celsius", "Efficiency"]
    for col in required_cols
        if col ∉ names(cop_df)
            error("$(filename) is missing required column: $col")
        end
    end

    if any(cop_df.Efficiency .<= 0)
        error("$(filename) contains non-positive Efficiency values. All COP values must be positive.")
    end

    cop_df.Technology = map(cop_df.Technology) do tech
        normalize_utes_cop_technology(tech)
    end

    for tech in unique(cop_df.Technology)
        if tech ∉ UTES_COP_VALID_TECHNOLOGIES
            error("$(filename) contains invalid Technology value: '$tech'. Valid values are: $(UTES_COP_VALID_TECHNOLOGIES)")
        end
    end

    has_resource_col = "Resource" in names(cop_df)
    if has_resource_col && haskey(inputs, "RESOURCES") && haskey(inputs, "UTES")
        gen = inputs["RESOURCES"]
        UTES = inputs["UTES"]
        utes_resource_names = Set(resource_name(gen[y]) for y in UTES)
        csv_resource_names = Set(cop_df.Resource)

        missing_resources = setdiff(utes_resource_names, csv_resource_names)
        if !isempty(missing_resources)
            error("$(filename) has a Resource column but is missing entries for UTES resources: $(collect(missing_resources))")
        end
    end

    lookup = Dict{String, Any}()
    for tech in UTES_COP_VALID_TECHNOLOGIES
        tech_df = filter(row -> row.Technology == tech, cop_df)

        if nrow(tech_df) == 0
            lookup[tech] = nothing
            continue
        end

        if has_resource_col
            resource_lookup = Dict{String, Tuple{Vector{Float64}, Vector{Float64}}}()
            for resource in unique(tech_df.Resource)
                res_df = filter(row -> row.Resource == resource, tech_df)
                sort!(res_df, :Deg_Celsius)
                temps = collect(Float64, res_df.Deg_Celsius)
                cops = collect(Float64, res_df.Efficiency)
                resource_lookup[resource] = (temps, cops)
            end
            lookup[tech] = resource_lookup
        else
            sort!(tech_df, :Deg_Celsius)
            temps = collect(Float64, tech_df.Deg_Celsius)
            cops = collect(Float64, tech_df.Efficiency)
            lookup[tech] = (temps, cops)
        end
    end

    return lookup
end

function maybe_load_utes_cop_lookup(file_path::AbstractString, inputs::Dict)
    if !isfile(file_path)
        return nothing
    end

    cop_df = load_dataframe(file_path)
    lookup = validate_and_parse_utes_cop!(cop_df, basename(file_path), inputs)
    println("$(basename(file_path)) Successfully Read!")
    return lookup
end

@doc raw"""
    load_utes_cop!(setup::Dict, resources_path::AbstractString, inputs::Dict)

Load optional UTES COP (Coefficient of Performance) lookup tables from the resources folder.

Supported files:
- `UTES_COP.csv`: legacy lookup used for both direct data center cooling and reservoir cooling
- `UTES_COP_Data_Center.csv`: purpose-specific lookup for direct data center cooling
- `UTES_COP_Reservoir.csv`: purpose-specific lookup for reservoir / tertiary-loop cooling

The CSV files must contain the following columns:
- `Technology`: Either "dry_cooler" or "chiller" (case-insensitive, accepts "dry-cooler", "dry cooler" as alternatives)
- `Deg_Celsius`: Ambient temperature in degrees Celsius
- `Efficiency`: COP value at that temperature (must be positive)

Optional column:
- `Resource`: Resource name. If present, COP values are specified per-resource and all UTES resources must be listed.

Purpose-specific files take precedence over `UTES_COP.csv`. If a purpose-specific file is absent,
the legacy lookup is used for that purpose. This preserves legacy behavior when only `UTES_COP.csv`
is present or when direct and reservoir COP values are identical.
"""
function load_utes_cop!(setup::Dict, resources_path::AbstractString, inputs::Dict)
    legacy_lookup = maybe_load_utes_cop_lookup(joinpath(resources_path, "UTES_COP.csv"), inputs)
    data_center_lookup = maybe_load_utes_cop_lookup(joinpath(resources_path, UTES_COP_PURPOSE_FILENAMES["data_center"]), inputs)
    reservoir_lookup = maybe_load_utes_cop_lookup(joinpath(resources_path, UTES_COP_PURPOSE_FILENAMES["reservoir"]), inputs)

    inputs["UTES_COP_Lookup"] = legacy_lookup
    inputs["UTES_COP_Lookups"] = Dict(
        "data_center" => data_center_lookup === nothing ? legacy_lookup : data_center_lookup,
        "reservoir" => reservoir_lookup === nothing ? legacy_lookup : reservoir_lookup,
    )

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
Uses purpose-specific lookup table interpolation if available, otherwise uses default equations.
Stores results in legacy keys `inputs["COP_DC"]` and `inputs["COP_Chiller"]` for backward compatibility,
and also stores purpose-specific keys for direct data center and reservoir cooling.

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
    
    lookups_by_purpose = get(inputs, "UTES_COP_Lookups", Dict(
        "data_center" => get(inputs, "UTES_COP_Lookup", nothing),
        "reservoir" => get(inputs, "UTES_COP_Lookup", nothing),
    ))

    function uses_lookup(purpose::String, technology::String)
        lookup = get(lookups_by_purpose, purpose, nothing)
        return lookup !== nothing && get(lookup, technology, nothing) !== nothing
    end

    for purpose in UTES_COP_PURPOSES
        if uses_lookup(purpose, "dry_cooler")
            println("Dry cooler $(purpose) COP: using lookup table")
        else
            println("Dry cooler $(purpose) COP: using default equation")
        end

        if uses_lookup(purpose, "chiller")
            println("Chiller $(purpose) COP: using lookup table")
        else
            println("Chiller $(purpose) COP: using default equation")
        end
    end

    COP_DC = Dict{Int, Vector{Float64}}()
    COP_Chiller = Dict{Int, Vector{Float64}}()
    COP_DC_Data_Center = Dict{Int, Vector{Float64}}()
    COP_DC_Reservoir = Dict{Int, Vector{Float64}}()
    COP_Chiller_Data_Center = Dict{Int, Vector{Float64}}()
    COP_Chiller_Reservoir = Dict{Int, Vector{Float64}}()

    warning_flags = Dict(
        (purpose, technology, bound) => Ref(false)
        for purpose in UTES_COP_PURPOSES,
            technology in UTES_COP_VALID_TECHNOLOGIES,
            bound in ("low", "high")
    )

    function get_lookup_tuple(purpose::String, technology::String, resource_nm::AbstractString)
        lookup = get(lookups_by_purpose, purpose, nothing)
        if lookup === nothing
            return nothing
        end

        tech_lookup = get(lookup, technology, nothing)
        if tech_lookup === nothing
            return nothing
        elseif tech_lookup isa Dict
            return get(tech_lookup, String(resource_nm), nothing)
        else
            return tech_lookup
        end
    end

    function compute_default_cop(y, ambient_temp::Float64, technology::String)
        if technology == "dry_cooler"
            dc_numerator = gen[y].temp_data_center_out_c - gen[y].approach_temp_dry_cooler - ambient_temp
            if dc_numerator > 0
                return 1000 * 1.2 * gen[y].fan_coefficient_dry_cooler * 1.013 *
                    dc_numerator /
                    (gen[y].fractional_pressure_dry_cooler_fan * gen[y].ambient_pressure_pa)
            end
            return 1e-6
        end

        denominator = ambient_temp + gen[y].temp_lift_chiller_c +
            gen[y].temp_approach_chiller_c - gen[y].temp_evaporator_chiller_c
        if denominator > 0
            return gen[y].irreversibility_factor_chiller *
                (gen[y].temp_evaporator_chiller_c + 273.15) / denominator
        end
        return 1e-6
    end

    function compute_cop_series(y, resource_nm::AbstractString, zone::Int, purpose::String, technology::String)
        cop_vec = Vector{Float64}(undef, T)
        lookup_tuple = get_lookup_tuple(purpose, technology, resource_nm)

        for t in 1:T
            ambient_temp = pAmbientTemp[zone, t]
            if lookup_tuple !== nothing
                temps, cops = lookup_tuple
                warned = Ref(warning_flags[(purpose, technology, "low")][] || warning_flags[(purpose, technology, "high")][])
                cop_vec[t] = interpolate_cop(ambient_temp, temps, cops, warned, "$(technology)_$(purpose)")
                if warned[] && !warning_flags[(purpose, technology, "low")][] && !warning_flags[(purpose, technology, "high")][]
                    if ambient_temp < temps[1]
                        warning_flags[(purpose, technology, "low")][] = true
                    else
                        warning_flags[(purpose, technology, "high")][] = true
                    end
                end
            else
                cop_vec[t] = compute_default_cop(y, ambient_temp, technology)
            end
        end

        if any(cop_vec .<= 0)
            error("Computed $(technology) COP contains non-positive values for resource $resource_nm and purpose $purpose. Check input parameters or lookup tables.")
        end

        return cop_vec
    end
    
    for y in UTES
        resource_nm = resource_name(gen[y])
        zone = gen[y].zone
        
        cop_dc_data_center_vec = compute_cop_series(y, resource_nm, zone, "data_center", "dry_cooler")
        cop_dc_reservoir_vec = compute_cop_series(y, resource_nm, zone, "reservoir", "dry_cooler")
        cop_chiller_data_center_vec = compute_cop_series(y, resource_nm, zone, "data_center", "chiller")
        cop_chiller_reservoir_vec = compute_cop_series(y, resource_nm, zone, "reservoir", "chiller")

        COP_DC[y] = copy(cop_dc_data_center_vec)
        COP_Chiller[y] = copy(cop_chiller_data_center_vec)
        COP_DC_Data_Center[y] = cop_dc_data_center_vec
        COP_DC_Reservoir[y] = cop_dc_reservoir_vec
        COP_Chiller_Data_Center[y] = cop_chiller_data_center_vec
        COP_Chiller_Reservoir[y] = cop_chiller_reservoir_vec
    end
    
    inputs["COP_DC"] = COP_DC
    inputs["COP_Chiller"] = COP_Chiller
    inputs["COP_DC_Data_Center"] = COP_DC_Data_Center
    inputs["COP_DC_Reservoir"] = COP_DC_Reservoir
    inputs["COP_Chiller_Data_Center"] = COP_Chiller_Data_Center
    inputs["COP_Chiller_Reservoir"] = COP_Chiller_Reservoir
    
    return nothing
end
